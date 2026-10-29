import 'dart:math';

import 'package:aurora_shared/games/abstract3/abalone.dart';
import 'package:aurora_shared/games/abstract3/defs.dart';
import 'package:aurora_shared/games/abstract3/santorini.dart';
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
  test('abstract3: bots finish every variant (count: 30)', () {
    expect(runSims(abstract3Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 10)));

  group('santorini', () {
    test('placement phase and basic move + build', () {
      final e = Santorini(_setup(2))..start();
      expect(e.phase, 'place');
      e.handle(0, {'type': 'place', 'cell': 0});
      e.handle(0, {'type': 'place', 'cell': 1});
      expect(e.turn, 1);
      // Cannot place on occupied cell
      expect(() => e.handle(1, {'type': 'place', 'cell': 0}), throwsA(isA<GameError>()));
      e.handle(1, {'type': 'place', 'cell': 23});
      e.handle(1, {'type': 'place', 'cell': 24});
      expect(e.phase, 'play');
      expect(e.turn, 0);
      expect(e.step, 'move');

      // Player 0 moves worker from 0 to 5, then builds at 0
      e.handle(0, {'type': 'move', 'from': 0, 'to': 5});
      expect(e.step, 'build');
      e.handle(0, {'type': 'build', 'cell': 0});
      expect(e.heights[0], 1);
      expect(e.turn, 1);
      expect(e.step, 'move');
    });

    test('height climbing limit and level-3 win', () {
      final e = Santorini(_setup(2))..start();
      e.workers = [
        [6, 12],
        [18, 24],
      ];
      e.phase = 'play';
      e.step = 'move';
      e.heights[7] = 2;
      // Cannot climb from 0 (at 6) to 2 (at 7)
      expect(() => e.handle(0, {'type': 'move', 'from': 6, 'to': 7}), throwsA(isA<GameError>()));

      // If worker at 6 is at height 2 and cell 7 is height 3 -> moving onto 7 wins immediately!
      e.heights[6] = 2;
      e.heights[7] = 3;
      e.handle(0, {'type': 'move', 'from': 6, 'to': 7});
      expect(e.isOver, isTrue);
      expect(e.winner, 0);
      expect(e.placings, [1, 2]);
    });

    test('3-player elimination removes workers and continues until 1 remains', () {
      final e = Santorini(_setup(3))..start();
      e.workers = [
        [0, 1],
        [4, 9], // player 1 trapped by domes
        [20, 21],
      ];
      e.phase = 'play';
      e.step = 'move';
      e.turn = 0;
      // Surround player 1's workers (4 and 9) with domes at 3, 8, 13, 14
      for (final c in [3, 8, 13, 14]) {
        e.heights[c] = 4;
      }
      // Player 0 moves 0 -> 5 and builds at 0
      e.handle(0, {'type': 'move', 'from': 0, 'to': 5});
      e.handle(0, {'type': 'build', 'cell': 0});
      // Player 1 has no moves -> automatically eliminated, turn passes to Player 2!
      expect(e.eliminated[1], isTrue);
      expect(e.workers[1], isEmpty);
      expect(e.isOver, isFalse);
      expect(e.turn, 2);
    });

    test('gods: apollo swap, artemis 2-step, athena lock, atlas dome, demeter 2-build, hephaestus double, pan drop, prometheus prebuild', () {
      // Apollo + Athena
      final e = Santorini(_setup(2, {'gods': true}, 1))..start();
      e.gods = ['apollo', 'athena'];
      e.athenaSeat = 1;
      e.workers = [
        [6, 0],
        [7, 24],
      ];
      e.phase = 'play';
      e.step = 'move';
      e.turn = 0;
      // Apollo at 6 swaps with opponent at 7
      e.handle(0, {'type': 'move', 'from': 6, 'to': 7});
      expect(e.workers[0].contains(7), isTrue);
      expect(e.workers[1].contains(6), isTrue);
      e.heights[12] = 0;
      e.handle(0, {'type': 'build', 'cell': 12});

      // Now Athena (seat 1) climbs from 6 (height 0) to 12 (height 1)
      e.handle(1, {'type': 'move', 'from': 6, 'to': 12});
      expect(e.athenaLocked, isTrue);
      e.handle(1, {'type': 'build', 'cell': 11}); // height[11] = 1

      // Seat 0 cannot climb onto height 1 at 11 while athenaLocked is true
      expect(() => e.handle(0, {'type': 'move', 'from': 7, 'to': 11}), throwsA(isA<GameError>()));

      // Artemis 2-step
      e.athenaLocked = false;
      e.gods[0] = 'artemis';
      e.handle(0, {'type': 'move', 'from': 7, 'to': 9}); // 2 steps: 7 -> 8 -> 9
      e.handle(0, {'type': 'build', 'cell': 8});

      // Atlas dome at any level
      e.gods[1] = 'atlas';
      e.handle(1, {'type': 'move', 'from': 24, 'to': 23});
      e.handle(1, {'type': 'build', 'cell': 24, 'dome': true});
      expect(e.heights[24], 4);

      // Demeter build twice on different cells
      e.gods[0] = 'demeter';
      e.handle(0, {'type': 'move', 'from': 9, 'to': 14});
      e.handle(0, {'type': 'build', 'cell': 9});
      expect(e.step, 'build2');
      expect(() => e.handle(0, {'type': 'build', 'cell': 9}), throwsA(isA<GameError>()));
      e.handle(0, {'type': 'build', 'cell': 13});
      expect(e.heights[9], 1);
      expect(e.heights[13], 1);
      expect(e.turn, 1);

      // Hephaestus double build
      e.gods[1] = 'hephaestus';
      e.handle(1, {'type': 'move', 'from': 23, 'to': 18});
      e.handle(1, {'type': 'build', 'cell': 23, 'double': true});
      expect(e.heights[23], 2);

      // Prometheus prebuild -> non-climbing move -> post-build
      e.gods[0] = 'prometheus';
      e.handle(0, {'type': 'prebuild', 'from': 0, 'cell': 1});
      expect(e.heights[1], 1);
      expect(e.step, 'post_prebuild');
      // Cannot climb onto cell 1 (height 1) after prebuild
      expect(() => e.handle(0, {'type': 'move', 'from': 0, 'to': 1}), throwsA(isA<GameError>()));
      e.handle(0, {'type': 'move', 'from': 0, 'to': 5});
      e.handle(0, {'type': 'build', 'cell': 0});
      expect(e.turn, 1);

      // Pan wins by dropping 2 levels
      e.gods[1] = 'pan';
      e.heights[18] = 2;
      e.heights[17] = 0;
      e.handle(1, {'type': 'move', 'from': 18, 'to': 17});
      expect(e.isOver, isTrue);
      expect(e.winner, 1);
    });
  });

  group('abalone', () {
    test('board has 61 cells and both layouts have 14 marbles per side', () {
      expect(abaloneCells.length, 61);
      for (final layout in ['standard', 'belgian']) {
        final e = Abalone(_setup(2, {'layout': layout}))..start();
        expect(e.board.where((c) => c == 0).length, 14);
        expect(e.board.where((c) => c == 1).length, 14);
        expect(e.board.where((c) => c == -1).length, 33);
      }
    });

    test('in-line and broadside moves, sumito push, and off-board ejection win', () {
      final e = Abalone(_setup(2))..start();
      e.board.fillRange(0, 61, -1);
      // Place 3 Black marbles at (0,0), (1,0), (2,0) and 2 White marbles at (3,0), (4,0)
      e.setAt(0, 0, 0);
      e.setAt(1, 0, 0);
      e.setAt(2, 0, 0);
      e.setAt(3, 0, 1);
      e.setAt(4, 0, 1);
      // Also a White marble at (-3, 0)
      e.setAt(-3, 0, 1);

      // 2 Black marbles (1,0),(2,0) cannot push 2 White marbles (3,0),(4,0)
      expect(
        () => e.handle(0, {
          'type': 'move',
          'marbles': [
            [1, 0],
            [2, 0]
          ],
          'dir': 0,
        }),
        throwsA(isA<GameError>()),
      );

      // 3 Black marbles (0,0),(1,0),(2,0) CAN push 2 White marbles (3,0),(4,0) East (dir 0) -> ejects (4,0)!
      e.ejected[0] = 5;
      e.handle(0, {
        'type': 'move',
        'marbles': [
          [0, 0],
          [1, 0],
          [2, 0]
        ],
        'dir': 0,
      });
      expect(e.ejected[0], 6);
      expect(e.at(0, 0), -1);
      expect(e.at(1, 0), 0);
      expect(e.at(2, 0), 0);
      expect(e.at(3, 0), 0);
      expect(e.at(4, 0), 1);
      expect(e.isOver, isTrue);
      expect(e.winner, 0);
      expect(e.placings, [1, 2]);
    });

    test('broadside move cannot push opponent marbles', () {
      final e = Abalone(_setup(2))..start();
      e.board.fillRange(0, 61, -1);
      e.setAt(0, 0, 0);
      e.setAt(1, 0, 0);
      e.setAt(0, 1, 1); // Blocking SE (dir 5)
      expect(
        () => e.handle(0, {
          'type': 'move',
          'marbles': [
            [0, 0],
            [1, 0]
          ],
          'dir': 5,
        }),
        throwsA(isA<GameError>()),
      );
      // Broadside NW (dir 2) is empty -> succeeds
      e.handle(0, {
        'type': 'move',
        'marbles': [
          [0, 0],
          [1, 0]
        ],
        'dir': 2,
      });
      expect(e.at(0, -1), 0);
      expect(e.at(1, -1), 0);
    });
  });
}
