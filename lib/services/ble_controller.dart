import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../main.dart';
import 'auto_subscribe.dart';
import 'get_info.dart';
import '../models/current_info.dart';
import 'artwork_service.dart';
import 'package:permission_handler/permission_handler.dart';

class BleController {
  static final BleController _instance = BleController._internal();
  factory BleController() => _instance;
  BleController._internal();

  Timer? _artworkDebounceTimer; //timer for artwork fix.

  BluetoothDevice? connectedDevice;
  final Map<String, StreamSubscription> _notificationSubscriptions = {};

  final Map<String, Map<String, String>> charValues = {};
  final Map<String, String> trackTitles = {};

  // Flag to prevent recursive infinite loops during metadata updates
  bool _isUpdating = false;

  // --- BATTERY EXEMPTOR ---

  Future<void> requestBatteryOptimizationOff() async {
    // 1. Check if we already have the permission
    var status = await Permission.ignoreBatteryOptimizations.status;

    if (status.isDenied) {
      print("Requesting to ignore battery optimizations...");
      // 2. This will open the system dialog asking the user to "Allow"
      await Permission.ignoreBatteryOptimizations.request();
    } else {
      print("Battery optimizations already disabled.");
    }
  }

  // --- NOTIFICATION METHODS ---
  void _updateAndroidNotification(MediaPlayerInfo info, String title, String artist, String url) {
    audioHandler.updateMetadata(
      title: title,
      artist: artist,
      album: info.albumName.isNotEmpty ? info.albumName.first.toString() : "Unknown",
      duration: Duration(seconds: (info.duration.isNotEmpty ? double.tryParse(info.duration.first.toString()) ?? 0 : 0).toInt()),
      artworkUrl: url,
    );
  }

  // --- CORE BLUETOOTH METHODS ---

  Stream<BluetoothAdapterState> get adapterState => FlutterBluePlus.adapterState;

  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    if (await FlutterBluePlus.isSupported == false) return;
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
    }
    await FlutterBluePlus.startScan(timeout: timeout);
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Future<void> connectToDevice(BluetoothDevice device) async {
    await stopScan();

    try {
      // Attempt connection with a timeout
      await device.disconnect();
      await device.connect(
          autoConnect: false,
          timeout: const Duration(seconds: 10),
          license: License.nonprofit
      );
      connectedDevice = device;
      print("Successfully connected to ${device.remoteId}");

    } catch (e) {
      print("Connection error: $e");

      // Check if it's the 133 error (or any other GATT failure)
      if (e.toString().contains('133') || e.toString().contains('GATT_ERROR')) {
        print("GATT 133 detected. Cleaning up and closing GATT...");

        // THIS IS THE FIX: Fully disconnect and close the GATT bridge
        await device.disconnect();

        // Optional: Wait a moment before allowing the user to try again
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Re-throw so the UI can show the error snackbar
      rethrow;
    }
  }

Future<void> disconnectDevice(BluetoothDevice device) async {
  for (var sub in _notificationSubscriptions.values) {
    await sub.cancel();
  }
  _notificationSubscriptions.clear();

  //Stop the Android Media Service and remove notification
  await audioHandler.stop();

  // Reset the subscription flag
  AutoSubscribe.reset();

  await device.disconnect();
  connectedDevice = null;
}

  Future<List<BluetoothService>> discoverServices(BluetoothDevice device) async {
    return await device.discoverServices();
  }

  Future<List<int>> readCharacteristic(BluetoothCharacteristic characteristic) async {
    return await characteristic.read();
  }

  Future<void> writeCharacteristic(BluetoothCharacteristic characteristic, List<int> bytes) async {
    bool withoutResponse = characteristic.properties.writeWithoutResponse && !characteristic.properties.write;
    await characteristic.write(bytes, withoutResponse: withoutResponse);
  }

  Future<void> toggleNotification(BluetoothCharacteristic characteristic, Function(List<int>) onDataCallback) async {
    final charKey = characteristic.uuid.toString();

    if (characteristic.isNotifying) {
      await characteristic.setNotifyValue(false);
      await _notificationSubscriptions[charKey]?.cancel();
      _notificationSubscriptions.remove(charKey);
    } else {
      await characteristic.setNotifyValue(true);
      final subscription = characteristic.lastValueStream.listen((value) {
        onDataReceived(charKey, value);
        onDataCallback(value);
      });
      _notificationSubscriptions[charKey] = subscription;
    }
  }

  // --- AMS LOGIC ---

  /// Handles refreshing metadata after a change is detected
  Future<void> handleUpdate() async {
    if (_isUpdating) return;
    _isUpdating = true;
    try {
      await InfoService().writeToAMS();
    } finally {
      _isUpdating = false;
    }
  }

  /// Entry point for all data received from the iPhone via notifications
  void onDataReceived(String charUuid, List<int> rawValue) {
    // 1. Initial Validation: AMS responses are always > 3 bytes (3 bytes header + data)
    if (rawValue.length <= 3) return;

    final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];
    if (playerInfo == null) return;

    // 2. Parse AMS Entity Updates

    // --- ENTITY 0: PLAYER (Volume & Playback) ---
    if (rawValue[0] == 0) {
      if (rawValue[1] == 2) { // Attribute 2: Volume
        String curVol = utf8.decode(rawValue.skip(3).toList(), allowMalformed: true);
        curVol = curVol.replaceAll(RegExp(r'\x00'), '').trim();
        double? parsedVol = double.tryParse(curVol);
        if (parsedVol != null) {
          playerInfo.volume = parsedVol;
          CurrentInfoString.updateTrigger.value++;
        }
      } else if (rawValue[1] == 1) { // Attribute 1: Playback Info
        String info = utf8.decode(rawValue.skip(3).toList());
        List<String> parts = info.split(',');
        if (parts.length >= 3) {
          playerInfo.isPlaying = parts[0] == "1";
          double timeFromAMD = double.tryParse(parts[2]) ?? 0.0;
          playerInfo.elapsedTime = timeFromAMD; // Latency compensation
          CurrentInfoString.updateTrigger.value++;
        }
      }
    }

    // --- ENTITY 1: QUEUE (Shuffle & Repeat) ---
    else if (rawValue[0] == 1) {
      String info = utf8.decode(rawValue.skip(3).toList());
      int mode = int.tryParse(info) ?? 0;
      if (rawValue[1] == 2) { // Attribute 2: Shuffle
        playerInfo.shuffleMode = mode;
      } else if (rawValue[1] == 3) { // Attribute 3: Repeat
        playerInfo.repeatMode = mode;
      }
      CurrentInfoString.updateTrigger.value++;
    }

    // --- ENTITY 2: TRACK INFO (Metadata) ---
    else if (rawValue[0] == 2) {
      String decoded = utf8.decode(rawValue.skip(3).toList(), allowMalformed: true).trim();
      decoded = decoded.replaceAll(RegExp(r'\x00'), '');
      if (decoded.isEmpty) return;

      bool textChanged = false;

      switch (rawValue[1]) {
        case 0: // Artist Name
          if (playerInfo.artistName.isEmpty || playerInfo.artistName.first != decoded) {
            playerInfo.artistName = [decoded];
            textChanged = true;
          }
          break;

        case 2: // Track Title
          if (playerInfo.trackName.isEmpty || playerInfo.trackName.first != decoded) {
            playerInfo.trackName = [decoded];
            textChanged = true;
          }
          break;

        case 3: // Duration
          playerInfo.duration = [decoded];
          break;
      }

      if (textChanged) {
        // 1. UI Feedback: Clear art and show blur immediately
        playerInfo.artworkURL = "";
        CurrentInfoString.isFetching.value = true;
        CurrentInfoString.updateTrigger.value++;

        // 2. Restart the "Settling" timer
        _artworkDebounceTimer?.cancel();
        _artworkDebounceTimer = Timer(const Duration(milliseconds: 600), () {

          // 3. This code runs only after BLE packets have stopped arriving
          String artist = playerInfo.artistName.isNotEmpty ? playerInfo.artistName.first.toString() : "";
          String title = playerInfo.trackName.isNotEmpty ? playerInfo.trackName.first.toString() : "";

          if (title.isNotEmpty) {
            print("Metadata settled. Fetching artwork for: $title by $artist");
            fetchArtwork(artist, title).then((url) {
              if (url.isNotEmpty) playerInfo.artworkURL = url;

              // Update notification and clean up
              _updateAndroidNotification(playerInfo, title, artist, url);
              CurrentInfoString.isFetching.value = false;
              CurrentInfoString.updateTrigger.value++;
            });
          }
        });
      }
    }

    // 3. Update Debug Map
    String formattedValue = rawValue.join(',');
    String existingCurrent = charValues[charUuid]?['current'] ?? '';

    if (existingCurrent != formattedValue && isFixingDelay == 0) {
      charValues[charUuid] = {
        'prev': existingCurrent,
        'current': formattedValue,
      };

      // Auto-trigger a refresh if anything actually changed
      if (existingCurrent.isNotEmpty) {
        handleUpdate();
      }
    }

    //  FOR NOTIF BTW:
    // When Title/Artist/Art changes:
    audioHandler.updateMetadata(
      title: playerInfo.trackName.isNotEmpty ? playerInfo.trackName.first.toString() : "Unknown",
      artist: playerInfo.artistName.isNotEmpty ? playerInfo.artistName.first.toString() : "Unknown",
      album: playerInfo.albumName.isNotEmpty ? playerInfo.albumName.first.toString() : "Unknown",
      duration: Duration(seconds: (playerInfo.duration.isNotEmpty ? double.tryParse(playerInfo.duration.first.toString()) ?? 0 : 0).toInt()),
      artworkUrl: playerInfo.artworkURL,
    );

    // When Playback Info changes:
    audioHandler.updatePlaybackState(
      playerInfo.isPlaying,
      Duration(seconds: playerInfo.elapsedTime.toInt()),
    );

  }
}