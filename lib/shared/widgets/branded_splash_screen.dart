import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BrandedSplashScreen extends StatefulWidget {
  const BrandedSplashScreen({
    super.key,
    this.onFinished,
    this.duration = const Duration(milliseconds: 1500),
    this.error,
  });

  final VoidCallback? onFinished;
  final Duration duration;
  final Object? error;

  @override
  State<BrandedSplashScreen> createState() => _BrandedSplashScreenState();
}

class _BrandedSplashScreenState extends State<BrandedSplashScreen>
    with SingleTickerProviderStateMixin {
  static const _brand = Color(0xffdd2d4a);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: .84,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.onFinished != null && widget.error == null) {
      _timer = Timer(widget.duration, () {
        if (mounted) widget.onFinished!();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: _brand,
      systemNavigationBarDividerColor: _brand,
    ),
    child: PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _brand,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _SplashPattern(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Spacer(),
                    FadeTransition(
                      opacity: _fade,
                      child: ScaleTransition(
                        scale: _scale,
                        child: const _BrandMark(),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: _fade,
                      child: const Column(
                        children: [
                          Text(
                            'HAZARD HERO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Ready. Resilient. Together.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xfffde9ed),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (widget.error == null)
                      const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxWidth: 440),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .28),
                          ),
                        ),
                        child: const Text(
                          'Hazard Hero could not finish starting. Please close the app and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 116,
    height: 116,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(32),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 30,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: const Icon(
      Icons.health_and_safety_rounded,
      color: Color(0xffdd2d4a),
      size: 68,
    ),
  );
}

class _SplashPattern extends StatelessWidget {
  const _SplashPattern();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        Positioned(
          right: -110,
          top: -105,
          child: _Ring(size: 310, opacity: .12),
        ),
        Positioned(
          left: -150,
          bottom: -165,
          child: _Ring(size: 400, opacity: .09),
        ),
        Positioned(
          left: 32,
          top: 110,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0x66ffffff),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        width: 44,
        color: Colors.white.withValues(alpha: opacity),
      ),
    ),
  );
}
