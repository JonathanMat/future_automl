import 'dart:math';

import '../utils/constants.dart';

/// Friend codes are 6 characters, letters and digits. New codes never use
/// I, O, 0 or 1 so they are easy to read out loud.
abstract final class FriendCodeValidator {
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _pattern = RegExp(
    '^[A-Z0-9]{${AppConstants.friendCodeLength}}\$',
  );

  /// Upper case, spaces and dashes removed.
  static String normalize(String input) =>
      input.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  /// Null when valid, otherwise a message for the user.
  static String? validate(String? input) {
    final code = normalize(input ?? '');
    if (code.isEmpty) return 'Vul een vriendcode in.';
    if (code.length != AppConstants.friendCodeLength) {
      return 'Een vriendcode heeft ${AppConstants.friendCodeLength} tekens.';
    }
    if (!_pattern.hasMatch(code)) return 'Alleen letters en cijfers.';
    return null;
  }

  static String generate(Random random) => List.generate(
    AppConstants.friendCodeLength,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}
