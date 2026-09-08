import 'package:flutter/material.dart';
import 'package:mediabridge/models/current_info.dart';
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
  int _lastSyncValue = -1; // to ensure the elapsed doesn't stick to 0:00
  Timer? _fetchingTimeout;


@override
void initState() {
  super.initState();

  //first time ticker for 1st updated song
  _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
    final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];
    if (playerInfo != null && playerInfo.isPlaying ){
      setState(() {
        _localElapsed += 1;
      });
    }

   //every 5 second refresher, fixing the 1-2 second delay.
    if (timer.tick % 5 == 0) {
      _triggerPlaybackSync();
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
void _triggerPlaybackSync() {
  // Use your existing InfoService
  InfoService().syncPlaybackOnly();
  // Note: Since writeToAMS now includes 'Playback', it will refresh the time.
  print("Fixing delay...");
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
        if (playerInfo != null) {
          // Sync the local timer with the double from BLE
          if (_lastSyncValue != triggerValue) {
            _localElapsed = playerInfo.elapsedTime;
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: Colors.black87,
                          inactiveTrackColor: Colors.grey[300],
                          thumbColor: Colors.black87,
                        ),
                        child: LinearProgressIndicator(
                          value: (_localElapsed / totalDuration).clamp(0.0, 1.0),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(_localElapsed), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(_formatDuration(totalDuration), style: const TextStyle(color: Colors.grey, fontSize: 12)),
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