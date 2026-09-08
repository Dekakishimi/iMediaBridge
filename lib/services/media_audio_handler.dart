import 'package:audio_service/audio_service.dart';
import 'remote_control_service.dart';
import '../models/get_send_tables.dart';

class MediaBridgeAudioHandler extends BaseAudioHandler with SeekHandler {
  final RemoteControlService _remoteControlService = RemoteControlService();

  // 1. Handle Play/Pause from Notification
  @override
  Future<void> play() => _remoteControlService.sendRemoteCommand(RemoteCommands.play);

  @override
  Future<void> pause() => _remoteControlService.sendRemoteCommand(RemoteCommands.pause);

  @override
  Future<void> stop() async {
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
    await super.stop();
  }

  // 2. Handle Skip from Notification
  @override
  Future<void> skipToNext() => _remoteControlService.sendRemoteCommand(RemoteCommands.next);

  @override
  Future<void> skipToPrevious() => _remoteControlService.sendRemoteCommand(RemoteCommands.previous);

  // 3. Handle Seek from Notification
  @override

  // 4. Custom method to update metadata from your BLE notifications
  void updateMetadata({
    required String title,
    required String artist,
    required String album,
    required Duration duration,
    String? artworkUrl,
  }) {
    mediaItem.add(MediaItem(
      id: 'mediabridge_current',
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
    ));
  }

  // 5. Custom method to update playback state (playing/paused)
  void updatePlaybackState(bool isPlaying, Duration position) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: {MediaAction.seek},
      playing: isPlaying,
      updatePosition: position,
      processingState: AudioProcessingState.ready,
    ));
  }
}