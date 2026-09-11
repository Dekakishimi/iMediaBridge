
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_controller.dart';
import '../models/get_send_tables.dart';
import '../models/current_info.dart';
import 'get_info.dart';

class RemoteControlService {
  final BleController _bleController = BleController();
  static BluetoothCharacteristic? _cachedRemoteChar;

  Future<void> _ensureRemoteChar() async {
    if (_cachedRemoteChar != null) return;
    final device = _bleController.connectedDevice;
    if (device == null) return;

    final services = await device.discoverServices();
    for (var service in services) {
      for (var char in service.characteristics) {
        if (char.uuid.toString().toUpperCase().contains('9B3C81D8')) {
          _cachedRemoteChar = char;
          return;
        }
      }
    }
  }

  Future<void> sendRemoteCommand(List<int> command) async {
    await _ensureRemoteChar();
    if (_cachedRemoteChar == null) return;

    try {
      await _bleController.writeCharacteristic(_cachedRemoteChar!, command);

      final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];

      if (command.first == 4 || command.first == 10) {
        if (playerInfo != null) {
          playerInfo.elapsedTime = 0.0;
          CurrentInfoString.updateTrigger.value++;
        }
      }

      // Handle Blur/Metadata refresh
      bool isSilent = RemoteCommands.silentCommands.any((c) =>
      c.length == command.length && c.first == command.first);

      if (!isSilent) {
        // Clear previous artwork and reset fetching state
        if (playerInfo != null) {
          playerInfo.artworkURL = "";
          CurrentInfoString.updateTrigger.value++;
        }

        // Set to true to start the 10s timer in the UI
        CurrentInfoString.isFetching.value = true;
        await Future.delayed(const Duration(milliseconds: 300));
        await InfoService().writeToAMS();

      } else {
        await Future.delayed(const Duration(milliseconds: 500));
        await InfoService().writeToAMS();
      }
    } catch (e) {
      print("Remote Command failed: $e");
    }
  }
}