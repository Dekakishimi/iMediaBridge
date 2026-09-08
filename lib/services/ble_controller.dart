import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../main.dart';
import 'auto_subscribe.dart';
import 'get_info.dart';
import '../models/current_info.dart';
import 'artwork_service.dart';

class BleController {
  static final BleController _instance = BleController._internal();
  factory BleController() => _instance;
  BleController._internal();

  BluetoothDevice? connectedDevice;
  final Map<String, StreamSubscription> _notificationSubscriptions = {};

  final Map<String, Map<String, String>> charValues = {};
  final Map<String, String> trackTitles = {};

  // Flag to prevent recursive infinite loops during metadata updates
  bool _isUpdating = false;

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
    await device.connect(autoConnect: false, timeout: const Duration(seconds: 10), license: License.nonprofit);
    connectedDevice = device;
  }

Future<void> disconnectDevice(BluetoothDevice device) async {
  // ... existing cleanup ...

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
          playerInfo.elapsedTime = timeFromAMD + 0.5; // Latency compensation
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

      bool changed = false;
      switch (rawValue[1]) {
        case 0: // Artist
          playerInfo.artistName = [decoded];
          changed = true;
          break;
        case 1: // Album
          playerInfo.albumName = [decoded];
          break;
        case 2: // Title
          playerInfo.trackName = [decoded];
          changed = true;

          // Trigger External Artwork Search
          String artist = playerInfo.artistName.isNotEmpty ? playerInfo.artistName.first.toString() : "";
          fetchArtwork(artist, decoded).then((url) {
            if (url.isNotEmpty) {
              playerInfo.artworkURL = url;
              CurrentInfoString.updateTrigger.value++;
              CurrentInfoString.isFetching.value = false; // End loading state
            }
          });
          break;
        case 3: // Duration
          playerInfo.duration = [decoded];
          changed = true;
          break;
      }
      if (changed) CurrentInfoString.updateTrigger.value++;
    }

    // 3. Update Debug Map
    String formattedValue = rawValue.join(',');
    String existingCurrent = charValues[charUuid]?['current'] ?? '';

    if (existingCurrent != formattedValue) {
      charValues[charUuid] = {
        'prev': existingCurrent,
        'current': formattedValue,
      };

      // Auto-trigger a refresh if anything actually changed
      handleUpdate();
    }

    // When Title/Artist/Art changes:
    audioHandler.updateMetadata(
      title: playerInfo.trackName.first.toString(),
      artist: playerInfo.artistName.first.toString(),
      album: playerInfo.albumName.first.toString(),
      duration: Duration(seconds: (double.tryParse(playerInfo.duration.first.toString()) ?? 0).toInt()),
      artworkUrl: playerInfo.artworkURL,
    );

// When Playback Info changes:
    audioHandler.updatePlaybackState(
      playerInfo.isPlaying,
      Duration(seconds: playerInfo.elapsedTime.toInt()),
    );

  }
}