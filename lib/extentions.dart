import 'package:flutter/material.dart';

extension TimeOfDayConverter on TimeOfDay {
  /// `H:mm` (FM1): "7:30", "18:05".
  String to24hours() {
    final m = minute.toString().padLeft(2, '0');
    return '$hour:$m';
  }
}
