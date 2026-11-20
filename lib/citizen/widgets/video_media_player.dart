import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoMediaPlayer extends StatefulWidget {
  const VideoMediaPlayer({super.key, required this.url});
  final String url;
  @override
  State<VideoMediaPlayer> createState() => _VideoMediaPlayerState();
}

class _VideoMediaPlayerState extends State<VideoMediaPlayer> {
  late final VideoPlayerController c = VideoPlayerController.networkUrl(
    Uri.parse(widget.url),
  );
  Object? _error;

  @override
  void initState() {
    super.initState();
    c.initialize().then(
      (_) {
        if (mounted) setState(() {});
      },
      onError: (Object error) {
        if (mounted) setState(() => _error = error);
      },
    );
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _error != null
      ? const AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
            color: Colors.black12,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_file_outlined),
                  SizedBox(height: 8),
                  Text('This video could not be loaded.'),
                ],
              ),
            ),
          ),
        )
      : c.value.isInitialized
      ? AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(c),
              IconButton.filled(
                onPressed: () {
                  setState(() {
                    c.value.isPlaying ? c.pause() : c.play();
                  });
                },
                icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
            ],
          ),
        )
      : const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(child: CircularProgressIndicator()),
        );
}
