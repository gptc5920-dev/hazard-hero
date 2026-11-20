import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../shared/media/media_link.dart';
import 'video_media_player.dart';

class EmbeddedVideoPlayer extends StatelessWidget {
  const EmbeddedVideoPlayer({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final info = MediaLinkInfo.parse(url);
    return switch (info?.provider) {
      EmbeddedMediaProvider.youtube => _YouTubePlayer(videoId: info!.videoId!),
      EmbeddedMediaProvider.vimeo => _VimeoPlayer(uri: info!.embedUri!),
      _ => VideoMediaPlayer(url: url),
    };
  }
}

class _YouTubePlayer extends StatefulWidget {
  const _YouTubePlayer({required this.videoId});

  final String videoId;

  @override
  State<_YouTubePlayer> createState() => _YouTubePlayerState();
}

class _YouTubePlayerState extends State<_YouTubePlayer> {
  late final YoutubePlayerController _controller =
      YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: true,
        ),
      );

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      YoutubePlayer(controller: _controller, aspectRatio: 16 / 9);
}

class _VimeoPlayer extends StatefulWidget {
  const _VimeoPlayer({required this.uri});

  final Uri uri;

  @override
  State<_VimeoPlayer> createState() => _VimeoPlayerState();
}

class _VimeoPlayerState extends State<_VimeoPlayer> {
  var _progress = 0;
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.black)
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        onNavigationRequest: (request) {
          final host = Uri.tryParse(request.url)?.host.toLowerCase() ?? '';
          return host == 'player.vimeo.com' || host.endsWith('.vimeo.com')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ),
    )
    ..loadRequest(widget.uri);

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Stack(
      children: [
        Positioned.fill(child: WebViewWidget(controller: _controller)),
        if (_progress < 100)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black12,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    ),
  );
}
