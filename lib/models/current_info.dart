import 'package:flutter/foundation.dart';

class MediaPlayerInfo {
  List<Object> trackName, artistName, repeatStatus, shuffleStatus, isPlaying, duration, albumName;

  MediaPlayerInfo({
    required this.trackName,
    required this.artistName,
    required this.repeatStatus,
    required this.shuffleStatus,
    required this.isPlaying,
    required this.duration,
    required this.albumName,
  });
}

class CurrentInfoString {
  // A complete list of all
  static final ValueNotifier<int> updateTrigger = ValueNotifier(0); //update trigger for media player.
  static final Map<String, MediaPlayerInfo> registry =
  {
    'GetPlayerNameBytes': MediaPlayerInfo(
        trackName: [],
        artistName: [],
        repeatStatus: [],
        shuffleStatus: [],
        isPlaying: [],
        duration: [],
        albumName: [],
    ),
  };
}


