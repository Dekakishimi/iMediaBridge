import 'package:flutter/material.dart';
import 'package:mediabridge/models/current_info.dart';


class MediaInterface extends StatefulWidget {
  const MediaInterface({super.key});

  @override
  State<MediaInterface> createState() => _MediaInterfaceState();
}

class _MediaInterfaceState extends State<MediaInterface> {


  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: CurrentInfoString.updateTrigger,
        builder: (context, value, child) {

      //carryover the data from the current info map
      final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];
      //for track title
      String trackTitle = "Unknown Track";
      if (playerInfo != null && playerInfo.trackName.isNotEmpty) {
        trackTitle = playerInfo.trackName.first.toString();
      }
      //for artist name
      String artistName = "Unknown Artist";
      if (playerInfo != null && playerInfo.artistName.isNotEmpty) {
        artistName = playerInfo.artistName.first.toString();
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

              // Album Art View
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.music_note_rounded,
                        size: 120,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // Title and Artist Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(
                             trackTitle, //track title
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            artistName, //artist name
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // More Options Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.more_horiz, size: 24),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Scrubber (Progress Bar)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14),
                        activeTrackColor: Colors.black87,
                        inactiveTrackColor: Colors.grey[300],
                        thumbColor: Colors.black87,
                      ),
                      child: Slider(
                        value: 0.35,
                        onChanged: (value) {},
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1:12', style: TextStyle(color: Colors.grey,
                              fontSize: 12)),
                          Text('-2:45', style: TextStyle(color: Colors.grey,
                              fontSize: 12)),
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
                    onPressed: () {},
                    icon: const Icon(
                        Icons.skip_previous_rounded, color: Colors.black),
                  ),
                  IconButton(
                    iconSize: 85,
                    onPressed: () {},
                    icon: const Icon(
                        Icons.play_arrow_rounded, color: Colors.black),
                  ),
                  IconButton(
                    iconSize: 45,
                    onPressed: () {},
                    icon: const Icon(
                        Icons.skip_next_rounded, color: Colors.black),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // Volume Control
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  children: [
                    const Icon(
                        Icons.volume_down_rounded, size: 20, color: Colors.grey),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 0), // Hidden thumb like Apple
                          activeTrackColor: Colors.grey[600],
                          inactiveTrackColor: Colors.grey[200],
                        ),
                        child: Slider(
                          value: 0.6,
                          onChanged: (value) {},
                        ),
                      ),
                    ),
                    const Icon(
                        Icons.volume_up_rounded, size: 20, color: Colors.grey),
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
                      onPressed: () {},
                      icon: const Icon(
                          Icons.image, color: Colors.black54, size: 22),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                          Icons.airplay_rounded, color: Colors.black54, size: 22),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                          Icons.list_rounded, color: Colors.black54, size: 22),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}