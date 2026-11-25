/// Tournament codes are 5 characters, letters and digits (the Firebase
/// backend leaves out I, O, 0 and 1, but a typo gets "not found" rather
/// than a validation error).
abstract final class TournamentCodeValidator {
  static const length = 5;
  static final _pattern = RegExp('^[A-Z0-9]{$length}\$');

  /// Upper case, spaces removed.
  static String normalize(String input) =>
      input.replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// Null when valid, otherwise a message for the user.
  static String? validate(String? input) {
    final code = normalize(input ?? '');
    if (code.isEmpty) return 'Vul de toernooicode in.';
    if (code.length != length) return 'Een toernooicode heeft $length tekens.';
    if (!_pattern.hasMatch(code)) return 'Alleen letters en cijfers.';
    return null;
  }

  static bool isValid(String? input) => validate(input) == null;
}
