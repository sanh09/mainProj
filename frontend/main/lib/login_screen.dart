import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'user_session.dart';

/// 로그인 화면에서 공통으로 사용하는 색상 팔레트.
class LoginPalette {
  static const Color primary = Color(0xFFFF8C00);
  static const Color backgroundLight = Color(0xFFFFF7EB);
  static const Color backgroundDark = Color(0xFF1A1612);
  static const Color cardLight = Color(0xB3FFFFFF);
  static const Color cardDark = Color(0xCC2D2823);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFFFD7B0);
}

/// 이메일/비밀번호 및 소셜 로그인 진입점을 제공하는 화면.
class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onSignupClick;

  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onSignupClick,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// 로그인 입력 상태와 컨트롤러를 관리하는 상태 객체.
class _LoginScreenState extends State<LoginScreen> {
  bool _showPassword = false;

  // 입력 컨트롤러는 화면 생명주기에 맞춰 생성/해제한다.
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  static const String _googleLoginUrl = 'https://accounts.google.com/';
  static const String _appleLoginUrl = 'https://appleid.apple.com/';
  static const String _loginEndpoint = 'http://3.38.43.65:8000/login';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final trimmedEmail = _email.text.trim();
    final trimmedPassword = _password.text.trim();

    if (trimmedEmail.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이메일을 입력해주세요.')),
        );
      }
      return;
    }

    if (trimmedPassword.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호를 입력해주세요.')),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final uri = Uri.parse(_loginEndpoint);
      debugPrint('[login] POST $uri email=$trimmedEmail');
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': trimmedEmail, 'password': trimmedPassword}),
      );
      final body = utf8.decode(response.bodyBytes);
      debugPrint('[login] status=${response.statusCode} body=$body');

      if (response.statusCode != 200) {
        final detail = _extractErrorDetail(body);
        final message = detail ?? '로그인에 실패했습니다. (${response.statusCode})';
        throw Exception(message);
      }

      final payload = _decodeLoginPayload(body);
      final userId = payload?['id'];
      if (userId is! int) {
        throw Exception('로그인 응답이 올바르지 않습니다.');
      }

      // Cache the email and user id locally for downstream profile lookup.
      UserSession.email = payload?['email']?.toString() ?? trimmedEmail;
      UserSession.userId = userId;
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      widget.onLogin();
    } catch (error) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인 실패: $error')));
      }
    }
  }

  String? _extractErrorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
      }
    } catch (_) {
      // Ignore JSON parse errors and fallback to a generic message.
    }
    return null;
  }

  Map<String, dynamic>? _decodeLoginPayload(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore JSON parse errors and treat as invalid payload.
    }
    return null;
  }


  Future<void> _openSocialLogin(String url) async {
    // Launch external login flow; app-side OAuth is out of scope here.
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 페이지를 열 수 없습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? LoginPalette.backgroundDark : LoginPalette.backgroundLight;
    final titleColor =
        isDark ? const Color(0xFFF8FAFC) : LoginPalette.textDark;
    final mutedColor =
        isDark ? const Color(0xFFCBD5F5) : LoginPalette.textMuted;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = math.min(430.0, constraints.maxWidth);
            return Center(
              child: SizedBox(
                width: maxWidth,
                height: constraints.maxHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      const _AmbientShapes(),
                      Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: _GlassCard(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                28,
                                20,
                                22,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const _LogoMark(),
                                  const SizedBox(height: 18),
                                  Text(
                                    'CanSi',
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      color: titleColor,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'AI를 활용한 계약서 분석.\n 계속하려면 로그인을 하세요.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: mutedColor,
                                      fontSize: 16,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  _InputGroup(
                                    label: '이메일',
                                    child: _InputField(
                                      controller: _email,
                                      hintText: 'name@gmail.com',
                                      prefixIcon: Icons.mail_outline_rounded,
                                      obscureText: false,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _InputGroup(
                                    label: '비밀번호',
                                    child: _InputField(
                                      controller: _password,
                                      hintText: '••••••••••••',
                                      prefixIcon: Icons.lock_outline_rounded,
                                      obscureText: !_showPassword,
                                      suffixIcon: _showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      onSuffixTap: () => setState(
                                        () => _showPassword = !_showPassword,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {},
                                      style: TextButton.styleFrom(
                                        foregroundColor: LoginPalette.primary,
                                      ),
                                      child: Text(
                                        '비밀번호를 잃으셨나요?',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: LoginPalette.primary,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        elevation: 8,
                                        shadowColor:
                                            LoginPalette.primary.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Text(
                                            '로그인',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 20,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward,
                                            size: 20,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const _DividerLabel(label: '소셜 계정으로 로그인'),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _SocialCircleButton(
                                        tooltip: 'Login with Google',
                                        backgroundColor: Colors.white,
                                        icon: const _GoogleIcon(),
                                        onTap: () =>
                                            _openSocialLogin(_googleLoginUrl),
                                      ),
                                      const SizedBox(width: 16),
                                      _SocialCircleButton(
                                        tooltip: 'Login with Apple',
                                        backgroundColor: Colors.black,
                                        icon: const Icon(
                                          Icons.apple,
                                          color: Colors.white,
                                        ),
                                        onTap: () =>
                                            _openSocialLogin(_appleLoginUrl),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '게정이 없으신가요?',
                                        style: TextStyle(
                                          color: mutedColor,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: widget.onSignupClick,
                                        child: const Text(
                                          '회원가입',
                                          style: TextStyle(
                                            color: LoginPalette.primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 상단 브랜드 로고 블록.
class _LogoMark extends StatefulWidget {
  const _LogoMark();

  @override
  State<_LogoMark> createState() => _LogoMarkState();
}

class _LogoMarkState extends State<_LogoMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final t = _pulseController.value;
              final scale = 0.95 + (0.12 * math.sin(t * 2 * math.pi).abs());
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LoginPalette.primary.withValues(alpha: 0.06),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 100,
            height: 100,
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
                    width: 52,
                    height: 70,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          width: 32,
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          width: 18,
                          height: 3,
                          margin: const EdgeInsets.only(left: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: -4,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F2E),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
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
                        size: 16,
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

/// 라벨과 입력 필드를 묶어 보여주는 구성요소.

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
                  LoginPalette.primary.withValues(alpha: 0.2),
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
  final EdgeInsets padding;
  final Widget child;

  const _GlassCard({required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return Padding(padding: padding, child: child);
    }
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white54;
    return _GlassSurface(
      padding: padding,
      borderRadius: BorderRadius.circular(28),
      color: isDark ? LoginPalette.cardDark : LoginPalette.cardLight,
      border: Border.all(color: borderColor),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 24,
          offset: Offset(0, 16),
        ),
      ],
      child: child,
    );
  }
}

class _GlassSurface extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
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

class _InputGroup extends StatelessWidget {
  final String label;
  final Widget child;

  const _InputGroup({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor =
        isDark ? const Color(0xFFE2E8F0) : LoginPalette.textDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.obscureText,
    this.suffixIcon,
    this.onSuffixTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFF8FAFC) : LoginPalette.textDark;
    final mutedColor =
        isDark ? const Color(0xFFCBD5F5) : LoginPalette.textMuted;
    final fillColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final borderColor = isDark ? Colors.white24 : LoginPalette.border;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
      ),
      decoration: InputDecoration(
        // 힌트 텍스트는 입력값이 없을 때만 보인다.
        hintText: hintText,
        hintStyle: TextStyle(
          color: mutedColor.withValues(alpha: 0.7),
          fontSize: 13,
        ),
        prefixIcon: Icon(prefixIcon, color: mutedColor),
        suffixIcon: suffixIcon == null
            ? null
            : IconButton(
                icon: Icon(suffixIcon, color: mutedColor),
                onPressed: onSuffixTap,
              ),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LoginPalette.primary, width: 1.2),
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  final String label;

  const _DividerLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white24 : LoginPalette.border;
    final labelColor =
        isDark ? const Color(0xFFCBD5F5) : LoginPalette.textMuted;
    return Row(
      children: [
        Expanded(child: Divider(color: dividerColor, height: 1)),
        const SizedBox(width: 10),
        Text(
          label,
          // 구분선 중앙 라벨 스타일.
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: dividerColor, height: 1)),
      ],
    );
  }
}

class _SocialCircleButton extends StatelessWidget {
  final String tooltip;
  final Color backgroundColor;
  final Widget icon;
  final VoidCallback onTap;

  const _SocialCircleButton({
    required this.tooltip,
    required this.backgroundColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          // 각 소셜 로그인에 맞는 콜백을 위에서 주입.
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 55, height: 55, child: Center(child: icon)),
        ),
      ),
    );
  }
}

/// 인라인 SVG로 그린 구글 로고 아이콘.
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _googleLogoSvg,
      width: 25,
      height: 25,
      fit: BoxFit.contain,
    );
  }
}

/// 소셜 버튼에서 사용하는 구글 로고 SVG.
const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
  <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
</svg>
''';
