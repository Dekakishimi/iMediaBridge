import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '/services/media_audio_handler.dart';
import 'screens/scan_screen.dart';
import 'screens/first_time_setup.dart';
import 'package:shared_preferences/shared_preferences.dart';

late MediaBridgeAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final bool showSetup = prefs.getBool('setup_completed') ?? false;

  // Register the handler
  audioHandler = await AudioService.init(
    builder: () => MediaBridgeAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'idv.kii.mediabridge.channel.audio',
      androidNotificationChannelName: 'iMediaBridge Playback',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'mipmap/launcher_icon',
    ),
  );

  runApp(MediaBridge(showSetup: showSetup));
}

class MediaBridge extends StatelessWidget {
  final bool showSetup;
  const MediaBridge({super.key, required this.showSetup});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iMediaBridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: showSetup ? const ScanScreen() : const FirstTimeSetup(),
    );
  }
}