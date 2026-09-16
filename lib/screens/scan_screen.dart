import 'package:material_ui/material_ui.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/auto_subscribe.dart';
import '/services/ble_controller.dart';
import '/services/ble_device_filter.dart';
import 'media_interface.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

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

          return M3ECardList(
            variant: M3ECardVariant.outlined,
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              final deviceInfo = BleDeviceFilter.getDeviceInfo(result);

              return M3EListItem(
                leading: CircleAvatar(
                  child: Icon(deviceInfo.icon, color: deviceInfo.iconColor),
                ),
                headline: deviceInfo.detectedName,
                supportingText: '${result.device.remoteId} | RSSI: ${result.rssi} dBm',
                trailing: M3EButton(
                  child: const Text('Connect'),
                  onPressed: () async {
                    try {
                      M3ESnackbar.show(context, message: 'Connecting...');
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
                        M3ESnackbar.show(context, message: 'Failed to connect: $e');
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