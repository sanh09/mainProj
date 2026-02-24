import 'package:flutter/material.dart';

import '../app_settings.dart';

class SystemPalette {
  static const Color primary = Color(0xFFFF8A00);
  static const Color primaryLight = Color(0xFFFF9F4D);
  static const Color primaryDark = Color(0xFFE67900);
  static const Color backgroundLight = Color(0xFFFFF4E6);
  static const Color backgroundDark = Color(0xFF1A1612);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
}

class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  double _fontSlider = 0.5;
  FontChoice _fontChoice = FontChoice.base;

  @override
  void initState() {
    super.initState();
    _fontSlider = _scaleToSlider(AppSettings.textScale.value);
    _fontChoice = AppSettings.fontChoice.value;
  }

  double _sliderToScale(double slider) => 0.85 + (slider * 0.35);

  double _scaleToSlider(double scale) =>
      ((scale - 0.85) / 0.35).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? SystemPalette.backgroundDark
        : SystemPalette.backgroundLight;
    return Scaffold(
      backgroundColor: backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.clamp(0, 430).toDouble();
          return Center(
            child: SizedBox(
              width: maxWidth == 0 ? constraints.maxWidth : maxWidth,
              height: constraints.maxHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: SafeArea(
                  bottom: false,
                  child: Stack(
                    children: [
                      Positioned(
                        top: -50,
                        right: -50,
                        child: _Blob(
                          size: 240,
                          color: SystemPalette.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      Positioned(
                        top: 260,
                        left: -80,
                        child: _Blob(
                          size: 300,
                          color: const Color(0xFFFFC392).withValues(alpha: 0.35),
                        ),
                      ),
                      Positioned(
                        bottom: -40,
                        right: -100,
                        child: _Blob(
                          size: 260,
                          color: SystemPalette.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      Column(
                        children: [
                          _Header(onBack: () => Navigator.of(context).pop()),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _GlassCard(
                                    child: _ModeSection(
                                      choice: _fontChoice,
                                      onChanged: (next) {
                                        setState(() {
                                          _fontChoice = next;
                                        });
                                        AppSettings.fontChoice.value = next;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _GlassCard(
                                    child: _FontSizeSection(
                                      scale: _fontSlider,
                                      onChanged: (value) {
                                        setState(() {
                                          _fontSlider = value;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const _HelpCard(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      _SaveBar(
                        onSave: () {
                          AppSettings.textScale.value = _sliderToScale(_fontSlider);
                          AppSettings.fontChoice.value = _fontChoice;
                          Navigator.of(context).pop('글꼴 설정');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 60),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xCC2D2823) : const Color(0xB3FFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF374151) : const Color(0x66FFFFFF),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: (isDark
                ? const Color(0xFF1F2937)
                : SystemPalette.backgroundLight)
            .withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.chevron_left,
                color: isDark ? Colors.white : SystemPalette.textDark,
              ),
              onPressed: onBack,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '시스템 설정',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : SystemPalette.textDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class _ModeSection extends StatelessWidget {
  final FontChoice choice;
  final ValueChanged<FontChoice> onChanged;

  const _ModeSection({required this.choice, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '글꼴 설정',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : SystemPalette.textDark,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          children: [
            _FontChip(
              label: '기본 (Inter)',
              selected: choice == FontChoice.base,
              onTap: () => onChanged(FontChoice.base),
            ),
            _FontChip(
              label: '명조체',
              selected: choice == FontChoice.serif,
              onTap: () => onChanged(FontChoice.serif),
            ),
            _FontChip(
              label: '고딕체',
              selected: choice == FontChoice.sans,
              onTap: () => onChanged(FontChoice.sans),
            ),
            _FontChip(
              label: '나눔고딕',
              selected: choice == FontChoice.nanumGothic,
              onTap: () => onChanged(FontChoice.nanumGothic),
            ),
            _FontChip(
              label: '나눔명조',
              selected: choice == FontChoice.nanumMyeongjo,
              onTap: () => onChanged(FontChoice.nanumMyeongjo),
            ),
            _FontChip(
              label: '고운바탕',
              selected: choice == FontChoice.gowunBatang,
              onTap: () => onChanged(FontChoice.gowunBatang),
            ),
            _FontChip(
              label: '고운돋움',
              selected: choice == FontChoice.gowunDodum,
              onTap: () => onChanged(FontChoice.gowunDodum),
            ),
          ],
        ),
      ],
    );
  }
}
class _FontSizeSection extends StatelessWidget {
  final double scale;
  final ValueChanged<double> onChanged;

  const _FontSizeSection({required this.scale, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final previewSize = 16 + (scale * 6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '글꼴 크기',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : SystemPalette.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : SystemPalette.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Text(
                  '계약서의 주요 조항을\nAI가 분석 중입니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: previewSize,
                    height: 1.4,
                    color: isDark ? Colors.white : SystemPalette.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'A',
                    style:
                        TextStyle(fontSize: 12, color: SystemPalette.textMuted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: SystemPalette.primary,
                        inactiveTrackColor:
                            isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                        thumbColor: SystemPalette.primary,
                        overlayColor:
                            SystemPalette.primary.withValues(alpha: 0.1),
                      ),
                      child: Slider(
                        value: scale,
                        onChanged: onChanged,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'A',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : SystemPalette.textDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FontChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FontChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? SystemPalette.primary
              : (isDark ? const Color(0xFF1F2937) : SystemPalette.surfaceLight),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? SystemPalette.primary
                : (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: SystemPalette.primary.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected
                ? Colors.white
                : (isDark ? const Color(0xFFE2E8F0) : SystemPalette.textMuted),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info,
            color: isDark ? const Color(0xFF94A3B8) : SystemPalette.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '글꼴 설정 안내',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFE2E8F0) : SystemPalette.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '선택한 글꼴과 크기 설정은 모든 계약 분석 화면에 적용됩니다. '
                  '밝은 환경에서는 라이트 모드를 권장합니다.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: isDark ? const Color(0xFF9CA3AF) : SystemPalette.textMuted,
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

class _SaveBar extends StatelessWidget {
  final VoidCallback onSave;

  const _SaveBar({required this.onSave});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0x001A1612),
                    Color(0xFF1A1612),
                    Color(0xFF1A1612),
                  ]
                : const [
                    Color(0x00FFF4E6),
                    Color(0xFFFFF4E6),
                    Color(0xFFFFF4E6),
                  ],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [SystemPalette.primary, SystemPalette.primaryLight],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: SystemPalette.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onSave,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '설정 저장하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.check_circle, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
