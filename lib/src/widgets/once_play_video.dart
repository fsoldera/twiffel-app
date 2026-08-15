import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Shared hero clip, initialized during splash so the first screen can paint it.
class HeroVideo {
  static VideoPlayerController? controller;
  static Future<void>? _preload;
  static bool splashCleared = false;
  static VoidCallback? onSplashCleared;

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
    final next = VideoPlayerController.asset(OncePlayVideo.defaultAsset);
    try {
      await next.initialize();
      await next.setVolume(0);
      await next.setLooping(false);
      await next.pause();
      await next.seekTo(Duration.zero);
      controller = next;
    } catch (_) {
      await next.dispose();
      _preload = null;
    }
  }

  static void markSplashCleared() {
    splashCleared = true;
    onSplashCleared?.call();
  }
}

/// Asset video that plays once, then holds the last frame.
class OncePlayVideo extends StatefulWidget {
  const OncePlayVideo({
    super.key,
    this.asset = defaultAsset,
    this.maxHeight = 200,
  });

  static const defaultAsset = 'assets/animations/hero-rabbit.mp4';
  static const slotKey = ValueKey<String>('first-step-hero-video');

  final String asset;
  final double maxHeight;

  @override
  State<OncePlayVideo> createState() => _OncePlayVideoState();
}

class _OncePlayVideoState extends State<OncePlayVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _froze = false;

  static bool get _inWidgetTest {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();
    if (_inWidgetTest) return;
    final cached = HeroVideo.controller;
    if (cached != null && cached.value.isInitialized) {
      _attach(cached);
      return;
    }
    _start();
  }

  void _attach(VideoPlayerController controller) {
    _controller = controller;
    _ready = true;
    controller.addListener(_onTick);
    HeroVideo.onSplashCleared = _playWhenAllowed;
    if (HeroVideo.splashCleared) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playWhenAllowed();
      });
    }
  }

  Future<void> _start() async {
    await HeroVideo.preload();
    if (!mounted) return;
    final cached = HeroVideo.controller;
    if (cached == null || !cached.value.isInitialized) return;
    setState(() => _attach(cached));
  }

  void _playWhenAllowed() {
    final controller = _controller;
    if (!mounted || controller == null || !controller.value.isInitialized) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _freezeOnLastFrame();
      return;
    }
    final duration = controller.value.duration;
    if (duration > Duration.zero && controller.value.position >= duration) {
      return;
    }
    controller.play();
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || _froze || !controller.value.isInitialized) {
      return;
    }
    final duration = controller.value.duration;
    if (duration <= Duration.zero) return;
    if (controller.value.position >= duration) {
      _freezeOnLastFrame();
    }
  }

  Future<void> _freezeOnLastFrame() async {
    if (_froze) return;
    _froze = true;
    final controller = _controller;
    if (controller == null) return;
    final duration = controller.value.duration;
    await controller.pause();
    if (duration > Duration.zero) {
      await controller.seekTo(duration);
    }
  }

  @override
  void dispose() {
    if (HeroVideo.onSplashCleared == _playWhenAllowed) {
      HeroVideo.onSplashCleared = null;
    }
    _controller?.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null || !controller.value.isInitialized) {
      return const SizedBox(key: OncePlayVideo.slotKey);
    }
    final size = controller.value.size;
    final aspect = size.height == 0 ? 16 / 9 : size.width / size.height;
    return KeyedSubtree(
      key: OncePlayVideo.slotKey,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: AspectRatio(
            aspectRatio: aspect,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}
