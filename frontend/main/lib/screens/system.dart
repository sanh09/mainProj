import 'package:flutter/material.dart';

import '../app_settings.dart';

class SystemPalette {
  static const Color primary = Color(0xFFF27F0D);
  static const Color primaryLight = Color(0xFFFF9F4D);
  static const Color primaryDark = Color(0xFFCC6600);
  static const Color backgroundLight = Color(0xFFFDFBF7);
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
  _FontChoice _fontChoice = _FontChoice.base;
  _SystemMode _systemMode = _SystemMode.light;

  @override
  void initState() {
    super.initState();
    _fontSlider = _scaleToSlider(AppSettings.textScale.value);
  }

  double _sliderToScale(double slider) => 0.85 + (slider * 0.35);

  double _scaleToSlider(double scale) =>
      ((scale - 0.85) / 0.35).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SystemPalette.backgroundLight,
      body: Stack(
        children: [
          Column(
            children: [
              _Header(onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ModeSection(
                        mode: _systemMode,
                        onChanged: (next) {
                          setState(() {
                            _systemMode = next;
                          });
                        },
                      ),
                      const SizedBox(height: 28),
                      _FontSizeSection(
                        scale: _fontSlider,
                        onChanged: (value) {
                          setState(() {
                            _fontSlider = value;
                          });
                        },
                      ),
                      const SizedBox(height: 28),
                      _FontFamilySection(
                        choice: _fontChoice,
                        onChanged: (next) {
                          setState(() {
                            _fontChoice = next;
                          });
                        },
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
              final label =
                  _systemMode == _SystemMode.light ? '라이트' : '다크 모드';
              AppSettings.textScale.value = _sliderToScale(_fontSlider);
              Navigator.of(context).pop(label);
            },
          ),
        ],
      ),
    );
  }
}

enum _FontChoice { base, serif, sans }

enum _SystemMode { light, dark }

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: SystemPalette.backgroundLight.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.chevron_left,
                color: SystemPalette.textDark,
              ),
              onPressed: onBack,
            ),
            const Expanded(
              child: Center(
                child: Text(
                  '시스템 설정',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
  final _SystemMode mode;
  final ValueChanged<_SystemMode> onChanged;

  const _ModeSection({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '화면 모드',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SystemPalette.textDark,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SystemPalette.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                mode == _SystemMode.light ? 'Light Active' : 'Dark Active',
                style: const TextStyle(
                  fontSize: 11,
                  color: SystemPalette.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ModeCard(
                selected: mode == _SystemMode.light,
                label: '라이트',
                icon: Icons.light_mode,
                onTap: () => onChanged(_SystemMode.light),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeCard(
                selected: mode == _SystemMode.dark,
                label: '다크 모드',
                icon: Icons.dark_mode,
                onTap: () => onChanged(_SystemMode.dark),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? SystemPalette.primary : Colors.transparent;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SystemPalette.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: SystemPalette.primary.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          children: [
            if (selected)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: SystemPalette.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'ON',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Container(
              height: 90,
              decoration: BoxDecoration(
                color:
                    selected ? const Color(0xFFFFF7ED) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 32,
                  color: selected
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color:
                    selected ? SystemPalette.primary : SystemPalette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FontSizeSection extends StatelessWidget {
  final double scale;
  final ValueChanged<double> onChanged;

  const _FontSizeSection({required this.scale, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final previewSize = 16 + (scale * 6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '글자 크기',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: SystemPalette.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SystemPalette.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  '계약서의 주요 조항을\nAI가 분석 중입니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: previewSize,
                    height: 1.4,
                    color: SystemPalette.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'A',
                    style:
                        TextStyle(fontSize: 12, color: SystemPalette.textMuted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: SystemPalette.primary,
                        inactiveTrackColor: const Color(0xFFE5E7EB),
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
                  const Text(
                    'A',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: SystemPalette.textDark,
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

class _FontFamilySection extends StatelessWidget {
  final _FontChoice choice;
  final ValueChanged<_FontChoice> onChanged;

  const _FontFamilySection({
    required this.choice,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '글꼴 설정',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: SystemPalette.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _FontChip(
              label: '기본 (Inter)',
              selected: choice == _FontChoice.base,
              onTap: () => onChanged(_FontChoice.base),
            ),
            _FontChip(
              label: '명조체',
              selected: choice == _FontChoice.serif,
              onTap: () => onChanged(_FontChoice.serif),
            ),
            _FontChip(
              label: '고딕체',
              selected: choice == _FontChoice.sans,
              onTap: () => onChanged(_FontChoice.sans),
            ),
          ],
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
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? SystemPalette.primary : SystemPalette.surfaceLight,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? SystemPalette.primary : const Color(0xFFE5E7EB),
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
            color: selected ? Colors.white : SystemPalette.textMuted,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: SystemPalette.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '화면 설정 도움말',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: SystemPalette.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '선택하신 테마와 글꼴 설정은 모든 계약 분석 화면에 즉시 적용됩니다. '
                  '밝은 환경에서는 라이트 모드를 권장합니다.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: SystemPalette.textMuted,
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
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x00FDFBF7),
              Color(0xFFFDFBF7),
              Color(0xFFFDFBF7),
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
