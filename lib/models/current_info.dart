import 'package:flutter/foundation.dart';

int isFixingDelay = 0; // used for duplicate call for fixing delay FIX.

class MediaPlayerInfo {
  List<Object>
      trackName,
      artistName,
      repeatStatus,
      shuffleStatus,
      duration,
      albumName;
      double timeFromAMD;
      double elapsedTime;
      bool isPlaying;
      String artworkURL;
      int shuffleMode;
      int repeatMode;
      double volume;
      bool pendingArtistChange = false;
      bool pendingTitleChange = false;

  MediaPlayerInfo({
    required this.trackName,
    required this.artistName,
    required this.repeatStatus,
    required this.shuffleStatus,
    required this.isPlaying,
    required this.duration,
    required this.albumName,
    required this.timeFromAMD,
    required this.elapsedTime,
    required this.artworkURL,
    required this.shuffleMode,
    required this.repeatMode,
    required this.volume,
    required this. pendingArtistChange ,
    required this. pendingTitleChange

  });
}

class CurrentInfoString {
  // A complete list of all information that is used by the media interface
  static final ValueNotifier<int> updateTrigger = ValueNotifier(0); //update trigger for media player.
  static final ValueNotifier<bool> isFetching = ValueNotifier(false); // value to keep info is the app is fetching metadata.
  static final Map<String, MediaPlayerInfo> registry =
  {
    'GetPlayerNameBytes': MediaPlayerInfo(
        trackName: [],
        artistName: [],
        repeatStatus: [],
        shuffleStatus: [],
        duration: [],
        albumName: [],
        timeFromAMD: 0.0,
        elapsedTime: 0.0,
        isPlaying: false,
        artworkURL: "",
        shuffleMode: 0,
        repeatMode: 0,
        volume: 0.0,
        pendingArtistChange: false,
        pendingTitleChange: false,
    ),
  };
}





