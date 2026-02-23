import 'package:flutter/material.dart';

extension ColorWithValuesCompat on Color {
  Color withValues({
    double? alpha,
    double? red,
    double? green,
    double? blue,
  }) {
    int to8Bit(double value) => (value.clamp(0.0, 1.0) * 255).round();

    int fromChannel(double channel) =>
        (channel * 255.0).round().clamp(0, 255);

    return Color.fromARGB(
      alpha == null ? fromChannel(a) : to8Bit(alpha),
      red == null ? fromChannel(r) : to8Bit(red),
      green == null ? fromChannel(g) : to8Bit(green),
      blue == null ? fromChannel(b) : to8Bit(blue),
    );
  }
}
