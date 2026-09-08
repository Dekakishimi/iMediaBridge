class CommandBytes {
  final List<int> bytes;

  const CommandBytes({
    required this.bytes,
  });
}

class GetCommandsForAMS {
  // A compilation of hex codes for AMS commands, feel free to add more (please mention in your PR if you do.)
  static const Map<String, CommandBytes> registry =
  {

    // ENTITYID = 0 (PLAYER)

    'GetPlayerNameBytes': CommandBytes(
        bytes: [0,0]
    ),
    'GetPlaybackInfoBytes': CommandBytes(
        bytes: [0,1]
    ),
    'GetVolumeBytes': CommandBytes(
        bytes: [0,2]
    ),

    // ENTITYID = 1 (QUEUE)

    'GetQueueIndexBytes': CommandBytes(
        bytes: [1,0]
    ),
    'GetQueueCountBytes': CommandBytes(
        bytes: [1,1]
    ),
    'GetShuffleModeBytes': CommandBytes(
        bytes: [1,2] // 0=OFF, 1=ONE 2=ALL
    ),
    'GetRepeatModeBytes': CommandBytes(
        bytes: [1,3] // 0=OFF, 1=ONE 2=ALL
    ),

    // ENTITYID = 2 (TRACK INFO)

    'GetArtistNameBytes': CommandBytes(
        bytes: [2,0]
    ),
    'GetAlbumNameBytes': CommandBytes(
        bytes: [2,1]
    ),
    'GetTrackTitleBytes': CommandBytes(
        bytes: [2,2] // 0=OFF, 1=ONE 2=ALL
    ),
    'GetDurationBytes': CommandBytes(
        bytes: [2,3] // 0=OFF, 1=ONE 2=ALL
    ),
  };
}

class RemoteCommands {

  // Lists of bytes for the remoteCommands of the Apple Media Services.
  // I wont put comments for them since its pretty self-explanatory lol.
  static const List<int> play = [0];

  static const List<int> pause = [1];

  static const List<int> toggle = [2]; //this should only be used if the app doesn't support play/pause.

  static const List<int> next = [3];

  static const List<int> previous = [4];

  static const List<int> volumeUp = [5];

  static const List<int> volumeDown = [6];

  static const List<int> cycleRepeat = [7];

  static const List<int> cycleShuffle = [8];

  static const List<int> forward = [9];

  static const List<int> rewind = [10];

  // commands that should not trigger blur of image and text.
  static const List<List<int>> silentCommands = [[7], [8], [0], [1], [2]];
}


