import '../utils/constants.dart';

/// Room codes are 4 characters, letters and digits. The Firebase backend
/// never uses I, O, 0 or 1, but we accept them so a typo gets a clear
/// "room not found" instead of a confusing validation error.
abstract final class RoomCodeValidator {
  static final _pattern = RegExp('^[A-Z0-9]{${AppConstants.roomCodeLength}}\$');

  /// Upper case, spaces removed.
  static String normalize(String input) =>
      input.replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// Null when valid, otherwise a message for the user.
  static String? validate(String? input) {
    final code = normalize(input ?? '');
    if (code.isEmpty) return 'Vul een kamercode in.';
    if (code.length != AppConstants.roomCodeLength) {
      return 'Een kamercode heeft ${AppConstants.roomCodeLength} tekens.';
    }
    if (!_pattern.hasMatch(code)) return 'Alleen letters en cijfers.';
    return null;
  }

  static bool isValid(String? input) => validate(input) == null;
}
