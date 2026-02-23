import 'package:flutter/material.dart';

class SecurityPalette {
  static const Color primary = Color(0xFFF19B22);
  static const Color primaryDark = Color(0xFFD1800F);
  static const Color backgroundLight = Color(0xFFF8F7F6);
  static const Color backgroundDark = Color(0xFF221B10);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF2D2418);
  static const Color textMain = Color(0xFF2D2D2D);
  static const Color textSub = Color(0xFF666666);
}

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? SecurityPalette.backgroundDark
        : SecurityPalette.backgroundLight;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '개인정보 처리방침',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : SecurityPalette.primary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'CanSi 서비스 이용을 위한\n개인정보 처리방침',
                style: TextStyle(
                  fontSize: 22,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : SecurityPalette.textMain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'CanSi는 회원의 개인정보를 중요시하며, '
                '"정보통신망 이용촉진 및 정보보호"에 관한 법률을 준수하고 있습니다.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF9CA3AF) : SecurityPalette.textSub,
                ),
              ),
              const SizedBox(height: 20),
              _PolicySection(
                index: '1',
                title: '수집하는 개인정보 항목',
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '회사는 회원가입, 상담, 서비스 신청 등등을 위해 아래와 같은 개인정보를 수집하고 있습니다.',
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    _BulletLine(
                      color: SecurityPalette.primary,
                      label: '필수 항목:',
                      text:
                          '이름, 이메일 주소, 비밀번호, 서비스 이용 기록, 접속 로그, 쿠키, 접속 IP 정보',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _BulletLine(
                      color: const Color(0xFFD1D5DB),
                      label: '선택 항목:',
                      text: '마케팅 정보 수신 동의 여부, 직업군, 계약서 유형 선호도',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PolicySection(
                index: '2',
                title: '개인정보의 수집 및 이용목적',
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '회사는 수집한 개인정보를 다음의 목적을 위해 활용합니다. '
                      '처리하고 있는 개인정보는 다음의 목적 이외의 용도로는 이용되지 않으며, '
                      '이용 목적이 변경되는 경우에는 별도의 동의를 받는 등 필요한 조치를 이행할 예정입니다.',
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    _InsetCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _PurposeLine(
                            title: '서비스 제공에 관한 계약 이행:',
                            body: '콘텐츠 제공, AI 분석 결과 제공, 구매 및 요금 결제',
                          ),
                          SizedBox(height: 6),
                          _PurposeLine(
                            title: '회원 관리:',
                            body:
                                '회원제 서비스 이용에 따른 본인확인, 개인 식별, 불량회원의 부정 이용 방지와 비인가 사용 방지',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PolicySection(
                index: '3',
                title: '개인정보의 보유 및 이용기간',
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '원칙적으로 개인정보 수집 및 이용목적이 달성된 후에는 '
                      '해당 정보를 지체 없이 파기합니다. 단, 관계법령의 규정에 의하여 '
                      '보존할 필요가 있는 경우 회사는 아래와 같이 관계법령에서 정한 '
                      '일정한 기간 동안 회원정보를 보관합니다.',
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    _RetentionRow(
                      label: '계약 또는 청약철회 등에 관한 기록',
                      value: '5년',
                      isDark: isDark,
                    ),
                    _RetentionRow(
                      label: '대금결제 및 재화 등의 공급에 관한 기록',
                      value: '5년',
                      isDark: isDark,
                    ),
                    _RetentionRow(
                      label: '소비자의 불만 또는 분쟁처리에 관한 기록',
                      value: '3년',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PolicySection(
                index: '4',
                title: '개인정보의 파기절차 및 방법',
                isDark: isDark,
                child: const Text(
                  '회사는 원칙적으로 개인정보 수집 및 이용목적이 달성된 후에는 '
                  '해당 정보를 지체 없이 파기합니다. 파기절차 및 방법은 다음과 같습니다.\n\n'
                  '전자적 파일형태로 저장된 개인정보는 기록을 재생할 수 없는 기술적 방법을 사용하여 삭제합니다. '
                  '종이에 출력된 개인정보는 분쇄기로 분쇄하거나 소각을 통하여 파기합니다.',
                  style: TextStyle(height: 1.5),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? const Color(0xFF3F3F46)
                          : const Color(0xFFE5E7EB),
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '최종 업데이트일: 2024년 5월 22일',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: SecurityPalette.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '본 방침은 2024년 5월 22일부터 시행됩니다.',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? const Color(0xFF6B7280)
                            : const Color(0xFF94A3B8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String index;
  final String title;
  final Widget child;
  final bool isDark;

  const _PolicySection({
    required this.index,
    required this.title,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        isDark ? SecurityPalette.surfaceDark : SecurityPalette.surfaceLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: SecurityPalette.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                index,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SecurityPalette.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : SecurityPalette.textMain,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: isDark ? const Color(0xFFCBD5F5) : const Color(0xFF4B5563),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  final Color color;
  final String label;
  final String text;
  final bool isDark;

  const _BulletLine({
    required this.color,
    required this.label,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : SecurityPalette.textMain,
                  ),
                ),
                TextSpan(text: ' $text'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InsetCard extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _InsetCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _PurposeLine extends StatelessWidget {
  final String title;
  final String body;

  const _PurposeLine({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: title,
            style: const TextStyle(
              color: SecurityPalette.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: ' $body'),
        ],
      ),
      style: const TextStyle(fontSize: 11.5, height: 1.5),
    );
  }
}

class _RetentionRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _RetentionRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : SecurityPalette.textMain,
            ),
          ),
        ],
      ),
    );
  }
}
