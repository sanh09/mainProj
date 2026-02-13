import 'package:flutter/material.dart';

import '../login_screen.dart';
import '../result.dart';
import '../shared/color_compat.dart';
import '../signup_screen.dart';
import '../shared/history_repository.dart';
import '../user_session.dart';
import '../welcome_screen.dart';
import 'profile_screen.dart';
import 'upload_screen.dart';

class HistoryPalette {
  static const Color primary = Color(0xFFFF8A00);
  static const Color backgroundLight = Color(0xFFFFF4E6);
  static const Color backgroundDark = Color(0xFF1A1612);
  static const Color cardLight = Color(0xB3FFFFFF);
  static const Color cardDark = Color(0xCC2D2823);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
}

enum _HistoryDateFilter { all, today, week, month, threeMonths }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryDateFilter _selectedDateFilter = _HistoryDateFilter.all;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      await HistoryRepository.instance.loadForSession(
        userId: UserSession.userId,
        email: UserSession.email,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load history: $error')),
      );
    }
  }

  void _openLoginFlow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLogin: () {
            Navigator.of(context).pop();
          },
          onSignupClick: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SignupScreen(
                  onSignup: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const UploadScreen()),
                    );
                  },
                  onBack: () => Navigator.of(context).pop(),
                  onLoginTap: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? HistoryPalette.backgroundDark
        : HistoryPalette.backgroundLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -50,
              child: _Blob(
                size: 240,
                color: HistoryPalette.primary.withValues(alpha: 0.2),
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
                color: HistoryPalette.primary.withValues(alpha: 0.12),
              ),
            ),
            Column(
              children: [
                const _HistoryAppBar(),
                _GlassCard(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _HistorySearch(
                    selectedFilter: _selectedDateFilter,
                    onFilterSelected: (filter) {
                      setState(() {
                        _selectedDateFilter = filter;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _HistoryList(
                    onRefresh: _loadHistory,
                    dateFilter: _selectedDateFilter,
                  ),
                ),
                const SizedBox(height: 88),
              ],
            ),
            const Positioned(
              right: 24,
              bottom: 108,
              child: _ScrollTopButton(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _HistoryBottomNav(
                onLoginTap: _openLoginFlow,
              ),
            ),
          ],
        ),
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
  final EdgeInsets margin;

  const _GlassCard({required this.child, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? HistoryPalette.cardDark : HistoryPalette.cardLight,
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
    );
  }
}

class _HistoryAppBar extends StatelessWidget {
  const _HistoryAppBar();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).popUntil(
              (route) => route.isFirst,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
            color: isDark ? Colors.white : HistoryPalette.textDark,
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFFDF0E8),
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '분석 기록',
              style: TextStyle(
                color: isDark ? Colors.white : HistoryPalette.textDark,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            icon: const Icon(Icons.account_circle_rounded),
            color: isDark ? const Color(0xFFE2E8F0) : HistoryPalette.textDark,
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFFDF0E8),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySearch extends StatelessWidget {
  final _HistoryDateFilter selectedFilter;
  final ValueChanged<_HistoryDateFilter> onFilterSelected;

  const _HistorySearch({
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: '계약서 이름 검색',
            hintStyle: TextStyle(
              color: isDark ? const Color(0xFF9CA3AF) : HistoryPalette.textMuted,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: isDark ? const Color(0xFF9CA3AF) : HistoryPalette.textMuted,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFF0F2F4),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: HistoryPalette.primary,
                width: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(
                  label: '전체',
                  selected: selectedFilter == _HistoryDateFilter.all,
                  onTap: () => onFilterSelected(_HistoryDateFilter.all),
                ),
                _Chip(
                  label: '오늘',
                  selected: selectedFilter == _HistoryDateFilter.today,
                  onTap: () => onFilterSelected(_HistoryDateFilter.today),
                ),
                _Chip(
                  label: '1주일',
                  selected: selectedFilter == _HistoryDateFilter.week,
                  onTap: () => onFilterSelected(_HistoryDateFilter.week),
                ),
                _Chip(
                  label: '1개월',
                  selected: selectedFilter == _HistoryDateFilter.month,
                  onTap: () => onFilterSelected(_HistoryDateFilter.month),
                ),
                _Chip(
                  label: '3개월',
                  selected: selectedFilter == _HistoryDateFilter.threeMonths,
                  onTap: () => onFilterSelected(_HistoryDateFilter.threeMonths),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? HistoryPalette.primary
                : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF0F2F4)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark ? const Color(0xFFE2E8F0) : HistoryPalette.textDark),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final _HistoryDateFilter dateFilter;

  const _HistoryList({
    required this.onRefresh,
    required this.dateFilter,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ActivityEntry>>(
      valueListenable: HistoryRepository.instance.entries,
      builder: (context, entries, _) {
        final filtered = _filterEntriesByDate(entries, dateFilter);
        if (filtered.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [_EmptyHistoryState()],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemBuilder: (context, index) {
              return _HistoryEntryCard(entry: filtered[index]);
            },
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemCount: filtered.length,
          ),
        );
      },
    );
  }

  List<ActivityEntry> _filterEntriesByDate(
    List<ActivityEntry> entries,
    _HistoryDateFilter filter,
  ) {
    if (filter == _HistoryDateFilter.all) {
      return entries;
    }

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final threshold = switch (filter) {
      _HistoryDateFilter.today => startOfToday,
      _HistoryDateFilter.week => startOfToday.subtract(const Duration(days: 7)),
      _HistoryDateFilter.month => DateTime(now.year, now.month - 1, now.day),
      _HistoryDateFilter.threeMonths => DateTime(now.year, now.month - 3, now.day),
      _HistoryDateFilter.all => DateTime.fromMillisecondsSinceEpoch(0),
    };

    return entries.where((entry) {
      final date = entry.createdAt ?? _parseEntryTime(entry.time);
      if (date == null) {
        return false;
      }
      return !date.isBefore(threshold);
    }).toList(growable: false);
  }

  DateTime? _parseEntryTime(String value) {
    if (value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.replaceFirst(' ', 'T'));
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          '아직 기록이 없습니다.',
          style: TextStyle(
            color: isDark ? const Color(0xFF9CA3AF) : HistoryPalette.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final ActivityEntry entry;

  const _HistoryEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _openHistoryDetail(context, entry),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? HistoryPalette.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: entry.iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(entry.icon, color: entry.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : HistoryPalette.textDark,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        entry.time,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : HistoryPalette.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: entry.badgeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      entry.statusLabel,
                      style: TextStyle(
                        color: entry.statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openHistoryDetail(BuildContext context, ActivityEntry entry) async {
  final analysisId = entry.analysisId;
  if (analysisId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('상세 데이터를 찾을 수 없습니다.')),
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final data = await HistoryRepository.instance.fetchAnalysisDetail(analysisId);
    if (!context.mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
    final viewModel = ResultViewModel.fromApi(
      data,
      filename: data['original_name']?.toString() ??
          data['filename']?.toString() ??
          entry.title,
      fallbackSummary: data['summary']?.toString(),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultScreen(viewModel: viewModel)),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('상세 로드 실패: $error')));
  }
}

class _ScrollTopButton extends StatelessWidget {
  const _ScrollTopButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HistoryPalette.primary,
      shape: const CircleBorder(),
      elevation: 6,
      child: InkWell(
        onTap: () {},
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.arrow_upward, color: Colors.white),
        ),
      ),
    );
  }
}

class _HistoryBottomNav extends StatelessWidget {
  final void Function(BuildContext) onLoginTap;

  const _HistoryBottomNav({
    required this.onLoginTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xCC0F172A) : const Color(0xCCFFFFFF),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _HistoryNavItem(
            icon: Icons.home_rounded,
            label: '홈',
            onTap: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => WelcomeScreen(
                    onLoginTap: onLoginTap,
                    onSignupTap: (_) {},
                  ),
                ),
                (_) => false,
              );
            },
          ),
          const _HistoryNavItem(
            icon: Icons.history_rounded,
            label: '기록',
            selected: true,
          ),
          const _HistoryNavItem(icon: Icons.smart_toy_rounded, label: 'AI 상담'),
          _HistoryNavItem(
            icon: Icons.person_rounded,
            label: '마이페이지',
            onTap: () {
              if (UserSession.userId == null) {
                onLoginTap(context);
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _HistoryNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? HistoryPalette.primary : const Color(0xFF94A3B8);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}




