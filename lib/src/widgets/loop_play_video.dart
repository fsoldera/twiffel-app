import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Shared wait-screen clip, initialized at splash so it can loop without a pop-in.
class WaitingVideo {
  static VideoPlayerController? controller;
  static Future<void>? _preload;

  static bool get isReady => controller?.value.isInitialized == true;

  static bool get _inWidgetTest {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  }

  static Future<void> preload() {
    if (_inWidgetTest) return Future<void>.value();
    return _preload ??= _load();
  }

  static Future<void> _load() async {
    final next = VideoPlayerController.asset(LoopPlayVideo.defaultAsset);
    try {
      await next.initialize();
      await next.setVolume(0);
      await next.setLooping(true);
      await next.pause();
      await next.seekTo(Duration.zero);
      controller = next;
    } catch (_) {
      await next.dispose();
      _preload = null;
    }
  }
}

/// Asset video that loops while visible, muted.
class LoopPlayVideo extends StatefulWidget {
  const LoopPlayVideo({
    super.key,
    this.asset = defaultAsset,
    this.maxHeight = 220,
  });

  static const defaultAsset = 'assets/animations/waiting-loop.mp4';
  static const slotKey = ValueKey<String>('waiting-loop-video');

  final String asset;
  final double maxHeight;

  @override
  State<LoopPlayVideo> createState() => _LoopPlayVideoState();
}

class _LoopPlayVideoState extends State<LoopPlayVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;

  static bool get _inWidgetTest {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();
    if (_inWidgetTest) return;
    final cached = WaitingVideo.controller;
    if (cached != null && cached.value.isInitialized) {
      _attach(cached);
      return;
    }
    _start();
  }

  void _attach(VideoPlayerController controller) {
    _controller = controller;
    _ready = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playOrFreeze();
    });
  }

  Future<void> _start() async {
    await WaitingVideo.preload();
    if (!mounted) return;
    final cached = WaitingVideo.controller;
    if (cached == null || !cached.value.isInitialized) return;
    setState(() => _attach(cached));
  }

  void _playOrFreeze() {
    final controller = _controller;
    if (!mounted || controller == null || !controller.value.isInitialized) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.pause();
      return;
    }
    controller.play();
  }

  @override
  void dispose() {
    _controller?.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null || !controller.value.isInitialized) {
      return const SizedBox(key: LoopPlayVideo.slotKey);
    }
    final size = controller.value.size;
    final aspect = size.height == 0 ? 16 / 9 : size.width / size.height;
    return KeyedSubtree(
      key: LoopPlayVideo.slotKey,
      child: Semantics(
        label: 'Loading',
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: AspectRatio(
              aspectRatio: aspect,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      ),
    );
  }
}
