import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> fadeIcon;
  late Animation<double> fadeText;
  late Animation<double> scaleIcon;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    // Both icon and text are immediately visible (opacity 1) so the first
    // Flutter frame continues seamlessly from the native Android splash which
    // now shows the full design. Only the scale settles in.
    fadeIcon = const AlwaysStoppedAnimation<double>(1.0);
    fadeText = const AlwaysStoppedAnimation<double>(1.0);
    scaleIcon = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.45, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Navigate after animation completes + brief hold.
    Timer(const Duration(milliseconds: 5800), () {
      if (mounted) context.go('/dashboard');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.55, 1.0],
            colors: [Color(0xFFF5F3FF), Color(0xFFEDEBFF), Color(0xFFD8D4FF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ── Centre content ──────────────────────────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App icon (SVG)
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, __) => Opacity(
                        opacity: fadeIcon.value,
                        child: Transform.scale(
                          scale: scaleIcon.value,
                          child: SvgPicture.asset(
                            'assets/icons/audesiq-logo.svg',
                            width: MediaQuery.of(context).size.width * 0.40,
                            height: MediaQuery.of(context).size.width * 0.40,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppDimens.space6),

                    // "Audesiq" wordmark
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (_, __) => Opacity(
                        opacity: fadeText.value,
                        child: Column(
                          children: [
                            Text('Audesiq', style: AppTextStyles.displayLarge),
                            const SizedBox(height: AppDimens.space2),
                            Text(
                              'Movies for Everyone',
                              style: AppTextStyles.subhead.copyWith(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Bottom tagline ──────────────────────────────────────────
              Positioned(
                bottom: AppDimens.space8,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => Opacity(
                    opacity: fadeText.value,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PREMIUM CINEMA EXPERIENCE',
                          style: AppTextStyles.navLabel.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 2.5,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
