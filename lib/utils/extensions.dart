import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

extension DurationFormat on Duration {
  /// "0,4 s" – Dutch decimal comma, one decimal.
  String get secondsLabel {
    final s = inMilliseconds / 1000;
    return '${s.toStringAsFixed(1).replaceAll('.', ',')} s';
  }
}

extension RelativeTime on DateTime {
  /// "net nu", "10 min geleden", "3 u geleden", "2 d geleden".
  String timeAgo([DateTime? now]) {
    final diff = (now ?? DateTime.now()).difference(this);
    if (diff.inMinutes < 1) return 'net nu';
    if (diff.inHours < 1) return '${diff.inMinutes} min geleden';
    if (diff.inDays < 1) return '${diff.inHours} u geleden';
    return '${diff.inDays} d geleden';
  }
}

extension PlayerNameX on String {
  /// First letter, upper case, for avatars. "?" for an empty name.
  String get initial {
    final t = trim();
    return t.isEmpty ? '?' : t.characters.first.toUpperCase();
  }

  /// A stable avatar colour for this name.
  Color get avatarColor {
    final t = trim().toLowerCase();
    var hash = 0;
    for (final unit in t.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return AppColors.avatars[hash % AppColors.avatars.length];
  }
}

extension PercentX on double {
  /// 0.934 → "93%".
  String get percent => '${(this * 100).round()}%';
}
