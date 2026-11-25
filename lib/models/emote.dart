/// Quick reactions players can send each other during a duel.
///
/// The art is drawn in `widgets/duel/emotes/emote_art.dart`, the sounds are
/// made by `tool/gen_sfx.py`.
enum Emote {
  hallo('Hallo'),
  haha('Haha'),
  boos('Boos'),
  huilen('Huilen'),
  gg('GG'),
  goedGespeeld('Goed gespeeld');

  const Emote(this.label);

  final String label;

  /// Name stored in the database.
  String get wire => name;

  static Emote? fromWire(Object? value) {
    for (final e in values) {
      if (e.wire == value) return e;
    }
    return null;
  }
}
