part of 'result.dart';

// Clause list UI sliced out of result.dart for readability.
class ResultClauseList extends StatelessWidget {
  final bool isDark;
  final bool isLocked;
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
    required this.isLocked,
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
              isLocked: isLocked,
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
  final bool isLocked;
  final ContractClause clause;
  final ValueChanged<ContractClause> onHighlightTap;
  final bool isSelected;
  final bool showSummary;
  final List<ResultSummarySpan> summarySpans;
  final VoidCallback onCloseSummary;
  final VoidCallback onSummaryAction;

  const _ClauseSection({
    required this.isDark,
    required this.isLocked,
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
  // TapGestureRecognizer는 수동 해제가 필요하므로 보관한다.
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
          Stack(
            children: [
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
              if (widget.isLocked)
                const Positioned(
                  right: 0,
                  top: 0,
                  child: _LockBadge(),
                ),
            ],
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
    // 겹치는 구간은 합쳐서 중복 하이라이트를 방지한다.
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

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ResultPalette.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ResultPalette.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.lock_rounded,
            size: 12,
            color: ResultPalette.primary,
          ),
          SizedBox(width: 4),
          Text(
            '로그인',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ResultPalette.primary,
            ),
          ),
        ],
      ),
    );
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
            maxLines: 4,
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
