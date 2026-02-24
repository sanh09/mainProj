import 'package:flutter/material.dart';

enum FontChoice {
  base,
  serif,
  sans,
  nanumGothic,
  nanumMyeongjo,
  gowunBatang,
  gowunDodum,
}

class AppSettings {
  static final ValueNotifier<double> textScale = ValueNotifier(1.0);
  static final ValueNotifier<FontChoice> fontChoice =
      ValueNotifier(FontChoice.base);
}
