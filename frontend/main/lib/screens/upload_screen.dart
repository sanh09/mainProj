import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'guide.dart';

import '../result.dart';
import '../shared/dashboard_palette.dart';
import '../shared/history_repository.dart';
import '../user_session.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

/// 臾몄꽌 ?낅줈??珥ъ쁺 諛?遺꾩꽍 寃곌낵瑜?蹂댁뿬二쇰뒗 ?붾㈃.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

/// ?낅줈??珥ъ쁺 ?먮쫫怨??쒕룞 紐⑸줉??愿由ы븯???곹깭 媛앹껜.
class _UploadScreenState extends State<UploadScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final userId = UserSession.userId;
    if (userId == null) {
      return;
    }
    try {
      await HistoryRepository.instance.loadForUser(userId);
    } catch (error) {
      debugPrint('[history] load failed: $error');
    }
  }

  /// ?뚯씪 ?뺤옣?먯뿉 ?곕씪 ?꾩씠肄섏쓣 ?좏깮?쒕떎.
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

  /// ?쒕룞 濡쒓렇???쒖떆???쒓컙 臾몄옄?댁쓣 留뚮뱺??
  String _formatTimestamp(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return 'Today, $hour12:$minute $suffix';
  }

  int? _pickIntField(Map<String, dynamic> data, List<String> keys) {
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


  String? _pickStringField(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _logPreview(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '<empty>';
    }
    if (trimmed.length <= 400) {
      return trimmed;
    }
    return '${trimmed.substring(0, 400)}...';
  }

  /// ?뚯씪 ?좏깮湲곕? ?닿퀬 ?좏깮???뚯씪??遺꾩꽍 API濡??꾩넚?쒕떎.
  Future<void> _handleUpload(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // ?뚯씪 ?좏깮湲곕뒗 PDF/?대?吏 ?뺤옣?먮쭔 ?덉슜?쒕떎.
    final pickerResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );

    if (pickerResult == null) {
      messenger.showSnackBar(const SnackBar(content: Text('?뚯씪 ?좏깮??痍⑥냼?섏뿀?듬땲??')));
      return;
    }

    final pickedFile = pickerResult.files.single;
    final path = pickedFile.path;
    if (path == null) {
      // 寃쎈줈瑜??뺤씤?????놁쑝硫??낅줈?쒕? 吏꾪뻾?????녿떎.
      messenger.showSnackBar(
        const SnackBar(content: Text('?뚯씪 寃쎈줈瑜??뺤씤?????놁뒿?덈떎.')),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }
    await _analyzeFile(context, path, displayName: pickedFile.name);
  }

  /// 湲곌린 移대찓?쇰줈 珥ъ쁺???대?吏瑜?遺꾩꽍 API濡??꾩넚?쒕떎.
  Future<void> _handleCameraTap(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // 移대찓???깆쓣 ?몄텧???ъ쭊??珥ъ쁺?쒕떎.
    final captured = await _imagePicker.pickImage(source: ImageSource.camera);
    if (captured == null) {
      messenger.showSnackBar(const SnackBar(content: Text('珥ъ쁺??痍⑥냼?섏뿀?듬땲??')));
      return;
    }
    if (!context.mounted) {
      return;
    }

    final displayName = captured.name.isNotEmpty ? captured.name : 'camera.jpg';
    await _analyzeFile(context, captured.path, displayName: displayName);
  }

  /// ?뚯씪 寃쎈줈瑜?諛쏆븘 遺꾩꽍 API ?몄텧怨?寃곌낵 UI 媛깆떊???섑뻾?쒕떎.
  Future<void> _analyzeFile(
    BuildContext context,
    String path, {
    required String displayName,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final userId = UserSession.userId;
    final email = UserSession.email;
    debugPrint('[upload] userId=${userId ?? 'null'} email=${email ?? 'null'}');
    if (userId == null && (email == null || email.isEmpty)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('濡쒓렇???뺣낫媛 ?놁뒿?덈떎.')),
      );
      return;
    }


    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GuideScreen(showCancelButton: true),
      ),
    );

    try {
      // 濡쒖뺄 API ?붾뱶?ъ씤?몃줈 ?뚯씪???꾩넚?쒕떎.
      final uri = Uri.parse('http://3.38.43.65:8000/analyze/file');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', path, filename: displayName));

      if (userId != null) {
        request.fields['user_id'] = userId.toString();
      }
      request.fields['original_name'] = displayName;
      if (email != null && email.isNotEmpty) {
        request.fields['email'] = email;
      }

      final response = await request.send();
      final responseBytes = await response.stream.toBytes();
      final body = utf8.decode(responseBytes, allowMalformed: true);
      debugPrint('[upload] status=${response.statusCode}');
      debugPrint('[upload] headers=${response.headers}');
      debugPrint('[upload] bytesLen=${responseBytes.length}');
      debugPrint('[upload] utf8=${_logPreview(body)}');
      debugPrint(
        '[upload] latin1=${_logPreview(latin1.decode(responseBytes, allowInvalid: true))}',
      );

      if (response.statusCode != 200) {
        // ?곹깭 肄붾뱶媛 200???꾨땲硫??ㅽ뙣濡?泥섎━?쒕떎.
        throw Exception('API ?ㅻ쪟: ${response.statusCode} $body');
      }

      // ?묐떟 JSON???뚯떛???꾪뿕 議고빆 ?섏? ?붿빟??異붿텧?쒕떎.
      final data = jsonDecode(body) as Map<String, dynamic>;
      final riskyClausesList = data['risky_clauses'] as List?;
      final riskyCount =
          _pickIntField(data, ['risky_count', 'risk_count', 'riskyCount']) ??
          (riskyClausesList?.length ?? 0);
      final analysisId =
          _pickIntField(data, ['analysis_id', 'analysisId', 'id']);
      final riskLevel =
          _pickStringField(data, ['risk_level', 'riskLevel'])?.toUpperCase();
      final summary = (data['summary'] ?? data['llm_summary'])
          ?.toString()
          .trim();

      if (!context.mounted) {
        return;
      }

      Navigator.of(context, rootNavigator: true).pop();

      // ?쒕룞 ?댁뿭 移대뱶???쒖떆???곗씠??援ъ꽦.
      final statusLabel = riskyCount > 0
          ? '$riskyCount Risks Found'
          : (riskLevel ?? 'Safe');
      final isRisky =
          riskyCount > 0 || (riskLevel != null && riskLevel != 'SAFE');

      final activity = ActivityEntry(
        title: displayName,
        time: _formatTimestamp(DateTime.now()),
        statusLabel: statusLabel,
        statusColor: isRisky
            ? const Color(0xFFDC2626)
            : const Color(0xFF15803D),
        badgeColor: isRisky
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFDCFCE7),
        icon: _pickIconForFile(displayName),
        iconBg: isRisky
            ? const Color(0xFFFEE2E2)
            : const Color(0xFFDCFCE7),
        iconColor: isRisky
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A),
        showPulse: false,
        analysisId: analysisId,
      );

      HistoryRepository.instance.add(activity);

      if (!context.mounted) {
        return;
      }

      // 遺꾩꽍 寃곌낵 ?붾㈃?쇰줈 ?꾪솚?쒕떎.
      final viewModel = ResultViewModel.fromApi(
        data,
        filename: displayName,
        fallbackSummary: summary,
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultScreen(viewModel: viewModel)),
      );
    } catch (error) {
      if (context.mounted) {
        // ?ㅽ뙣 ??濡쒕뵫???リ퀬 硫붿떆吏瑜??쒖떆?쒕떎.
        Navigator.of(context, rootNavigator: true).pop();
        messenger.showSnackBar(SnackBar(content: Text('遺꾩꽍 ?ㅽ뙣: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardPalette.backgroundLight,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              color: Colors.white,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // ?ㅽ겕濡??곸뿭 ?덉뿉???꾩껜 ?덉씠?꾩썐??援ъ꽦?쒕떎.
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _TopAppBar(),
                          const _GreetingSection(),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            child: _HeroCard(
                              onCameraTap: () => _handleCameraTap(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // ?낅줈??湲곕줉 ?≪뀡 移대뱶 2??
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _ActionCard(
                                    title: '파일 업로드',
                                    subtitle: 'PDF ?먮뒗 ?ъ쭊',
                                    icon: Icons.upload_file,
                                    onTap: () => _handleUpload(context),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ActionCard(
                                    title: '湲곕줉',
                                    subtitle: '怨쇨굅 湲곕줉 蹂닿린',
                                    icon: Icons.history,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const HistoryScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: _SectionHeader(
                              title: '理쒓렐 ?쒕룞',
                              actionLabel: '紐⑤뱺 蹂닿린',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            // ?쒕룞 ?댁뿭???놁쑝硫?鍮??곹깭瑜?蹂댁뿬以??
                            child: ValueListenableBuilder<List<ActivityEntry>>(
                              valueListenable:
                                  HistoryRepository.instance.entries,
                              builder: (context, entries, _) {
                                if (entries.isEmpty) {
                                  return const _EmptyActivityState();
                                }
                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: entries.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) =>
                                      _ActivityItem.fromEntry(entries[index]),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _TrustFooter(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ?곷떒 ??諛?
class _TopAppBar extends StatelessWidget {
  const _TopAppBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'CanSi',
              style: TextStyle(
                color: DashboardPalette.textDark,
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          IconButton(
            // 異뷀썑 怨꾩젙/?ㅼ젙?쇰줈 ?곌껐 媛??
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            icon: const Icon(Icons.account_circle),
            color: DashboardPalette.textDark,
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ?몄궗留먭낵 ?덈궡 臾멸뎄 ?뱀뀡.
class _GreetingSection extends StatelessWidget {
  const _GreetingSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '諛섍컩?듬땲??',
            style: TextStyle(
              color: DashboardPalette.textDark,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '臾몄꽌瑜?遺꾩꽍??以鍮꾧? ?섏뼱 ?덉뒿?덇퉴?',
            style: TextStyle(
              color: DashboardPalette.textMuted,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 珥ъ쁺 ?덈궡媛 ?ㅼ뼱?덈뒗 ?덉뼱濡?移대뱶.
class _HeroCard extends StatelessWidget {
  final VoidCallback onCameraTap;

  const _HeroCard({required this.onCameraTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
        ),
      ),
      child: Stack(
        children: [
          // 諛곌꼍 ?μ떇 ?꾩씠肄?
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: Align(
                alignment: Alignment.topRight,
                child: Icon(
                  Icons.network_check_rounded,
                  size: 160,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
          // ?섎떒?쇰줈 媛덉닔濡??대몢?뚯????ㅻ쾭?덉씠.
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(0, 19, 127, 236),
                  Color.fromARGB(220, 15, 23, 42),
                ],
              ),
            ),
          ),
          // ?곗륫 ?곷떒 ?ㅼ틦???꾩씠肄?諛곗?.
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(
                Icons.document_scanner,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          // ?섎떒???띿뒪?몄? 珥ъ쁺 踰꾪듉 諛곗튂.
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '珥ъ쁺?섍린',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '移대찓?쇰줈 ?낆냼 議고빆??利됱떆 媛먯??⑸땲??',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: DashboardPalette.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    // 珥ъ쁺 踰꾪듉 ?대┃ ??移대찓???ㅽ뻾.
                    onTap: onCameraTap,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.photo_camera, color: Colors.white),
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

/// 湲곕뒫 吏꾩엯??移대뱶(?뚯씪 ?낅줈??湲곕줉 ??.
class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        // 移대뱶 ?꾩껜媛 ???곸뿭.
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: DashboardPalette.borderLight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DashboardPalette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: DashboardPalette.primary, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: DashboardPalette.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: DashboardPalette.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ?뱀뀡 ?쒕ぉ怨??≪뀡 ?덉씠釉??곸뿭.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;

  const _SectionHeader({required this.title, required this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: DashboardPalette.textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          actionLabel,
          style: const TextStyle(
            color: DashboardPalette.primary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// ?쒕룞 ?댁뿭???놁쓣 ??蹂댁뿬二쇰뒗 鍮??곹깭 ?붾㈃.
class _EmptyActivityState extends StatelessWidget {
  const _EmptyActivityState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          '?꾩쭅 湲곕줉 ?놁쓬',
          style: const TextStyle(
            color: DashboardPalette.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// ?쒕룞 ?댁뿭???쒖떆???곗씠??紐⑤뜽.
class _ActivityItem extends StatelessWidget {
  final String title;
  final String time;
  final String statusLabel;
  final Color statusColor;
  final Color badgeColor;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final bool showPulse;

  const _ActivityItem({
    required this.title,
    required this.time,
    required this.statusLabel,
    required this.statusColor,
    required this.badgeColor,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    this.showPulse = false,
  });

  factory _ActivityItem.fromEntry(ActivityEntry entry) {
    return _ActivityItem(
      title: entry.title,
      time: entry.time,
      statusLabel: entry.statusLabel,
      statusColor: entry.statusColor,
      badgeColor: entry.badgeColor,
      icon: entry.icon,
      iconBg: entry.iconBg,
      iconColor: entry.iconColor,
      showPulse: entry.showPulse,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F2F4)),
      ),
      child: Row(
        children: [
          // ?뚯씪 ?좏삎 ?꾩씠肄?
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          // ?쒕ぉ怨??쒓컙 ?뺣낫.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DashboardPalette.textDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: DashboardPalette.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // ?꾪뿕 ?щ? 諛곗?.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                if (showPulse)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: SizedBox(
                      width: 6,
                      height: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: DashboardPalette.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

/// ?섎떒 蹂댁븞 ?덈궡 ?뗮꽣.
class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.lock, size: 14, color: DashboardPalette.textMuted),
          SizedBox(width: 6),
          Text(
            'End-to-end Encrypted',
            style: TextStyle(
              color: DashboardPalette.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
