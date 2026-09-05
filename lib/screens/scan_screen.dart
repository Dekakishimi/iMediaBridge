import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '/services/ble_controller.dart';
import 'device_details_screen.dart';
import '/services/ble_device_filter.dart';

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
        title: const Text('BLE Scanner'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.search),
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
            return const Center(child: Text('No devices found. Tap search to scan.'));
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
                      await _bleController.connectToDevice(result.device);
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => DeviceDetailsScreen(device: result.device),
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