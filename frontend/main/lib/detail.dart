import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shared/color_compat.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'welcome_screen.dart';

class DetailPalette {
  static const Color primary = Color(0xFFFA9819);
  static const Color accentOrange = Color(0xFFE85D04);
  static const Color backgroundLight = Color(0xFFF8FAFB);
  static const Color backgroundDark = Color(0xFF0F171A);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color cream = Color(0xFFFFF9F0);
  static const Color yellowBg = Color(0xFFFEFCE8);
  static const Color yellowBorder = Color(0xFFFEF08A);
  static const Color blueBg = Color(0xFFE0F2FE);
  static const Color blueBorder = Color(0xFF7DD3FC);
  static const Color orangeBg = Color(0xFFFFF7ED);
  static const Color orangeBorder = Color(0xFFFDBA74);
  static const Color purpleBg = Color(0xFFF3E8FF);
  static const Color purpleBorder = Color(0xFFD8B4FE);
}

enum _DetailTab { debate, alternative, question }

class DetailScreen extends StatefulWidget {
  final String clauseText;
  final String tenantArgument;
  final String landlordArgument;
  final List<String> tenantTags;
  final List<String> landlordTags;
  final List<String> negotiationPoints;
  final String compromiseQuote;

  const DetailScreen({
    super.key,
    required this.clauseText,
    required this.tenantArgument,
    required this.landlordArgument,
    required this.tenantTags,
    required this.landlordTags,
    required this.negotiationPoints,
    required this.compromiseQuote,
  });

  factory DetailScreen.sample() {
    return const DetailScreen(
      clauseText:
          '임대인은 주요 구조물의 수리에 대한 책임을 지며, 임차인은 일상적인 사용으로 발생하는 소규모 유지보수에 대한 책임을 진다. 단, 관리비 항목에 포함되지 않는 소모품 교체는 임차인의 부담으로 한다.',
      tenantArgument:
          '임차인 입장에서는 소모품 범위를 명확히 제한해야 합니다. 통상적인 사용으로 인한 자연 마모는 임대인의 부담임을 주장할 수 있습니다.',
      landlordArgument:
          '임대인 입장에서는 재산권 보호 차원에서 임차인의 과실로 인한 손해는 보상받아야 한다고 주장할 수 있습니다.',
      tenantTags: ['자연 마모', '권리 보호'],
      landlordTags: ['재산 보호', '손해 보상'],
      negotiationPoints: ['수리 범위와 소모품 기준을 계약서에 명확히 기재', '퇴거 시 분쟁 방지를 위한 기준 합의'],
      compromiseQuote: '양측의 부담 범위를 구체적으로 합의하고, 분쟁 발생 시 객관적 기준을 적용하도록 명시하세요.',
    );
  }

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  _DetailTab _selectedTab = _DetailTab.debate;

  @override
  Widget build(BuildContext context) {
    final safeTenantArgument = _sanitizeArgumentText(widget.tenantArgument);
    final safeLandlordArgument = _sanitizeArgumentText(widget.landlordArgument);
    final safeCompromiseQuote = _sanitizeArgumentText(widget.compromiseQuote);
    final safeNegotiationPoints = widget.negotiationPoints
        .map(_sanitizeArgumentText)
        .toList(growable: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? DetailPalette.backgroundDark
        : DetailPalette.backgroundLight;
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _DetailAppBar(isDark: isDark),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SelectedClauseCard(
                      isDark: isDark,
                      text: widget.clauseText,
                    ),
                    const SizedBox(height: 16),
                    _SegmentedTabs(
                      selectedTab: _selectedTab,
                      onDebateTap: () {
                        setState(() {
                          _selectedTab = _DetailTab.debate;
                        });
                      },
                      onAlternativeTap: () {
                        setState(() {
                          _selectedTab = _DetailTab.alternative;
                        });
                      },
                      onQuestionTap: () {
                        setState(() {
                          _selectedTab = _DetailTab.question;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_selectedTab == _DetailTab.debate) ...[
                      _WhySection(
                        isDark: isDark,
                        text: safeNegotiationPoints.isNotEmpty
                            ? safeNegotiationPoints.join(' ')
                            : safeCompromiseQuote,
                      ),
                      const SizedBox(height: 16),
                      _PerspectiveSection(
                        isDark: isDark,
                        tenantText: safeTenantArgument,
                        landlordText: safeLandlordArgument,
                        neutralText: safeCompromiseQuote,
                      ),
                    ] else if (_selectedTab == _DetailTab.alternative) ...[
                      _WhySection(
                        isDark: isDark,
                        text: safeNegotiationPoints.isNotEmpty
                            ? safeNegotiationPoints.join(' ')
                            : safeCompromiseQuote,
                      ),
                      const SizedBox(height: 16),
                      _AlternativeSection(isDark: isDark),
                    ] else ...[
                      _WhySection(
                        isDark: isDark,
                        text: safeNegotiationPoints.isNotEmpty
                            ? safeNegotiationPoints.join(' ')
                            : safeCompromiseQuote,
                      ),
                      const SizedBox(height: 16),
                      const _QuestionDraftSection(),
                    ],
                  ],
                ),
              ),
            ),
            _BottomActionBar(
              isDark: isDark,
              buttonLabel: '분석 완료',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => WelcomeScreen(
                      onLoginTap: (context) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LoginScreen(
                              onLogin: () => Navigator.of(context).pop(),
                              onSignupClick: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SignupScreen(
                                      onSignup: () =>
                                          Navigator.of(context).pop(),
                                      onBack: () => Navigator.of(context).pop(),
                                      onLoginTap: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                      onSignupTap: (context) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SignupScreen(
                              onSignup: () => Navigator.of(context).pop(),
                              onBack: () => Navigator.of(context).pop(),
                              onLoginTap: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => LoginScreen(
                                      onLogin: () =>
                                          Navigator.of(context).pop(),
                                      onSignupClick: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => SignupScreen(
                                              onSignup: () =>
                                                  Navigator.of(context).pop(),
                                              onBack: () =>
                                                  Navigator.of(context).pop(),
                                              onLoginTap: () =>
                                                  Navigator.of(context).pop(),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _sanitizeArgumentText(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return value;
  }
  final jsonCandidate = _extractJsonObject(trimmed);
  if (jsonCandidate != null) {
    try {
      final decoded = jsonDecode(jsonCandidate);
      if (decoded is Map<String, dynamic>) {
        final rationale = _stringFromMap(decoded['rationale']);
        if (rationale != null && rationale.isNotEmpty) {
          return rationale;
        }
        final text = _stringFromMap(decoded['text']);
        if (text != null && text.isNotEmpty) {
          return text;
        }
      }
    } catch (_) {
      // Fall through to raw text.
    }
  }
  return value;
}

String? _stringFromMap(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  final converted = value.toString().trim();
  return converted.isEmpty ? null : converted;
}

String? _extractJsonObject(String value) {
  final start = value.indexOf('{');
  final end = value.lastIndexOf('}');
  if (start == -1 || end == -1 || end <= start) {
    return null;
  }
  return value.substring(start, end + 1);
}

class _DetailAppBar extends StatelessWidget {
  final bool isDark;

  const _DetailAppBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: (isDark ? DetailPalette.backgroundDark : Colors.white)
            .withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : DetailPalette.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new),
            color: isDark ? Colors.white : DetailPalette.textDark,
          ),
          Expanded(
            child: Text(
              '상세 분석',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : DetailPalette.textDark,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.info_outline),
            color: isDark ? Colors.white70 : DetailPalette.primary,
          ),
        ],
      ),
    );
  }
}

class _SelectedClauseCard extends StatelessWidget {
  final bool isDark;
  final String text;

  const _SelectedClauseCard({required this.isDark, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : DetailPalette.cream,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: DetailPalette.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info,
                    size: 18,
                    color: DetailPalette.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '선택한 조항',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : DetailPalette.textDark,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF3F2D16)
                    : DetailPalette.yellowBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF7C5D2A)
                      : DetailPalette.yellowBorder,
                ),
              ),
              child: Text(
                '"$text"',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: isDark ? Colors.white70 : DetailPalette.textDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final _DetailTab selectedTab;
  final VoidCallback onDebateTap;
  final VoidCallback onAlternativeTap;
  final VoidCallback onQuestionTap;

  const _SegmentedTabs({
    required this.selectedTab,
    required this.onDebateTap,
    required this.onAlternativeTap,
    required this.onQuestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: DetailPalette.cream,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onDebateTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selectedTab == _DetailTab.debate
                      ? DetailPalette.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '토론 결과',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selectedTab == _DetailTab.debate
                        ? Colors.white
                        : DetailPalette.textMuted,
                    fontWeight: selectedTab == _DetailTab.debate
                        ? FontWeight.w700
                        : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onAlternativeTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selectedTab == _DetailTab.alternative
                      ? DetailPalette.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '대안 예시',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selectedTab == _DetailTab.alternative
                        ? Colors.white
                        : DetailPalette.textMuted,
                    fontWeight: selectedTab == _DetailTab.alternative
                        ? FontWeight.w700
                        : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onQuestionTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selectedTab == _DetailTab.question
                      ? DetailPalette.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '질문 초안',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selectedTab == _DetailTab.question
                        ? Colors.white
                        : DetailPalette.textMuted,
                    fontWeight: selectedTab == _DetailTab.question
                        ? FontWeight.w700
                        : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhySection extends StatelessWidget {
  final bool isDark;
  final String text;

  const _WhySection({required this.isDark, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFFEE2E2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3B1D1D) : const Color(0xFFFFF5F5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFFED7D7),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.help, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text(
                  '왜 이 조항을 확인해야 하나요?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF9B2C2C),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: isDark ? Colors.white70 : DetailPalette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerspectiveSection extends StatelessWidget {
  final bool isDark;
  final String tenantText;
  final String landlordText;
  final String neutralText;

  const _PerspectiveSection({
    required this.isDark,
    required this.tenantText,
    required this.landlordText,
    required this.neutralText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                const Icon(
                  Icons.groups,
                  size: 18,
                  color: DetailPalette.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '관점별 해설',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : DetailPalette.textDark,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              '협상 시 참고할 수 있는 논점 정리 자료입니다',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white60 : DetailPalette.textMuted,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _PerspectiveCard(
                  title: '임차인 관점 해설',
                  text: tenantText,
                  tint: DetailPalette.blueBg,
                  border: DetailPalette.blueBorder,
                  stripe: const Color(0xFF3B82F6),
                  icon: Icons.person,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _PerspectiveCard(
                  title: '임대인 관점 해설',
                  text: landlordText,
                  tint: DetailPalette.orangeBg,
                  border: DetailPalette.orangeBorder,
                  stripe: DetailPalette.primary,
                  icon: Icons.home_work,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _PerspectiveCard(
                  title: '중립 요약',
                  text: neutralText,
                  tint: DetailPalette.purpleBg,
                  border: DetailPalette.purpleBorder,
                  stripe: const Color(0xFF8B5CF6),
                  icon: Icons.balance,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlternativeSection extends StatefulWidget {
  final bool isDark;

  const _AlternativeSection({required this.isDark});

  @override
  State<_AlternativeSection> createState() => _AlternativeSectionState();
}

class _AlternativeSectionState extends State<_AlternativeSection> {
  String _selectedGrade = 'B';

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white70 : DetailPalette.textMuted;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '변경 후 (AI 추천 대안)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: DetailPalette.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Divider(color: Color(0xFFFED7AA), height: 1)),
          ],
        ),
        const SizedBox(height: 14),

        Stack(
          clipBehavior: Clip.none,
          children: [
            if (_selectedGrade == 'B')
              Positioned(
                top: -10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DetailPalette.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'AI 추천',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            _AlternativeChoiceCard(
              isDark: isDark,
              grade: 'A',
              title: '보수적',
              selected: _selectedGrade == 'A',
              text:
                  '계약 상대방은 직접적인 손해에 대해 책임을 지며, 총 책임 한도는 10만 달러 또는 청구 전 12개월 동안 지급된 총 수수료 중 더 큰 금액으로 제한된다.',
              color: cardColor,
              onTap: () => setState(() => _selectedGrade = 'B'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            if (_selectedGrade == 'B')
              Positioned(
                top: -10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DetailPalette.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'AI 추천',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            _AlternativeChoiceCard(
              isDark: isDark,
              grade: 'B',
              title: '중립적',
              selected: _selectedGrade == 'B',
              text:
                  '계약 상대방은 직접적인 손해에 대해 책임을 지며, 총 책임 한도는 10만 달러 또는 청구 전 12개월 동안 지급된 총 수수료 중 더 큰 금액으로 제한된다.',
              color: cardColor,
              onTap: () => setState(() => _selectedGrade = 'B'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            if (_selectedGrade == 'B')
              Positioned(
                top: -10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DetailPalette.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'AI 추천',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            _AlternativeChoiceCard(
              isDark: isDark,
              grade: 'C',
              title: '상대방 친화적',
              selected: _selectedGrade == 'C',
              text:
                  '계약 상대방은 직접적인 손해에 대해 책임을 지며, 총 책임 한도는 10만 달러 또는 청구 전 12개월 동안 지급된 총 수수료 중 더 큰 금액으로 제한된다.',
              color: cardColor,
              onTap: () => setState(() => _selectedGrade = 'C'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Center(
          child: Column(
            children: [
              Text(
                '해당 조항은 유사 계약 데이터베이스에서 분석된 표현 예시입니다.',
                style: TextStyle(fontSize: 10, color: textColor),
                textAlign: TextAlign.center,
              ),
              Text(
                '법적 조언을 대신하지 않습니다.',
                style: TextStyle(fontSize: 10, color: textColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlternativeChoiceCard extends StatelessWidget {
  final bool isDark;
  final String grade;
  final String title;
  final bool selected;
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _AlternativeChoiceCard({
    required this.isDark,
    required this.grade,
    required this.title,
    required this.selected,
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseText = isDark ? Colors.white70 : DetailPalette.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? DetailPalette.primary : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected
                        ? DetailPalette.primary
                        : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      grade,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? DetailPalette.primary
                        : const Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? DetailPalette.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? DetailPalette.primary
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: baseText,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '가장 균형 잡힌 조항',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: DetailPalette.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionDraftSection extends StatelessWidget {
  const _QuestionDraftSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const draftText = '''
안녕하세요, 계약서 제5조 보증금 반환 조항과 관련하여 몇 가지 확인하고 싶은 사항이 있습니다.
1. '임차인의 책임 있는 사유'의 구체적인 범위
 - 어떤 경우가 여기에 해당하는지 예시를 알려주시면 감사하겠습니다
 - 통상적인 사용으로 인한 자연 마모(벽지 변색, 경미한 바닥 흠집 등)도 포함되나요?
2. 손해 산정 방법
 - 손해 금액은 어떤 기준으로 산정하시나요?
 - 견적서 등 증빙자료를 제공해주실 수 있나요?
3. 이의 제기 절차
 - 손해 공제 금액에 이의가 있을 경우 어떻게 해결하나요?
명확한 기준이 있으면 서로 편할 것 같아 여쭤봅니다.''';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  '2. 이 조항을 보고 생각해볼 질문',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _QuestionCard(
          title: '\'구체적으로 어떤 경우가 "책임 있는 사유"에 해당하는지 예시를 제시해주실 수 있나요?\'',
          hint: '추상적인 문구는 분쟁의 원인이 됩니다. 구체적인 사례로 범위를 한정짓는 것이 유리합니다.',
        ),
        const SizedBox(height: 12),
        _QuestionCard(
          title: '\'손해 금액은 어떤 방식으로 산정하며, 제3자 감정이 필요한 경우 비용은 누가 부담하나요?\'',
          hint: '임대인이 임의로 고액의 수리비를 청구하는 것을 방지하기 위해 객관적 기준이 필요합니다.',
        ),
        const SizedBox(height: 12),
        _QuestionCard(
          title: '\'통상적인 사용으로 인한 자연 마모(벽지 변색, 바닥 흠집 등)도 임차인 책임인가요?\'',
          hint: '자연 마모는 원칙적으로 임대인의 부담이나, 특약으로 전가될 수 있어 확인이 필요합니다.',
        ),
        const SizedBox(height: 12),
        _QuestionCard(
          title: '\'손해 공제에 이의가 있을 경우 해결 절차는 어떻게 되나요?\'',
          hint: '보증금 반환이 지연되지 않도록 분쟁 해결 절차를 미리 알아두는 것이 좋습니다.',
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE9D5FF),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2E1A47)
                      : const Color(0xFFF5F3FF),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.copy_rounded,
                      color: Color(0xFF7C3AED),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '3. 질문 정리 예시 문안',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6D28D9),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '참고용 문안입니다. 복사하여 자유롭게 수정하세요.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white60
                            : DetailPalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF3F2D16)
                            : DetailPalette.yellowBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF7C5D2A)
                              : DetailPalette.yellowBorder,
                        ),
                      ),
                      child: Text(
                        draftText,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.6,
                          color: isDark
                              ? Colors.white70
                              : DetailPalette.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: draftText),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('질문 문안을 복사했습니다.')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('복사하기'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '전송 기능은 제공하지 않습니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final String title;
  final String hint;

  const _QuestionCard({required this.title, required this.hint});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: isDark ? Colors.white : DetailPalette.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _CopyCircleButton(text: title),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hint,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
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

class _CopyCircleButton extends StatelessWidget {
  final String text;

  const _CopyCircleButton({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('질문을 복사했습니다.')));
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3F2D16) : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Icon(
          Icons.copy_rounded,
          size: 18,
          color: DetailPalette.primary,
        ),
      ),
    );
  }
}

class _PerspectiveCard extends StatelessWidget {
  final String title;
  final String text;
  final Color tint;
  final Color border;
  final Color stripe;
  final IconData icon;
  final bool isDark;

  const _PerspectiveCard({
    required this.title,
    required this.text,
    required this.tint,
    required this.border,
    required this.stripe,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: stripe,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: stripe),
                        const SizedBox(width: 6),
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: isDark
                                ? Colors.white
                                : DetailPalette.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.6,
                        color: isDark
                            ? Colors.white70
                            : DetailPalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final bool isDark;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _BottomActionBar({
    required this.isDark,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: (isDark ? DetailPalette.backgroundDark : Colors.white)
            .withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : DetailPalette.borderLight,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.check, size: 18),
          label: Text(
            buttonLabel,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: DetailPalette.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            elevation: 6,
            shadowColor: DetailPalette.primary.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}
