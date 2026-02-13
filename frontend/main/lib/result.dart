import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'detail.dart';
import 'login_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'shared/color_compat.dart';
import 'user_session.dart';
import 'welcome_screen.dart';

final Map<String, Map<String, dynamic>> _detailCache = {};
final Map<String, Future<Map<String, dynamic>>> _detailInFlight = {};

class AnalysisFlowTrace {
  static Stopwatch? _stopwatch;
  static String? _source;
  static String? _filename;
  static int _runId = 0;

  static bool get _isActive => _stopwatch != null;

  static void start({
    required String source,
    required String filename,
  }) {
    _runId += 1;
    _source = source;
    _filename = filename;
    _stopwatch = Stopwatch()..start();
    _print('start');
  }

  static void mark(String step, {Map<String, Object?>? data}) {
    if (!_isActive) {
      return;
    }
    _print(step, data: data);
  }

  static void end(String step, {Map<String, Object?>? data}) {
    if (!_isActive) {
      return;
    }
    _print(step, data: data);
    _stopwatch?.stop();
    _stopwatch = null;
    _source = null;
    _filename = null;
  }

  static void _print(String step, {Map<String, Object?>? data}) {
    final elapsedMs = _stopwatch?.elapsedMilliseconds ?? 0;
    final extras = <String>[];
    final source = _source;
    final filename = _filename;
    if (source != null) {
      extras.add('source=$source');
    }
    if (filename != null) {
      extras.add('file=$filename');
    }
    data?.forEach((key, value) {
      extras.add('$key=${value ?? 'null'}');
    });
    final suffix = extras.isEmpty ? '' : ' ${extras.join(' ')}';
    debugPrint('[flow][$_runId] t=${elapsedMs}ms step=$step$suffix');
  }
}

// 결과 화면에서 사용하는 색상 팔레트.
class ResultPalette {
  static const Color primary = Color(0xFFFA9819);
  static const Color accentBlue = Color(0xFFE85D04);
  static const Color navyPanel = Color(0xFFFFF4D6);
  static const Color backgroundLight = Color(0xFFFFFDF8);
  static const Color backgroundDark = Color(0xFF1A1612);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF2D2823);
  static const Color cardBorder = Color(0xFFFFE2BF);
  static const Color textHeader = Color(0xFF1F2937);
  static const Color textBody = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color riskRed = Color(0xFFE85D04);
  static const Color riskYellow = Color(0xFFFFB347);
  static const Color riskBlue = Color(0xFFFA9819);
}

// 조항 위험도를 표현하는 등급.
enum RiskLevel { high, medium, low, info }

// 하이라이트로 표시할 텍스트 구간(시작/끝 인덱스).
class _HighlightRange {
  final int start;
  final int end;

  const _HighlightRange(this.start, this.end);
}

// API 조항 데이터를 화면 모델로 변환한 구조.
class ContractClause {
  final int? id;
  final String? lookupKey;
  final String title;
  final String body;
  final String? highlight;
  final List<String> highlights;
  final RiskLevel? risk;

  const ContractClause({
    this.id,
    this.lookupKey,
    required this.title,
    required this.body,
    this.highlight,
    this.highlights = const [],
    this.risk,
  });
}

// 요약 텍스트를 스타일별로 나누기 위한 스팬 모델.
class ResultSummarySpan {
  final String text;
  final bool isBold;
  final Color? underlineColor;
  final Color? textColor;

  const ResultSummarySpan(
    this.text, {
    this.isBold = false,
    this.underlineColor,
    this.textColor,
  });
}

// 결과 화면에 필요한 집계/목록/요약 데이터 컨테이너.
class ResultData {
  final int foundClauseCount;
  final int riskyClauseCount;
  final List<ContractClause> clauses;
  final List<ResultSummarySpan> summarySpans;
  final String? rawText;
  final List<String> rawHighlights;

  const ResultData({
    required this.foundClauseCount,
    required this.riskyClauseCount,
    required this.clauses,
    required this.summarySpans,
    this.rawText,
    this.rawHighlights = const [],
  });
}

// API 응답을 화면 모델로 변환하고 상태를 관리하는 뷰모델.
class ResultViewModel extends ChangeNotifier {
  ResultData data;
  bool showSummary;
  final String? filename;
  final String? analysisId;
  final List<ResultSummarySpan> _defaultSummarySpans;

  ResultViewModel({
    required this.data,
    this.showSummary = false,
    this.filename,
    this.analysisId,
  }) : _defaultSummarySpans = data.summarySpans;

  void toggleSummary() {
    showSummary = !showSummary;
    notifyListeners();
  }

  void closeSummary() {
    if (!showSummary) {
      return;
    }
    debugPrint('[result] summary close');
    showSummary = false;
    if (data.summarySpans != _defaultSummarySpans) {
      data = ResultData(
        foundClauseCount: data.foundClauseCount,
        riskyClauseCount: data.riskyClauseCount,
        clauses: data.clauses,
        summarySpans: _defaultSummarySpans,
        rawText: data.rawText,
        rawHighlights: data.rawHighlights,
      );
    }
    notifyListeners();
  }

  void openSummary() {
    if (showSummary || data.summarySpans.isEmpty) {
      return;
    }
    debugPrint('[result] summary open');
    showSummary = true;
    notifyListeners();
  }

  void updateSummarySpans(List<ResultSummarySpan> spans) {
    data = ResultData(
      foundClauseCount: data.foundClauseCount,
      riskyClauseCount: data.riskyClauseCount,
      clauses: data.clauses,
      summarySpans: spans,
      rawText: data.rawText,
      rawHighlights: data.rawHighlights,
    );
    notifyListeners();
  }

  // API 응답을 화면 모델로 변환한다.
  static ResultViewModel fromApi(
    Map<String, dynamic> data, {
    String? filename,
    String? fallbackSummary,
  }) {
    final riskySnippets = _extractRiskSnippets(data);
    final clauses = _parseClauses(data, riskySnippets: riskySnippets);
    final riskyClauses = data['risky_clauses'] as List?;
    final analysisId = _stringOrIntFrom(
      data,
      ['analysis_id', 'analysisId', 'id'],
    );
    final riskyCount =
        _intFrom(data, ['risky_count', 'risk_count', 'riskyCount']) ??
        riskyClauses?.length ??
        clauses
            .where(
              (clause) =>
                  clause.risk == RiskLevel.high ||
                  clause.risk == RiskLevel.medium,
            )
            .length;
    final foundCount =
        (data['total_clauses'] as int?) ??
        (data['clauses'] as List?)?.length ??
        (clauses.isNotEmpty ? clauses.length : riskyCount);
    final summaryText = _cleanText(
      (data['summary'] as String?)?.trim() ??
          (data['llm_summary'] as String?)?.trim() ??
          fallbackSummary?.trim(),
    );
    final summarySpans = _buildSummarySpans(summaryText);
    final rawTextSource = _rawStringFrom(data, [
      'raw_text',
      'rawText',
      'ocr_text',
    ]);
    final rawText = rawTextSource == null
        ? null
        : _dedupeRepeatedRawText(rawTextSource);
    final rawHighlights = rawText == null
        ? const <String>[]
        : _collectHighlights(rawText, null, riskySnippets);

    final highlightCount = clauses
        .map((clause) => clause.highlights.length)
        .fold<int>(0, (sum, count) => sum + count);
    debugPrint(
      '[result] analysisId=${analysisId ?? 'null'} '
      'clauses=${clauses.length} highlights=$highlightCount '
      'riskySnippets=${riskySnippets.length} '
      'riskyCount=$riskyCount foundCount=$foundCount '
      'summary=${summaryText == null ? 'null' : 'len=${summaryText.length}'}',
    );
    if (rawText != null) {
      final preview = rawText.length > 200
          ? rawText.substring(0, 200)
          : rawText;
      debugPrint('[result] raw_text len=${rawText.length} preview=$preview');
    } else {
      debugPrint('[result] raw_text=null');
    }
    if (clauses.isNotEmpty) {
      final sample = clauses.take(3).map((clause) {
        final hl = clause.highlights.isNotEmpty
            ? 'hl=${clause.highlights.length}'
            : (clause.highlight == null ? 'hl=0' : 'hl=1');
        return '${clause.title}(risk=${clause.risk}, $hl)';
      }).join(' | ');
      debugPrint('[result] sample=$sample');
    }

    final resolvedClauses = clauses.isNotEmpty
        ? clauses
        : _fallbackClausesFromRisky(riskyClauses);
    final resolvedFoundCount = foundCount > 0
        ? foundCount
        : resolvedClauses.length;

    return ResultViewModel(
      filename: filename,
      analysisId: analysisId,
      data: ResultData(
        foundClauseCount: resolvedFoundCount,
        riskyClauseCount: riskyCount,
        clauses: resolvedClauses,
        summarySpans: summarySpans,
        rawText: rawText,
        rawHighlights: rawHighlights,
      ),
      showSummary: false,
    );
  }

  // risky_clauses에서 위험 문구 후보를 추출한다.
  static List<String> _extractRiskSnippets(Map<String, dynamic> data) {
    final raw = data['risky_clauses'];
    if (raw is! List) {
      return [];
    }
    final snippets = <String>[];
    for (final item in raw) {
      if (item is String && item.trim().isNotEmpty) {
        snippets.add(_cleanText(item) ?? item.trim());
        continue;
      }
      if (item is Map<String, dynamic>) {
        final text = _stringFrom(item, [
          'risk_text',
          'highlight',
          'text',
          'body',
          'content',
          'clause',
        ]);
        if (text != null) {
          snippets.add(_cleanText(text) ?? text);
        }
      }
    }
    return snippets;
  }

  // clauses 배열을 파싱해 ContractClause 목록으로 변환한다.
  static List<ContractClause> _parseClauses(
    Map<String, dynamic> data, {
    List<String> riskySnippets = const [],
  }) {
    final rawClauses = data['clauses'];
    if (rawClauses is! List) {
      return [];
    }

    final clauses = <ContractClause>[];
    final seen = <String>{};
    for (final item in rawClauses) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final title = _cleanText(_stringFrom(item, ['title', 'name']));
      final body = _cleanText(_stringFrom(item, ['body', 'content', 'text']));
      final clauseId = _intFrom(item, [
        'id',
        'clause_id',
        'clauseId',
        'article_id',
        'articleId',
      ]);
      final lookupKey = _rawStringFrom(item, ['article_num', 'title', 'name']);
      if (title == null || body == null) {
        continue;
      }
      final highlight =
          _cleanText(_stringFrom(item, ['highlight', 'risk_text']));
      final risk = _riskFromString(_stringFrom(item, ['risk', 'level']));
      final highlights = _collectHighlights(body, highlight, riskySnippets);
      final dedupeKey =
          '${_normalizeRawText(title).toLowerCase()}|${_normalizeRawText(body).toLowerCase()}';
      if (!seen.add(dedupeKey)) {
        continue;
      }
      clauses.add(
        ContractClause(
          id: clauseId,
          lookupKey: lookupKey,
          title: title,
          body: body,
          highlight: highlight,
          highlights: highlights,
          risk: risk,
        ),
      );
    }
    return clauses;
  }

  static List<ContractClause> _fallbackClausesFromRisky(List? riskyClauses) {
    if (riskyClauses == null || riskyClauses.isEmpty) {
      return const [];
    }
    final clauses = <ContractClause>[];
    var index = 1;
    for (final item in riskyClauses) {
      String? body;
      RiskLevel? risk;
      if (item is String && item.trim().isNotEmpty) {
        body = _cleanText(item) ?? item.trim();
      } else if (item is Map<String, dynamic>) {
        body = _cleanText(_stringFrom(item, [
          'risk_text',
          'highlight',
          'text',
          'body',
          'content',
          'clause',
        ]));
        risk = _riskFromString(_stringFrom(item, ['risk', 'level']));
      }
      if (body == null || body.isEmpty) {
        continue;
      }
      clauses.add(
        ContractClause(
          title: '독소 조항 $index',
          body: body,
          highlight: body,
          highlights: [body],
          risk: risk ?? RiskLevel.high,
        ),
      );
      index += 1;
    }
    return clauses;
  }

  // 여러 키 후보 중 유효한 문자열 값을 찾는다.
  static String? _stringFrom(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  // 앞뒤 공백을 유지한 원문 문자열이 필요할 때 사용한다.
  static String? _rawStringFrom(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static int? _intFrom(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) {
        return value;
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static String? _stringOrIntFrom(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is int) {
        return value.toString();
      }
    }
    return null;
  }

  static String? _cleanText(String? value) {
    if (value == null) {
      return null;
    }
    final originalTrimmed = value.trim();
    if (originalTrimmed.isEmpty) {
      return null;
    }
    final cleaned = value
        // Remove zero-width and non-breaking spaces.
        .replaceAll(RegExp(r'[\u00A0\u200B\u200C\u200D\uFEFF]'), '')
        // Normalize ideographic space to a regular space.
        .replaceAll('\u3000', ' ')
        // Remove bidi/formatting/control marks that can shift alignment.
        .replaceAll(
          RegExp(r'[\u0000-\u001F\u007F-\u009F\u200E\u200F\u202A-\u202E\u2066-\u2069]'),
          '',
        )
        // Collapse whitespace runs.
        .replaceAll(RegExp(r'\s+'), ' ')
        // Trim including any remaining leading/trailing spaces.
        .trim();
    return cleaned.isEmpty ? originalTrimmed : cleaned;
  }

  // OCR 원문이 그대로 두 번 붙어 오는 경우 첫 번째 블록만 남긴다.
  static String _dedupeRepeatedRawText(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 120) {
      return trimmed;
    }

    final midpoint = trimmed.length ~/ 2;
    final start = (midpoint - 240).clamp(1, trimmed.length - 1);
    final end = (midpoint + 240).clamp(1, trimmed.length - 1);

    for (var split = start; split <= end; split++) {
      final left = trimmed.substring(0, split).trim();
      final right = trimmed.substring(split).trim();
      if (left.isEmpty || right.isEmpty) {
        continue;
      }
      if (_normalizeRawText(left) == _normalizeRawText(right)) {
        debugPrint(
          '[result] raw_text deduplicated '
          'original=${trimmed.length} deduped=${left.length}',
        );
        return left;
      }
    }

    return trimmed;
  }

  static String _normalizeRawText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // 위험도 문자열을 enum으로 매핑한다.
  static RiskLevel? _riskFromString(String? value) {
    if (value == null) {
      return null;
    }
    switch (value.toLowerCase()) {
      case 'high':
      case 'danger':
      case 'red':
        return RiskLevel.high;
      case 'medium':
      case 'warning':
      case 'yellow':
        return RiskLevel.medium;
      case 'low':
      case 'info':
      case 'blue':
        return RiskLevel.low;
    }
    return null;
  }

  // 본문에 실제 존재하는 하이라이트만 수집한다.
  static List<String> _collectHighlights(
    String body,
    String? primaryHighlight,
    List<String> riskySnippets,
  ) {
    final matches = <String>[];
    if (primaryHighlight != null && primaryHighlight.trim().isNotEmpty) {
      matches.add(primaryHighlight.trim());
    }
    for (final snippet in riskySnippets) {
      final trimmed = snippet.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (_findHighlightRange(body, trimmed) != null) {
        matches.add(trimmed);
      }
    }
    if (matches.isEmpty) {
      return const [];
    }
    final seen = <String>{};
    final unique = <String>[];
    for (final item in matches) {
      final key = item.replaceAll(RegExp(r'\s+'), '');
      if (seen.add(key)) {
        unique.add(item);
      }
    }
    return unique;
  }

  // 하이라이트 구간을 찾고 공백 차이를 보정한다.
  static _HighlightRange? _findHighlightRange(String body, String highlight) {
    final index = body.indexOf(highlight);
    if (index >= 0) {
      return _HighlightRange(index, index + highlight.length);
    }

    final normalizedBody = _normalizeText(body);
    final normalizedHighlight = _normalizeText(highlight);
    if (normalizedHighlight.isEmpty ||
        normalizedHighlight.length > normalizedBody.length) {
      return null;
    }

    final normalizedIndex = normalizedBody.indexOf(normalizedHighlight);
    if (normalizedIndex < 0) {
      return null;
    }

    final mapping = _buildNormalizedIndexMap(body);
    if (normalizedIndex >= mapping.length) {
      return null;
    }
    final endIndex = normalizedIndex + normalizedHighlight.length - 1;
    if (endIndex >= mapping.length) {
      return null;
    }
    final start = mapping[normalizedIndex];
    final end = mapping[endIndex] + 1;
    if (start >= 0 && end > start && end <= body.length) {
      return _HighlightRange(start, end);
    }
    return null;
  }

  // 공백/개행을 제거한 문자열로 정규화한다.
  static String _normalizeText(String value) {
    return value.replaceAll(RegExp(r'\s+'), '');
  }

  // 정규화 인덱스를 원문 인덱스로 매핑하는 테이블.
  static List<int> _buildNormalizedIndexMap(String value) {
    final mapping = <int>[];
    for (var i = 0; i < value.length; i++) {
      if (!RegExp(r'\s').hasMatch(value[i])) {
        mapping.add(i);
      }
    }
    return mapping;
  }

  // 요약 텍스트를 스팬 목록으로 변환한다.
  static List<ResultSummarySpan> _buildSummarySpans(String? summaryText) {
    final cleaned = _cleanSummaryText(summaryText);
    if (cleaned != null && cleaned.isNotEmpty) {
      return [ResultSummarySpan(cleaned)];
    }

    return const [];
  }

  static String? _cleanSummaryText(String? value) {
    if (value == null) {
      return null;
    }
    final lines = value.split('\n');
    final cleanedLines = <String>[];
    for (final line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      // Remove markdown heading/bullets.
      trimmed = trimmed.replaceAll(RegExp(r'^#{1,6}\s*'), '');
      trimmed = trimmed.replaceAll(RegExp(r'^[-*•]\s+'), '');
      // Remove markdown emphasis markers.
      trimmed = trimmed.replaceAll(RegExp(r'[*_`]+'), '');
      if (trimmed.isNotEmpty) {
        cleanedLines.add(trimmed);
      }
    }
    if (cleanedLines.isEmpty) {
      return null;
    }
    return cleanedLines.join(' ');
  }
}

// 결과 화면 루트 위젯.
class ResultScreen extends StatefulWidget {
  final ResultViewModel viewModel;

  const ResultScreen({super.key, required this.viewModel});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

// 결과 화면의 상태 및 렌더링 로직.
class _ResultScreenState extends State<ResultScreen> {
  ContractClause? _lastTappedClause;
  bool _isSummaryDialogOpen = false;
  String? _summaryLoadingKey;
  String? _lastTapKey;
  DateTime? _lastTapAt;
  bool _isDetailOpening = false;

  @override
  void initState() {
    super.initState();
    AnalysisFlowTrace.mark(
      'result_screen_init',
      data: {
        'analysisId': widget.viewModel.analysisId ?? 'null',
        'clauses': widget.viewModel.data.clauses.length,
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalysisFlowTrace.end(
        'result_first_frame',
        data: {
          'analysisId': widget.viewModel.analysisId ?? 'null',
          'clauses': widget.viewModel.data.clauses.length,
          'highlights': widget.viewModel.data.rawHighlights.length,
        },
      );
    });
  }

  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        final shouldShowRawText = _shouldShowRawTextCard(widget.viewModel.data);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final background = isDark
            ? ResultPalette.backgroundDark
            : ResultPalette.backgroundLight;
        return Scaffold(
          backgroundColor: background,
          bottomNavigationBar: const ResultBottomNav(),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  color: background,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          ResultTopAppBar(
                            isDark: isDark,
                            onBack: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => WelcomeScreen(
                                    onLoginTap: (context) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => LoginScreen(
                                            onLogin: () =>
                                                Navigator.of(context).pop(),
                                            onSignupClick: () {},
                                          ),
                                        ),
                                      );
                                    },
                                    onSignupTap: (_) {},
                                  ),
                                ),
                                (route) => false,
                              );
                            },
                            onMenu: () {},
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 80),
                              child: Column(
                                children: [
                                  ResultStatsRow(
                                    isDark: isDark,
                                    foundCount:
                                        widget.viewModel.data.foundClauseCount,
                                    riskyCount:
                                        widget.viewModel.data.riskyClauseCount,
                                  ),
                                  if (shouldShowRawText)
                                    _OcrRawTextCard(
                                      isDark: isDark,
                                      text: widget.viewModel.data.rawText!,
                                      highlights:
                                          widget.viewModel.data.rawHighlights,
                                      onHighlightTap: (highlight) =>
                                          _handleOcrHighlightTap(
                                            context,
                                            highlight,
                                          ),
                                    ),
                                  const SizedBox(height: 80),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _shouldShowRawTextCard(ResultData data) {
    final rawText = data.rawText;
    if (rawText == null || rawText.trim().isEmpty) {
      return false;
    }

    final normalizedRaw = ResultViewModel._normalizeRawText(
      rawText,
    ).toLowerCase();
    if (normalizedRaw.length < 40) {
      return true;
    }

    for (final clause in data.clauses) {
      final normalizedBody = ResultViewModel._normalizeRawText(
        clause.body,
      ).toLowerCase();
      if (normalizedBody.isEmpty) {
        continue;
      }

      final isSameText = normalizedBody == normalizedRaw;
      final bodyMostlyRaw =
          normalizedBody.length >= (normalizedRaw.length * 0.85) &&
          normalizedRaw.contains(normalizedBody);
      final rawMostlyBody =
          normalizedRaw.length >= (normalizedBody.length * 0.85) &&
          normalizedBody.contains(normalizedRaw);

      if (isSameText || bodyMostlyRaw || rawMostlyBody) {
        return false;
      }
    }

    return true;
  }


  void _handleHighlightTap(BuildContext context, ContractClause clause) {
    final analysisId = widget.viewModel.analysisId;
    if (analysisId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 데이터를 찾을 수 없습니다.')),
      );
      return;
    }
    final key = _detailCacheKey(analysisId, clause);
    final now = DateTime.now();
    if (_lastTapKey == key &&
        _lastTapAt != null &&
        now.difference(_lastTapAt!).inMilliseconds < 700) {
      debugPrint('[result] highlight tap ignored (debounce) key=$key');
      return;
    }
    _lastTapKey = key;
    _lastTapAt = now;
    _lastTappedClause = clause;
    debugPrint(
      '[result] highlight tap analysisId=$analysisId '
      'clauseId=${clause.id?.toString() ?? 'null'} '
      'lookup=${clause.lookupKey ?? 'null'} '
      'title=${clause.title}',
    );
    _loadClauseSummary(context, analysisId, clause);
  }

  Future<void> _showSummaryDialog(BuildContext context) async {
    if (_isSummaryDialogOpen || !context.mounted) {
      return;
    }
    _isSummaryDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: AnimatedBuilder(
            animation: widget.viewModel,
            builder: (context, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return ResultSummaryCard(
                isDark: isDark,
                spans: widget.viewModel.data.summarySpans,
                onClose: () {
                  widget.viewModel.closeSummary();
                  Navigator.of(dialogContext).pop();
                },
                onAction: () {
                  Navigator.of(dialogContext).pop();
                  _openSelectedClauseDetail(context);
                },
              );
            },
          ),
        );
      },
    );
    _isSummaryDialogOpen = false;
  }

  void _handleOcrHighlightTap(BuildContext context, String highlight) {
    final clauses = widget.viewModel.data.clauses;
    ContractClause? matched;
    for (final clause in clauses) {
      if (clause.highlights.any((item) => item.contains(highlight))) {
        matched = clause;
        break;
      }
    }
    if (matched == null) {
      for (final clause in clauses) {
        if (clause.highlights.any((item) => highlight.contains(item))) {
          matched = clause;
          break;
        }
      }
    }
    if (matched == null) {
      final normalizedHighlight = _normalizeForMatch(highlight);
      for (final clause in clauses) {
        final normalizedBody = _normalizeForMatch(clause.body);
        if (normalizedBody.contains(normalizedHighlight)) {
          matched = clause;
          break;
        }
      }
    }
    if (matched == null) {
      debugPrint('[result] ocr highlight no match: "$highlight"');
      widget.viewModel.updateSummarySpans(
        const [ResultSummarySpan('해당 하이라이트 요약을 찾지 못했습니다.')],
      );
      widget.viewModel.openSummary();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('해당 하이라이트 조항을 찾지 못했습니다.')),
      );
      return;
    }
    debugPrint('[result] ocr highlight match: "${matched.title}"');
    _handleHighlightTap(context, matched);
  }

  String _normalizeForMatch(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[.,!?:;()"\\[\\]{}<>\\-]'), '')
        .replaceAll('·', '')
        .replaceAll('ㆍ', '')
        .toLowerCase();
  }

  void _openSelectedClauseDetail(BuildContext context) {
    if (_isDetailOpening) {
      return;
    }
    final analysisId = widget.viewModel.analysisId;
    final clauses = widget.viewModel.data.clauses;
    if (analysisId == null || clauses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 데이터를 찾을 수 없습니다.')),
      );
      return;
    }
    final clause = _lastTappedClause ??
        clauses.firstWhere(
          (item) => item.id != null,
          orElse: () => clauses.first,
        );
    debugPrint(
      '[result] detail open clause="${clause.title}" id=${clause.id?.toString() ?? 'null'}',
    );
    _isDetailOpening = true;
    _openDetail(context, analysisId, clause).whenComplete(() {
      _isDetailOpening = false;
    });
  }

  Future<void> _loadClauseSummary(
    BuildContext context,
    String? analysisId,
    ContractClause clause,
  ) async {
    widget.viewModel.updateSummarySpans(
      const [ResultSummarySpan('요약을 불러오는 중입니다.')],
    );
    widget.viewModel.openSummary();
    _showSummaryDialog(context);
    if (analysisId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 데이터를 찾을 수 없습니다.')),
      );
      return;
    }
    final cacheKey = _detailCacheKey(analysisId, clause);
    if (_summaryLoadingKey == cacheKey) {
      debugPrint('[result] summary load skipped (already loading) key=$cacheKey');
      return;
    }
    _summaryLoadingKey = cacheKey;

    try {
      final decoded = await _getClauseDetailWithCache(analysisId, clause);
      if (!context.mounted) {
        return;
      }
      final spans = _buildClauseSummarySpans(decoded);
      widget.viewModel.updateSummarySpans(spans);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      final message = _friendlyDetailErrorMessage(error);
      widget.viewModel.updateSummarySpans(
        const [ResultSummarySpan('해당 조항 요약을 불러올 수 없습니다.')],
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (_summaryLoadingKey == cacheKey) {
        _summaryLoadingKey = null;
      }
    }
  }
}

// 상단 앱바(뒤로가기/타이틀/더보기).

String _detailCacheKey(String analysisId, ContractClause clause) {
  return '$analysisId::${clause.id?.toString() ?? clause.lookupKey ?? clause.title}';
}

class ResultTopAppBar extends StatelessWidget {
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onMenu;

  const ResultTopAppBar({
    super.key,
    required this.isDark,
    required this.onBack,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:
            (isDark
                    ? ResultPalette.backgroundDark
                    : ResultPalette.backgroundLight)
                .withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : ResultPalette.cardBorder,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new),
            color: isDark ? Colors.white : ResultPalette.textHeader,
          ),
          Expanded(
            child: Text(
              '분석 결과 리포트',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ResultPalette.textHeader,
              ),
            ),
          ),
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.more_horiz),
            color: isDark ? Colors.white : ResultPalette.textHeader,
          ),
        ],
      ),
    );
  }
}

// 상단 통계 카드(발견 조항/독소 가능성).
class ResultStatsRow extends StatelessWidget {
  final bool isDark;
  final int foundCount;
  final int riskyCount;

  const ResultStatsRow({
    super.key,
    required this.isDark,
    required this.foundCount,
    required this.riskyCount,
  });

  @override
  Widget build(BuildContext context) {
    final highlightCount = foundCount > 0 ? foundCount : riskyCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ResultPalette.navyPanel.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ResultPalette.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: ResultPalette.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: ResultPalette.accentBlue,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$highlightCount개의 확인 필요 조항이 발견되었습니다',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ResultPalette.accentBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultBottomNav extends StatelessWidget {
  const ResultBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoggedIn = UserSession.userId != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xCC1A1612)
            : ResultPalette.cardLight.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0xFF1F2937)
                : ResultPalette.primary.withValues(alpha: 0.2),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: ResultPalette.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _ResultNavItem(
                icon: Icons.home_rounded,
                label: '홈',
                onTap: () {
                  if (!isLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('로그인 후 이용가능')),
                    );
                    return;
                  }
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => WelcomeScreen(
                        onLoginTap: (context) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LoginScreen(
                                onLogin: () => Navigator.of(context).pop(),
                                onSignupClick: () {},
                              ),
                            ),
                          );
                        },
                        onSignupTap: (_) {},
                      ),
                    ),
                    (_) => false,
                  );
                },
              ),
              _ResultNavItem(
                icon: Icons.history_rounded,
                label: '히스토리',
                onTap: () {
                  if (!isLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('로그인 후 이용가능')),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
              ),
              const _ResultNavItem(
                icon: Icons.smart_toy_rounded,
                label: 'AI 상담',
              ),
              _ResultNavItem(
                icon: Icons.person_rounded,
                label: '마이페이지',
                onTap: () {
                  if (!isLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('로그인 후 이용가능')),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: 120,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ResultNavItem({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : ResultPalette.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OcrRawTextCard extends StatelessWidget {
  final bool isDark;
  final String text;
  final List<String> highlights;
  final ValueChanged<String> onHighlightTap;

  const _OcrRawTextCard({
    required this.isDark,
    required this.text,
    required this.highlights,
    required this.onHighlightTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white70 : ResultPalette.textBody;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                height: 1.6,
              ),
              children: _buildHighlightSpans(
                text,
                highlights,
                ResultPalette.riskBlue,
                onTap: onHighlightTap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildHighlightSpans(
    String body,
    List<String> highlights,
    Color color, {
    ValueChanged<String>? onTap,
  }) {
    if (highlights.isEmpty) {
      return [TextSpan(text: body)];
    }

    final ranges = <_HighlightRange>[];
    for (final highlight in highlights) {
      final range = ResultViewModel._findHighlightRange(body, highlight);
      if (range != null) {
        ranges.add(range);
      }
    }
    if (ranges.isEmpty) {
      return [TextSpan(text: body)];
    }

    ranges.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_HighlightRange>[];
    for (final range in ranges) {
      if (merged.isEmpty || range.start > merged.last.end) {
        merged.add(range);
      } else if (range.end > merged.last.end) {
        merged[merged.length - 1] = _HighlightRange(
          merged.last.start,
          range.end,
        );
      }
    }

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final range in merged) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: body.substring(cursor, range.start)));
      }
      final highlightText = body.substring(range.start, range.end);
      spans.add(
        TextSpan(
          text: highlightText,
          style: TextStyle(
            backgroundColor: color.withValues(alpha: 0.2),
          ),
          recognizer: onTap == null
              ? null
              : (TapGestureRecognizer()..onTap = () => onTap(highlightText)),
        ),
      );
      cursor = range.end;
    }
    if (cursor < body.length) {
      spans.add(TextSpan(text: body.substring(cursor)));
    }
    return spans;
  }
}

// 조항 리스트 섹션.
class ResultClauseList extends StatelessWidget {
  final bool isDark;
  final List<ContractClause> clauses;
  final ValueChanged<ContractClause> onHighlightTap;
  final ContractClause? selectedClause;
  final bool showSummary;
  final List<ResultSummarySpan> summarySpans;
  final VoidCallback onCloseSummary;
  final VoidCallback onSummaryAction;

  const ResultClauseList({
    super.key,
    required this.isDark,
    required this.clauses,
    required this.onHighlightTap,
    required this.selectedClause,
    required this.showSummary,
    required this.summarySpans,
    required this.onCloseSummary,
    required this.onSummaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final clause in clauses)
            _ClauseSection(
              isDark: isDark,
              clause: clause,
              onHighlightTap: onHighlightTap,
              isSelected: selectedClause == clause,
              showSummary: showSummary,
              summarySpans: summarySpans,
              onCloseSummary: onCloseSummary,
              onSummaryAction: onSummaryAction,
            ),
        ],
      ),
    );
  }
}

// 단일 조항 섹션(제목 + 본문 하이라이트).
class _ClauseSection extends StatefulWidget {
  final bool isDark;
  final ContractClause clause;
  final ValueChanged<ContractClause> onHighlightTap;
  final bool isSelected;
  final bool showSummary;
  final List<ResultSummarySpan> summarySpans;
  final VoidCallback onCloseSummary;
  final VoidCallback onSummaryAction;

  const _ClauseSection({
    required this.isDark,
    required this.clause,
    required this.onHighlightTap,
    required this.isSelected,
    required this.showSummary,
    required this.summarySpans,
    required this.onCloseSummary,
    required this.onSummaryAction,
  });

  @override
  State<_ClauseSection> createState() => _ClauseSectionState();
}

class _ClauseSectionState extends State<_ClauseSection> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTextColor = widget.isDark
        ? Colors.grey.shade300
        : ResultPalette.textBody;
    final highlights = widget.clause.highlights.isNotEmpty
        ? widget.clause.highlights
        : (widget.clause.highlight != null
              ? [widget.clause.highlight!]
              : const <String>[]);
    final highlightColor = _riskColor(
      widget.clause.risk,
      hasHighlight: highlights.isNotEmpty,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.clause.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark
                        ? Colors.white
                        : ResultPalette.textHeader,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 17,
                height: 1.6,
                color: baseTextColor,
              ),
              children: _buildHighlightSpans(
                widget.clause.body,
                highlights,
                highlightColor,
              ),
            ),
          ),
          if (widget.isSelected &&
              widget.showSummary &&
              widget.summarySpans.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ResultSummaryCard(
                isDark: widget.isDark,
                spans: widget.summarySpans,
                onClose: widget.onCloseSummary,
                onAction: widget.onSummaryAction,
              ),
            ),
        ],
      ),
    );
  }

  List<TextSpan> _buildHighlightSpans(
    String body,
    List<String> highlights,
    Color? color,
  ) {
    if (highlights.isEmpty || color == null) {
      return [TextSpan(text: body)];
    }

    final ranges = <_HighlightRange>[];
    for (final highlight in highlights) {
      final range = ResultViewModel._findHighlightRange(body, highlight);
      if (range != null) {
        ranges.add(range);
      }
    }
    if (ranges.isEmpty) {
      return [TextSpan(text: body)];
    }

    ranges.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_HighlightRange>[];
    for (final range in ranges) {
      if (merged.isEmpty || range.start > merged.last.end) {
        merged.add(range);
      } else if (range.end > merged.last.end) {
        merged[merged.length - 1] = _HighlightRange(
          merged.last.start,
          range.end,
        );
      }
    }

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final range in merged) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: body.substring(cursor, range.start)));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onHighlightTap(widget.clause);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: body.substring(range.start, range.end),
          style: TextStyle(
            backgroundColor: color.withValues(alpha: 0.2),
            decoration: TextDecoration.underline,
            decorationColor: color.withValues(alpha: 0.5),
            decorationThickness: 2,
          ),
          recognizer: recognizer,
        ),
      );
      cursor = range.end;
    }
    if (cursor < body.length) {
      spans.add(TextSpan(text: body.substring(cursor)));
    }
    return spans;
  }

  Color? _riskColor(
    RiskLevel? risk, {
    required bool hasHighlight,
  }) {
    return hasHighlight ? ResultPalette.riskBlue : null;
  }
}

// 요약 카드(옵션 표시).
class ResultSummaryCard extends StatelessWidget {
  final bool isDark;
  final List<ResultSummarySpan> spans;
  final VoidCallback onClose;
  final VoidCallback onAction;

  const ResultSummaryCard({
    super.key,
    required this.isDark,
    required this.spans,
    required this.onClose,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : ResultPalette.textHeader;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? ResultPalette.cardDark : ResultPalette.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : ResultPalette.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ResultPalette.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 20,
                  color: ResultPalette.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AI 분석 요약',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
                color: isDark ? Colors.white54 : ResultPalette.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: isDark ? Colors.grey.shade300 : ResultPalette.textBody,
              ),
              children: [
                for (final span in spans)
                  TextSpan(
                    text: span.text,
                    style: TextStyle(
                      fontWeight: span.isBold
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: span.textColor ??
                          (isDark ? Colors.white : ResultPalette.textHeader),
                      decoration: span.underlineColor != null
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      decorationColor: span.underlineColor,
                      decorationThickness: 1.4,
                    ),
                  ),
              ],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.chevron_right, size: 18),
              label: const Text(
                '자세히 보기',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ResultPalette.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                elevation: 6,
                shadowColor: ResultPalette.primary.withValues(alpha: 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openDetail(
  BuildContext context,
  String? analysisId,
  ContractClause clause,
) async {
  if (analysisId == null) {
    debugPrint(
      '[result] detail skip analysisId=null '
      'clauseId=${clause.id?.toString() ?? 'null'}',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('상세 정보를 열 수 없습니다.')),
    );
    return;
  }

  var dialogShown = false;
  showDialog(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  dialogShown = true;

  try {
    final decoded = await _getClauseDetailWithCache(analysisId, clause);

    final clauseText = _stringFromMap(decoded['clause_text']) ?? clause.body;
    final tenantArgument =
        _stringFromMap(decoded['tenant_argument']) ?? '';
    final landlordArgument =
        _stringFromMap(decoded['landlord_argument']) ?? '';
    final compromiseQuote =
        _stringFromMap(decoded['compromise_quote']) ?? '';
    final tenantTags = _stringListFrom(decoded['tenant_tags']);
    final landlordTags = _stringListFrom(decoded['landlord_tags']);
    final negotiationPoints = _stringListFrom(decoded['negotiation_points']);

    if (!context.mounted) {
      debugPrint('[result] detail push skipped: context not mounted');
      return;
    }
    if (dialogShown) {
      Navigator.of(context, rootNavigator: true).pop();
      dialogShown = false;
    }
    debugPrint('[result] detail push start');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          clauseText: clauseText,
          tenantArgument: tenantArgument,
          landlordArgument: landlordArgument,
          tenantTags: tenantTags,
          landlordTags: landlordTags,
          negotiationPoints: negotiationPoints,
          compromiseQuote: compromiseQuote,
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) {
      debugPrint('[result] detail error after dispose: $error');
      return;
    }
    final message = _friendlyDetailErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } finally {
    if (dialogShown && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

Future<Map<String, dynamic>> _fetchClauseDetail(
  String analysisId,
  ContractClause clause,
) async {
  const maxAttempts = 3;
  const timeoutPerAttempt = Duration(seconds: 20);
  final clauseId = clause.id?.toString() ?? clause.lookupKey ?? clause.title;
  final uri = Uri.parse(
    'http://3.38.43.65:8000/analysis/$analysisId/clause/${Uri.encodeComponent(clauseId)}',
  );
  debugPrint('[result] detail request url=$uri attempts=$maxAttempts');
  Object? lastError;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      debugPrint(
        '[result] detail request attempt=$attempt '
        'timeout=${timeoutPerAttempt.inSeconds}s',
      );
      final response = await http.get(uri).timeout(timeoutPerAttempt);
      final body = utf8.decode(response.bodyBytes);
      debugPrint(
        '[result] detail response status=${response.statusCode} '
        'length=${body.length} attempt=$attempt',
      );
      if (response.statusCode != 200) {
        throw Exception('상세 API 오류: ${response.statusCode} ${body.trim()}');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('상세 API 응답 형식이 올바르지 않습니다.');
      }
      return decoded;
    } on TimeoutException catch (error) {
      lastError = error;
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
        continue;
      }
      throw Exception('상세 정보를 불러오는 중 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.');
    } on http.ClientException catch (error) {
      lastError = error;
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
        continue;
      }
      throw Exception('네트워크 연결이 불안정합니다. 연결 상태를 확인한 뒤 다시 시도해 주세요.');
    } catch (error) {
      lastError = error;
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
        continue;
      }
      rethrow;
    }
  }
  throw Exception('상세 정보를 불러오지 못했습니다: ${lastError ?? '알 수 없는 오류'}');
}

Future<Map<String, dynamic>> _getClauseDetailWithCache(
  String analysisId,
  ContractClause clause,
) async {
  final cacheKey = _detailCacheKey(analysisId, clause);
  final cached = _detailCache[cacheKey];
  if (cached != null) {
    return cached;
  }

  final inFlight = _detailInFlight[cacheKey];
  if (inFlight != null) {
    debugPrint('[result] detail join in-flight key=$cacheKey');
    return inFlight;
  }

  final future = _fetchClauseDetail(analysisId, clause);
  _detailInFlight[cacheKey] = future;
  try {
    final decoded = await future;
    _detailCache[cacheKey] = decoded;
    return decoded;
  } finally {
    _detailInFlight.remove(cacheKey);
  }
}

String _friendlyDetailErrorMessage(Object error) {
  final text = error.toString();
  if (text.contains('시간이 초과')) {
    return '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해 주세요.';
  }
  if (text.contains('네트워크 연결이 불안정')) {
    return '네트워크 상태를 확인한 뒤 다시 시도해 주세요.';
  }
  if (text.contains('상세 API 오류: 404')) {
    return '요청한 조항 상세 데이터를 찾을 수 없습니다.';
  }
  if (text.contains('상세 API 오류: 5')) {
    return '서버 오류로 상세 데이터를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }
  if (text.contains('상세 API 오류')) {
    return '상세 데이터 요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
  }
  return '상세 데이터를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

List<ResultSummarySpan> _buildClauseSummarySpans(
  Map<String, dynamic> decoded,
) {
  final tenantArgument = _sanitizeArgument(decoded['tenant_argument']);
  final landlordArgument = _sanitizeArgument(decoded['landlord_argument']);
  final compromiseQuote = _sanitizeArgument(decoded['compromise_quote']);
  final negotiationPoints = _stringListFrom(decoded['negotiation_points']);

  final parts = <String>[];
  if (tenantArgument != null) {
    parts.add(tenantArgument);
  }
  if (landlordArgument != null) {
    parts.add(landlordArgument);
  }
  if (negotiationPoints.isNotEmpty) {
    parts.add(negotiationPoints.join(' · '));
  }
  if (compromiseQuote != null) {
    parts.add(compromiseQuote);
  }

  if (parts.isEmpty) {
    return const [ResultSummarySpan('해당 조항 요약을 불러올 수 없습니다.')];
  }

  final cleaned = ResultViewModel._cleanSummaryText(parts.join(' '));
  if (cleaned == null || cleaned.isEmpty) {
    return const [ResultSummarySpan('해당 조항 요약을 불러올 수 없습니다.')];
  }
  return [ResultSummarySpan(cleaned)];
}

String? _sanitizeArgument(dynamic value) {
  final raw = _stringFromMap(value);
  if (raw == null) {
    return null;
  }
  final trimmed = raw.trim();
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
  return raw;
}

String? _extractJsonObject(String value) {
  final start = value.indexOf('{');
  final end = value.lastIndexOf('}');
  if (start == -1 || end == -1 || end <= start) {
    return null;
  }
  return value.substring(start, end + 1);
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

List<String> _stringListFrom(dynamic value) {
  if (value is List) {
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final single = _stringFromMap(value);
  if (single == null) {
    return const [];
  }
  return [single];
}

