import 'package:audio_service/audio_service.dart';
import 'package:material_3_expressive/foundations/foundations.dart';
import 'package:material_ui/material_ui.dart';
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
    return M3EMaterialApp(
      title: 'iMediaBridge',
      data: M3EThemeData.light(seedColor: const Color(0xFF6750A4)),
      fontFamily: 'Google Sans Flex',
      typeScaleMode: M3ETypeScaleMode.variable,
      variableFont: const M3EVariableFontConfig(
        global: M3EVariableFontAxes(wght: 400, opsz: 16),
        brand: M3EVariableFontAxes(wght: 700),
        body: M3EVariableFontAxes(wght: 400),
      ),
      autoTheming: true,
      dynamicColoring: true,
      drawUnderSystemBars: false, // transparent system bars, edge-to-edge layout
      debugShowCheckedModeBanner: false,
      home: showSetup ? const ScanScreen() : const FirstTimeSetup(),

    );
  }
}