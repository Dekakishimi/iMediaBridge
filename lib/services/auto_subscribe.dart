// lib/services/auto_subscribe.dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_controller.dart';
import 'get_info.dart';

class AutoSubscribe {
  static final BleController _bleController = BleController();

  // Track if we are already subscribed
  static bool _isSetupComplete = false;

  static Future<void> setupAMS(BluetoothDevice device) async {
    // 1. EXIT EARLY if already setup
    if (_isSetupComplete) {
      print("AMS already setup, skipping...");
      return;
    }

    try {
      print("Starting one-time auto-subscription for AMS...");
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        if (service.uuid.toString().toUpperCase().contains('89D3502B')) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toUpperCase().contains('2F7CABCE')) {
              // 1. Enable notifications
              await _bleController.toggleNotification(char, (data) {});

              // 2. WAIT longer for the iPhone to stabilize subscriptions
              await Future.delayed(const Duration(seconds: 1));

              // 3. Initial metadata request (Specific attributes)
              await InfoService().writeToAMS();
            }
            // Only enable if NOT already notifying
          }
        }
      }
      // 2. Mark as complete
      _isSetupComplete = true;
      print("AMS Setup marked as Complete.");
    } catch (e) {
      print("Error during AMS setup: $e");
    }
  }

  // 3. Reset the flag if the device disconnects
  static void reset() {
    _isSetupComplete = false;
  }
}