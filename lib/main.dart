import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mediabridge/services/media_audio_handler.dart';
import 'screens/scan_screen.dart';

late MediaBridgeAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register the handler
  audioHandler = await AudioService.init(
    builder: () => MediaBridgeAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'idv.kii.mediabridge.channel.audio',
      androidNotificationChannelName: 'MediaBridge Playback',
      androidNotificationOngoing: true,
    ),
  );

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