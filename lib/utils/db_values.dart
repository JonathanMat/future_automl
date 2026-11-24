/// Reading values from the Realtime Database without crashing on data
/// that has an unexpected type (for example edited by hand in the console).
abstract final class DbValues {
  /// A non-empty string, a number as text, or null.
  static String? text(Object? value) => switch (value) {
    final String v when v.isNotEmpty => v,
    final num v => '$v',
    _ => null,
  };

  static int integer(Object? value) => switch (value) {
    final num v => v.toInt(),
    final String v => int.tryParse(v) ?? 0,
    _ => 0,
  };
}
