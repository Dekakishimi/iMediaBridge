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
            final charUuid = char.uuid.toString().toUpperCase();

            // Only enable if NOT already notifying
            if (!char.isNotifying) {
              if (charUuid.contains('2F7CABCE')) {
                await _bleController.toggleNotification(char, (data) {});
              }
              if (charUuid.contains('9B3C81D8')) {
                if (char.properties.notify || char.properties.indicate) {
                  await _bleController.toggleNotification(char, (data) {});
                }
              }
            }
          }
        }
      }

      await Future.delayed(const Duration(milliseconds: 500));
      await InfoService().writeToAMS();

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