import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'get_info.dart';
import '../models/current_info.dart';

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
    if (rawValue.isEmpty) return;

    // updates regardless of value
    if (rawValue[0] == 2 ) {
      try {
        // Decode as UTF-8 (more robust than fromCharCodes)
        String decoded = utf8.decode(
            rawValue.skip(3).toList(), allowMalformed: true).trim();
        decoded = decoded.replaceAll(RegExp(r'\x00'), '');
        if (decoded.isNotEmpty) {
          trackTitles[charUuid] = decoded;
        }
      } catch (e) {
        // Fallback to basic char codes if UTF-8 fails
        String decoded = String.fromCharCodes(rawValue.skip(1)).trim();
        decoded = decoded.replaceAll(RegExp(r'\x00'), '');
        if (decoded.isNotEmpty) {
          trackTitles[charUuid] = decoded;
        }
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