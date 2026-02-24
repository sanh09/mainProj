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
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textMuted = isDark ? Colors.white70 : const Color(0xFF6B7280);

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LogoMark(
                        pulseController: _pulseController,
                        primary: primary,
                        accent: accent,
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CanSi',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'YOUR CONTRACT HELPER',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PreviewCard(
                            isDark: isDark,
                            shimmer: _pulseController,
                          ),
                          const SizedBox(height: 24),
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
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final shouldCancel = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) {
                            const redoOrange = Color(0xFFFA9819);
                            const redoOrangeDeep = Color(0xFFFF7A00);
                            const redoBlueTint = Color(0xFFB6C9CF);
                            const textMain = Color(0xFF1A1C1E);

                            return Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 24,
                              ),
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 340),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 40,
                                      offset: const Offset(0, 20),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(32),
                                        ),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            redoOrange.withValues(alpha: 0.08),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        32,
                                        24,
                                        24,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: redoOrange.withValues(
                                                alpha: 0.12,
                                              ),
                                            ),
                                            child: Center(
                                              child: Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: redoOrange
                                                      .withValues(alpha: 0.12),
                                                ),
                                                child: const Icon(
                                                  Icons.logout,
                                                  size: 36,
                                                  color: redoOrange,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          const Text(
                                            '분석을 중단하시겠어요?',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              height: 1.2,
                                              color: textMain,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            '지금 나가시면 분석 중인 데이터가 저장되지 않을 수 있습니다.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 15,
                                              height: 1.5,
                                              color: redoBlueTint
                                                  .withValues(alpha: 0.9),
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          Column(
                                            children: [
                                              SizedBox(
                                                width: double.infinity,
                                                height: 56,
                                                child: ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.of(dialogContext)
                                                          .pop(false),
                                                  style: ElevatedButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        20,
                                                      ),
                                                    ),
                                                    elevation: 0,
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    shadowColor:
                                                        Colors.transparent,
                                                  ),
                                                  child: Ink(
                                                    decoration: BoxDecoration(
                                                      gradient:
                                                          const LinearGradient(
                                                        colors: [
                                                          redoOrange,
                                                          redoOrangeDeep,
                                                        ],
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        20,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: redoOrange
                                                              .withValues(
                                                            alpha: 0.4,
                                                          ),
                                                          blurRadius: 20,
                                                          offset: const Offset(
                                                            0,
                                                            8,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Center(
                                                      child: Text(
                                                        '돌아가기',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              SizedBox(
                                                width: double.infinity,
                                                height: 56,
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      Navigator.of(dialogContext)
                                                          .pop(true),
                                                  style: OutlinedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFF1F5F9),
                                                    foregroundColor:
                                                        const Color(0xFF94A3B8),
                                                    side: BorderSide(
                                                      color: const Color(
                                                        0xFFE2E8F0,
                                                      ).withValues(alpha: 0.7),
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        20,
                                                      ),
                                                    ),
                                                    textStyle: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  child: const Text('끝내기'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                        if (!context.mounted) return;
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
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: 120,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
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

class _LogoMark extends StatelessWidget {
  final AnimationController pulseController;
  final Color primary;
  final Color accent;

  const _LogoMark({
    required this.pulseController,
    required this.primary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) {
              final t = pulseController.value;
              final scale = 0.95 + (0.15 * t);
              final alpha = (1 - t).clamp(0.0, 1.0);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withValues(alpha: 0.08),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.4 * alpha),
                        blurRadius: 18,
                        spreadRadius: 4 + 10 * t,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Container(
            width: 56,
            height: 56,
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
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 32,
                height: 42,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 20,
                          height: 2.5,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 2.5,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 12,
                            height: 2.5,
                            margin: const EdgeInsets.only(left: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 10,
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

class _PreviewCard extends StatelessWidget {
  final bool isDark;
  final Animation<double> shimmer;

  const _PreviewCard({required this.isDark, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.6),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
            _ShimmerLayer(isDark: isDark, animation: shimmer),
            Center(
              child: Icon(
                Icons.movie_rounded,
                size: 56,
                color:
                    (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerLayer extends StatelessWidget {
  final bool isDark;
  final Animation<double> animation;

  const _ShimmerLayer({required this.isDark, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final start = -1.5 + (3 * t);
        final base = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF6F7F8);
        final highlight = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFEDEEF1);
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(start, 0),
              end: Alignment(start + 1, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
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
