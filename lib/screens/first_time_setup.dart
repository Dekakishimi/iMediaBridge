import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ble_controller.dart';
import 'scan_screen.dart';

class FirstTimeSetup extends StatelessWidget {
  const FirstTimeSetup({super.key});

  Future<void> _completeSetup(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_completed', true);

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ScanScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final BleController bleController = BleController();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.battery_saver_outlined, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                "Battery Permissions",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                "To keep your music info updated while your screen is off, iMediaBridge needs to be exempt from battery optimizations.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: () async {
                  await bleController.requestBatteryOptimizationOff();
                  if (context.mounted) _completeSetup(context);
                  },
                child: const Text("Allow Background Work"),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const ScanScreen()),
                  );
                },
                child: const Text("Continue to Scanner"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}