enum EmbeddedMediaProvider { youtube, vimeo, direct }

class MediaLinkInfo {
  const MediaLinkInfo({
    required this.provider,
    required this.originalUri,
    this.videoId,
    this.embedUri,
  });

  final EmbeddedMediaProvider provider;
  final Uri originalUri;
  final String? videoId;
  final Uri? embedUri;

  static MediaLinkInfo? parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');

    if (const {
      'youtube.com',
      'm.youtube.com',
      'youtube-nocookie.com',
      'youtu.be',
    }.contains(host)) {
      final id = _youtubeId(uri, host);
      if (id == null) return null;
      return MediaLinkInfo(
        provider: EmbeddedMediaProvider.youtube,
        originalUri: uri,
        videoId: id,
        embedUri: Uri.https('www.youtube-nocookie.com', '/embed/$id'),
      );
    }

    if (const {'vimeo.com', 'player.vimeo.com'}.contains(host)) {
      final id = uri.pathSegments.reversed.firstWhere(
        (segment) => RegExp(r'^\d+$').hasMatch(segment),
        orElse: () => '',
      );
      if (id.isEmpty) return null;
      return MediaLinkInfo(
        provider: EmbeddedMediaProvider.vimeo,
        originalUri: uri,
        videoId: id,
        embedUri: Uri.https('player.vimeo.com', '/video/$id'),
      );
    }

    return MediaLinkInfo(
      provider: EmbeddedMediaProvider.direct,
      originalUri: uri,
    );
  }

  static String? _youtubeId(Uri uri, String host) {
    String? id;
    if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
      id = uri.pathSegments.first;
    } else {
      id = uri.queryParameters['v'];
      if ((id == null || id.isEmpty) && uri.pathSegments.length >= 2) {
        final marker = uri.pathSegments.first;
        if (marker == 'embed' || marker == 'shorts' || marker == 'live') {
          id = uri.pathSegments[1];
        }
      }
    }
    if (id == null || !RegExp(r'^[A-Za-z0-9_-]{6,}$').hasMatch(id)) {
      return null;
    }
    return id;
  }
}
