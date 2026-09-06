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


