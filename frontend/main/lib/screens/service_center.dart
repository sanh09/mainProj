import 'package:flutter/material.dart';

class ServiceCenterPalette {
  static const Color primary = Color(0xFFF19B22);
  static const Color primaryLight = Color(0xFFFDDCA7);
  static const Color backgroundLight = Color(0xFFF8F7F6);
  static const Color backgroundDark = Color(0xFF221B10);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF2D2418);
}

class ServiceCenterScreen extends StatelessWidget {
  const ServiceCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? ServiceCenterPalette.backgroundDark
        : ServiceCenterPalette.backgroundLight;
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          _BackgroundBlobs(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                _Header(isDark: isDark),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _Intro(isDark: isDark),
                        const SizedBox(height: 24),
                        _EmailCard(isDark: isDark),
                        const Spacer(),
                        const _Footer(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundBlobs extends StatelessWidget {
  final bool isDark;

  const _BackgroundBlobs({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -40,
          right: -40,
          child: _Blob(
            size: 160,
            color: ServiceCenterPalette.primary.withValues(alpha: 0.2),
          ),
        ),
        Positioned(
          top: 180,
          left: -80,
          child: _Blob(
            size: 220,
            color: ServiceCenterPalette.primary.withValues(alpha: 0.12),
          ),
        ),
        Positioned(
          bottom: 120,
          right: -20,
          child: _Blob(
            size: 260,
            color: ServiceCenterPalette.primary.withValues(alpha: 0.16),
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 80),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isDark;

  const _Header({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: isDark
            ? ServiceCenterPalette.backgroundDark.withValues(alpha: 0.9)
            : ServiceCenterPalette.backgroundLight.withValues(alpha: 0.9),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDark ? Colors.white : const Color(0xFF334155),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '고객센터',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final bool isDark;

  const _Intro({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '안녕하세요,\n무엇을 도와드릴까요?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            height: 1.3,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '궁금한 점이 있으시면 언제든지 문의해주세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _EmailCard extends StatelessWidget {
  final bool isDark;

  const _EmailCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ServiceCenterPalette.primary, Color(0xFFF59E0B)],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: ServiceCenterPalette.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mail, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '이메일 문의하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'jpb0928@gmail.com',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Text(
      '고객센터 운영시간: 평일 09:00 - 18:00 (주말/공휴일 휴무)',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF6B7280)
            : const Color(0xFF94A3B8),
      ),
    );
  }
}
