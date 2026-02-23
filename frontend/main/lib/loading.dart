import 'dart:ui';

import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFFF8A00);
    const backgroundLight = Color(0xFFFFF4E6);
    const backgroundDark = Color(0xFF1A1612);
    const accent = Color(0xFFFFD29D);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? backgroundDark : backgroundLight;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            _Blob(
              color: isDark
                  ? primary.withValues(alpha: 0.12)
                  : const Color(0xFFFED7AA).withValues(alpha: 0.5),
              size: 500,
              top: -100,
              left: -100,
            ),
            _Blob(
              color: primary.withValues(alpha: 0.12),
              size: 400,
              bottom: -50,
              right: -100,
            ),
            _Blob(
              color: isDark
                  ? primary.withValues(alpha: 0.08)
                  : accent.withValues(alpha: 0.2),
              size: 300,
              top: 340,
              left: 80,
            ),
            Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LogoCluster(
                        pulseController: _pulseController,
                        primary: primary,
                        accent: accent,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          Text(
                            'CanSi',
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'YOUR CONTRACT HELPER',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 2.6,
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 44),
                  child: Column(
                    children: [
                      _BouncingDots(
                        controller: _dotsController,
                        color: primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '계약서를 분석중입니다.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            final shouldCancel =
                                await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) {
                                return Dialog(
                                  backgroundColor:
                                      isDark ? backgroundDark : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      22,
                                      22,
                                      18,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: primary.withValues(
                                              alpha: isDark ? 0.2 : 0.12,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.pause_circle_filled_rounded,
                                            color: primary,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          '분석을 중단할까요?',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '계속 진행하거나 지금 바로 중단할 수 있어요.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: isDark
                                                ? Colors.white70
                                                : const Color(0xFF6B7280),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () {
                                                  Navigator.of(dialogContext)
                                                      .pop(false);
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(
                                                    color: primary.withValues(
                                                      alpha: 0.6,
                                                    ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      16,
                                                    ),
                                                  ),
                                                ),
                                                child: const Text(
                                                  '계속하기',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  Navigator.of(dialogContext)
                                                      .pop(true);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: primary,
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      16,
                                                    ),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                child: const Text(
                                                  '중단하기',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                            if (!mounted) return;
                            if (shouldCancel == true) {
                              Navigator.of(context).pop();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: primary),
                            backgroundColor: Colors.white,
                            foregroundColor: primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            '중단하기',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoCluster extends StatelessWidget {
  final AnimationController pulseController;
  final Color primary;
  final Color accent;
  final bool isDark;

  const _LogoCluster({
    required this.pulseController,
    required this.primary,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            child: ClipPath(
              clipper: _ShieldClipper(),
              child: Container(
                width: 200,
                height: 220,
                color: isDark
                    ? primary.withValues(alpha: 0.08)
                    : const Color(0xFFFFF7ED).withValues(alpha: 0.9),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) {
              final t = pulseController.value;
              final scale = 0.95 + (0.15 * t);
              final alpha = (1 - t).clamp(0.0, 1.0);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withValues(alpha: 0.06),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35 * alpha),
                        blurRadius: 28,
                        spreadRadius: 4 + 18 * t,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Container(
            width: 150,
            height: 150,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0xFFFF9F2E),
                  Color(0xFFFF8A00),
                  Color(0xFFE67A00),
                ],
                center: Alignment(-0.3, -0.3),
                radius: 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x66FF8A00),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 90,
                height: 118,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 52,
                          height: 6,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Container(
                          width: 52,
                          height: 6,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 32,
                            height: 6,
                            margin: const EdgeInsets.only(left: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 20,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingDots extends StatelessWidget {
  final AnimationController controller;
  final Color color;

  const _BouncingDots({
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = controller.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dot(value, 0),
            const SizedBox(width: 8),
            _dot(value, 0.2),
            const SizedBox(width: 8),
            _dot(value, 0.4),
          ],
        );
      },
    );
  }

  Widget _dot(double value, double delay) {
    final t = (value + delay) % 1.0;
    final offset = -6 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, offset),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  const _Blob({
    required this.color,
    required this.size,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height * 0.15)
      ..lineTo(size.width, size.height * 0.85)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(0, size.height * 0.85)
      ..lineTo(0, size.height * 0.15)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
