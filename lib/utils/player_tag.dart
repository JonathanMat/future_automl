import 'dart:math';

/// A public 4-digit number after a name ("Jan #4821"), so two players with
/// the same name can be told apart. Not secret and not unique on its own:
/// it is not the friend code, so knowing it does not let anyone add you.
abstract final class PlayerTag {
  static final _pattern = RegExp(r'^[0-9]{4}$');

  /// 1000–9999.
  static String generate(Random random) => '${1000 + random.nextInt(9000)}';

  static bool isValid(Object? tag) => tag is String && _pattern.hasMatch(tag);

  /// Reads a tag from the database. Accepts a number too (e.g. typed in
  /// the Firebase console without quotes); anything else is null.
  static String? parse(Object? value) {
    final s = switch (value) {
      final String v => v,
      final num v => v.toInt().toString().padLeft(4, '0'),
      _ => null,
    };
    return isValid(s) ? s : null;
  }

  /// "#4821", or empty when there is no tag.
  static String format(String? tag) =>
      tag == null || tag.isEmpty ? '' : '#$tag';

  /// "Jan #4821", or just "Jan".
  static String withName(String name, String? tag) {
    final t = format(tag);
    return t.isEmpty ? name : '$name $t';
  }
}
