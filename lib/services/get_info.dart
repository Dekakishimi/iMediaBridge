import 'dart:convert';
import '../models/current_info.dart';
import 'ble_controller.dart';
import '../models/get_tables.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class InfoService {
  final BleController _bleController = BleController();

  /// Simplified function to write to AMS without required parameters
  Future<void> writeToAMS() async {
      // 1. Get the connected device from your controller
      final device = _bleController.connectedDevice;
      if (device == null) return;

      // 2. Find the services already discovered on the device
      final services = await device.discoverServices();

      // 3. Find the specific AMS Remote Command characteristic
      // (UUID: 9B3C81D8-6351-4A5E-8F09-70FD23ED5FD3)
      BluetoothCharacteristic? amsRemoteChar;

      for (var service in services) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().toUpperCase().contains('2F7CABCE')) {
            amsRemoteChar = char;
            break;
          }
        }
      }
      if (amsRemoteChar == null) {
        print("AMS Characteristic not found!");
        return;
      }

      try {
        // User will implement custom logic here
        print("writeToAMS triggered");

        final List<CommandBytes> trackCommands = GetCommandsForAMS.registry
            .entries // gets all track related bytes first
            .where((entry) =>
        entry.key.contains('Track') || entry.key.contains('Artist') ||
            entry.key.contains('Album') || entry.key.contains('Duration'))
            .map((entry) => entry.value)
            .toList();

        for (final command in trackCommands) {
          await _bleController.writeCharacteristic(
              amsRemoteChar, command.bytes);
          await Future.delayed(const Duration(
              milliseconds: 100)); //delay to catch up with responses

          // inserting the values in the current info map

          if (amsRemoteChar.lastValue.length > 2) {
            // Access the specific entry in the registry
            final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];

            if (playerInfo != null) {
              String decoded = utf8.decode(amsRemoteChar.lastValue.skip(3).toList(), allowMalformed: true).trim();
              decoded = decoded.replaceAll(RegExp(r'\x00'), '');

              // Identify which attribute was received (Entity ID 2 = Track Info)
              if (amsRemoteChar.lastValue[0] == 2) {
                switch (amsRemoteChar.lastValue[1]) {
                  case 0: // Artist Name
                    playerInfo.artistName = [decoded];
                    print("Updated Artist: $decoded");
                    CurrentInfoString.updateTrigger.value++;
                    break;
                  case 2: // Track Title
                    playerInfo.trackName = [decoded];
                    CurrentInfoString.updateTrigger.value++;
                    print("Updated Title: $decoded");
                    break;
                  case 3: // Duration
                    playerInfo.duration = [decoded];
                    CurrentInfoString.updateTrigger.value++;
                    print("Updated Duration: $decoded");
                    break;
                }
              }
            }
          }
          print("Command ${command.bytes} result: ${amsRemoteChar.lastValue}");
        }
      } catch (e) {
        print("Error in writeToAMS: $e");
      }
  }
}