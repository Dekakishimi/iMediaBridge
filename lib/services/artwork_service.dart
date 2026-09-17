// lib/services/artwork_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/current_info.dart';

Future<String> fetchArtwork(String artist, String track) async {

  final playerInfo = CurrentInfoString.registry['GetPlayerNameBytes'];
  final playerPackage = playerInfo?.playerName ?? "";

  if (playerPackage == 'LiveContainer' || artist.toLowerCase().contains('livecontainer')) {
    return fetchYouTubeThumbnail(track, artist);
  }

  if (playerPackage == 'Music' || artist.toLowerCase().contains('music')) {
    return fetchYouTubeMusicArtwork(track, artist);
  }

  try {
    print(track);
    print(artist);

    final query = Uri.encodeComponent('$artist $track');
    print('search query: $query');
    final url = Uri.parse('https://itunes.apple.com/search?term=$query&entity=song&attribute=songTerm&limit=1');

    final client = HttpClient();
    final request = await client.getUrl(url);
    final response = await request.close();

    if (response.statusCode == 200) {
      final content = await response.transform(utf8.decoder).join();
      final data = json.decode(content);

      if (data['results'] != null && data['results'].isNotEmpty) {
        String url = data['results'][0]['artworkUrl100'];
        return url.replaceAll('100x100bb.jpg', '1000x1000bb.jpg');
      }
    }
  } catch (e) {
    print("Artwork fetch failed: $e");
  }
  return "";
}

Future<String> fetchYouTubeThumbnail(String title, String channel) async {
  if (title.isEmpty) return "";

  try {
    // 1. Clean up the query string
    String cleanTitle = title
        .replaceAll(RegExp(r'\(Official Video\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Official Audio\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\| Video', caseSensitive: false), '')
        .trim();

    final searchUrl = Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeComponent('$cleanTitle $channel')}');
    print('Scraping YouTube Search for Video ID: $searchUrl');

    // 2. Fetch the raw search results page HTML content
    // We send a standard desktop browser header to make sure YouTube sends down correct video lists
    final response = await http.get(searchUrl, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
    });

    if (response.statusCode == 200) {
      final html = response.body;

      // 3. Find the first video ID match inside the raw page data using a RegExp
      // YouTube embeds watch links inside the JSON block: "/watch?v=XXXXXXXXXXX"
      final regExp = RegExp(r'\/watch\?v=([a-zA-Z0-9_-]{11})');
      final match = regExp.firstMatch(html);

      if (match != null && match.groupCount >= 1) {
        final String videoId = match.group(1)!;
        print('Successfully extracted Video ID: $videoId');

        // 4. Return the maximum resolution widescreen thumbnail image URL directly
        final String hqThumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';

        // Double-check if maxresdefault exists by making a swift HEAD request,
        // fallback to hqdefault if it's an older non-HD video clip
        final checkResponse = await http.head(Uri.parse(hqThumbnailUrl));
        if (checkResponse.statusCode == 200) {
          return hqThumbnailUrl;
        } else {
          return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
        }
      } else {
        print('Could not locate any video IDs in the search results html.');
      }
    } else {
      print('YouTube Search server returned status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Scraper thumbnail extraction failed: $e');
  }

  return ""; // Returns empty string safely to fallback to the M3E video icon placeholder
}

Future<String> fetchYouTubeMusicArtwork(String artist, String track) async {
  if (track.isEmpty || artist.isEmpty) return "";

  try {
    // 1. Construct the YouTube Music Search Endpoint URL
    final query = Uri.encodeComponent('$artist $track');
    final searchUrl = Uri.parse('https://music.youtube.com/search?q=$query');
    print('Searching YouTube Music for artwork: $searchUrl');

    // 2. Query the endpoint using a standard web browser User-Agent
    final response = await http.get(searchUrl, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
    });

    if (response.statusCode == 200) {
      final html = response.body;

      // 3. Match Google's album image URL signature inside the script tags
      // YouTube Music tracks images host on the lh3.googleusercontent.com or googleusercontent domains

      final regExp = RegExp(
        r'https?:\\?\/\\?\/[a-zA-Z0-9._-]+\.(?:googleusercontent|ggpht|ytimg)\.com\\?\/[^"\\ ]+'
      );

      // 2. Fetch all matches and find the first one that looks like a high-res cover
      final matches = regExp.allMatches(html);
      String artworkUrl = "";

      for (final match in matches) {
        String candidate = match.group(0)!;

        // Clean the URL (remove escape characters)
        candidate = candidate.replaceAll(r'\/', '/').replaceAll(r'\u003d', '=');

        // YouTube Music search results often use hqdefault.jpg for videos in results.
        // We want the ones that contain 'googleusercontent' (albums) or high-res video thumbnails.
        if (candidate.contains('googleusercontent') || candidate.contains('hqdefault.jpg')) {
          artworkUrl = candidate;
          break;
        }
      }

      if (artworkUrl.isNotEmpty) {
        // UPGRADE RESOLUTION:
        // For googleusercontent links:
        artworkUrl = artworkUrl.replaceAll(RegExp(r'=w\d+-h\d+'), '=w1000-h1000');

        // For ytimg (video) links, upgrade hqdefault to maxresdefault
        if (artworkUrl.contains('hqdefault.jpg')) {
          artworkUrl = artworkUrl.replaceAll('hqdefault.jpg', 'maxresdefault.jpg');
        }
        print('Successfully extracted YouTube Music Asset: $artworkUrl');
        return artworkUrl;
      } else {
        print('No valid artwork candidates found in HTML.');
      }
    } else {
      print('YouTube Music Server error status: ${response.statusCode}');
    }
  } catch (e) {
    print('YouTube Music artwork scraper exception: $e');
  }

  return ""; // Returns empty safely to trigger fallback asset states
}