import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';
import '../models/media_file.dart';

class ScraperService {
  static Future<List<MediaFile>> scanUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to load page: ${response.statusCode}');
      }

      final document = parser.parse(response.body);
      final List<MediaFile> files = [];

      // visuales.uclv.cu and similar sites usually use <a> tags in tables or lists
      final List<Element> links = document.querySelectorAll('a');

      for (var link in links) {
        final href = link.attributes['href'];
        final text = link.text.trim();

        if (href != null && _isMediaFile(href)) {
          // Normalize URL if it's relative
          String fullUrl = href;
          if (!href.startsWith('http')) {
             final baseUri = Uri.parse(url);
             fullUrl = baseUri.resolve(href).toString();
          }

          files.add(MediaFile.fromUrl(text.isEmpty ? _getFileNameFromUrl(href) : text, fullUrl));
        }
      }

      return files;
    } catch (e) {
      print('Scraping error: $e');
      return [];
    }
  }

  static bool _isMediaFile(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.mp4') ||
        lowerUrl.endsWith('.mkv') ||
        lowerUrl.endsWith('.avi') ||
        lowerUrl.endsWith('.srt') ||
        lowerUrl.endsWith('.mp3');
  }

  static String _getFileNameFromUrl(String url) {
    return url.split('/').last;
  }
}
