import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'loading.dart';
import 'result.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'shared/color_compat.dart';
import 'user_session.dart';

class WelcomePalette {
  static const Color primary = Color(0xFFFF8C00);
  static const Color backgroundLight = Color(0xFFFFF7EB);
  static const Color backgroundDark = Color(0xFF1A1612);
  static const Color cardLight = Color(0xEFFFFFFF);
  static const Color cardDark = Color(0xCC2D2823);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF64748B);
}

class WelcomeScreen extends StatelessWidget {
  final void Function(BuildContext) onLoginTap;
  final void Function(BuildContext) onSignupTap;

  const WelcomeScreen({
    super.key,
    required this.onLoginTap,
    required this.onSignupTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? WelcomePalette.backgroundDark
        : WelcomePalette.backgroundLight;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = math.min(430.0, constraints.maxWidth);
          return Center(
            child: SizedBox(
              width: maxWidth,
              height: constraints.maxHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const _AmbientShapes(),
                      Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                24,
                                24,
                                132,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 24),
                                  Text(
                                    '계약서, 그냥 넘기기 전에\n한번 더 확인하세요',
                                    style: TextStyle(
                                      fontSize: 32,
                                      height: 1.15,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? Colors.white
                                          : WelcomePalette.textDark,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Text(
                                        '당신의 계약서 도우미 CanSi',
                                        style: TextStyle(
                                          fontSize: 18,
                                          height: 1.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? const Color(0xFFCBD5F5)
                                              : WelcomePalette.textMuted,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const _ContractHelperMiniLogo(),
                                    ],
                                  ),
                                  const SizedBox(height: 50),
                                  SizedBox(
                                    height: math.min(
                                      420,
                                      screenSize.height * 0.46,
                                    ),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          left: 0,
                                          top: 0,
                                          child: _FloatingBob(
                                            distance: 9,
                                            duration: const Duration(
                                              milliseconds: 4300,
                                            ),
                                            phase: 0.2,
                                            child: Transform.rotate(
                                              angle: -math.pi / 15,
                                              child: _GlassCard(
                                                width: 232,
                                                padding: const EdgeInsets.all(18),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .description_rounded,
                                                          size: 18,
                                                          color: WelcomePalette
                                                              .primary,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '최근 분석',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: WelcomePalette
                                                                .primary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      '부동산 계약서_2405.pdf',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: isDark
                                                            ? Colors.white
                                                            : WelcomePalette
                                                                  .textDark,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: isDark
                                                            ? const Color(
                                                                0x33FF8C00,
                                                              )
                                                            : const Color(
                                                                0xFFFFF0DB,
                                                              ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              999,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: const [
                                                          Icon(
                                                            Icons
                                                                .warning_amber_rounded,
                                                            size: 18,
                                                            color:
                                                                WelcomePalette
                                                                    .primary,
                                                          ),
                                                          SizedBox(width: 6),
                                                          Text(
                                                            '확인이 필요합니다',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              color:
                                                                  WelcomePalette
                                                                      .primary,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: -6,
                                          top: math.min(
                                            180,
                                            screenSize.height * 0.22,
                                          ),
                                          child: _FloatingBob(
                                            distance: 7,
                                            duration: const Duration(
                                              milliseconds: 3900,
                                            ),
                                            phase: 1.8,
                                            child: Transform.rotate(
                                              angle: math.pi / 60,
                                              child: _GlassCard(
                                                width: 208,
                                                padding: const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF3B82F6,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.verified_rounded,
                                                        color: Colors.white,
                                                        size: 18,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      '임대차 계약서',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: isDark
                                                            ? Colors.white
                                                            : WelcomePalette
                                                                  .textDark,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '분석 완료',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isDark
                                                            ? const Color(
                                                                0xFF94A3B8,
                                                              )
                                                            : WelcomePalette
                                                                  .textMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 16,
                                          top: math.min(
                                            200,
                                            screenSize.height * 0.26,
                                          ),
                                          child: _GlassCircle(
                                            size: 56,
                                            child: Icon(
                                              Icons.search_rounded,
                                              color: WelcomePalette.primary,
                                            ),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: Center(
                                            child: _FloatingBob(
                                              distance: 6,
                                              duration: const Duration(
                                                milliseconds: 3600,
                                              ),
                                              phase: 0.9,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  const _RotatingDashedRing(),
                                                  _CaptureButton(
                                                    onPressed: () =>
                                                        _showCaptureOptions(
                                                          context,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 10,
                                          top: math.min(
                                            320,
                                            screenSize.height * 0.36,
                                          ),
                                          child: _FloatingBob(
                                            distance: 8,
                                            duration: const Duration(
                                              milliseconds: 4700,
                                            ),
                                            phase: 2.4,
                                            child: Transform.rotate(
                                              angle: -math.pi / 60,
                                              child: _GlassCard(
                                                width: 185,
                                                padding: const EdgeInsets.all(14),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: const [
                                                        Icon(
                                                          Icons.image_rounded,
                                                          size: 16,
                                                          color: Color(
                                                            0xFF16A34A,
                                                          ),
                                                        ),
                                                        SizedBox(width: 6),
                                                        Text(
                                                          '최근 분석',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            color: Color(
                                                              0xFF16A34A,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      '계약서.jpg',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isDark
                                                            ? Colors.white
                                                            : WelcomePalette
                                                                  .textDark,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 35),
                                  Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          '카메라로 계약서를 찍으면\n3초 만에 요약해 드려요',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            height: 1.5,
                                            color: isDark
                                                ? const Color(0xFFCBD5F5)
                                                : WelcomePalette.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ValueListenableBuilder<int?>(
                                          valueListenable:
                                              UserSession.userIdNotifier,
                                          builder: (context, userId, _) {
                                            if (userId != null) {
                                              return const SizedBox.shrink();
                                            }
                                            return Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '계정이 없으신가요?',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF94A3B8,
                                                          )
                                                        : WelcomePalette
                                                              .textMuted,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                TextButton(
                                                  onPressed: () =>
                                                      onSignupTap(context),
                                                  style: TextButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                    minimumSize: const Size(
                                                      0,
                                                      0,
                                                    ),
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                    foregroundColor:
                                                        WelcomePalette.primary,
                                                  ),
                                                  child: const Text(
                                                    '회원가입',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      decoration: TextDecoration
                                                          .underline,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      _BottomNav(onLoginTap: onLoginTap),
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

void _showCaptureOptions(BuildContext context) {
  final parentContext = context;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return _GlassSurface(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        color: isDark ? const Color(0xEE0F172A) : const Color(0xFFF8FAFC),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            _OptionTile(
              icon: Icons.photo_camera_rounded,
              label: '사진촬영',
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _pickFromCamera(parentContext);
              },
            ),
            _OptionTile(
              icon: Icons.insert_drive_file_rounded,
              label: '파일 업로드',
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _pickFromFile(parentContext);
              },
            ),
            _OptionTile(
              icon: Icons.image_rounded,
              label: '이미지 업로드',
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _pickFromGallery(parentContext);
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _pickFromCamera(BuildContext context) async {
  try {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (!context.mounted) return;
    if (image == null) return;
    await _analyzeFile(context, image.path, displayName: image.name);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('카메라 열기 실패: $error')));
  }
}

Future<void> _pickFromGallery(BuildContext context) async {
  try {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (!context.mounted) return;
    if (image == null) return;
    await _analyzeFile(context, image.path, displayName: image.name);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('갤러리 열기 실패: $error')));
  }
}

Future<void> _pickFromFile(BuildContext context) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (!context.mounted) return;
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('파일 경로를 확인할 수 없습니다.')));
      return;
    }
    await _analyzeFile(context, path, displayName: file.name);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('파일 선택 실패: $error')));
  }
}

Future<void> _analyzeFile(
  BuildContext context,
  String path, {
  required String displayName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final userId = UserSession.userId;
  final email = UserSession.email;
  final extension = displayName.contains('.')
      ? displayName.split('.').last.toLowerCase()
      : 'unknown';

  AnalysisFlowTrace.start(
    source: 'welcome_upload',
    filename: displayName,
  );
  AnalysisFlowTrace.mark(
    'file_ready',
    data: {
      'pathLen': path.length,
      'ext': extension,
      'userId': userId ?? 'guest',
    },
  );

  AnalysisFlowTrace.mark('loading_push');
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const LoadingScreen()),
  );

  try {
    AnalysisFlowTrace.mark('request_prepare_start');
    final uri = Uri.parse('http://3.38.43.65:8000/analyze/file');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        await http.MultipartFile.fromPath('file', path, filename: displayName),
      );

    if (userId != null) {
      request.fields['user_id'] = userId.toString();
    }
    if (email != null && email.isNotEmpty) {
      request.fields['email'] = email;
    }
    request.fields['original_name'] = displayName;
    AnalysisFlowTrace.mark(
      'request_prepare_done',
      data: {
        'fields': request.fields.length,
      },
    );

    AnalysisFlowTrace.mark('request_send_start');
    final response = await request.send();
    AnalysisFlowTrace.mark(
      'response_headers',
      data: {
        'status': response.statusCode,
      },
    );
    final body = await response.stream.bytesToString();
    AnalysisFlowTrace.mark(
      'response_body_done',
      data: {
        'status': response.statusCode,
        'bodyLen': body.length,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('API 오류: ${response.statusCode} $body');
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final parsedClauses = (data['clauses'] is List)
        ? (data['clauses'] as List).length
        : 0;
    AnalysisFlowTrace.mark(
      'decode_done',
      data: {
        'analysisId': data['analysis_id'] ?? data['analysisId'] ?? data['id'],
        'clauses': parsedClauses,
      },
    );
    final summary = (data['summary'] ?? data['llm_summary'])?.toString().trim();

    if (!context.mounted) return;
    AnalysisFlowTrace.mark('loading_pop');
    Navigator.of(context, rootNavigator: true).pop();

    final viewModel = ResultViewModel.fromApi(
      data,
      filename: displayName,
      fallbackSummary: summary,
    );
    AnalysisFlowTrace.mark('result_route_push');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultScreen(viewModel: viewModel)),
    );
  } catch (error) {
    AnalysisFlowTrace.end(
      'analyze_failed',
      data: {
        'error': error.toString(),
      },
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(SnackBar(content: Text('분석 실패: $error')));
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final iconColor = isDark ? const Color(0xFFF8FAFC) : WelcomePalette.primary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFFFE6CC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: textColor),
      onTap: onTap,
    );
  }
}

class _AmbientShapes extends StatelessWidget {
  const _AmbientShapes();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            right: -120,
            top: -100,
            child: _Blob(
              size: 380,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFBD71).withValues(alpha: 0.2),
                  WelcomePalette.primary.withValues(alpha: 0.2),
                ],
              ),
              blur: 44,
            ),
          ),
          Positioned(
            left: -120,
            bottom: 80,
            child: _Blob(
              size: 340,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF9500).withValues(alpha: 0.16),
                  const Color(0xFFFFCC33).withValues(alpha: 0.16),
                ],
              ),
              blur: 60,
            ),
          ),
          if (!isDark)
            Positioned(
              top: -140,
              left: -40,
              child: Transform.rotate(
                angle: -math.pi / 12,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(90),
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Gradient gradient;
  final double blur;

  const _Blob({required this.size, required this.gradient, required this.blur});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(size * 0.4),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final double width;
  final EdgeInsets padding;
  final Widget child;

  const _GlassCard({
    required this.width,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white54;
    final boxShadow = isDark
        ? const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: Offset(0, 16),
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0x1AFF8C00),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ];
    return _GlassSurface(
      width: width,
      padding: padding,
      borderRadius: BorderRadius.circular(28),
      color: isDark ? WelcomePalette.cardDark : WelcomePalette.cardLight,
      border: Border.all(color: borderColor),
      boxShadow: boxShadow,
      child: child,
    );
  }
}

class _GlassCircle extends StatelessWidget {
  final double size;
  final Widget child;

  const _GlassCircle({required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _GlassSurface(
      width: size,
      height: size,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(size / 2),
      color: isDark ? const Color(0xCC334155) : const Color(0xE6FFFFFF),
      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      boxShadow: isDark
          ? const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ]
          : [
              BoxShadow(
                color: const Color(0x14FF8C00),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
      child: Center(child: child),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  final double? width;
  final double? height;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final Color color;
  final Border border;
  final List<BoxShadow> boxShadow;
  final Widget child;

  const _GlassSurface({
    required this.padding,
    required this.borderRadius,
    required this.color,
    required this.border,
    required this.boxShadow,
    required this.child,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: borderRadius,
            border: border,
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FloatingBob extends StatefulWidget {
  final Widget child;
  final double distance;
  final Duration duration;
  final double phase;

  const _FloatingBob({
    required this.child,
    this.distance = 8,
    this.duration = const Duration(milliseconds: 4200),
    this.phase = 0,
  });

  @override
  State<_FloatingBob> createState() => _FloatingBobState();
}

class _FloatingBobState extends State<_FloatingBob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
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
      child: widget.child,
      builder: (context, child) {
        final t = (_controller.value * 2 * math.pi) + widget.phase;
        final dy = math.sin(t) * widget.distance;
        return Transform.translate(
          offset: Offset(0, dy),
          child: child,
        );
      },
    );
  }
}

class _ContractHelperMiniLogo extends StatefulWidget {
  const _ContractHelperMiniLogo();

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
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final ringScale = 0.92 + (0.18 * math.sin(t * 2 * math.pi).abs());
              return Transform.scale(
                scale: ringScale,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: WelcomePalette.primary.withValues(alpha: 0.05),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0xFFFF9F2E),
                  Color(0xFFFF8A00),
                  Color(0xFFE67A00),
                ],
                center: Alignment(-0.3, -0.3),
                radius: 0.9,
              ),
            ),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 20,
                    height: 24,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 11,
                          height: 1.6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 11,
                          height: 1.6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 6,
                          height: 1.6,
                          margin: const EdgeInsets.only(left: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 5,
                    bottom: -1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F2E),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CaptureButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(120),
        child: Ink(
          width: 200,
          height: 200,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: WelcomePalette.primary,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.photo_camera_rounded, color: Colors.white, size: 62),
              SizedBox(height: 12),
              Text(
                '계약서 찍기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RotatingDashedRing extends StatefulWidget {
  const _RotatingDashedRing();

  @override
  State<_RotatingDashedRing> createState() => _RotatingDashedRingState();
}

class _RotatingDashedRingState extends State<_RotatingDashedRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: const Size(252, 252),
        painter: _DashedCirclePainter(
          color: WelcomePalette.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;

  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = color;

    const dashCount = 48;
    final segment = (2 * math.pi) / dashCount;
    final sweep = segment * 0.55;
    final radius = size.width / 2;

    for (var i = 0; i < dashCount; i++) {
      final startAngle = i * segment;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _BottomNav extends StatelessWidget {
  final void Function(BuildContext) onLoginTap;

  const _BottomNav({required this.onLoginTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const _NavItem(
                  icon: Icons.home_rounded,
                  label: '홈',
                  selected: true,
                ),
                _NavItem(
                  icon: Icons.history_rounded,
                  label: '기록',
                  onTap: () {
                    if (UserSession.userId == null) {
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
                const _NavItem(icon: Icons.smart_toy_rounded, label: 'AI 상담'),
                _NavItem(
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
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? WelcomePalette.primary
        : Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF94A3B8);
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
