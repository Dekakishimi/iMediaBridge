import 'package:flutter/material.dart';
import 'screens/scan_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MediaBridge());
}

class MediaBridge extends StatelessWidget {
  const MediaBridge({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediaBridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ScanScreen(),
    );
  }
}