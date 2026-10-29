import 'package:aurora_client/games/board_index.g.dart';
import 'package:aurora_client/games/boards.dart';
import 'package:aurora_shared/aurora_shared.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the generated deferred-board index (tool/gen_boards.dart): every
/// game in the registry must have a board, and the index must match the real
/// package maps exactly. If this fails, run `dart run tool/gen_boards.dart`.
void main() {
  setUpAll(loadAllBoardPackages);

  test('every registered game has a board package and a loaded builder', () {
    final missing = [
      for (final def in gameRegistry)
        if (!hasBoard(def.id) || loadedBoard(def.id) == null) def.id,
    ];
    expect(missing, isEmpty, reason: 'run `dart run tool/gen_boards.dart`');
  });

  test('board index matches each package map exactly', () {
    for (var i = 0; i < boardPackages.length; i++) {
      final p = boardPackages[i];
      final real = p.boards().keys.toSet();
      final indexed = {
        for (final e in boardPackageOf.entries)
          if (e.value == i) e.key,
      };
      expect(indexed, real, reason: 'package ${p.name}: run `dart run tool/gen_boards.dart`');
    }
  });
}
