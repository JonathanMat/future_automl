import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../utils/player_tag.dart';

/// "Jan #4821": the name in [style], the tag smaller and muted.
class PlayerName extends StatelessWidget {
  const PlayerName({
    super.key,
    required this.name,
    this.tag,
    required this.style,
    this.suffix = '',
    this.textAlign = TextAlign.start,
  });

  final String name;
  final String? tag;
  final TextStyle style;

  /// Extra text after the tag, e.g. " (jij)".
  final String suffix;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final t = PlayerTag.format(tag);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: name),
          if (t.isNotEmpty)
            TextSpan(
              text: ' $t',
              style: style.copyWith(
                fontSize: (style.fontSize ?? 14) * 0.8,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (suffix.isNotEmpty) TextSpan(text: suffix),
        ],
      ),
      style: style,
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
