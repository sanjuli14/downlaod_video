enum MediaType { video, subtitle, audio, unknown }

class MediaFile {
  final String name;
  final String url;
  final MediaType type;
  bool isSelected;
  String? taskId;

  MediaFile({
    required this.name,
    required this.url,
    required this.type,
    this.isSelected = true,
    this.taskId,
  });

  factory MediaFile.fromUrl(String name, String url) {
    MediaType type = MediaType.unknown;
    final lowerName = name.toLowerCase();
    
    if (lowerName.endsWith('.mp4') || lowerName.endsWith('.mkv') || lowerName.endsWith('.avi')) {
      type = MediaType.video;
    } else if (lowerName.endsWith('.srt')) {
      type = MediaType.subtitle;
    } else if (lowerName.endsWith('.mp3')) {
      type = MediaType.audio;
    }

    return MediaFile(name: name, url: url, type: type);
  }
}
