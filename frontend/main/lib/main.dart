import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:main/screens/upload_screen.dart';
import 'package:main/welcome_screen.dart';

import 'app_settings.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

void main() => runApp(const App());

/// ??吏꾩엯?먭낵 ?뚮쭏/?쇱슦?낆쓣 援ъ꽦?섎뒗 猷⑦듃 ?꾩젽.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FontChoice>(
      valueListenable: AppSettings.fontChoice,
      builder: (context, fontChoice, _) {
        return ValueListenableBuilder<double>(
          valueListenable: AppSettings.textScale,
          builder: (context, scale, _) {
            final baseTheme = ThemeData(useMaterial3: true);
            final textTheme = switch (fontChoice) {
              FontChoice.serif =>
                GoogleFonts.notoSerifKrTextTheme(baseTheme.textTheme),
              FontChoice.sans =>
                GoogleFonts.notoSansKrTextTheme(baseTheme.textTheme),
              FontChoice.base =>
                GoogleFonts.interTextTheme(baseTheme.textTheme),
              FontChoice.nanumGothic =>
                GoogleFonts.nanumGothicTextTheme(baseTheme.textTheme),
              FontChoice.nanumMyeongjo =>
                GoogleFonts.nanumMyeongjoTextTheme(baseTheme.textTheme),
              FontChoice.gowunBatang =>
                GoogleFonts.gowunBatangTextTheme(baseTheme.textTheme),
              FontChoice.gowunDodum =>
                GoogleFonts.gowunDodumTextTheme(baseTheme.textTheme),
            };
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: baseTheme.copyWith(textTheme: textTheme),
              builder: (context, child) {
                final media = MediaQuery.of(context);
                return MediaQuery(
                  data: media.copyWith(textScaler: TextScaler.linear(scale)),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: Builder(
                // Entry flow uses the welcome screen; auth routes are pushed from it.
                builder: (context) => WelcomeScreen(
                  onLoginTap: (context) {
                    // Login keeps this screen on the stack so user can return.
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LoginScreen(
                          onLogin: () {
                            Navigator.of(context).pop();
                          },
                          onSignupClick: () {
                            // Signup sits on top of login and returns or continues.
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
                              MaterialPageRoute(
                                builder: (_) => const UploadScreen(),
                              ),
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
          },
        );
      },
    );
  }

}

/// ??쒕낫???붾㈃?먯꽌 怨듯넻?쇰줈 ?곕뒗 ?됱긽 ?붾젅??
