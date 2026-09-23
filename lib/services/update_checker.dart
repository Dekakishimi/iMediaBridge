// lib/services/update_checker.dart
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

class GitHubRelease {
  final String tagName;
  final String htmlUrl;
  final String body;

  GitHubRelease({
    required this.tagName,
    required this.htmlUrl,
    required this.body,
  });
}

class UpdateChecker {
  // Replace with your GitHub Username and Repository Name
  static const String githubOwner = 'Dekakishimi';
  static const String githubRepo = 'iMediaBridge';
  static const String currentVersion = '1.0.9'; // Current app version

  /// Checks GitHub API for the latest release
  static Future<GitHubRelease?> checkForUpdate() async {
    try {
      final url = Uri.parse(
        'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest',
      );

      final response = await http.get(url, headers: {
        'Accept': 'application/vnd.github+json',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String rawTagName = (data['tag_name'] ?? '').toString();

        // ✅ Strip all leading non-digit letters (handles both 'v' and 'V')
        final String cleanedTag = rawTagName.replaceAll(RegExp(r'^[^\d]+'), '').trim();
        final String htmlUrl = data['html_url'] ?? '';
        final String body = data['body'] ?? '';

        print("Update Check -> Current: $currentVersion | GitHub: $cleanedTag ($rawTagName)");

        if (_isNewerVersion(currentVersion, cleanedTag)) {
          return GitHubRelease(
            tagName: data['tag_name'] ?? cleanedTag,
            htmlUrl: htmlUrl,
            body: body,
          );
        }
      }
    } catch (e) {
      print('Failed to check for updates: $e');
    }
    return null;
  }

  /// Compares current version (e.g. 1.1.0) with latest tag (e.g. 1.2.0)
  static bool _isNewerVersion(String current, String latest) {
    try {
      List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < latestParts.length; i++) {
        int currentPart = i < currentParts.length ? currentParts[i] : 0;
        if (latestParts[i] > currentPart) return true;
        if (latestParts[i] < currentPart) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Displays the Update Dialog
  static void showUpdateDialog(BuildContext context, GitHubRelease release) {
    if (!context.mounted) return;

    try {
      M3EDialog.show<void>(
        context,
        barrierDismissible: true,
        dialog : M3EDialog(
          icon: const Icon(M3EIcons.system_update_alt, size: 32),
          title: ('Update Available (${release.tagName})'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'A new version of iMediaBridge is available on GitHub!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if (release.body.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Release Notes:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    release.body,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            M3EButton(
              style: M3EButtonStyle.text,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
            M3EButton(
              style: M3EButtonStyle.filled,
              onPressed: () async {
                final Uri url = Uri.parse(release.htmlUrl);
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (e) {
                  print("Error launching update URL: $e");
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Download'),
            ),
          ],
        ),
      );
    } catch (e) {
      print("Error displaying update dialog: $e");
    }
  }
}