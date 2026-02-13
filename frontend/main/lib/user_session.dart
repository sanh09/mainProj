import 'package:flutter/foundation.dart';

class UserSession {
  // In-memory session cache for the current user's email.
  static String? email;
  // In-memory session cache for the current user's id.
  static int? _userId;

  static final ValueNotifier<int?> userIdNotifier = ValueNotifier<int?>(null);

  static int? get userId => _userId;

  static set userId(int? value) {
    _userId = value;
    userIdNotifier.value = value;
  }
}
