import 'package:flutter/material.dart';
import '../services/ble_controller.dart';
import '/models/current_info.dart';
import 'dart:async';
import '../models/get_send_tables.dart';
import '../services/get_info.dart';
import 'dart:ui';
import '../services/remote_control_service.dart';


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

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.music_note_rounded, size: 120, color: Colors.grey[400]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: CurrentInfoString.updateTrigger,
      builder: (context, triggerValue, child) {
        // Carryover the data from the current info map
        final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];
        // Data for album cover
        String artworkURL = playerInfo?.artworkURL ?? "";

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
          backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.black), // "X" icon to close
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
              title: const Text(
                  "Now Playing",
                  style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600)
              ),
              centerTitle: true,
            ),
          body: SafeArea(
            child: Column(
              children: [
                // Top Indicator (Basic style grabber)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
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
                            aspectRatio: 1,
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: fetching ? 8.0 : 0.0,
                                sigmaY: fetching ? 8.0 : 0.0,
                              ),
                              child: (artworkURL.isEmpty)
                                  ? _buildPlaceholder()
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        artworkURL,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

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

                const SizedBox(height: 20),

                // Scrubber (Progress Bar)
                Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // 1. The Progress Bar (Using a custom Slider for the "Dot" and "Active Line" look)
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 0, // Hidden thumb like modern iOS
                          disabledThumbRadius: 0,
                        ),
                        overlayShape: SliderComponentShape.noOverlay,
                        activeTrackColor: Colors.black.withValues(alpha: 0.8),
                        inactiveTrackColor: Colors.black.withValues(alpha: 0.1),
                        // If you want a thumb while dragging, you can set radius to 6
                      ),
                      child: Slider(
                        value: (_localElapsed / totalDuration).clamp(0.0, 1.0),
                        onChanged: null, // Set to null to make it read-only for now
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 2. The Timing Text (Modern, spaced typography)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_localElapsed),
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [FontFeature.tabularFigures()], // Fixed width numbers!
                            ),
                          ),
                          Text(
                            "-${_formatDuration(totalDuration - _localElapsed)}", // Countdown style
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.5),
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

                const SizedBox(height: 10),

                // Main Playback Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      iconSize: 45,
                      onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.previous),
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.black),
                    ),
                    IconButton(
                      iconSize: 45,
                      onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.rewind),
                      icon: const Icon(Icons.replay_10, color: Colors.black),
                    ),
                    IconButton(
                      iconSize: 85,
                      onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.toggle),
                      icon: Icon(
                        playerInfo?.isPlaying == true ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                      ),
                    ),IconButton(
                      iconSize: 45,
                      onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.forward),
                      icon: const Icon(Icons.forward_10, color: Colors.black),
                    ),
                    IconButton(
                      iconSize: 45,
                      onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.next),
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.black),
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
                      IconButton(
                        onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.volumeDown),
                        icon: const Icon(Icons.volume_down_rounded, size: 20, color: Colors.grey),
                      ),

                      // 2. Volume Progress Bar
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (playerInfo!.volume / 1).clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                          ),
                        ),
                      ),

                      // 3. Volume Up Button
                      IconButton(
                        onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.volumeUp),
                        icon: const Icon(Icons.volume_up_rounded, size: 20, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // Bottom Bar Accessories
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.cycleRepeat),
                        icon: Icon(
                          playerInfo.repeatMode == 1 ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                          color: playerInfo.repeatMode != 0 ? Colors.blue : Colors.black45,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.cycleShuffle),
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: playerInfo.shuffleMode != 0 ? Colors.blue : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}