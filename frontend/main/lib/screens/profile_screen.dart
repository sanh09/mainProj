import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:main/loading.dart';

import '../welcome_screen.dart';
import 'upload_screen.dart';
import '../login_screen.dart';
import '../profile_edit_screen.dart';
import '../result.dart';
import '../signup_screen.dart';
import '../user_session.dart';
import 'history_screen.dart';
import 'security.dart';
import 'service_center.dart';
import 'system.dart';
import 'guide.dart';

class SettingsPalette {
  static const Color primary = Color(0xFFFF8A00);
  static const Color primaryDark = Color(0xFFE67900);
  static const Color backgroundLight = Color(0xFFFFF4E6);
  static const Color backgroundDark = Color(0xFF1A1612);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
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

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xCC2D2823) : const Color(0xB3FFFFFF),
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

class _ProfileAvatar extends StatelessWidget {
  final String initials;
  final bool isDark;

  const _ProfileAvatar({required this.initials, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                isDark ? const Color(0xFF374151) : const Color(0xFFFFEDD5),
                isDark ? const Color(0xFF4B5563) : const Color(0xFFFED7AA),
              ],
            ),
          ),
          child: CircleAvatar(
            backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
            child: Text(
              initials.isNotEmpty ? initials.characters.first : 'U',
              style: TextStyle(
                color: isDark ? Colors.white : SettingsPalette.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? const Color(0xFF9CA3AF) : SettingsPalette.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String? trailingLabel;
  final bool isLast;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    this.trailingLabel,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(
                  color: isDark
                      ? const Color(0x334B5563)
                      : const Color(0xFFE5E7EB),
                ),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : SettingsPalette.textDark,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingLabel != null)
              Text(
                trailingLabel!,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF9CA3AF)
                      : SettingsPalette.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x334B5563) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : SettingsPalette.textDark,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: SettingsPalette.primary,
        ),
      ),
    );
  }
}

class _SettingsLogoutTile extends StatelessWidget {
  final VoidCallback onLogout;

  const _SettingsLogoutTile({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onLogout,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Text(
            '로그아웃',
            style: TextStyle(
              color: Colors.red.shade400,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  final bool isDark;

  const _DisclaimerCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '면책 조항 (Disclaimer)',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF334155),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'CanSi는 법률 자문 서비스가 아닙니다. AI가 제공하는 검토 결과는 참고용이며 실제 계약 체결 전 반드시 법률 전문가의 확인을 거치시기 바랍니다.',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF64748B),
                    fontSize: 11.5,
                    height: 1.4,
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

class _SettingsBottomNav extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onCameraTap;

  const _SettingsBottomNav({
    required this.onHomeTap,
    required this.onHistoryTap,
    required this.onCameraTap,
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
          _BottomNavItem(
            icon: Icons.home_rounded,
            label: '홈',
            active: false,
            onTap: onHomeTap,
          ),
          _BottomNavItem(
            icon: Icons.history_rounded,
            label: '기록',
            active: false,
            onTap: onHistoryTap,
          ),
          const _BottomNavItem(
            icon: Icons.person_rounded,
            label: '마이페이지',
            active: true,
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? SettingsPalette.primary : const Color(0xFF94A3B8);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileData {
  final String name;
  final String email;

  const _ProfileData({required this.name, required this.email});
}

/// 사용자 프로필 화면.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final String? _email;
  late Future<_ProfileData?> _profileFuture;
  bool _notificationsEnabled = true;
  String _systemModeLabel = '시스템 설정';

  @override
  void initState() {
    super.initState();
    // Email is cached in memory after login/signup.
    _email = UserSession.email;
    final email = _email;
    if (email == null || email.isEmpty) {
      // No identity available; show placeholder values.
      _profileFuture = Future.value(null);
    } else {
      _profileFuture = _fetchProfile(email);
    }
  }

  Future<_ProfileData> _fetchProfile(String email) async {
    // Pull profile data using the email-based lookup endpoint.
    final uri = Uri.parse(
      'http://3.38.43.65:8000/profile?email=${Uri.encodeQueryComponent(email)}',
    );
    final response = await http.get(uri);
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      final snippet = body.trim().length > 300
          ? body.trim().substring(0, 300)
          : body.trim();
      throw Exception(
        'Profile API error: ${response.statusCode} ${snippet.isEmpty ? '(empty body)' : snippet}',
      );
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    final profile = _unwrapProfileMap(data);
    final name =
        _pickString(profile, const [
          'name',
          'username',
          'user_name',
          'full_name',
          'fullName',
          'nickname',
          'display_name',
          'displayName',
        ]) ??
        _pickString(data, const [
          'name',
          'username',
          'user_name',
          'full_name',
          'fullName',
          'nickname',
          'display_name',
          'displayName',
        ]);
    final emailValue =
        _pickString(profile, const [
          'email',
          'email_address',
          'emailAddress',
          'mail',
        ]) ??
        _pickString(data, const [
          'email',
          'email_address',
          'emailAddress',
          'mail',
        ]);
    return _ProfileData(
      name: (name == null || name.isEmpty) ? email : name,
      email: (emailValue == null || emailValue.isEmpty) ? email : emailValue,
    );
  }

  Future<void> _openSystemSettings(BuildContext context) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SystemScreen()),
    );
    if (!mounted || result == null || result.isEmpty) {
      return;
    }
    setState(() {
      _systemModeLabel = result;
    });
  }

  Map<String, dynamic> _unwrapProfileMap(Map<String, dynamic> data) {
    final nestedKeys = ['data', 'profile', 'user', 'result'];
    for (final key in nestedKeys) {
      final value = data[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
    }
    return data;
  }

  String? _pickString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (!data.containsKey(key)) {
        continue;
      }
      final value = data[key];
      if (value == null) {
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? SettingsPalette.backgroundDark
        : SettingsPalette.backgroundLight;
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
                  child: SafeArea(
                    bottom: false,
                    child: Stack(
                      children: [
                        Positioned(
                          top: -50,
                          right: -50,
                          child: _Blob(
                            size: 240,
                            color: SettingsPalette.primary.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 260,
                          left: -80,
                          child: _Blob(
                            size: 300,
                            color: const Color(
                              0xFFFFC392,
                            ).withValues(alpha: 0.35),
                          ),
                        ),
                        Positioned(
                          bottom: -40,
                          right: -100,
                          child: _Blob(
                            size: 260,
                            color: SettingsPalette.primary.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        FutureBuilder<_ProfileData?>(
                          future: _profileFuture,
                          builder: (context, snapshot) {
                            final profile = snapshot.data;
                            final displayName = profile?.name ?? 'User';
                            final displayEmail =
                                profile?.email ?? (_email ?? '');
                            return Column(
                              children: [
                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      16,
                                      20,
                                      120,
                                    ),
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '설정',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : SettingsPalette.textDark,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(width: 40, height: 40),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      _GlassCard(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                _ProfileAvatar(
                                                  initials: displayName,
                                                  isDark: isDark,
                                                ),
                                                const SizedBox(width: 12),
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      displayName,
                                                      style: TextStyle(
                                                        color: isDark
                                                            ? Colors.white
                                                            : SettingsPalette
                                                                  .textDark,
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    SizedBox(
                                                      width: 150,
                                                      child: Text(
                                                        displayEmail,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? const Color(
                                                                  0xFF9CA3AF,
                                                                )
                                                              : SettingsPalette
                                                                    .textMuted,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                final updated =
                                                    await Navigator.of(
                                                      context,
                                                    ).push<bool>(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const ProfileEditScreen(),
                                                      ),
                                                    );
                                                if (updated == true &&
                                                    mounted) {
                                                  setState(() {
                                                    final email = _email;
                                                    if (email != null &&
                                                        email.isNotEmpty) {
                                                      _profileFuture =
                                                          _fetchProfile(email);
                                                    }
                                                  });
                                                }
                                              },
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(
                                                  0xFF2563EB,
                                                ),
                                                backgroundColor: isDark
                                                    ? const Color(0xFF1E293B)
                                                    : const Color(0xFFEFF6FF),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 6,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                              ),
                                              child: const Text(
                                                '관리',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (snapshot.hasError)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            8,
                                            12,
                                            8,
                                            0,
                                          ),
                                          child: Text(
                                            '프로필을 불러오지 못했습니다: ${snapshot.error}',
                                            style: const TextStyle(
                                              color: Color(0xFFDC2626),
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 24),
                                      const _SectionHeader(label: '일반'),
                                      _GlassCard(
                                        child: Column(
                                          children: [
                                            _SettingsToggleTile(
                                              icon: Icons.notifications,
                                              iconColor:
                                                  SettingsPalette.primary,
                                              iconBg: isDark
                                                  ? const Color(0xFF3B2F1E)
                                                  : const Color(0xFFFFEDD5),
                                              label: '알림',
                                              value: _notificationsEnabled,
                                              onChanged: (value) {
                                                setState(() {
                                                  _notificationsEnabled = value;
                                                });
                                              },
                                            ),
                                            _SettingsTile(
                                              icon: Icons.dark_mode,
                                              iconColor: const Color(
                                                0xFF64748B,
                                              ),
                                              iconBg: isDark
                                                  ? const Color(0xFF1F2937)
                                                  : const Color(0xFFF1F5F9),
                                              label: '시스템 설정',
                                              trailingLabel: _systemModeLabel,
                                              isLast: true,
                                              onTap: () {
                                                _openSystemSettings(context);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      const _SectionHeader(label: '참고 자료'),
                                      _GlassCard(
                                        child: Column(
                                          children: [
                                              _SettingsTile(
                                                icon: Icons.security,
                                                iconColor: const Color.fromARGB(
                                                  255,
                                                  37,
                                                  37,
                                                  138,
                                                ),
                                                iconBg: isDark
                                                    ? const Color(0xFF312E81)
                                                    : const Color(0xFFE0E7FF),

                                                label: '계약 전 행동 가이드',
                                                isLast: true,
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const GuideScreen(),
                                                    ),
                                                  );
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      const _SectionHeader(label: '계정 및 지원'),
                                      _GlassCard(
                                        child: Column(
                                          children: [
                                              _SettingsTile(
                                                icon: Icons.support_agent,
                                                iconColor: const Color(
                                                  0xFF64748B,
                                                ),
                                                iconBg: isDark
                                                    ? const Color(0xFF1F2937)
                                                    : const Color(0xFFF1F5F9),
                                                label: '고객센터',
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const ServiceCenterScreen(),
                                                    ),
                                                  );
                                                },
                                              ),
                                              _SettingsTile(
                                                icon: Icons.policy,
                                                iconColor: const Color(
                                                  0xFF64748B,
                                                ),
                                                iconBg: isDark
                                                    ? const Color(0xFF1F2937)
                                                    : const Color(0xFFF1F5F9),
                                                label: '개인정보 처리방침',
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const SecurityScreen(),
                                                    ),
                                                  );
                                                },
                                              ),
                                            _SettingsLogoutTile(
                                              onLogout: _handleLogout,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _DisclaimerCard(isDark: isDark),
                                      const SizedBox(height: 20),
                                      const _AppVersionFooter(),
                                    ],
                                  ),
                                ),
                                _SettingsBottomNav(
                                  onHomeTap: _goHomeFromBottomNav,
                                  onHistoryTap: _goHistoryFromBottomNav,
                                  onCameraTap: _openCaptureOptionsFromBottomNav,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openCaptureOptionsFromBottomNav() {
    _showCaptureOptions(context);
  }

  void _showCaptureOptions(BuildContext context) {
    final parentContext = context;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xEE0F172A) : const Color(0xFFF8FAFC),
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
                offset: Offset(0, -4),
              ),
            ],
          ),
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
              _CaptureOptionTile(
                icon: Icons.photo_camera_rounded,
                label: '사진촬영',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickFromCamera(parentContext);
                },
              ),
              _CaptureOptionTile(
                icon: Icons.insert_drive_file_rounded,
                label: '파일 업로드',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickFromFile(parentContext);
                },
              ),
              _CaptureOptionTile(
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
      if (!context.mounted || image == null) {
        return;
      }
      await _analyzeFile(context, image.path, displayName: image.name);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카메라 열기 실패: $error')));
    }
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (!context.mounted || image == null) {
        return;
      }
      await _analyzeFile(context, image.path, displayName: image.name);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
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
      if (!context.mounted || result == null || result.files.isEmpty) {
        return;
      }
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
      if (!context.mounted) {
        return;
      }
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

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoadingScreen()));

    try {
      final uri = Uri.parse('http://3.38.43.65:8000/analyze/file');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            path,
            filename: displayName,
          ),
        );

      if (userId != null) {
        request.fields['user_id'] = userId.toString();
      }
      if (email != null && email.isNotEmpty) {
        request.fields['email'] = email;
      }
      request.fields['original_name'] = displayName;

      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        throw Exception('API 오류: ${response.statusCode} $body');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final summary = (data['summary'] ?? data['llm_summary'])
          ?.toString()
          .trim();

      if (!context.mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();

      final viewModel = ResultViewModel.fromApi(
        data,
        filename: displayName,
        fallbackSummary: summary,
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultScreen(viewModel: viewModel)),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(SnackBar(content: Text('분석 실패: $error')));
    }
  }

  void _goHistoryFromBottomNav() {
    if (UserSession.userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원 상태에서만 이동할 수 있습니다.')));
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
  }

  void _goHomeFromBottomNav() {
    if (UserSession.userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원 상태에서만 이동할 수 있습니다.')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(
          onLoginTap: (context) {
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
                              MaterialPageRoute(
                                builder: (_) => const UploadScreen(),
                              ),
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
          },
          onSignupTap: (context) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SignupScreen(
                  onSignup: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const UploadScreen()),
                    );
                  },
                  onBack: () => Navigator.of(context).pop(),
                  onLoginTap: () {
                    Navigator.of(context).pushReplacement(
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
                                      MaterialPageRoute(
                                        builder: (_) => const UploadScreen(),
                                      ),
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
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleLogout() {
    UserSession.email = null;
    UserSession.userId = null;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => WelcomeScreen(
          onLoginTap: (context) {
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
                              MaterialPageRoute(
                                builder: (_) => const UploadScreen(),
                              ),
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
          },
          onSignupTap: (context) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SignupScreen(
                  onSignup: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const UploadScreen()),
                    );
                  },
                  onBack: () => Navigator.of(context).pop(),
                  onLoginTap: () {
                    Navigator.of(context).pushReplacement(
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
                                      MaterialPageRoute(
                                        builder: (_) => const UploadScreen(),
                                      ),
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
                  },
                ),
              ),
            );
          },
        ),
      ),
      (_) => false,
    );
  }
}

class _AppVersionFooter extends StatelessWidget {
  const _AppVersionFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      child: Column(
        children: [
          Text(
            'Version 1.2.0 (Build 340)',
            style: TextStyle(
              color: SettingsPalette.textMuted.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CaptureOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final iconColor = isDark
        ? const Color(0xFFF8FAFC)
        : SettingsPalette.primary;
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
