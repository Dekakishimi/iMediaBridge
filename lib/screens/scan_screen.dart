import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/auto_subscribe.dart';
import '/services/ble_controller.dart';
import '/services/ble_device_filter.dart';
import 'media_interface.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final BleController _bleController = BleController();
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) setState(() => _isScanning = scanning);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediaBridge'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.restart_alt),
            onPressed: () {
              if (_isScanning) {
                _bleController.stopScan();
              } else {
                _bleController.startScan();
              }
            },
          )
        ],
      ),
      body: StreamBuilder<List<ScanResult>>(
        stream: _bleController.scanResults,
        initialData: const [],
        builder: (context, snapshot) {
          final results = snapshot.data ?? [];
          if (results.isEmpty) {
            return const Center(child: Text('No devices found. Tap arrow to start scan.'));
          }

          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              final deviceInfo = BleDeviceFilter.getDeviceInfo(result);

              return ListTile(
                leading: Icon(
                  deviceInfo.icon,
                  color: deviceInfo.iconColor,
                ),
                title: Text(deviceInfo.detectedName),
                subtitle: Text('${result.device.remoteId} | RSSI: ${result.rssi} dBm'),
                trailing: ElevatedButton(
                  child: const Text('Connect'),
                  onPressed: () async {
                    try {
                      SnackBar(content: Text('Connecting...'));
                      // 1. Establish BLE connection
                      await _bleController.connectToDevice(result.device);

                      // 2. Setup AMS subscriptions automatically
                      await AutoSubscribe.setupAMS(result.device);

                      // 3. Navigate straight to the Media Player UI
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            // Change DeviceDetailsScreen to MediaInterface
                            builder: (context) => const MediaInterface(),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to connect: $e')),
                        );
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}