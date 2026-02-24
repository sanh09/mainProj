import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ActivityEntry {
  final String title;
  final String time;
  final DateTime? createdAt;
  final String statusLabel;
  final Color statusColor;
  final Color badgeColor;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final bool showPulse;
  final int? analysisId;

  const ActivityEntry({
    required this.title,
    required this.time,
    this.createdAt,
    required this.statusLabel,
    required this.statusColor,
    required this.badgeColor,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.showPulse = false,
    this.analysisId,
  });
}

/// 기록/활동 내역 데이터를 앱 전역에서 공유하는 저장소.
class HistoryRepository {
  HistoryRepository._();

  static final HistoryRepository instance = HistoryRepository._();

  final ValueNotifier<List<ActivityEntry>> entries =
      ValueNotifier<List<ActivityEntry>>([]);

  void add(ActivityEntry entry) {
    entries.value = [entry, ...entries.value];
  }

  Future<void> loadForSession({int? userId, String? email}) async {
    final trimmedEmail = email?.trim() ?? '';
    final hasEmail = trimmedEmail.isNotEmpty;
    if (userId == null && !hasEmail) {
      entries.value = const [];
      return;
    }

    final uris = <Uri>[];
    if (userId != null) {
      uris.add(Uri.parse('http://3.38.43.65:8000/history?user_id=$userId'));
      uris.add(Uri.parse('http://3.38.43.65:8000/history?userId=$userId'));
    }
    if (hasEmail) {
      final encoded = Uri.encodeQueryComponent(trimmedEmail);
      uris.add(Uri.parse('http://3.38.43.65:8000/history?email=$encoded'));
      uris.add(Uri.parse('http://3.38.43.65:8000/history?user_email=$encoded'));
    }

    Exception? lastError;
    for (final uri in uris) {
      try {
        final response = await http.get(uri);
        final body = utf8.decode(response.bodyBytes);
        if (response.statusCode != 200) {
          lastError = Exception(
            'History API error: ${response.statusCode} ${body.trim()}',
          );
          continue;
        }

        final decoded = jsonDecode(body);
        if (_looksLikeErrorPayload(decoded)) {
          lastError = Exception('History API payload indicates an error.');
          continue;
        }

        final rawList = _extractHistoryList(decoded);
        final mapped = rawList.map(_mapHistoryEntry).toList(growable: false);
        entries.value = mapped;
        return;
      } catch (error) {
        lastError = Exception(error.toString());
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    entries.value = const [];
  }

  Future<void> loadForUser(int userId) async {
    return loadForSession(userId: userId);
  }

  Future<Map<String, dynamic>> fetchAnalysisDetail(int analysisId) async {
    final uri = Uri.parse('http://3.38.43.65:8000/analysis/$analysisId');
    final response = await http.get(uri);
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw Exception('Analysis API error: ${response.statusCode} ${body.trim()}');
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Analysis API returned invalid payload.');
  }

  List<dynamic> _extractHistoryList(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }
    if (decoded is Map<String, dynamic>) {
      for (final key in [
        'data',
        'history',
        'results',
        'items',
        'analyses',
        'records',
        'rows',
      ]) {
        final value = decoded[key];
        if (value is List) {
          return value;
        }
        if (value is Map<String, dynamic>) {
          final nested = _extractHistoryList(value);
          if (nested.isNotEmpty) {
            return nested;
          }
        }
      }
    }
    return const [];
  }

  bool _looksLikeErrorPayload(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) {
      return false;
    }
    for (final key in ['detail', 'error']) {
      final value = decoded[key];
      if (value is String && value.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  ActivityEntry _mapHistoryEntry(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return const ActivityEntry(
        title: 'Unknown file',
        time: '',
        createdAt: null,
        statusLabel: 'Safe',
        statusColor: Color(0xFF15803D),
        badgeColor: Color(0xFFDCFCE7),
        icon: Icons.insert_drive_file,
        iconBg: Color(0xFFDCFCE7),
        iconColor: Color(0xFF16A34A),
        analysisId: null,
      );
    }

    final analysisId =
        _pickInt(raw, ['analysis_id', 'analysisId', 'id']);
    final filename = _pickString(raw, [
          'filename',
          'file_name',
          'original_filename',
          'original_name',
          'contract_name',
          'title',
          'document_name',
          'file',
        ]) ??
        'Unknown file';
    final riskyCount = _pickInt(raw, [
          'risky_count',
          'risk_count',
          'riskyCount',
          'riskCount',
        ]) ??
        0;
    final riskLevel =
        _pickString(raw, ['risk_level', 'riskLevel'])?.toUpperCase();
    final createdAt = _pickString(raw, [
      'created_at',
      'createdAt',
      'created',
      'timestamp',
      'created_time',
    ]);
    final createdAtDateTime = _tryParseDate(createdAt);
    final timestamp = _formatHistoryTime(createdAt);

    final statusLabel = riskyCount > 0
        ? '$riskyCount Risks Found'
        : (riskLevel ?? 'Safe');
    final isRisky = riskyCount > 0 || (riskLevel != null && riskLevel != 'SAFE');
    final statusColor =
        isRisky ? const Color(0xFFDC2626) : const Color(0xFF15803D);
    final badgeColor =
        isRisky ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
    final icon = _pickIconForFile(filename);
    final iconBg = badgeColor;
    final iconColor =
        isRisky ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    return ActivityEntry(
      title: filename,
      time: timestamp,
      createdAt: createdAtDateTime,
      statusLabel: statusLabel,
      statusColor: statusColor,
      badgeColor: badgeColor,
      icon: icon,
      iconBg: iconBg,
      iconColor: iconColor,
      showPulse: false,
      analysisId: analysisId,
    );
  }

  String? _pickString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  int? _pickInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
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

  String _formatHistoryTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) {
      return '';
    }
    final parsed = _tryParseDate(timestamp);
    if (parsed == null) {
      return timestamp;
    }
    final year = parsed.year.toString().padLeft(4, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  DateTime? _tryParseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    final direct = DateTime.tryParse(trimmed);
    if (direct != null) {
      return direct;
    }
    final normalized = trimmed.replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(normalized);
    if (parsed != null) {
      return parsed;
    }
    final withoutFraction = normalized.contains('.')
        ? normalized.split('.').first
        : normalized;
    return DateTime.tryParse(withoutFraction);
  }

  IconData _pickIconForFile(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return Icons.image;
    }
    return Icons.insert_drive_file;
  }

}

