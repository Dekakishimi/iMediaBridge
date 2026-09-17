import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import '../models/app_manufacturer_ids.dart';
import '../services/ble_controller.dart';
import '/models/current_info.dart';
import 'dart:async';
import '../models/get_send_tables.dart';
import '../services/get_info.dart';
import 'dart:ui';
import '../services/remote_control_service.dart';
import 'device_details_screen.dart';

class MediaInterface extends StatefulWidget {
  const MediaInterface({super.key});

  @override
  State<MediaInterface> createState() => _MediaInterfaceState();
}

class _MediaInterfaceState extends State<MediaInterface> {

  final RemoteControlService _remoteControlService = RemoteControlService();

  //timer for scrubber
  Timer? _ticker;
  double _localElapsed = 0.0;
  int _lastSyncValue = 0; // to ensure the elapsed doesn't stick to 0:00
  Timer? _fetchingTimeout;


@override
void initState() {
  super.initState();

  //first time ticker for 1st updated song
  _ticker = Timer.periodic(const Duration(milliseconds: 200), (timer) {
    final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];
    if (playerInfo != null && playerInfo.isPlaying ){
      setState(() {
        _localElapsed += 0.2;
      });
    }

   //every 5 second refresher, fixing the 1-2 second delay.
    if (timer.tick % 50 == 0) {
      _triggerPlaybackDelaySync();
      InfoService().syncVolumeOnly();
    }

  });
  CurrentInfoString.isFetching.addListener(_handleFetchingTimeout);
}
//TIMEOUT HELPER.

  void _handleFetchingTimeout() {
    if (CurrentInfoString.isFetching.value) {
      _fetchingTimeout?.cancel();
      _fetchingTimeout = Timer(const Duration(seconds: 10), () {
        if (CurrentInfoString.isFetching.value) {
          // Force unblur and show toast
          CurrentInfoString.isFetching.value = false;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("TIMEOUT: Unable to find cover art..."),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      });
    } else {
      _fetchingTimeout?.cancel();
    }
  }

// Helper to send just the sync command
Future<void> _triggerPlaybackDelaySync() async {
  print("Fixing delay...");
  isFixingDelay = 1;
  // Use your existing InfoService
  await InfoService().syncPlaybackOnly();
  await Future.delayed(const Duration(milliseconds: 500)); //wait till the thing finishes processing.
  isFixingDelay = 0;
  // Note: Since writeToAMS now includes 'Playback', it will refresh the time.

}

  @override
  void dispose() {
    CurrentInfoString.isFetching.removeListener(_handleFetchingTimeout);
    _fetchingTimeout?.cancel();
    _ticker?.cancel(); // Stop the timer when the widget is destroyed
    super.dispose();
  }

  // Helper to format seconds (e.g., 125 -> "2:05")
  String _formatDuration(double seconds) {
    int mins = (seconds / 60).floor();
    int secs = (seconds % 60).floor();
    return "$mins:${secs.toString().padLeft(2, '0')}";
  }

  Widget _buildPlaceholder(IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(M3EIcons.music_note_rounded, size: 120, color: Colors.grey[400]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CurrentInfoString.updateTrigger,
      builder: (context, triggerValue, child) {
        // Carryover the data from the current info map
        final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];
        String playerName = playerInfo?.playerName ?? "Unknown Player";
        // Data for album cover
        String artworkURL = playerInfo?.artworkURL ?? "";
        bool isVideoMode = AppClassifier.getCategory(playerName) == 'video';

        double targetAspectRatio = isVideoMode ? (16 / 9) : 1.0;
        IconData placeholderIcon = isVideoMode ? M3EIcons.video_library_rounded : M3EIcons.music_note_rounded;

        // Extract all data (to avoid null pointer.)
        if (playerInfo != null && !CurrentInfoString.isFetching.value) {
          // 1. Check if a new BLE update has arrived
          if (_lastSyncValue != triggerValue) {

            // 2. Calculate the difference between local time and iPhone time
            double difference = (playerInfo.elapsedTime - _localElapsed).abs();

            // 3. Only jump if the drift is more than 0.5 seconds
            if (difference > 0.5 || playerInfo.elapsedTime < 1.0) {
              print("Drift detected (${difference.toStringAsFixed(2)}s). Correcting...");
              _localElapsed = playerInfo.elapsedTime;
            } else {
              print("Sync ignored: Drift is negligible (${difference.toStringAsFixed(2)}s).");
            }
            // Always update the sync value so we don't re-run this logic until the next packet
            _lastSyncValue = triggerValue;
          }
        }

        // Default values
        String trackTitle = "Unknown Track";
        String artistName = "Unknown Artist";
        double totalDuration = 1.0; // Initialize the variable

        if (playerInfo != null) {
          // 1. Extract Duration String and convert to double
          if (playerInfo.duration.isNotEmpty) {
            totalDuration = double.tryParse(playerInfo.duration.first.toString()) ?? 1.0;
          }
          // 2. Extract Title/Artist
          if (playerInfo.trackName.isNotEmpty) trackTitle = playerInfo.trackName.first.toString();
          if (playerInfo.artistName.isNotEmpty) artistName = playerInfo.artistName.first.toString();
        }

        // Basic style layout

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            leading: IconButton(
              icon: const Icon(M3EIcons.close), // "X" icon to close
              onPressed: () async {
                final controller = BleController();
                final device = controller.connectedDevice;

                if (device != null) {
                  print("Disconnecting and exiting...");
                  // 1. Clean up BLE connection
                  await controller.disconnectDevice(device);
                }

                // 2. Go back to scan screen
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            title: Text(
              // Gets the device name.
                BleController().connectedDevice?.platformName.isNotEmpty == true
                    ? BleController().connectedDevice!.platformName
                    : "Now Playing",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(M3EIcons.settings_rounded),
                onPressed: () {
                  final device = BleController().connectedDevice;
                  if (device != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            DeviceDetailsScreen(device: device),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("No connected device found.")),
                    );
                  }
                },
               ),
              ],
             ),
          body: SafeArea(
            child: Column(
              children: [
                // Top Indicator (Basic style grabber)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // --- BLUR / FETCHING SECTION START ---
                ValueListenableBuilder(
                  valueListenable: CurrentInfoString.isFetching,
                  builder: (context, fetching, child) {
                    return Column(
                      children: [
                        // ARTWORK SECTION
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: AspectRatio(
                            aspectRatio: targetAspectRatio,
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: fetching ? 8.0 : 0.0,
                                sigmaY: fetching ? 8.0 : 0.0,
                              ),
                              child: (artworkURL.isEmpty)
                                  ? _buildPlaceholder(placeholderIcon)
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        artworkURL,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(placeholderIcon),
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // TEXT SECTION
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Row(
                            children: [
                              Expanded(
                                child: ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                    sigmaX: fetching ? 8.0 : 0.0,
                                    sigmaY: fetching ? 8.0 : 0.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, // Aligns children to the left
                                    children: [
                                      Text(
                                        trackTitle,
                                        textAlign: TextAlign.left, // Forces text alignment to the left
                                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        artistName,
                                        textAlign: TextAlign.left, // Forces text alignment to the left
                                        style: TextStyle(fontSize: 22, color: Colors.grey[600]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                // --- BLUR / FETCHING SECTION END ---

                const Spacer(flex: 2),

                const SizedBox(height: 20),

                // Progress Bar
                Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    M3EProgressIndicator.linearWavy(
                        value: (_localElapsed / totalDuration).clamp(0.0, 1.0),
                        linearSize: M3EProgressIndicatorSize.m,
                      ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_localElapsed),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [FontFeature.tabularFigures()], // Fixed width numbers!
                            ),
                          ),
                          Text(
                            "-${_formatDuration(totalDuration - _localElapsed)}", // Countdown style
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

                const Spacer(flex: 1),

                // Main Playback Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      iconSize: 45,
                      onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.previous),
                      icon: const Icon(M3EIcons.skip_previous_rounded),
                    ),
                    IconButton(
                      iconSize: 45,
                      onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.rewind),
                      icon: const Icon(M3EIcons.replay_10),
                    ),
                    IconButton(
                      iconSize: 85,
                      onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.toggle),
                      icon: Icon(
                        playerInfo?.isPlaying == true ? M3EIcons.pause_rounded : M3EIcons.play_arrow_rounded,
                      ),
                    ),IconButton(
                      iconSize: 45,
                      onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.forward),
                      icon: const Icon(M3EIcons.forward_10),
                    ),
                    IconButton(
                      iconSize: 45,
                      onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.next),
                      icon: const Icon(M3EIcons.skip_next_rounded),
                    ),
                  ],
                ),

                const Spacer(flex: 1),

                // Volume Control
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      // 1. Volume Down Button
                      M3EIconButton(
                        variant: M3EIconButtonVariant.tonal,
                        size: M3EIconButtonSize.xs,
                        onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.volumeDown),
                        icon: const Icon(M3EIcons.volume_down_rounded, size: 20),
                      ),

                      // 2. Volume Progress Bar
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: M3EProgressIndicator.linear(
                            value: (playerInfo!.volume / 1).clamp(0.0, 1.0),
                          ),
                        ),
                      ),

                      // 3. Volume Up Button
                      M3EIconButton(
                        variant: M3EIconButtonVariant.tonal,
                        size: M3EIconButtonSize.xs,
                        onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.volumeUp),
                        icon: const Icon(M3EIcons.volume_up_rounded, size: 20),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // Bottom Bar Accessories
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      //repeat
                      M3EIconButton(
                        variant: playerInfo.repeatMode != 0
                            ? M3EIconButtonVariant.filled
                            : M3EIconButtonVariant.tonal,
                        shape: M3EIconButtonShapeVariant.round,
                        onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.cycleRepeat),
                        icon: Icon(
                          playerInfo.repeatMode == 1 ? M3EIcons.repeat_one_rounded : M3EIcons.repeat_rounded,
                        ),
                      ),

                      const SizedBox(width: 0)
                      ,
                      //refresh the connection
                      M3EIconButton(
                        shape: M3EIconButtonShapeVariant.round,
                        onPressed: () => InfoService().writeToAMS(),
                        variant: M3EIconButtonVariant.tonal,
                        icon: Icon(
                          M3EIcons.refresh
                        ),
                      ),

                      const SizedBox(width: 0),
                      //shuffle
                      M3EIconButton(
                        onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.cycleShuffle),
                          variant: playerInfo.shuffleMode != 0
                              ? M3EIconButtonVariant.filled
                              : M3EIconButtonVariant.tonal,
                        shape: M3EIconButtonShapeVariant.round,
                          icon: const Icon(M3EIcons.shuffle_rounded)
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

              ],
            ),
          ),
          resizeToAvoidBottomInset: null,
        );
      },
    );
  }
}