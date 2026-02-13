import 'package:flutter/material.dart';

extension ColorWithValuesCompat on Color {
  Color withValues({
    double? alpha,
    double? red,
    double? green,
    double? blue,
  }) {
    int to8Bit(double value) => (value.clamp(0.0, 1.0) * 255).round();

    return Color.fromARGB(
      alpha == null ? this.alpha : to8Bit(alpha),
      red == null ? this.red : to8Bit(red),
      green == null ? this.green : to8Bit(green),
      blue == null ? this.blue : to8Bit(blue),
    );
  }
}
