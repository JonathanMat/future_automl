import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'game_rules.dart';

/// Commit-reveal so nobody can read the opponent's spell from the database
/// and counter it.
///
/// 1. At CAST each phone writes only `commitHash(spell, salt)`.
/// 2. Once both commits are in (or the cast window closed), each phone
///    writes its real spell and salt.
/// 3. The host checks that the revealed spell matches the commit.
class CommitReveal {
  CommitReveal._();

  static final Random _random = Random.secure();

  /// A random 128-bit salt as hex, so the hash of "vuur" can't be guessed.
  static String newSalt() =>
      List.generate(16, (_) => _random.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

  static String commitHash(Spell spell, String salt) =>
      sha256.convert(utf8.encode('${spell.wire}:$salt')).toString();

  static bool verify({
    required String hash,
    required Spell spell,
    required String salt,
  }) =>
      commitHash(spell, salt) == hash;
}
