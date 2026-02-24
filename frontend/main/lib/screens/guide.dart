import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'profile_screen.dart';

class GuidePalette {
  static const Color primary = Color(0xFFF19B22);
  static const Color primaryDark = Color(0xFFD68310);
  static const Color backgroundLight = Color(0xFFF8F7F6);
  static const Color backgroundDark = Color(0xFF221B10);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF2D2418);
}

class GuideScreen extends StatefulWidget {
  final bool showCancelButton;

  const GuideScreen({super.key, this.showCancelButton = false});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  int _activeTab = 0;
  final List<_GuideTab> _tabs = [
    _GuideTab(
      headerLabel: '',
      items: const [
        _GuideItem(
          title: '계약 사항과 주요 조항 확인',
          description: '서명 전에 불리한 문구가 있는지 확인하세요.',
          icon: Icons.gavel,
        ),
        _GuideItem(
          title: '특약 및 중요한 조항 검토',
          description: '특약과 계약 조건이 일치하는지 확인하세요.',
          icon: Icons.badge,
        ),
        _GuideItem(
          title: '계약 기간 및 종료 조건 확인',
          description: '구두로 합의한 내용과 문서 내용이 같은지 확인하세요.',
          icon: Icons.date_range,
        ),
        _GuideItem(
          title: '선수 금액 및 관리비 범위 확인',
          description: '관리비에 포함되는 항목과 부담 범위를 명확히 확인하세요.',
          icon: Icons.build,
        ),
      ],
      initialChecked: [false, false, false, false],
    ),
    _GuideTab(
      headerLabel: '',
      items: const [
        _GuideItem(
          title: '등기부등본 발급 확인',
          description: '온라인 발급본과 함께 원본도 직접 확인하세요.',
          icon: Icons.print,
        ),
        _GuideItem(
          title: '전입신고 및 확정일자 확인',
          description: '정부24, ARS 1382 등으로 권리 정보를 확인하세요.',
          icon: Icons.smartphone,
        ),
        _GuideItem(
          title: '공인중개사 자격 여부 확인',
          description: '국토교통부 사이트에서 등록 여부를 확인하세요.',
          icon: Icons.verified_user,
        ),
        _GuideItem(
          title: '현장 상태 사진 및 영상 촬영',
          description: '입주 전 상태를 사진과 영상으로 남겨두세요.',
          icon: Icons.camera_alt,
        ),
      ],
      initialChecked: [false, false, false, false],
    ),
  ];
  late final List<List<bool>> _checkedByTab = _tabs
      .map((tab) => List<bool>.from(tab.initialChecked))
      .toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? GuidePalette.backgroundDark
        : GuidePalette.backgroundLight;
    final activeTab = _tabs[_activeTab];
    final checked = _checkedByTab[_activeTab];
    final checkedCount = checked.where((value) => value).length;
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          _BackgroundGlow(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                _Header(
                  isDark: isDark,
                  showCancelButton: widget.showCancelButton,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroCard(
                          isDark: isDark,
                          showCancelButton: widget.showCancelButton,
                        ),
                        const SizedBox(height: 30),
                        _TabBar(
                          activeTab: _activeTab,
                          onChanged: (value) {
                            setState(() {
                              _activeTab = value;
                            });
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(height: 10),
                        for (int i = 0; i < activeTab.items.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ChecklistCard(
                              item: activeTab.items[i],
                              value: checked[i],
                              isDark: isDark,
                              onChanged: (value) {
                                setState(() {
                                  checked[i] = value;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _BottomAction(
            isDark: isDark,
            showCancelButton: widget.showCancelButton,
          ),
        ],
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  final bool isDark;

  const _BackgroundGlow({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -120,
          child: _GlowBlob(
            size: 280,
            color: GuidePalette.primary.withValues(alpha: 0.12),
          ),
        ),
        Positioned(
          bottom: 80,
          left: -120,
          child: _GlowBlob(
            size: 200,
            color: GuidePalette.primary.withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          bottom: -40,
          left: 0,
          right: 0,
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBlob({required this.size, required this.color});

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

class _ContractHelperMiniLogo extends StatefulWidget {
  final bool animate;

  const _ContractHelperMiniLogo({this.animate = false});

  @override
  State<_ContractHelperMiniLogo> createState() => _ContractHelperMiniLogoState();
}

class _ContractHelperMiniLogoState extends State<_ContractHelperMiniLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ContractHelperMiniLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      if (widget.animate) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final offset = widget.animate ? math.sin(t * math.pi * 2) * 4 : 0.0;
        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
      child: SizedBox(
        width: 90,
        height: 90,
        child: Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 50,
                height: 58,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: GuidePalette.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 25,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Container(
                          width: 25,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 20,
                            height: 3,
                            margin: const EdgeInsets.only(left: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 6,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: GuidePalette.primary,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isDark;
  final bool showCancelButton;

  const _Header({required this.isDark, required this.showCancelButton});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: isDark
            ? GuidePalette.surfaceDark.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.85),
      ),
      child: Row(
        children: [
          if (!showCancelButton)
            IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDark ? Colors.white : const Color(0xFF374151),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          const Expanded(
            child: Center(
              child: Text(
                '계약 전 행동 가이드',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool isDark;
  final bool showCancelButton;

  const _HeroCard({
    required this.isDark,
    required this.showCancelButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [GuidePalette.primary, Color(0xFFF97316)],
        ),
        boxShadow: [
          BoxShadow(
            color: GuidePalette.primary.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: _GlowBlob(
              size: 80,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          Positioned(
            left: 26,
            bottom: -20,
            child: _GlowBlob(
              size: 60,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CANSI AI ANALYSIS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        showCancelButton
                            ? '계약서 분석 중'
                            : '안전한 계약을 \n위한 최종 체크',
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 35),
                _ContractHelperMiniLogo(animate: showCancelButton),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onChanged;
  final bool isDark;

  const _TabBar({
    required this.activeTab,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? GuidePalette.surfaceDark : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TabButton(
            label: '계약서 확인 전',
            selected: activeTab == 0,
            onTap: () => onChanged(0),
          ),
          _TabButton(
            label: '계약서 체결 전',
            selected: activeTab == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? GuidePalette.primary : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final _GuideItem item;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _ChecklistCard({
    required this.item,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white : const Color(0xFF1F2937),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? GuidePalette.surfaceDark : GuidePalette.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? GuidePalette.primary.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: titleStyle),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(item.icon, color: GuidePalette.primary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final bool isDark;
  final bool showCancelButton;

  const _BottomAction({
    required this.isDark,
    required this.showCancelButton,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [GuidePalette.primary, Color(0xFFF97316)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: GuidePalette.primary.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              if (showCancelButton) {
                showDialog<void>(
                  context: context,
                  builder: (dialogContext) {
                    final dialogIsDark =
                        Theme.of(dialogContext).brightness == Brightness.dark;
                    return Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        decoration: BoxDecoration(
                          color: dialogIsDark
                              ? GuidePalette.surfaceDark
                              : GuidePalette.surfaceLight,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                          border: Border.all(
                            color: dialogIsDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '분석을 중단할까요?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: dialogIsDark
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '중단하면 분석 진행이 취소됩니다.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: dialogIsDark
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: dialogIsDark
                                          ? Colors.white
                                          : const Color(0xFF374151),
                                      side: BorderSide(
                                        color: dialogIsDark
                                            ? Colors.white
                                                .withValues(alpha: 0.18)
                                            : const Color(0xFFE5E7EB),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('계속할게요'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                      Navigator.of(context).pop();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: GuidePalette.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('중단하기'),
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
                return;
              }
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    showCancelButton ? '중단하기' : '완료하기',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideItem {
  final String title;
  final String description;
  final IconData icon;

  const _GuideItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _GuideTab {
  final String headerLabel;
  final List<_GuideItem> items;
  final List<bool> initialChecked;

  const _GuideTab({
    required this.headerLabel,
    required this.items,
    required this.initialChecked,
  });
}
