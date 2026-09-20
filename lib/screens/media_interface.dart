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
import 'package:marquee/marquee.dart';
import 'package:flutter/services.dart';

class MediaInterface extends StatefulWidget {
  const MediaInterface({super.key});

  @override
  State<MediaInterface> createState() => _MediaInterfaceState();
}

class _MediaInterfaceState extends State<MediaInterface> {
  final RemoteControlService _remoteControlService = RemoteControlService();

  Timer? _ticker;
  double _localElapsed = 0.0;
  int _lastSyncValue = 0;
  Timer? _fetchingTimeout;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));

    _ticker = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];
      if (playerInfo != null && playerInfo.isPlaying) {
        setState(() {
          _localElapsed += 0.2;
        });
      }
      if (timer.tick % 50 == 0) {
        _triggerPlaybackDelaySync();
        InfoService().syncVolumeOnly();
      }
    });
    CurrentInfoString.isFetching.addListener(_handleFetchingTimeout);
  }

  void _handleFetchingTimeout() {
    if (CurrentInfoString.isFetching.value) {
      _fetchingTimeout?.cancel();
      _fetchingTimeout = Timer(const Duration(seconds: 10), () {
        if (CurrentInfoString.isFetching.value) {
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

  Future<void> _triggerPlaybackDelaySync() async {
    print("Fixing Delay");
    isFixingDelay = 1;
    await InfoService().syncPlaybackOnly();
    await Future.delayed(const Duration(milliseconds: 500));
    isFixingDelay = 0;
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    CurrentInfoString.isFetching.removeListener(_handleFetchingTimeout);
    _fetchingTimeout?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

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
      child: Icon(icon, size: 120, color: Colors.grey[400]),
    );
  }

  @override
  Widget build(BuildContext context) {

    // Control Scaling Variables.

    final Size size = MediaQuery.of(context).size;
    final double sw = size.width;  // Total Width
    final double sh = size.height; // Total Height

    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    final double timeFontSize = sw > 900 ? 18 : (sw > 600 ? 15 : 13);

    final double titleFontSize = sw > 900 ? 34 : ( sw > 600 ? 28 : 24);
    final double artistFontSize = sw > 600 ? 24 : 22;

    final double titleHeight = titleFontSize * 1.5;
    final double artistHeight = artistFontSize * 1.5;

    final double playbackIconSize = sw > 900 ? 65 : (sw > 600 ? 55 : 45);
    final double mainToggleIconSize = sw > 900 ? 110 : (sw > 600 ? 90 : 85);
    final progressSize = sw > 900 ? M3EProgressIndicatorSize.m : M3EProgressIndicatorSize.s;
    final accessorySize = sw > 900 ? M3EIconButtonSize.md : M3EIconButtonSize.sm;

    return ValueListenableBuilder(
      valueListenable: CurrentInfoString.updateTrigger,
      builder: (context, triggerValue, child) {
        final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];
        String playerName = playerInfo?.playerName ?? "Unknown Player";
        String artworkURL = playerInfo?.artworkURL ?? "";
        bool isVideoMode = AppClassifier.getCategory(playerName) == 'video';

        double targetAspectRatio = isVideoMode ? (16 / 9) : 1.0;
        IconData placeholderIcon = isVideoMode ? M3EIcons.video_library_rounded : M3EIcons.music_note_rounded;

        if (playerInfo != null && !CurrentInfoString.isFetching.value) {
          if (_lastSyncValue != triggerValue) {

            // 1. Calculate the Latency-Compensated Target Time
            // We add 0.5s to the iPhone time to account for Bluetooth transmission delay
            double targetTime = playerInfo.elapsedTime + 0.5;

            // 2. Calculate the difference between local timer and our compensated target
            double difference = (targetTime - _localElapsed).abs();

            // 3. Perform Sync:
            // We ignore the extra 0.5s offset in the drift window calculation
            // by comparing the current local time to the targetTime.
            if (difference > 0.5 || playerInfo.elapsedTime < 1.0) {
              print("Drift detected (${difference.toStringAsFixed(2)}s). Correcting to target...");
              _localElapsed = targetTime;
            } else {
              print("Sync ignored: Drift is within tolerance (${difference.toStringAsFixed(2)}s).");
            }

            _lastSyncValue = triggerValue;
          }
        }

        String trackTitle = "Unknown Track";
        String artistName = "Unknown Artist";
        double totalDuration = 1.0;

        if (playerInfo != null) {
          if (playerInfo.duration.isNotEmpty) {
            totalDuration = double.tryParse(playerInfo.duration.first.toString()) ?? 1.0;
          }
          if (playerInfo.trackName.isNotEmpty) trackTitle = playerInfo.trackName.first.toString();
          if (playerInfo.artistName.isNotEmpty) artistName = playerInfo.artistName.first.toString();
        }

        // --- SUB-UI: ARTWORK & METADATA ---
        final metaSection = ValueListenableBuilder(
          valueListenable: CurrentInfoString.isFetching,
          builder: (context, fetching, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. ARTWORK
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isLandscape ? 20 : 40),
                  child: AspectRatio(
                    aspectRatio: targetAspectRatio,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: fetching ? 8.0 : 0.0, sigmaY: fetching ? 8.0 : 0.0),
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

                SizedBox(height: sw > 900 ? 32 : (isLandscape ? 16 : 24)),

                // 2. TITLE & ARTIST
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Column(
                    children: [
                      SizedBox(
                        height: titleHeight,
                        child: LayoutBuilder(builder: (context, constraints) {
                          bool fits = (trackTitle.length * (titleFontSize * 0.45)) < constraints.maxWidth;
                          return fits
                              ? Center(child: Text(trackTitle, style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.w700)))
                              : Marquee(text: trackTitle, style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.w700), scrollAxis: Axis.horizontal, crossAxisAlignment: CrossAxisAlignment.center, blankSpace: 80.0, velocity: 30.0, pauseAfterRound: const Duration(seconds: 3));
                        }),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: artistHeight,
                        child: LayoutBuilder(builder: (context, constraints) {
                          bool fits = (artistName.length * (artistFontSize * 0.45)) < constraints.maxWidth;
                          return fits
                              ? Center(child: Text(artistName, style: TextStyle(fontSize: artistFontSize, color: Colors.grey[600])))
                              : Marquee(text: artistName, style: TextStyle(fontSize: artistFontSize, color: Colors.grey[600]), scrollAxis: Axis.horizontal, crossAxisAlignment: CrossAxisAlignment.center, blankSpace: 80.0, velocity: 25.0, pauseAfterRound: const Duration(seconds: 3));
                        }),
                      ),
                    ],
                  ),
                ),

                if (!isLandscape) const SizedBox(height: 12),

              ],
            );
          },
        );

        // --- SUB-UI: ALL CONTROLS ---
        final controlsSection = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  M3EProgressIndicator.linearWavy(
                    value: (_localElapsed / totalDuration).clamp(0.0, 1.0),
                    linearSize: progressSize,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_localElapsed), style: TextStyle(fontSize: timeFontSize, fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()])),
                        Text("-${_formatDuration(totalDuration - _localElapsed)}", style: TextStyle(fontSize: timeFontSize, fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()])),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isLandscape ? 4 : 12),

            // Main Playback Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(iconSize: playbackIconSize, onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.previous), icon: const Icon(M3EIcons.skip_previous_rounded)),
                    IconButton(iconSize: playbackIconSize, onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.rewind), icon: const Icon(M3EIcons.replay_10)),
                    IconButton(iconSize: mainToggleIconSize, onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.toggle), icon: Icon(playerInfo?.isPlaying == true ? M3EIcons.pause_rounded : M3EIcons.play_arrow_rounded)),
                    IconButton(iconSize: playbackIconSize, onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.forward), icon: const Icon(M3EIcons.forward_10)),
                    IconButton(iconSize: playbackIconSize, onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.next), icon: const Icon(M3EIcons.skip_next_rounded)),
                  ],
                ),
              ),
            ),

            SizedBox(height: isLandscape ? 4 : 12),

            // Volume Control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  M3EIconButton(variant: M3EIconButtonVariant.tonal, size: M3EIconButtonSize.xs, onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.volumeDown), icon: const Icon(M3EIcons.volume_down_rounded, size: 20)),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: ClipRRect(borderRadius: BorderRadius.circular(4), child: M3EProgressIndicator.linear(value: (playerInfo!.volume / 1).clamp(0.0, 1.0), linearSize: progressSize)))),
                  M3EIconButton(variant: M3EIconButtonVariant.tonal, size: M3EIconButtonSize.xs, onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.volumeUp), icon: const Icon(M3EIcons.volume_up_rounded, size: 20)),
                ],
              ),
            ),

            SizedBox(height: isLandscape ? 8 : 16),

            // Bottom Bar Accessories
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  M3EIconButton(size: accessorySize, variant: playerInfo.repeatMode != 0 ? M3EIconButtonVariant.filled : M3EIconButtonVariant.tonal, shape: M3EIconButtonShapeVariant.round, onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.cycleRepeat), icon: Icon(playerInfo.repeatMode == 1 ? M3EIcons.repeat_one_rounded : M3EIcons.repeat_rounded)),
                  const SizedBox(width: 12),
                  M3EIconButton(size: accessorySize, shape: M3EIconButtonShapeVariant.round, onPressed: () => InfoService().writeToAMS(), variant: M3EIconButtonVariant.tonal, icon: const Icon(M3EIcons.refresh)),
                  const SizedBox(width: 12),
                  M3EIconButton(size: accessorySize, onPressed: () => _remoteControlService.sendRemoteCommand(RemoteCommands.cycleShuffle), variant: playerInfo.shuffleMode != 0 ? M3EIconButtonVariant.filled : M3EIconButtonVariant.tonal, shape: M3EIconButtonShapeVariant.round, icon: const Icon(M3EIcons.shuffle_rounded)),
                ],
              ),
            ),
          ],
        );

        return Scaffold(
          extendBodyBehindAppBar: isLandscape,
          appBar: AppBar(
            backgroundColor: isLandscape? Colors.transparent:null,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(M3EIcons.close),
              onPressed: () async {
                final controller = BleController();
                final device = controller.connectedDevice;
                if (device != null) await controller.disconnectDevice(device);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            title: isLandscape
                ? null  // Removes the clashing title
                : Text(
              BleController().connectedDevice?.platformName ?? "Now Playing",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(M3EIcons.settings_rounded),
                onPressed: () {
                  final device = BleController().connectedDevice;
                  if (device != null) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => DeviceDetailsScreen(device: device)));
                  }
                },
              ),
            ],
          ),
          body: SafeArea(
            top: !isLandscape,
            bottom: !isLandscape,
            child: isLandscape
                ? Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Row(
              children: [
                Expanded(flex: 25, child: Center(child: SingleChildScrollView(padding: EdgeInsets.symmetric(horizontal: (sw * 0.035).clamp(20, 60), vertical: 0), child: metaSection))),
                Expanded(flex: 30, child: Center(child: SingleChildScrollView(padding: EdgeInsets.only(top: (sh * 0.1).clamp(20, 40), left: (sw * 0.06).clamp(16, 40), right: (sw * 0.06).clamp(16, 40)), child: controlsSection,))),
              ],
            ),
        ) : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false, // This is key: it makes Spacers work
                  child: Column(
                    children: [
                      // Top Indicator
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
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

                      metaSection,

                      const SizedBox(height: 12),

                      controlsSection,

                      const Spacer(flex: 3),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          resizeToAvoidBottomInset: null,
        );
      },
    );
  }
}
