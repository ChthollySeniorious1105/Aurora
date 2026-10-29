import 'dart:math';

import 'package:aurora_shared/games/abstract13/defs.dart';
import 'package:aurora_shared/games/abstract13/punct.dart';
import 'package:aurora_shared/games/abstract13/surakarta.dart';
import 'package:aurora_shared/games/abstract13/yavalath.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int players, [Map<String, dynamic> opts = const {}, int seed = 1]) => GameSetup(
      players: players,
      options: opts,
      names: [for (var i = 0; i < players; i++) 'P$i'],
      bots: List.filled(players, false),
      rng: Random(seed),
    );

void main() {
  test('abstract13: bots finish every variant (count: 30)', () {
    expect(runSims(abstract13Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));

  group('punct', () {
    test('board geometry: 61 hex cells, 7 central restricted zone hexes, 18 reserve pieces per player', () {
      expect(punctBoardCells.length, 61);
      expect(punctCentralZone.length, 7);
      final g = PunctGame(_setup(2))..start();
      expect(g.totalReserve(0), 18);
      expect(g.totalReserve(1), 18);

      final gQuick = PunctGame(_setup(2, {'mode': 'quick'}))..start();
      expect(gQuick.totalReserve(0), 12);
      expect(gQuick.totalReserve(1), 12);
    });

    test('drop rejects central restricted zone and allows valid outer drops', () {
      final g = PunctGame(_setup(2))..start();
      // Central hex (0, 0) or satellite entering central hex (1, 0) must fail
      expect(
        () => g.handle(0, {'type': 'drop', 'shape': 'straight', 'rot': 0, 'q': 0, 'r': 0}),
        throwsA(isA<GameError>()),
      );
      expect(
        () => g.handle(0, {'type': 'drop', 'shape': 'straight', 'rot': 0, 'q': 2, 'r': 0}),
        throwsA(isA<GameError>()), // satellite at (1, 0) is inside central zone!
      );

      // Legal drop outside central zone: PÜNCT at (0, -3), straight along q-axis -> (-1,-3), (0,-3), (1,-3)
      g.handle(0, {'type': 'drop', 'shape': 'straight', 'rot': 0, 'q': 0, 'r': -3});
      expect(g.topColorAt(0, -3), 0);
      expect(g.topColorAt(1, -3), 0);
      expect(g.topColorAt(-1, -3), 0);
      expect(g.totalReserve(0), 17);
    });

    test('sliding into central zone and stacking with PÜNCT on own color vs enemy color', () {
      final g = PunctGame(_setup(2))..start();
      // Seat 0 drops straight at (0, -3) -> occupies (0,-3), (1,-3), (-1,-3), pieceId = 1
      g.handle(0, {'type': 'drop', 'shape': 'straight', 'rot': 0, 'q': 0, 'r': -3});
      // Seat 1 drops straight at (0, 3) -> occupies (0,3), (1,3), (-1,3), pieceId = 2
      g.handle(1, {'type': 'drop', 'shape': 'straight', 'rot': 0, 'q': 0, 'r': 3});

      // Seat 0 slides piece 1 along (0, 1) into the Central Restricted Zone at (0, 0)!
      g.handle(0, {'type': 'move', 'pieceId': 1, 'toQ': 0, 'toR': 0, 'rot': 0});
      expect(g.topColorAt(0, 0), 0);
      expect(g.topColorAt(1, 0), 0);
      expect(g.topColorAt(-1, 0), 0);
      expect(g.topColorAt(0, -3), -1);

      // Seat 1 cannot stack piece 2 onto (0, 0) because topColorAt(0, 0) is 0 (White), not 1 (Black)!
      expect(
        () => g.handle(1, {'type': 'move', 'pieceId': 2, 'toQ': 0, 'toR': 0, 'rot': 0}),
        throwsA(isA<GameError>()),
      );

      // Seat 1 drops another straight piece at (0, 2) -> occupies (0,2), (1,2), (-1,2), pieceId = 3
      g.handle(1, {'type': 'drop', 'shape': 'straight', 'rot': 0, 'q': 0, 'r': 2});
      // Seat 0 drops angled piece at (-3, 0)
      g.handle(0, {'type': 'drop', 'shape': 'angled', 'rot': 0, 'q': -3, 'r': 0});
      // Now Seat 1 stacks piece 2 from (0, 3) onto piece 3 at (0, 2) (PÜNCT lands on own color 1!)
      g.handle(1, {'type': 'move', 'pieceId': 2, 'toQ': 0, 'toR': 2, 'rot': 0});
      expect(g.stackHeight(0, 2), 2);
      expect(g.isPieceTopMost(2), isTrue);
      expect(g.isPieceTopMost(3), isFalse); // covered by piece 2!
    });

    test('connecting opposite outer sides wins immediately', () {
      final g = PunctGame(_setup(2))..start();
      // Build a bridge of White hexes from q = -4 to q = 4 except a 3-hex gap at (-1,0),(0,0),(1,0)
      g.debugPlacePiece(owner: 0, shape: 'straight', q: -3, r: 0, rot: 0); // (-4,0), (-3,0), (-2,0)
      g.debugPlacePiece(owner: 0, shape: 'straight', q: 3, r: 0, rot: 0); // (2,0), (3,0), (4,0)
      final moverId = g.debugPlacePiece(owner: 0, shape: 'straight', q: 0, r: -3, rot: 0);

      // Seat 0 slides moverId from (0, -3) to (0, 0), completing q = -4..4!
      g.handle(0, {'type': 'move', 'pieceId': moverId, 'toQ': 0, 'toR': 0, 'rot': 0});
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.winningPair, 0);
      expect(g.placings, [1, 2]);
    });
  });

  group('surakarta', () {
    test('initial board has 12 Black pebbles on rows 4..5 and 12 White pebbles on rows 0..1', () {
      final s = SurakartaGame(_setup(2))..start();
      expect(s.remainingCount(0), 12);
      expect(s.remainingCount(1), 12);
      for (var c = 0; c < 6; c++) {
        expect(s.board[0][c], 2);
        expect(s.board[1][c], 2);
        expect(s.board[4][c], 1);
        expect(s.board[5][c], 1);
      }
    });

    test('step moves 1 square to empty intersection and cannot capture', () {
      final s = SurakartaGame(_setup(2))..start();
      // Valid step from (4, 2) to (3, 2)
      s.handle(0, {'type': 'step', 'fromR': 4, 'fromC': 2, 'toR': 3, 'toC': 2});
      expect(s.board[4][2], 0);
      expect(s.board[3][2], 1);

      // Cannot step 2 squares
      expect(
        () => s.handle(1, {'type': 'step', 'fromR': 1, 'fromC': 2, 'toR': 3, 'toC': 2}),
        throwsA(isA<GameError>()),
      );

      // Move White to (2, 2), then Black cannot capture (2, 2) via step!
      s.handle(1, {'type': 'step', 'fromR': 1, 'fromC': 2, 'toR': 2, 'toC': 2});
      expect(
        () => s.handle(0, {'type': 'step', 'fromR': 3, 'fromC': 2, 'toR': 2, 'toC': 2}),
        throwsA(isA<GameError>()),
      );
    });

    test('corner loop orbit capture and rejection of direct non-loop capture', () {
      final s = SurakartaGame(_setup(2))..start();
      for (var r = 0; r < 6; r++) {
        for (var c = 0; c < 6; c++) {
          s.board[r][c] = 0;
        }
      }
      // Place Black at (2, 1) and White at (1, 3) and (5, 5)
      s.board[2][1] = 1;
      s.board[1][3] = 2;
      s.board[5][5] = 2;

      // Direct capture without corner loop is illegal (e.g., if White were on same col without loop)
      s.board[4][1] = 2;
      expect(
        () => s.handle(0, {'type': 'capture', 'fromR': 2, 'fromC': 1, 'toR': 4, 'toC': 1}),
        throwsA(isA<GameError>()),
      );

      // Legal inner-loop capture: Black at (2, 1) slides UP through (1,1), (0,1),
      // loops around TL-inner to (1,0), then slides RIGHT through (1,1) [vacated/empty], (1,2) to capture White at (1,3)!
      s.handle(0, {'type': 'capture', 'fromR': 2, 'fromC': 1, 'toR': 1, 'toC': 3});
      expect(s.board[2][1], 0);
      expect(s.board[1][3], 1);
      expect(s.captured[0], 1);
    });
  });

  group('yavalath', () {
    test('board geometry: 61 hexes in standard mode and 37 in quick mode', () {
      final y = YavalathGame(_setup(2))..start();
      expect(y.boardCells.length, 61);
      final yQuick = YavalathGame(_setup(2, {'mode': 'quick'}))..start();
      expect(yQuick.boardCells.length, 37);
    });

    test('3-in-a-row causes immediate loss (suicide)', () {
      final y = YavalathGame(_setup(2))..start();
      y.setStoneAt(0, 0, 0);
      y.setStoneAt(1, 0, 0);
      // Seat 0 places at (2, 0), forming a 3-in-a-row -> loses immediately!
      y.handle(0, {'type': 'place', 'q': 2, 'r': 0});
      expect(y.isOver, isTrue);
      expect(y.endedBySuicide, isTrue);
      expect(y.winner, 1);
      expect(y.placings, [2, 1]);
    });

    test('4-in-a-row wins immediately even if another axis simultaneously forms 3-in-a-row', () {
      final y = YavalathGame(_setup(2))..start();
      // Axis (1, 0): White at (-1, 0), (1, 0), (2, 0) -> placing at (0, 0) makes 4-in-a-row!
      y.setStoneAt(-1, 0, 0);
      y.setStoneAt(1, 0, 0);
      y.setStoneAt(2, 0, 0);
      // Axis (0, 1): White at (0, -1), (0, 1) -> placing at (0, 0) also makes 3-in-a-row on (0, 1)!
      y.setStoneAt(0, -1, 0);
      y.setStoneAt(0, 1, 0);

      y.handle(0, {'type': 'place', 'q': 0, 'r': 0});
      expect(y.isOver, isTrue);
      expect(y.endedBySuicide, isFalse);
      expect(y.winner, 0);
      expect(y.placings, [1, 2]);
    });
  });
}
