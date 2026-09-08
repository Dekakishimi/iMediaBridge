// lib/services/artwork_service.dart
import 'dart:convert';
import 'dart:io';

Future<String> fetchArtwork(String artist, String track) async {
  try {
    final query = Uri.encodeComponent('$artist $track');
    final url = Uri.parse('https://itunes.apple.com/search?term=$query&entity=song&limit=1');

    final client = HttpClient();
    final request = await client.getUrl(url);
    final response = await request.close();

    if (response.statusCode == 200) {
      final content = await response.transform(utf8.decoder).join();
      final data = json.decode(content);

      if (data['results'] != null && data['results'].isNotEmpty) {
        String url = data['results'][0]['artworkUrl100'];
        return url.replaceAll('100x100bb.jpg', '600x600bb.jpg');
      }
    }
  } catch (e) {
    print("Artwork fetch failed: $e");
  }
  return "";
}