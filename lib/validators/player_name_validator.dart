import '../utils/constants.dart';

abstract final class PlayerNameValidator {
  static const minLength = 2;

  static String normalize(String input) =>
      input.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Null when valid, otherwise a message for the user.
  static String? validate(String? input) {
    final name = normalize(input ?? '');
    if (name.isEmpty) return 'Vul je naam in.';
    if (name.length < minLength) return 'Minstens $minLength tekens.';
    if (name.length > AppConstants.playerNameMaxLength) {
      return 'Maximaal ${AppConstants.playerNameMaxLength} tekens.';
    }
    if (RegExp(r'[<>{}\[\]\\/]').hasMatch(name)) {
      return 'Gebruik geen speciale tekens.';
    }
    return null;
  }

  static bool isValid(String? input) => validate(input) == null;
}
