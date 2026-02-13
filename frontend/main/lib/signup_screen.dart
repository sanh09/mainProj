import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'shared/color_compat.dart';
import 'user_session.dart';

/// 회원가입 화면에서 공통으로 사용하는 색상 팔레트.
class SignupPalette {
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryDark = Color(0xFFE85D2A);
  static const Color backgroundLight = Color(0xFFFFFBF7);
  static const Color backgroundDark = Color(0xFF1A1A1A);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF262626);
  static const Color inputBorder = Color(0xFFFFDCC7);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
}

/// 회원가입 화면.
class SignupScreen extends StatefulWidget {
  final VoidCallback onSignup;
  final VoidCallback onBack;
  final VoidCallback onLoginTap;

  const SignupScreen({
    super.key,
    required this.onSignup,
    required this.onBack,
    required this.onLoginTap,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

/// 회원가입 입력 상태 및 유효성 검사를 관리하는 상태 객체.
class _SignupScreenState extends State<SignupScreen> {
  bool _showPassword = false;
  int _strengthScore = 0;
  String _strengthLabel = 'Weak';
  Color _strengthColor = const Color(0xFFF87171);
  bool _isEmailValid = false;
  static const String _googleSignupUrl = 'https://accounts.google.com/';
  static const String _appleSignupUrl = 'https://appleid.apple.com/';

  // 입력 컨트롤러는 화면 생명주기에 맞춰 관리한다.
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// 회원가입 완료 콜백을 실행한다.
  Future<void> _handleSignup() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일 형식을 확인해주세요.')));
      return;
    }
    if (!_isEmailValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 항목을 입력해주세요.')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final uri = Uri.parse('http://3.38.43.65:8000/signup');
      debugPrint('[signup] POST $uri name=$name email=$email');
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );
      final body = utf8.decode(response.bodyBytes);
      debugPrint('[signup] status=${response.statusCode} body=$body');

      if (response.statusCode != 200 && response.statusCode != 201) {
        final detail = _extractErrorDetail(body);
        final message = detail ?? '회원가입에 실패했습니다. (${response.statusCode})';
        throw Exception(message);
      }

      UserSession.email = email;
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      widget.onSignup();
    } catch (error) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('회원가입 실패: $error')));
      }
    }
  }

  /// 이메일 유효성 상태를 갱신한다.
  void _updateEmail(String value) {
    // Lightweight email format check to drive UI state.
    // 간단한 정규식으로 이메일 형식을 확인한다.
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    setState(() {
      _isEmailValid = emailPattern.hasMatch(value);
    });
  }

  String? _extractErrorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          if (detail.contains('Email already exists')) {
            return '\uC774\uBBF8 \uAC00\uC785\uB41C \uC774\uBA54\uC77C\uC785\uB2C8\uB2E4.';
          }
          return detail.trim();
        }
      }
    } catch (_) {
      // Ignore JSON parse errors and fallback to a generic message.
    }
    return null;
  }

  Future<void> _openSocialSignup(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('가입 페이지를 열 수 없습니다.')));
    }
  }

  /// 비밀번호 강도 점수를 계산하고 UI를 갱신한다.
  void _updateStrength(String value) {
    // 문자 조합 조건으로 점수를 계산한다.
    final hasLower = value.contains(RegExp(r'[a-z]'));
    final hasUpper = value.contains(RegExp(r'[A-Z]'));
    final hasDigit = value.contains(RegExp(r'[0-9]'));
    final hasSymbol = value.contains(RegExp(r'[^A-Za-z0-9]'));
    int score = 0;

    if (value.length >= 8) score++;
    if (hasLower && hasUpper) score++;
    if (hasDigit) score++;
    if (hasSymbol) score++;

    String label;
    Color color;

    if (score <= 1) {
      label = '\uc57d\ud568';
      color = const Color(0xFFF87171);
    } else if (score == 2) {
      label = '\uc911\uac04';
      color = const Color(0xFFFACC15);
    } else if (score == 3) {
      label = '\uac15\ud568';
      color = const Color(0xFF22C55E);
    } else {
      label = '\ub9e4\uc6b0 \uac15\ud568';
      color = const Color(0xFF16A34A);
    }

    setState(() {
      // Keep computed strength values for the meter UI.
      _strengthScore = score;
      _strengthLabel = label;
      _strengthColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? SignupPalette.backgroundDark
        : SignupPalette.backgroundLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            const _AmbientShapes(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    _Header(onBack: widget.onBack),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _IntroSection(isDark: isDark),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                children: [
                                  _InputGroup(
                                    label: '\uc774\ub984',
                                    child: _InputField(
                                      controller: _name,
                                      hintText: '예 : 장예슬',
                                      suffixIcon: Icons.person,
                                      borderColor: SignupPalette.inputBorder,
                                      fillColor: isDark
                                          ? SignupPalette.cardDark
                                          : SignupPalette.cardLight,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _InputGroup(
                                    label: '이메일',
                                    child: _InputField(
                                      controller: _email,
                                      hintText: 'name@naver.com',
                                      keyboardType: TextInputType.emailAddress,
                                      onChanged: _updateEmail,
                                      suffixIcon: _email.text.isEmpty
                                          ? null
                                          : (_isEmailValid
                                                ? Icons.check_circle
                                                : Icons.warning_amber_rounded),
                                      suffixColor: _isEmailValid
                                          ? SignupPalette.primary
                                          : const Color(0xFFEF4444),
                                      borderColor: _email.text.isEmpty
                                          ? SignupPalette.inputBorder
                                          : SignupPalette.primary,
                                      fillColor: isDark
                                          ? SignupPalette.cardDark
                                          : SignupPalette.cardLight,
                                      showRing: _email.text.isNotEmpty,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _InputGroup(
                                    label: '\ube44\ubc00\ubc88\ud638',
                                    child: _PasswordField(
                                      controller: _password,
                                      hintText:
                                          '8\uc790 \uc774\uc0c1 \uc785\ub825',
                                      showPassword: _showPassword,
                                      onToggle: () => setState(
                                        () => _showPassword = !_showPassword,
                                      ),
                                      onChanged: _updateStrength,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _StrengthIndicator(
                                    score: _strengthScore,
                                    label: _strengthLabel,
                                    labelColor: _strengthColor,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                              child: Column(
                                children: [
                                  const _SecurityRow(),
                                  const SizedBox(height: 16),
                                  _PrimaryButton(
                                    label:
                                        '\uacc4\uc815 \uc0dd\uc131\ud558\uae30',
                                    onPressed: _handleSignup,
                                  ),
                                  const SizedBox(height: 20),
                                  const _DividerLabel(
                                    label:
                                        '\ub610\ub294 \ub2e4\uc74c\uc73c\ub85c \uac00\uc785',
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _SocialButton(
                                          label: 'Apple',
                                          icon: _AppleIcon(),
                                          onPressed: () => _openSocialSignup(
                                            _appleSignupUrl,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _SocialButton(
                                          label: 'Google',
                                          icon: _GoogleIcon(),
                                          onPressed: () => _openSocialSignup(
                                            _googleSignupUrl,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '\uc774\ubbf8 \uacc4\uc815\uc774 \uc788\uc73c\uc2e0\uac00\uc694? ',
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFF9CA3AF)
                                              : SignupPalette.textMuted,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: widget.onLoginTap,
                                        child: const Text(
                                          '로그인',
                                          style: TextStyle(
                                            color: SignupPalette.primary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상단 헤더(뒤로가기 버튼 포함).

class _AmbientShapes extends StatelessWidget {
  const _AmbientShapes();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x33FFA07A), Color(0x00FFFBF7)],
                  radius: 0.7,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x1AFF6B35), Color(0x00FFFBF7)],
                  radius: 0.7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: isDark ? Colors.white : SignupPalette.textDark,
            style: IconButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF262626)
                  : const Color(0xFFFDF0E8),
              shape: const CircleBorder(),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '\ud68c\uc6d0\uac00\uc785',
                style: TextStyle(
                  color: isDark ? Colors.white : SignupPalette.textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// 회원가입 안내 문구 영역.
class _IntroSection extends StatelessWidget {
  final bool isDark;

  const _IntroSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\uacc4\uc815 \uc0dd\uc131\ud558\uae30',
            style: TextStyle(
              color: isDark ? Colors.white : SignupPalette.textDark,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI와 함께 안전하게 계약 분석을 시작해보세요.',
            style: TextStyle(
              color: isDark ? const Color(0xFF9CA3AF) : SignupPalette.textMuted,
              fontSize: 14.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 라벨과 입력 필드를 묶어 보여주는 구성요소.
class _InputGroup extends StatelessWidget {
  final String label;
  final Widget child;

  const _InputGroup({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : SignupPalette.textDark,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// 일반 텍스트 입력 필드.
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final IconData? suffixIcon;
  final Color? suffixColor;
  final Color borderColor;
  final Color fillColor;
  final ValueChanged<String>? onChanged;
  final bool showRing;

  const _InputField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.suffixIcon,
    this.suffixColor,
    required this.borderColor,
    required this.fillColor,
    this.onChanged,
    this.showRing = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderWidth = showRing ? 1.4 : 1.0;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(
        color: isDark ? Colors.white : SignupPalette.textDark,
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark
              ? const Color(0xFF9CA3AF)
              : SignupPalette.textMuted.withValues(alpha: 0.7),
          fontSize: 13,
        ),
        filled: true,
        fillColor: fillColor,
        suffixIcon: suffixIcon == null
            ? null
            : Icon(suffixIcon, color: suffixColor ?? SignupPalette.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF374151) : borderColor,
            width: borderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: SignupPalette.primary,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

/// 비밀번호 입력 필드(표시 토글 포함).
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool showPassword;
  final VoidCallback onToggle;
  final ValueChanged<String>? onChanged;

  const _PasswordField({
    required this.controller,
    required this.hintText,
    required this.showPassword,
    required this.onToggle,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      obscureText: !showPassword,
      onChanged: onChanged,
      style: TextStyle(
        color: isDark ? Colors.white : SignupPalette.textDark,
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark
              ? const Color(0xFF9CA3AF)
              : SignupPalette.textMuted.withValues(alpha: 0.7),
          fontSize: 13,
        ),
        filled: true,
        fillColor: isDark ? SignupPalette.cardDark : SignupPalette.cardLight,
        suffixIcon: IconButton(
          icon: Icon(
            showPassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: isDark ? const Color(0xFF9CA3AF) : SignupPalette.textMuted,
          ),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF374151) : SignupPalette.inputBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: SignupPalette.primary,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

/// 비밀번호 강도 표시 바.
class _StrengthIndicator extends StatelessWidget {
  final int score;
  final String label;
  final Color labelColor;

  const _StrengthIndicator({
    required this.score,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = [
      const Color(0xFFF87171),
      const Color(0xFFFACC15),
      const Color(0xFF22C55E),
      const Color(0xFF16A34A),
    ];
    final emptyColor = isDark
        ? const Color(0xFF374151)
        : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (index) {
            final barColor = index < score ? colors[index] : emptyColor;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 3 ? 0 : 6),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            text: '비밀번호 강도: ',
            style: TextStyle(
              color: isDark ? const Color(0xFF9CA3AF) : SignupPalette.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
            children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 보안 안내 문구 라인.
class _SecurityRow extends StatelessWidget {
  const _SecurityRow();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline,
          size: 16,
          color: isDark ? const Color(0xFF9CA3AF) : SignupPalette.textMuted,
        ),
        const SizedBox(width: 6),
        Text(
          '은행 수준의 보안 암호화 적용',
          style: TextStyle(
            color: isDark ? const Color(0xFF9CA3AF) : SignupPalette.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 회원가입 기본 액션 버튼.
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [SignupPalette.primary, Color(0xFFFF9F43)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: SignupPalette.primary.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 소셜 로그인 구분선 라벨.
class _DividerLabel extends StatelessWidget {
  final String label;

  const _DividerLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            height: 1,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: isDark ? const Color(0xFF9CA3AF) : SignupPalette.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            height: 1,
          ),
        ),
      ],
    );
  }
}

/// 소셜 로그인 버튼.
class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(
          color: isDark ? const Color(0xFF374151) : SignupPalette.inputBorder,
        ),
        backgroundColor: isDark
            ? SignupPalette.cardDark
            : SignupPalette.cardLight,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : SignupPalette.textDark,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 애플 로고 아이콘.
class _AppleIcon extends StatelessWidget {
  const _AppleIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.apple, size: 18, color: Colors.black);
  }
}

/// 구글 로고 아이콘(SVG).
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(_googleLogoSvg, width: 18, height: 18);
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
