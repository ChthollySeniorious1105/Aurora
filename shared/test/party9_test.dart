import 'dart:math';

import 'package:aurora_shared/games/party9/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

void main() {
  group('party9 unit tests', () {
    test('celestia: bail, navigate with wildcards, jetpack on crash, eject, and targetScore win', () {
      final setup = GameSetup(
        players: 3,
        options: {'target': 35},
        names: const ['A', 'B', 'C'],
        bots: const [false, false, false],
        rng: Random(42),
      );
      final g = CelestiaGame(setup)..start();

      expect(g.cityIndex, 0);
      expect(g.captain, 0);
      expect(g.aboard, [0, 1, 2]);
      expect(g.phase, 'passengers');
      expect(g.waitingFor, [1]);

      // Give player 1 an eject card and eject player 2 at city 0 (worth 1 pt)
      g.hands[1].add('eject');
      g.handle(1, {'type': 'eject', 'target': 2});
      expect(g.scores[2], 1);
      expect(g.aboard, [0, 1]);
      expect(g.waitingFor, [1]);

      // Player 1 stays
      g.handle(1, {'type': 'stay'});
      expect(g.phase, 'captain');
      expect(g.waitingFor, [0]);

      // Set hazards to [0, 1] and give captain (0) one 0 and one wildcard (4)
      g.hazards = [0, 1];
      g.hands[0] = [0, 4];
      g.handle(0, {'type': 'navigate', 'useWild': 1});
      expect(g.cityIndex, 1);
      expect(g.captain, 1); // rotated to next player aboard

      // Now at city 1 (worth 2 pts), player 0 is passenger, player 1 is captain
      expect(g.phase, 'passengers');
      expect(g.waitingFor, [0]);
      // Give player 1 a jetpack, player 0 stays, then captain 1 crashes!
      g.hands[1] = ['jetpack'];
      g.handle(0, {'type': 'stay'});
      expect(g.phase, 'captain');
      g.handle(1, {'type': 'crash'});
      // Player 1 got jetpack points (2 pts), player 0 got 0 pts, new voyage started at city 0!
      expect(g.scores[1], 2);
      expect(g.scores[0], 0);
      expect(g.cityIndex, 0);
      expect(g.voyage, 2);

      // Test reaching targetScore ends game at start of next voyage
      g.scores[0] = 35;
      // Everyone bails / crashes to trigger next voyage
      while (g.phase == 'passengers') {
        g.handle(g.waitingFor.first, {'type': 'bail'});
      }
      g.handle(g.captain, {'type': 'crash'});
      expect(g.isOver, isTrue);
      expect(g.placings![0], 1);
    });

    test('welcometo: strict ascending order, 5 effects, completed estates, and 3 refusals end game', () {
      final setup = GameSetup(
        players: 2,
        options: {'rounds': 14},
        names: const ['A', 'B'],
        bots: const [false, false],
        rng: Random(99),
      );
      final g = WelcomeToGame(setup)..start();

      // Force specific combos for deterministic testing
      g.combos = [
        {'number': 5, 'effect': 0}, // fence
        {'number': 8, 'effect': 3}, // pool
        {'number': 10, 'effect': 4}, // temp ±2
      ];

      // Player 0 builds number 5 at street 0, slot 0, and builds fence at slot 1
      g.handle(0, {'type': 'build', 'combo': 0, 'street': 0, 'slot': 0, 'fence': 1});
      expect(g.houses[0][0][0], 5);
      expect(g.fences[0][0][1], isTrue);

      // Player 1 uses temp (combo 2, number 10, delta -2 -> 8) at street 0, slot 2 (which has pool plan)
      g.handle(1, {'type': 'build', 'combo': 2, 'street': 0, 'slot': 2, 'delta': -2});
      expect(g.houses[1][0][2], 8);
      expect(g.tempsUsed[1], 1);

      // Round 2 started
      expect(g.round, 2);
      g.combos = [
        {'number': 6, 'effect': 2}, // park
        {'number': 4, 'effect': 1}, // estate upgrade
        {'number': 12, 'effect': 3}, // pool
      ];

      // Illegal move for player 0: writing 4 to the right of 5 on street 0 must fail
      expect(
        () => g.handle(0, {'type': 'build', 'combo': 1, 'street': 0, 'slot': 1}),
        throwsA(isA<GameError>()),
      );

      // Valid move for player 0: writing 6 at street 0, slot 1 completes a size-2 estate [0..1]!
      g.handle(0, {'type': 'build', 'combo': 0, 'street': 0, 'slot': 1});
      expect(g.completedEstateSizes(0), contains(2));
      expect(g.parks[0][0], 1);

      // Player 1 refuses 3 times across rounds to end the game
      g.handle(1, {'type': 'refuse'});
      expect(g.refusals[1], 1);

      g.handle(0, {'type': 'refuse'});
      g.handle(1, {'type': 'refuse'});
      expect(g.refusals[1], 2);

      g.handle(0, {'type': 'refuse'});
      g.handle(1, {'type': 'refuse'});
      expect(g.refusals[1], 3);
      expect(g.isOver, isTrue);
      expect(g.placings, isNotNull);
    });

    test('cryptid: unique intersection, essential clues, question, penalty cube, and search win', () {
      for (final p in [3, 4, 5]) {
        final setup = GameSetup(
          players: p,
          options: const {},
          names: [for (var i = 0; i < p; i++) 'P$i'],
          bots: List.filled(p, false),
          rng: Random(100 + p),
        );
        final g = CryptidGame(setup)..start();

        expect(g.cluePool.length, greaterThanOrEqualTo(24));
        expect(g.playerClues.length, p);

        // Verify intersection of all players' clues is exactly {targetHex}
        var inter = Set<int>.of(g.playerClues[0].matchingHexes);
        for (var i = 1; i < p; i++) {
          inter = inter.intersection(g.playerClues[i].matchingHexes);
        }
        expect(inter.length, 1);
        expect(inter.first, g.targetHex);

        // Verify removing any single player's clue leaves size >= 2
        for (var skip = 0; skip < p; skip++) {
          var sub = <int>{for (var h = 0; h < 54; h++) h};
          for (var i = 0; i < p; i++) {
            if (i != skip) sub = sub.intersection(g.playerClues[i].matchingHexes);
          }
          expect(sub.length, greaterThanOrEqualTo(2));
        }

        // Verify initial 2 cubes per player
        final initialCubes = g.cubes.where((c) => c != null).length;
        expect(initialCubes, p * 2);

        // Find a hex without a cube that does NOT match player 1's clue to test question -> penalty_cube
        final noMatchForP1 = [
          for (var h = 0; h < 54; h++)
            if (g.cubes[h] == null && !g.playerClues[1].matchingHexes.contains(h)) h,
        ].first;
        g.handle(0, {'type': 'question', 'target': 1, 'hex': noMatchForP1});
        expect(g.cubes[noMatchForP1], 1);
        expect(g.phase, 'penalty_cube');
        expect(g.waitingFor, [0]);

        final penaltyHexForP0 = [
          for (var h = 0; h < 54; h++)
            if (g.cubes[h] == null && !g.playerClues[0].matchingHexes.contains(h)) h,
        ].first;
        g.handle(0, {'type': 'place_cube', 'hex': penaltyHexForP0});
        expect(g.cubes[penaltyHexForP0], 0);
        expect(g.phase, 'turn');
        expect(g.turn, 1);

        // Player 1 searches on targetHex and wins immediately!
        g.handle(1, {'type': 'search', 'hex': g.targetHex});
        expect(g.isOver, isTrue);
        expect(g.winner, 1);
        expect(g.placings![1], 1);
      }
    });
  });

  test('simulate party9 games (30 seeds per player count & option)', () {
    final failures = runSims(party9Games, n: 30);
    expect(failures, 0);
  });
}
