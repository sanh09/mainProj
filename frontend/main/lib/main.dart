import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'screens/upload_screen.dart';
import 'signup_screen.dart';
import 'welcome_screen.dart';

void main() => runApp(const App());

/// 앱 진입점과 테마/라우팅을 구성하는 루트 위젯.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
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
}

/// 대시보드 화면에서 공통으로 쓰는 색상 팔레트.
