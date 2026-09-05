import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleController {
  // Singleton pattern for easy access
  static final BleController _instance = BleController._internal();
  factory BleController() => _instance;
  BleController._internal();

  BluetoothDevice? connectedDevice;
  final Map<String, StreamSubscription> _notificationSubscriptions = {};

  // Check if Bluetooth is supported and enabled
  Stream<BluetoothAdapterState> get adapterState => FlutterBluePlus.adapterState;

  // Start scanning for nearby devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
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
    await device.connect(autoConnect: false, timeout: const Duration(seconds: 10), license: License.nonprofit);
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
  Future<List<BluetoothService>> discoverServices(BluetoothDevice device) async {
    return await device.discoverServices();
  }

  // Read data from a characteristic
  Future<List<int>> readCharacteristic(BluetoothCharacteristic characteristic) async {
    return await characteristic.read();
  }

  // Write data to a characteristic (Single flexible method)
  Future<void> writeCharacteristic(BluetoothCharacteristic characteristic, List<int> bytes) async {
    // Automatically uses writeWithoutResponse if standard write isn't supported
    bool withoutResponse = characteristic.properties.writeWithoutResponse && !characteristic.properties.write;
    await characteristic.write(bytes, withoutResponse: withoutResponse);
  }

  // Subscribe / Unsubscribe to Characteristic Notifications/Indications
  Future<void> toggleNotification(
      BluetoothCharacteristic characteristic,
      Function(List<int>) onDataReceived,
      ) async {
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
        onDataReceived(value);
      });

      _notificationSubscriptions[charKey] = subscription;
    }
  }
}