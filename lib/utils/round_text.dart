import '../models/game_rules.dart';
import '../models/game_state.dart';
import '../models/spell_info.dart';

/// Title and subtitle for a round result, e.g. "RAAK!" / "IJS DOOFT VUUR".
({String title, String subtitle}) roundText(
  RoundResult result, {
  required String opponentName,
}) {
  final my = result.mySpell;
  final opp = result.opponentSpell;
  String beat(Spell w, Spell l) =>
      '${w.label} ${w.verbAgainst(l)} ${l.label}'.toUpperCase();

  return switch ((result.outcome, result.reason)) {
    (RoundOutcome.win, RoundReason.spellBeatsSpell) => (
      title: 'RAAK!',
      subtitle: beat(my!, opp!),
    ),
    (RoundOutcome.lose, RoundReason.spellBeatsSpell) => (
      title: 'AU!',
      subtitle: beat(opp!, my!),
    ),
    (RoundOutcome.win, RoundReason.opponentNoSpell) => (
      title: 'RAAK!',
      subtitle: '${opponentName.toUpperCase()} CASTTE NIETS',
    ),
    (RoundOutcome.lose, RoundReason.opponentNoSpell) => (
      title: 'TE LAAT!',
      subtitle: 'JIJ CASTTE NIETS',
    ),
    (_, RoundReason.sameSpell) => (
      title: 'GELIJK!',
      subtitle: 'ALLEBEI ${my?.label.toUpperCase() ?? ''}',
    ),
    (_, RoundReason.bothNoSpell) => (
      title: 'GELIJK',
      subtitle: 'NIEMAND CASTTE',
    ),
    _ => (title: 'GELIJK', subtitle: ''),
  };
}
