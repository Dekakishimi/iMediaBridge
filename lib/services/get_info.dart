// lib/services/get_info.dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_controller.dart';
import '../models/get_send_tables.dart';

class InfoService {
  final BleController _bleController = BleController();
  static BluetoothCharacteristic? _cachedUpdateChar;

  // IMPORTANT: For SUBSCRIPTION, write to 2F7CABCE
  Future<void> _ensureUpdateChar() async {
    if (_cachedUpdateChar != null) return;
    final device = _bleController.connectedDevice;
    if (device == null) return;

    final services = await device.discoverServices();
    for (var service in services) {
      for (var char in service.characteristics) {
        if (char.uuid.toString().toUpperCase().contains('2F7CABCE')) {
          _cachedUpdateChar = char;
          return;
        }
      }
    }
  }

  Future<void> writeToAMS() async {
    await _ensureUpdateChar();
    if (_cachedUpdateChar == null) return;

    final List<CommandBytes> trackCommands = GetCommandsForAMS.registry.values
        .toList();

    for (final command in trackCommands) {
      await _bleController.writeCharacteristic(
          _cachedUpdateChar!, command.bytes);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> syncPlaybackOnly() async {
    await _ensureUpdateChar();
    if (_cachedUpdateChar != null) {
      await _bleController.writeCharacteristic(_cachedUpdateChar!, [0, 1]);
    }
  }

  Future<void> syncRepeatShuffleModesOnly() async {
    await _ensureUpdateChar();
    if (_cachedUpdateChar != null) {
      await _bleController.writeCharacteristic(_cachedUpdateChar!, [1, 2]);
      await _bleController.writeCharacteristic(_cachedUpdateChar!, [1, 3]);
    }
  }

  Future<void> syncVolumeOnly() async {
    await _ensureUpdateChar();
    if (_cachedUpdateChar != null) {
      try {
        // 1. Send [0, 1] (Playback Info) to wake up the stream
        await _bleController.writeCharacteristic(_cachedUpdateChar!, [0, 1]);
        print("Two-step volume sync initiated.");
      } catch (e) {
        print("Volume sync failed: $e");
      }
    }
  }
}

// A QUIRK IVE FOUND OUT THE APPLE MEDIA SERVICE FOR VOLUME, IS THAT YOU NEED
// TO TRIGGER A 0,1 WRITE BEFORE YOU SEND THE 0,2 WRITE FOR THE VOLUME...
// (APPLE ENGINEERS..  I HATE YOU...)