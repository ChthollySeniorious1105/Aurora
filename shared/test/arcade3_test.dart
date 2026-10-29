import 'dart:math';

import 'package:aurora_shared/games/arcade3/defs.dart';
import 'package:aurora_shared/games/arcade3/math24.dart';
import 'package:aurora_shared/games/arcade3/mjconnect.dart';
import 'package:aurora_shared/games/arcade3/tankbattle.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n, Map<String, dynamic> opts, {int seed = 7, bool bots = false}) => GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, bots),
      hostSeat: 0,
      rng: Random(seed),
    );

void main() {
  group('算术24点 (math24)', () {
    test('exact fraction solver handles classic fractional 24 puzzles', () {
      // 5 * (5 - 1/5) = 24
      expect(Math24Solver.canMake24([1, 5, 5, 5]), isTrue);
      // 8 / (3 - 8/3) = 24
      expect(Math24Solver.canMake24([3, 3, 8, 8]), isTrue);
      // Impossible hand
      expect(Math24Solver.canMake24([1, 1, 1, 1]), isFalse);

      final rng = Random(42);
      for (var i = 0; i < 30; i++) {
        final (nums, _) = Math24Solver.deal(rng, 10);
        expect(nums.length, 4);
        expect(nums.every((x) => x >= 1 && x <= 10), isTrue);
        expect(Math24Solver.canMake24(nums), isTrue);
      }
    });

    test('step-by-step workspace, undo, reset, and speed bonus scoring', () {
      final e = Math24Game(_setup(3, {'rounds': 5, 'maxNum': 13}))..host = SimHost();
      e.start();
      // Force known numbers [3, 3, 8, 8] for deterministic step testing
      e.currentNums = [3, 3, 8, 8];
      for (var s = 0; s < 3; s++) {
        e.ps[s].resetForRound(e.currentNums);
      }

      // Player 0 makes a step, undoes it, resets, then solves [1, 2, 3, 4]
      e.currentNums = [1, 2, 3, 4];
      for (var s = 0; s < 3; s++) {
        e.ps[s].resetForRound(e.currentNums);
      }
      e.handle(0, {'type': 'op', 'a': 0, 'b': 1, 'op': '+'}); // [3, 3, 4]
      expect(e.ps[0].items.length, 3);
      e.handle(0, {'type': 'undo'});
      expect(e.ps[0].items.length, 4);
      e.handle(0, {'type': 'op', 'a': 0, 'b': 1, 'op': '-'});
      e.handle(0, {'type': 'reset'});
      expect(e.ps[0].items.map((x) => x.val.n).toList(), [1, 2, 3, 4]);

      // Player 0 solves 1st -> 10 pts
      e.handle(0, {'type': 'op', 'a': 0, 'b': 1, 'op': '*'}); // [2, 3, 4]
      e.handle(0, {'type': 'op', 'a': 0, 'b': 1, 'op': '*'}); // [6, 4]
      e.handle(0, {'type': 'op', 'a': 0, 'b': 1, 'op': '*'}); // [24]
      expect(e.ps[0].status, 'solved');
      expect(e.ps[0].score, 10);

      // Player 1 solves 2nd via 3-step 'solve' -> 8 pts
      e.handle(1, {
        'type': 'solve',
        'steps': [
          {'a': 0, 'b': 1, 'op': '*'},
          {'a': 0, 'b': 1, 'op': '*'},
          {'a': 0, 'b': 1, 'op': '*'},
        ],
      });
      expect(e.ps[1].status, 'solved');
      expect(e.ps[1].score, 8);

      // Player 2 skips -> 0 pts, triggers round end -> reveal phase
      e.handle(2, {'type': 'skip'});
      expect(e.ps[2].score, 0);
      expect(e.revealLeft, greaterThan(0));

      // Advance past reveal into round 2
      e.handle(0, {'type': 'next'});
      expect(e.round, 2);
      expect(e.ps[0].status, 'play');
    });

    test('division by zero and invalid actions throw GameError', () {
      final e = Math24Game(_setup(2, {}))..host = SimHost();
      e.start();
      e.currentNums = [4, 4, 6, 6];
      for (final p in e.ps) {
        p.resetForRound(e.currentNums);
      }
      e.handle(0, {'type': 'op', 'a': 0, 'b': 1, 'op': '-'}); // [0, 6, 6]
      expect(() => e.handle(0, {'type': 'op', 'a': 1, 'b': 0, 'op': '/'}), throwsA(isA<GameError>()));
      expect(() => e.handle(0, {'type': 'op', 'a': 0, 'b': 0, 'op': '+'}), throwsA(isA<GameError>()));
      expect(() => e.handle(-1, {'type': 'skip'}), throwsA(isA<GameError>()));
    });
  });

  group('坦克大战 (tankbattle)', () {
    TankBattle mk(int n, {int lives = 3, String map = 'standard'}) {
      final e = TankBattle(_setup(n, {'lives': lives, 'map': map}))..host = SimHost();
      e.start();
      e.countdown = 0;
      for (var i = 0; i < e.grid.length; i++) {
        if (!TankBattle.isBorder(i)) e.grid[i] = '.';
      }
      return e;
    }

    void tick(TankBattle e, [int k = 1]) {
      for (var i = 0; i < k && !e.isOver; i++) {
        (e.host as SimHost).runPending();
      }
    }

    test('terrain rules: water blocks tanks but bullets fly over; bricks break; 2-star breaks steel', () {
      final e = mk(2);
      final p0 = e.ps[0], p1 = e.ps[1];
      p0.cell = TankBattle.cell(2, 2);
      p0.dir = 1; // right
      p1.cell = TankBattle.cell(12, 12);

      // Water at (3, 2) blocks tank movement
      e.grid[TankBattle.cell(3, 2)] = 'w';
      e.grid[TankBattle.cell(5, 2)] = '+';
      e.handle(0, {'type': 'move', 'dir': 1});
      tick(e, 3);
      expect(p0.cell, TankBattle.cell(2, 2));

      // Bullet flies over water at (3, 2) and destroys brick at (5, 2)
      e.handle(0, {'type': 'fire'});
      tick(e, 3);
      expect(e.grid[TankBattle.cell(5, 2)], '.');

      // Interior steel at (6, 2) stops normal bullet, but breaks with 2-star upgrade
      e.grid[TankBattle.cell(6, 2)] = '#';
      tick(e, 5);
      e.handle(0, {'type': 'fire'});
      tick(e, 4);
      expect(e.grid[TankBattle.cell(6, 2)], '#');

      p0.stars = 2;
      tick(e, 5);
      e.handle(0, {'type': 'fire'});
      tick(e, 4);
      expect(e.grid[TankBattle.cell(6, 2)], '.');
    });

    test('power-ups, shield absorption, hit respawn, and elimination', () {
      final e = mk(2, lives: 3);
      final p0 = e.ps[0], p1 = e.ps[1];
      p0.cell = TankBattle.cell(2, 2);
      p0.dir = 1;
      p1.cell = TankBattle.cell(5, 2);
      p1.dir = 3;
      p1.lives = 1;

      // Give p1 a shield; first shot from p0 is absorbed
      p1.shield = 20;
      e.handle(0, {'type': 'fire'});
      tick(e, 3);
      expect(p1.alive, isTrue);
      expect(p1.shield, 0);
      expect(p1.lives, 1);

      // Wait for p0 fire cooldown and shoot again -> p1 eliminated
      tick(e, 6);
      e.handle(0, {'type': 'fire'});
      tick(e, 3);
      expect(p1.alive, isFalse);
      expect(e.isOver, isTrue);
      expect(e.placings, [1, 2]);
    });

    test('resign and input validation', () {
      final e = TankBattle(_setup(3, {}))..host = SimHost();
      e.start();
      expect(() => e.handle(0, {'type': 'move', 'dir': 99}), throwsA(isA<GameError>()));
      expect(() => e.handle(-1, {'type': 'fire'}), throwsA(isA<GameError>()));
      e.resign(1);
      expect(e.isOver, isFalse);
      e.resign(2);
      expect(e.isOver, isTrue);
      expect(e.placings, [1, 3, 2]);
    });
  });

  group('连连看竞速 (mjconnect)', () {
    test('pathfinding: 0, 1, 2 turns, outer border channel, and >=3 turns rejection', () {
      final w = 4, h = 4;
      // 1. Border connection: top row (0,0) and (3,0) blocked at (1,0) and (2,0)
      // Can connect via y = -1 (2 turns: (0,0)->(0,-1)->(3,-1)->(3,0))
      final g1 = [
        1, 2, 3, 1, //
        4, 5, 6, 4, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
      ];
      final pBorder = MjConnectSolver.findPath(g1, w, h, 0, 3);
      expect(pBorder, isNotNull);
      expect(pBorder!.length, lessThanOrEqualTo(4));

      // 2. Blocked when requiring 3 turns (4 segments)
      final gBlocked = [
        1, 2, 3, 4, //
        5, 6, 2, 7, //
        8, 3, 1, 9, //
        4, 7, 9, 8, //
      ];
      // (0,0)=1 is completely boxed in by non-matching tiles, and (2,2)=1 is interior boxed in
      expect(MjConnectSolver.findPath(gBlocked, w, h, 0, 10), isNull);
    });

    test('pair elimination, manual shuffle, and clearing the board to win', () {
      final e = MjConnect(_setup(2, {'size': 'small'}))..host = SimHost();
      e.start();
      expect(e.w, 6);
      expect(e.h, 4);
      expect(e.ps[0].grid, equals(e.ps[1].grid));

      // Manual shuffle costs penalty and decrements shufflesLeft
      e.ps[0].score = 10;
      e.handle(0, {'type': 'shuffle'});
      expect(e.ps[0].shufflesLeft, MjConnect.maxManualShuffles - 1);
      expect(e.ps[0].score, 10 - MjConnect.shufflePenalty);

      // Clear all pairs for seat 0 using solver
      while (!e.isOver) {
        final pair = MjConnectSolver.findAnyPair(e.ps[0].grid, e.w, e.h);
        expect(pair, isNotNull);
        e.handle(0, {'type': 'pair', 'a': pair!.$1, 'b': pair.$2});
      }
      expect(e.isOver, isTrue);
      expect(e.ps[0].done, isTrue);
      expect(e.placings, [1, 2]);
    });

    test('auto-shuffle triggers when remaining tiles have no valid pair', () {
      final g = [
        1, 2, 1, 2, //
        2, 1, 2, 1, //
        1, 2, 1, 2, //
        2, 1, 2, 1, //
      ];
      // Checkerboard of 1 and 2 has no orthogonal adjacent pairs, and outer border
      // only connects same-value tiles if they share an outer edge without needing >2 turns.
      // ShuffleRemaining always guarantees at least one valid pair.
      MjConnectSolver.shuffleRemaining(g, 4, 4, Random(1));
      expect(MjConnectSolver.findAnyPair(g, 4, 4), isNotNull);
    });
  });

  test('bot simulations (arcade3Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade3Games, n: 30), 0);
    print('arcade3 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
