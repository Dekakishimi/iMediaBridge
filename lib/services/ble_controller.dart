import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'get_info.dart';
import '../models/current_info.dart';
import 'artwork_service.dart';

class BleController {
  //memory leak fix
  bool _isUpdating = false; // Add this flag

  Future<void> handleUpdate() async {
    if (_isUpdating) return; // Exit if an update is already running

    _isUpdating = true;
    try {
      await InfoService().writeToAMS();
    } finally {
      _isUpdating = false; // Always reset the flag, even if it fails
    }
  }

  // ABANDONED AT THE MOMENT //
  // //initializing variable for the map
  // String currentVal = '';
  // String previousVal = '';

  // Singleton pattern for easy access
  static final BleController _instance = BleController._internal();

  factory BleController() => _instance;

  BleController._internal();

  BluetoothDevice? connectedDevice;
  final Map<String, StreamSubscription> _notificationSubscriptions = {};

  // Check if Bluetooth is supported and enabled
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  // Start scanning for nearby devices
  Future<void> startScan(
      {Duration timeout = const Duration(seconds: 15)}) async {
    if (await FlutterBluePlus.isSupported == false) return;

    // Ensure adapter is ON before scanning
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
    }

    await FlutterBluePlus.startScan(timeout: timeout);
  }

  // Stop active scan
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  // Stream of scan results
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  // Connect to a target device
  Future<void> connectToDevice(BluetoothDevice device) async {
    await stopScan();
    await device.connect(autoConnect: false,
        timeout: const Duration(seconds: 10),
        license: License.nonprofit);
    connectedDevice = device;
  }

  // Disconnect from current device
  Future<void> disconnectDevice(BluetoothDevice device) async {
    // Cancel active notification streams for this device
    for (var sub in _notificationSubscriptions.values) {
      await sub.cancel();
    }
    _notificationSubscriptions.clear();

    await device.disconnect();
    connectedDevice = null;
  }

  // Discover GATT Services and Characteristics
  Future<List<BluetoothService>> discoverServices(
      BluetoothDevice device) async {
    return await device.discoverServices();
  }

  // Read data from a characteristic
  Future<List<int>> readCharacteristic(
      BluetoothCharacteristic characteristic) async {
    return await characteristic.read();
  }

  // Write data to a characteristic (Single flexible method)
  Future<void> writeCharacteristic(BluetoothCharacteristic characteristic,
      List<int> bytes) async {
    // Automatically uses writeWithoutResponse if standard write isn't supported
    bool withoutResponse = characteristic.properties.writeWithoutResponse &&
        !characteristic.properties.write;
    await characteristic.write(bytes, withoutResponse: withoutResponse);
  }

  // Subscribe / Unsubscribe to Characteristic Notifications/Indications
  Future<void> toggleNotification(BluetoothCharacteristic characteristic,
      Function(List<int>) onDataReceived,) async {
    final charKey = characteristic.uuid.toString();

    if (characteristic.isNotifying) {
      // Turn OFF notifications
      await characteristic.setNotifyValue(false);
      await _notificationSubscriptions[charKey]?.cancel();
      _notificationSubscriptions.remove(charKey);
    } else {
      // Turn ON notifications
      await characteristic.setNotifyValue(true);

      // Listen to incoming value stream
      final subscription = characteristic.lastValueStream.listen((value) {
        this.onDataReceived(charKey, value); //adds the value to the map...
        onDataReceived(value);
      });

      _notificationSubscriptions[charKey] = subscription;
    }
  }

  // Map charUuid -> {'current': '...', 'prev': '...'}
  final Map<String, Map<String, String>> charValues = {};

  // Map charUuid -> Track Title
  final Map<String, String> trackTitles = {};
//DEPRECATED CODE EXISTS IN THIS SECTION, IT IS BEST TO KEEP THIS ALONE UNLESS
// NO ERRORS/FUNCTIONALITY BREAKS (DEVICE DETAILS DEBUG SCREEN WILL BREAK IF U REMOVE THIS.)
  void onDataReceived(String charUuid, List<int> rawValue) {
    if (rawValue.length <= 3) return; //reject the value if its only 2 bytes or less

    // updates regardless of value

    if (rawValue[0] == 1) { // Entity 1 (Queue)
      String info = utf8.decode(rawValue.skip(3).toList());
      int mode = int.tryParse(info) ?? 0;

      final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];
      if (playerInfo == null) return;

      if (rawValue[0] == 0 && rawValue[1] == 2) {
        // 1. Skip header and decode
        String curVol = utf8.decode(rawValue.skip(3).toList(), allowMalformed: true);

        // 2. IMPORTANT: Remove null bytes (\x00) before trimming
        curVol = curVol.replaceAll(RegExp(r'\x00'), '').trim();

        print("Cleaned Volume String: '$curVol'");

        // 3. Parse now that the string is clean numeric text
        double? parsedVol = double.tryParse(curVol);
        if (parsedVol != null) {
          playerInfo.volume = parsedVol;
          CurrentInfoString.updateTrigger.value++;
        }
      }

      if (rawValue[1] == 2) { // Attribute 2: Shuffle Mode
        playerInfo.shuffleMode = mode;
      } else if (rawValue[1] == 3) { // Attribute 3: Repeat Mode
        playerInfo.repeatMode = mode;
      }
      CurrentInfoString.updateTrigger.value++;
    }

    if (rawValue[0] == 2) { // Entity 2 (TrackInfo)
      String decoded = utf8.decode(rawValue.skip(3).toList(), allowMalformed: true).trim();
      decoded = decoded.replaceAll(RegExp(r'\x00'), '');

      final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];
      if (playerInfo == null) return;

      bool changed = false;
      switch (rawValue[1]) {
        case 0: // Artist
          playerInfo.artistName = [decoded];
          print("Artist Name: $decoded");
          print("IMPORTANT: Music has been detected playing as has been updated!");
          changed = true;
          break;
        case 1: // Album
          playerInfo.albumName = [decoded];
          print("Album: $decoded");
          break;
        case 2: // Title
          playerInfo.trackName = [decoded];
          print("Title: $decoded");
          changed = true;

          // Album Art (Uses the title)
          String artist = playerInfo.artistName.isNotEmpty ? playerInfo.artistName.first.toString() : "";
          fetchArtwork(artist, decoded).then((url) {
          if (url.isNotEmpty) {
            playerInfo.artworkURL = url;
            CurrentInfoString.updateTrigger.value++; // Trigger UI update
            print("Album art function executed.");
            CurrentInfoString.isFetching.value = false;
            print("Metadata fetching complete, blur should stop.");
            }
          });
          break;
        case 3: // Duration
          playerInfo.duration = [decoded];
          print("Duration: $decoded");
          changed = true;
          break;
      }

      if (changed) {
        CurrentInfoString.updateTrigger.value++;
      }
    }

    if (rawValue[0] == 0 && rawValue[1] == 1) { // Entity 0, Attribute 1)

      final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];
      if (playerInfo == null) return;

      String info = utf8.decode(rawValue.skip(3).toList());
      List<String> parts = info.split(',');
      if (parts.length >= 3) {
        playerInfo.isPlaying = parts[0] == "1"; // 1 = Playing
        double timeFromAMD = double.tryParse(parts[2]) ?? 0.0;
        playerInfo.elapsedTime = timeFromAMD + 0.5;
        CurrentInfoString.updateTrigger.value++;
      }
    }

    String formattedValue = rawValue.join(',');

    String existingCurrent = charValues[charUuid]?['current'] ?? '';

    // Only update if the value actually changed
    if (existingCurrent == formattedValue) return;
    // 1. Update the map FIRST
    charValues[charUuid] = {
      'prev': existingCurrent,
      'current': formattedValue,
    };

    // 2. Then trigger the update
    handleUpdate();
  }
}