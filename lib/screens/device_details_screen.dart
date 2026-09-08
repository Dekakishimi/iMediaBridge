import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_controller.dart';
import 'media_interface.dart';
import '../services/get_info.dart';

class DeviceDetailsScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceDetailsScreen({super.key, required this.device});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  final BleController _bleController = BleController();
  final infoService = InfoService();
  List<BluetoothService> _services = [];
  bool _isLoading = true;
  final Map<String, List<int>> _characteristicValues = {};

  @override
  void initState() {
    super.initState();
    _discoverServices();
  }

  Future<void> _discoverServices() async {
    try {
      final services = await _bleController.discoverServices(widget.device);
      setState(() {
        _services = services;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error discovering services: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName.isEmpty ? 'Device View' : widget.device.platformName),
        actions: [
          IconButton( // Handle Disconnection
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: () async {
              await _bleController.disconnectDevice(widget.device);
              if (mounted) Navigator.of(context).pop();
            },
          ),
          IconButton( // Go to Media Interface
            icon: const Icon(Icons.home),
            onPressed: () async {
              infoService.writeToAMS();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MediaInterface(),
                ),
              );
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _services.length,
        itemBuilder: (context, index) {
          final service = _services[index];
          return ExpansionTile(
            title: Text('Service: ${service.uuid.toString().substring(0, 4)}...'),
            subtitle: Text('UUID: ${service.uuid}'),
            children: service.characteristics.map((char) {
              final charUuid = char.uuid.toString();
              final currentVal = _bleController.charValues[charUuid]?['current'] ?? '';
              final previousVal = _bleController.charValues[charUuid]?['prev'] ?? '';
              final trackTitle = _bleController.trackTitles[charUuid] ?? '';

              return ListTile(
                title: Text('Char: ${charUuid.substring(0, 4)}...'),
subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Properties: ${_getPropertiesString(char.properties)}'),

    // NEW: Volume Trigger Check
    if (currentVal.startsWith('0,2,0'))
      const Text(
        'VOLUME TRIGGER DETECTED...',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)
      ),

    if (trackTitle.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text('Track Title: $trackTitle',
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    if (previousVal.isNotEmpty)
      Text('Value: $previousVal', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
    if (currentVal.isNotEmpty)
      Text('Value: $currentVal', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
  ],
),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // READ BUTTON
                    if (char.properties.read)
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.blue),
                        onPressed: () async {
                          final val = await _bleController.readCharacteristic(char);
                          _bleController.onDataReceived(charUuid, val);
                          setState(() => _characteristicValues[charUuid] = val);
                        },
                      ),
                    // WRITE BUTTON
                    if (char.properties.write || char.properties.writeWithoutResponse)
                      IconButton(
                        icon: const Icon(Icons.upload, color: Colors.orange),
                        onPressed: () => _showWriteDialog(char),
                      ),
                    // SUBSCRIBE/NOTIFY BUTTON
                    if (char.properties.notify || char.properties.indicate)
                      IconButton(
                        icon: Icon(
                          char.isNotifying ? Icons.notifications_active : Icons.notifications_off,
                          color: char.isNotifying ? Colors.green : Colors.grey,
                        ),
                        onPressed: () async { //Implement subscription automatically when open media player
                          await _bleController.toggleNotification(char, (data) {
                            setState(() => _characteristicValues[charUuid] = data);
                          });
                          setState(() {}); // Refresh icon state
                        },
                      ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  String _getPropertiesString(CharacteristicProperties props) {
    List<String> p = [];
    if (props.read) p.add('Read');
    if (props.write) p.add('Write');
    if (props.writeWithoutResponse) p.add('WriteNoResp');
    if (props.notify) p.add('Notify');
    if (props.indicate) p.add('Indicate');
    return p.join(', ');
  }
  //Write Dialog
void _showWriteDialog(BluetoothCharacteristic char) {
  final TextEditingController textController = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('Write to ${char.uuid.toString().substring(0, 4)}...'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'Value (Text)',
            hintText: 'Enter string to send',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final input = textController.text.trim();
              if (input.isEmpty) return;

              try {
                List<int> bytes;

                // Check if user entered comma-separated numbers (e.g. "0, 2, 4" or "0,2,4")
                if (input.contains(',')) {
                  bytes = input
                      .split(',')
                      .map((e) => int.parse(e.trim()))
                      .toList();
                } else { //updated to automatically send hex and decimal values instead of Strings which fails to execute on AMS.
                  bytes = input
                      .split(RegExp(r'[ ,]+'))
                      .map((e) {
                    final clean = e.trim();
                    // Handles both decimal (2) and hex (0x02)
                    return clean.startsWith('0x')
                        ? int.parse(clean.substring(2), radix: 16)
                        : int.parse(clean);
                  })
                      .toList();
              }

                await _bleController.writeCharacteristic(char, bytes);

                setState(() {
                  _characteristicValues[char.uuid.toString()] = bytes;
                });

                if (mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sent ${bytes.length} bytes: $bytes')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invalid input format or write failed: $e')),
                  );
                }
              }
            }
              ,child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }
}