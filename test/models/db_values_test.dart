import 'package:flutter_test/flutter_test.dart';
import 'package:spell_duel/utils/db_values.dart';
import 'package:spell_duel/utils/player_tag.dart';

void main() {
  test('tags typed as a number in the console still work', () {
    expect(PlayerTag.parse('4821'), '4821');
    expect(PlayerTag.parse(1111), '1111');
    expect(PlayerTag.parse(1234.0), '1234');
    expect(PlayerTag.parse(12345), isNull);
    expect(PlayerTag.parse('abc'), isNull);
    expect(PlayerTag.parse(null), isNull);
  });

  test('db values with an unexpected type do not crash', () {
    expect(DbValues.text('Jan'), 'Jan');
    expect(DbValues.text(''), isNull);
    expect(DbValues.text(42), '42');
    expect(DbValues.text({'a': 1}), isNull);
    expect(DbValues.integer('7'), 7);
    expect(DbValues.integer(3.0), 3);
    expect(DbValues.integer(true), 0);
  });
}
