import 'dart:math';

import 'package:aurora_shared/games/abstract12/clobber.dart';
import 'package:aurora_shared/games/abstract12/defs.dart';
import 'package:aurora_shared/games/abstract12/lyngk.dart';
import 'package:aurora_shared/games/abstract12/shobu.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(
  int players, [
  Map<String, dynamic> opts = const {},
  int seed = 1,
]) =>
    GameSetup(
      players: players,
      options: opts,
      names: [for (var i = 0; i < players; i++) 'P$i'],
      bots: List.filled(players, false),
      rng: Random(seed),
    );

void main() {
  test('abstract12: bots finish every variant (30 sims)', () {
    expect(runSims(abstract12Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 10)));

  group('lyngk', () {
    test('board initialization (37 and 43 cells) with 5 active colors + 2 wildcards', () {
      final g37 = LyngkGame(_setup(2, {'size': 'standard'}))..start();
      expect(g37.stacks.length, 37);
      expect(g37.stacks.every((s) => s.length == 1), isTrue);
      final flat37 = [for (final s in g37.stacks) s.first];
      expect(flat37.where((c) => c == 5).length, 2);
      for (var c = 0; c < 5; c++) {
        expect(flat37.where((x) => x == c).length, 7);
      }

      final g43 = LyngkGame(_setup(2, {'size': 'large'}))..start();
      expect(g43.stacks.length, 43);
      expect(g43.stacks.where((s) => s.first == 5).length, 2);
    });

    test('claiming shared colors: max 2 per player, max 1 per turn', () {
      final g = LyngkGame(_setup(2))..start();
      g.handle(0, {'type': 'claim', 'color': 0});
      expect(g.ownerOfColor[0], 0);
      expect(g.claimedColors[0], [0]);
      // Cannot claim twice in the same turn
      expect(() => g.handle(0, {'type': 'claim', 'color': 1}), throwsA(isA<GameError>()));
      // Make a valid move to end turn 0
      final m0 = g.legalMovesFor(0).first;
      g.handle(0, {'type': 'move', 'from': m0.from, 'to': m0.to});

      // Seat 1 cannot claim color 0 (already claimed by seat 0)
      expect(() => g.handle(1, {'type': 'claim', 'color': 0}), throwsA(isA<GameError>()));
      // Cannot claim white wildcard 5
      expect(() => g.handle(1, {'type': 'claim', 'color': 5}), throwsA(isA<GameError>()));
      g.handle(1, {'type': 'claim', 'color': 1});
      expect(g.ownerOfColor[1], 1);
    });

    test('neutral vs claimed stack height rules, unique colors, and 5-stack removal scoring', () {
      final g = LyngkGame(_setup(2))..start();
      for (final s in g.stacks) {
        s.clear();
      }
      final i0 = g.coordToIndex[(0, 0)]!;
      final i1 = g.coordToIndex[(1, 0)]!;
      final i2 = g.coordToIndex[(2, 0)]!;
      final i3 = g.coordToIndex[(-1, 0)]!;

      // i0 has height 1 (color 0), i1 has height 2 (colors 1, 2)
      g.stacks[i0] = [0];
      g.stacks[i1] = [1, 2];
      g.stacks[i2] = [3, 4];
      g.stacks[i3] = [1]; // duplicate color 1

      // While color 0 is neutral, height 1 stack at i0 cannot land on height 2 stack at i1
      expect(g.canMove(0, i0, i1), isFalse);
      // Duplicate color check: i0 [0] and i1 [1, 2] have no duplicates, but i1 [1, 2] onto i3 [1] has duplicate 1
      expect(g.canMove(0, i1, i3), isFalse);

      // Once seat 0 claims color 0, i0 (topped by 0) CAN land on taller stack i1!
      g.handle(0, {'type': 'claim', 'color': 0});
      expect(g.canMove(0, i0, i1), isTrue);
      g.handle(0, {'type': 'move', 'from': i0, 'to': i1});
      expect(g.stacks[i1], [1, 2, 0]);
      expect(g.stacks[i0], isEmpty);

      // Seat 1 turn: cannot move i1 because top is color 0 (claimed by seat 0)
      expect(g.canMove(1, i1, i2), isFalse);
      // Seat 1 moves neutral i3 [1] onto i2 [3, 4]? No, i3 height 1 < i2 height 2.
      // Seat 1 moves i2 [3, 4] across empty i0 onto i3 [1]? Wait: i1 is at (1,0), so (2,0)->(-1,0) is blocked by i1!
      expect(g.canMove(1, i2, i3), isFalse);

      // Let's set i4 at (3, 0) with [5] (white wildcard) and keep a spare neutral piece at (0, 2)
      g.stacks[i3].clear();
      final i4 = g.coordToIndex[(3, 0)]!;
      final iSpare = g.coordToIndex[(0, 2)]!;
      final iSpare2 = g.coordToIndex[(0, 3)]!;
      g.stacks[i4] = [5];
      g.stacks[iSpare] = [3];
      g.stacks[iSpare2] = [4];
      g.handle(1, {'type': 'move', 'from': i2, 'to': i4});
      expect(g.stacks[i4], [5, 3, 4]); // height 3

      // Combined height of i1 (3) + i4 (3) would be 6 > 5 -> illegal!
      expect(g.canMove(0, i1, i4), isFalse);

      // Reduce i4 to [5, 3] (height 2, with wildcard 5 and color 3).
      g.stacks[i4] = [5, 3];
      // Now i1 [1, 2, 0] (height 3, top 0) onto i4 [5, 3] (height 2) = height 5 with colors {5, 3, 1, 2, 0}!
      expect(g.canMove(0, i1, i4), isTrue);
      g.handle(0, {'type': 'move', 'from': i1, 'to': i4});
      // Completed 5-stack topped by seat 0's claimed color 0 is immediately removed and scored!
      expect(g.stacks[i4], isEmpty);
      expect(g.scoreStacks[0], 1);
    });

    test('resign and agreeDraw', () {
      final g1 = LyngkGame(_setup(2))..start();
      g1.resign(0);
      expect(g1.isOver, isTrue);
      expect(g1.placings, [2, 1]);

      final g2 = LyngkGame(_setup(2))..start();
      g2.agreeDraw();
      expect(g2.isOver, isTrue);
      expect(g2.placings, [1, 1]);
    });
  });

  group('shobu', () {
    test('initial setup has 4 boards with 4 black and 4 white stones each', () {
      final g = ShobuGame(_setup(2))..start();
      expect(g.boards.length, 4);
      for (var b = 0; b < 4; b++) {
        expect(g.countStonesOnBoard(b, 0), 4);
        expect(g.countStonesOnBoard(b, 1), 4);
        expect(g.boards[b].sublist(0, 4), [2, 2, 2, 2]);
        expect(g.boards[b].sublist(12, 16), [1, 1, 1, 1]);
      }
    });

    test('passive move cannot push stones and aggressive move must be on opposite-shade board', () {
      final g = ShobuGame(_setup(2))..start();
      // Seat 0 (Black) tries to use board 2 as passive board (invalid, home boards are 0 and 1)
      expect(
        () => g.handle(0, {
          'type': 'move',
          'pBoard': 2,
          'pFrom': 12,
          'aBoard': 1,
          'aFrom': 12,
          'dir': 0,
          'steps': 1,
        }),
        throwsA(isA<GameError>()),
      );

      // Seat 0 tries same-shade boards (pBoard: 0 Dark, aBoard: 2 Dark) -> invalid!
      expect(
        () => g.handle(0, {
          'type': 'move',
          'pBoard': 0,
          'pFrom': 12,
          'aBoard': 2,
          'aFrom': 12,
          'dir': 0,
          'steps': 1,
        }),
        throwsA(isA<GameError>()),
      );

      // Valid synchronized move: pBoard 0 (Dark), aBoard 1 (Light), dir 0 (North), steps 2
      g.handle(0, {
        'type': 'move',
        'pBoard': 0,
        'pFrom': 12,
        'aBoard': 1,
        'aFrom': 12,
        'dir': 0,
        'steps': 2,
      });
      expect(g.boards[0][12], 0);
      expect(g.boards[0][4], 1);
      expect(g.boards[1][12], 0);
      expect(g.boards[1][4], 1);
      expect(g.turn, 1);
    });

    test('aggressive move pushes 1 enemy stone off board, blocks on 2 stones, and wins on clearing 1 board', () {
      final g = ShobuGame(_setup(2))..start();
      // Set up Board 1 (Light) with only 1 White stone at index 0 (0,0) and a Black stone at index 4 (1,0)
      g.boards[1] = List.filled(16, 0);
      g.boards[1][0] = 2; // last White stone on board 1
      g.boards[1][4] = 1; // Black stone ready to push North (dir 0, steps 1)

      // Also test that 2 stones block a push on Board 3 (Light):
      g.boards[3] = List.filled(16, 0);
      g.boards[3][0] = 2;
      g.boards[3][4] = 2;
      g.boards[3][8] = 1; // Moving 2 steps North from 8 encounters 2 stones at 4 and 0 -> illegal!
      expect(g.checkAggressiveMove(0, 0, 3, 8, 0, 2), isNull);

      // Now execute winning push on Board 1 (Light) paired with Passive move on Board 0 (Dark):
      g.handle(0, {
        'type': 'move',
        'pBoard': 0,
        'pFrom': 12,
        'aBoard': 1,
        'aFrom': 4,
        'dir': 0,
        'steps': 1,
      });
      expect(g.countStonesOnBoard(1, 1), 0);
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.placings, [1, 2]);
    });
  });

  group('clobber', () {
    test('board initialization for quick (5x6) and standard (6x6)', () {
      final gQuick = ClobberGame(_setup(2, {'size': 'quick'}))..start();
      expect(gQuick.rows, 5);
      expect(gQuick.cols, 6);
      expect(gQuick.countStones(0), 15);
      expect(gQuick.countStones(1), 15);

      final gStd = ClobberGame(_setup(2, {'size': 'standard'}))..start();
      expect(gStd.rows, 6);
      expect(gStd.cols, 6);
      expect(gStd.countStones(0), 18);
      expect(gStd.countStones(1), 18);
    });

    test('capture-only orthogonal moves and isolation win condition', () {
      final g = ClobberGame(_setup(2, {'size': 'quick'}))..start();
      // Diagonal move is illegal
      expect(
        () => g.handle(0, {'type': 'move', 'fromR': 0, 'fromC': 0, 'toR': 1, 'toC': 1}),
        throwsA(isA<GameError>()),
      );
      // Orthogonal capture (0,0) Black -> (0,1) White is legal
      g.handle(0, {'type': 'move', 'fromR': 0, 'fromC': 0, 'toR': 0, 'toC': 1});
      expect(g.board[0][0], 0);
      expect(g.board[0][1], 1);
      expect(g.turn, 1);

      // Moving to empty cell (0,0) is illegal
      expect(
        () => g.handle(1, {'type': 'move', 'fromR': 1, 'fromC': 0, 'toR': 0, 'toC': 0}),
        throwsA(isA<GameError>()),
      );

      // Set up an endgame with only 1 adjacent pair left
      for (var r = 0; r < g.rows; r++) {
        for (var c = 0; c < g.cols; c++) {
          g.board[r][c] = 0;
        }
      }
      g.board[2][2] = 2; // White
      g.board[2][3] = 1; // Black
      g.board[0][0] = 2; // Isolated White stone
      g.turn = 1;
      g.handle(1, {'type': 'move', 'fromR': 2, 'fromC': 2, 'toR': 2, 'toC': 3});
      expect(g.isOver, isTrue);
      expect(g.winner, 1);
      expect(g.placings, [2, 1]);
    });
  });
}
