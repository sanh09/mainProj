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
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  int _activeTab = 0;
  final List<_GuideTab> _tabs = [
    _GuideTab(
      headerLabel: '체크리스트',
      items: const [
        _GuideItem(
          title: '특약 사항의 독소 조항 확인',
          description: '나에게 불리한 문구가 있는지 보세요',
          icon: Icons.gavel,
        ),
        _GuideItem(
          title: '임대인/임차인 인적사항 대조',
          description: '등기부등본상의 소유주와 일치하는지 확인하세요',
          icon: Icons.badge,
        ),
        _GuideItem(
          title: '계약 기간 및 임대료 명시 확인',
          description: '구두로 협의된 내용과 문서상 내용이 같은지 확인 필요합니다.',
          icon: Icons.date_range,
        ),
        _GuideItem(
          title: '수선 의무 및 관리비 범위 확인',
          description: '관리비에 포함되는 항목과 수리 책임 범위를 명확히 하세요.',
          icon: Icons.build,
        ),
      ],
      initialChecked: [false, false, false, false],
    ),
    _GuideTab(
      headerLabel: '필수 행동 가이드',
      items: const [
        _GuideItem(
          title: '등기부등본 현장 발급 확인',
          description: '인터넷 등기소가 아닌, 현장에서 직접 뽑아서 확인하세요. 가장 정확합니다.',
          icon: Icons.print,
        ),
        _GuideItem(
          title: '임대인 신분증 진위 확인',
          description: 'ARS 1382 또는 정부24 앱을 활용하여 신분증의 진위 여부를 대조하세요.',
          icon: Icons.smartphone,
        ),
        _GuideItem(
          title: '공인중개사 자격 여부 확인',
          description: '국가공간정보포털에서 중개사가 정식 등록된 인원인지 확인했습니다.',
          icon: Icons.verified_user,
        ),
        _GuideItem(
          title: '현장 상태 사진 및 동영상 촬영',
          description: '입주 전 파손 부위나 상태를 사진과 동영상으로 꼼꼼히 남겨두세요.',
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
                _Header(isDark: isDark),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroCard(isDark: isDark),
                        const SizedBox(height: 16),
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
                        _ChecklistHeader(
                          label: activeTab.headerLabel,
                          checkedCount: checkedCount,
                          totalCount: activeTab.items.length,
                        ),
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
          _BottomAction(isDark: isDark),
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

class _Header extends StatelessWidget {
  final bool isDark;

  const _Header({required this.isDark});

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
                '계약 전, 행동 가이드',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool isDark;

  const _HeroCard({required this.isDark});

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
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'CANSI AI ANALYSIS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '성공적인 계약을 위한\n최종 단계',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.security,
                    color: GuidePalette.primary,
                    size: 30,
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? GuidePalette.surfaceDark : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TabButton(
            label: '계약서 확인 시',
            selected: activeTab == 0,
            onTap: () => onChanged(0),
          ),
          _TabButton(
            label: '계약 체결 전',
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
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? GuidePalette.primary : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChecklistHeader extends StatelessWidget {
  final String label;
  final int checkedCount;
  final int totalCount;

  const _ChecklistHeader({
    required this.label,
    required this.checkedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final percent = totalCount == 0 ? 0 : (checkedCount / totalCount * 100);
    return Row(
      children: [
        Text(
          '$label ($checkedCount/$totalCount)',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        Text(
          '${percent.toStringAsFixed(0)}% 완료',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: GuidePalette.primary,
          ),
        ),
      ],
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
          Checkbox(
            value: value,
            activeColor: GuidePalette.primary,
            onChanged: (next) => onChanged(next ?? false),
          ),
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

  const _BottomAction({required this.isDark});

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
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '확인 완료',
                    style: TextStyle(
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
