import 'dart:math';

import 'package:aurora_shared/games/party19/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int players, {Map<String, dynamic>? options, int seed = 42}) {
  return GameSetup(
    players: players,
    options: options ?? const {},
    names: [for (var i = 0; i < players; i++) 'P$i'],
    bots: List<bool>.filled(players, false),
    hostSeat: 0,
    rng: Random(seed),
  );
}

void main() {
  group('winners_circle (皇家赛马会)', () {
    test('Hidden bet chips in view, once-per-cycle horse movement, occupied drop-back & dynamic odds payout', () {
      final g = WinnersCircleGame(_setup(2, options: {'mode': 'fast'}));
      g.start();
      expect(g.phase, 'bet');

      // Seat 0 places chip 2 on Horse 0; Seat 1 places chip 0 (Bluff) on Horse 0 to dilute Seat 0's odds!
      g.handle(0, {'type': 'bet', 'horse': 0, 'chip': 2});
      g.handle(1, {'type': 'bet', 'horse': 0, 'chip': 0});

      // Verify hidden chip values in view(seat)
      final v0 = g.view(0);
      final v1 = g.view(1);
      final betsOnH0For0 = (v0['bets'] as List)[0] as List;
      final betsOnH0For1 = (v1['bets'] as List)[0] as List;
      expect(betsOnH0For0[0]['chip'], 2); // Own chip visible
      expect(betsOnH0For0[1]['chip'], -1); // Opponent chip hidden!
      expect(betsOnH0For1[0]['chip'], -1);
      expect(betsOnH0For1[1]['chip'], 0);

      // Place remaining 2 chips each to finish 'bet' phase
      g.handle(0, {'type': 'bet', 'horse': 1, 'chip': 1});
      g.handle(1, {'type': 'bet', 'horse': 2, 'chip': 2});
      g.handle(0, {'type': 'bet', 'horse': 3, 'chip': 0});
      g.handle(1, {'type': 'bet', 'horse': 1, 'chip': 1});

      expect(g.phase, 'race');

      // Force dieFace = 0 (🐎 马头: Horse 0 moves 6, Horse 1 moves 5)
      g.dieFace = 0;
      final firstTurn = g.turn;
      g.handle(firstTurn, {'type': 'move', 'horse': 0});
      expect(g.horsePos[0], 6);
      expect(g.movedInCycle[0], isTrue);

      // Horse 0 cannot be moved again in the same cycle!
      expect(
        () => g.handle(g.turn, {'type': 'move', 'horse': 0}),
        throwsA(isA<GameError>()),
      );

      // Test occupied space drop-back rule: put Horse 2 at space 1 so when Horse 1 moves to 6 (occupied by Horse 0),
      // it drops back to space 5!
      g.horsePos[1] = 1;
      g.dieFace = 0; // Horse 1 speed on face 0 is 5 -> 1 + 5 = 6 (occupied by Horse 0) -> drops back to 5!
      g.handle(g.turn, {'type': 'move', 'horse': 1});
      expect(g.horsePos[1], 5);

      // Move remaining horses 2..6 to complete Cycle 1 -> movedInCycle resets for all unfinished horses!
      for (var h = 2; h <= 6; h++) {
        g.handle(g.turn, {'type': 'move', 'horse': h});
      }
      expect(g.cycle, 2);
      expect(g.movedInCycle.every((m) => !m), isTrue);

      // Position Horses 0, 2, 1 near Finish Line (18) to trigger 3-horse finish & dynamic odds payout:
      // Horse 0 has 2 chips (Seat 0's 2-chip + Seat 1's 0-Bluff chip) -> 1st place with 2 chips pays mult 7 (vs 10 for 1 chip)
      // Horse 2 has 1 chip (Seat 1's 2-chip) -> 2nd place with 1 chip pays mult 6
      // Horse 1 has 2 chips (Seat 0's 1-chip + Seat 1's 1-chip) -> 3rd place with 2 chips pays mult 3
      g.horsePos[0] = 17;
      g.horsePos[2] = 17;
      g.horsePos[1] = 17;
      g.handle(g.turn, {'type': 'move', 'horse': 0}); // 1st: Horse 0
      g.handle(g.turn, {'type': 'move', 'horse': 2}); // 2nd: Horse 2
      g.handle(g.turn, {'type': 'move', 'horse': 1}); // 3rd: Horse 1 -> Race 1 settles!

      // Seat 0 gets: 2 * 7 (1st on H0) + 1 * 3 (3rd on H1) = 17
      // Seat 1 gets: 0 * 7 (Bluff on H0) + 2 * 6 (2nd on H2) + 1 * 3 (3rd on H1) = 15
      expect(g.scores[0], 17);
      expect(g.scores[1], 15);
      expect(g.race, 2);
      expect(g.phase, 'bet');
    });
  });

  group('transamerica (横贯美利坚)', () {
    test('Hidden targetCities in view, terrain cost validation, shared rail network merge & instant 5-city round end', () {
      final g = TransAmericaGame(_setup(2, options: {'mode': 'fast'}));
      g.start();

      // Assign deterministic 5 target cities (one per region 0..4) for Seat 0 and Seat 1
      // Cities: 0(1,1), 3(2,2), 6(1,4), 9(5,4), 12(2,9)
      g.targetCities[0] = [0, 3, 6, 9, 12];
      g.targetCities[1] = [2, 5, 7, 10, 14];

      // Verify targetCities are hidden from opponent & spectator in view(seat)
      expect(g.view(0)['myTargets'], [0, 3, 6, 9, 12]);
      expect(g.view(0)['revealedTargets'], isNull);
      expect(g.view(1)['myTargets'], [2, 5, 7, 10, 14]);
      expect(g.view(-1)['myTargets'], isNull);

      // Place Start Hubs: Seat 0 at (1, 1) [Seattle, city 0], Seat 1 at (2, 2) [Salt Lake City, city 3]
      g.handle(0, {'type': 'place_hub', 'r': 1, 'c': 1});
      g.handle(1, {'type': 'place_hub', 'r': 2, 'c': 2});
      expect(g.phase, 'build');

      // Pre-connect Seat 1's hub (2,2) to cities 6(1,4) and 9(5,4), leaving only city 12(2,9) 1 step away
      for (final (r, c) in [
        (1, 2),
        (1, 3),
        (1, 4), // city 6
        (3, 2),
        (4, 2),
        (5, 2),
        (5, 3),
        (5, 4), // city 9
        (2, 3),
        (2, 4),
        (2, 5),
        (2, 6),
        (2, 7),
        (2, 8), // adjacent to city 12(2,9)!
      ]) {
        g.rails[r][c] = true;
      }

      // Notice Seat 0 at (1,1) is now orthogonally adjacent to (1,2) in Seat 1's rail network!
      // Because (1,1) and (1,2) both have rails[r][c] == true, their networks have MERGED into a shared network!
      expect(g.connectedTargetCities(0), containsAll([0, 3, 6, 9]));

      // Now Seat 0 builds 1 rail cell at (2, 9) [New York, city 12], completing all 5 of Seat 0's targetCities!
      g.turn = 0;
      g.handle(0, {
        'type': 'build_rail',
        'cells': [
          [2, 9],
        ],
      });

      // Instant Round End triggered! Seat 0 has 0 missing steps (0 penalty), Seat 1 loses missingSteps (< 0)
      expect(g.isOver, isTrue);
      expect(g.scores[0], 0);
      expect(g.scores[1], lessThan(0));
    });
  });

  group('oriflamme (王权烈焰)', () {
    test('Face-down queue placement, hidden cards in view, left-to-right keep_hidden vs reveal & Ambush counter-kill', () {
      final g = OriflammeGame(_setup(2, options: {'mode': 'fast'}));
      g.start();
      expect(g.phase, 'place');

      // Seat 0 places 💣 Ambush (6) on 'right'; Seat 1 places ⚔️ Soldier (5) on 'right'
      g.handle(0, {'type': 'place', 'card': 6, 'pos': 'right'});
      // Before Seat 1 places, verify Seat 0's face-down card in queue is hidden from Seat 1 in view(1)
      expect(((g.view(1)['queue'] as List)[0] as Map)['card'], -1);
      expect(((g.view(0)['queue'] as List)[0] as Map)['card'], 6);

      g.handle(1, {'type': 'place', 'card': 5, 'pos': 'right'});
      expect(g.phase, 'resolve');
      expect(g.resolveIdx, 0);

      // Step 0 of resolve: Seat 0 chooses keep_hidden on Ambush (idx 0) -> gains +1 token on the card!
      g.handle(0, {'type': 'keep_hidden'});
      expect(g.queue[0]['tokens'], 1);
      expect(g.resolveIdx, 1);
      expect(g.turn, 1);

      // Step 1 of resolve: Seat 1 reveals ⚔️ Soldier (idx 1) targeting Seat 0's face-down 💣 Ambush (idx 0)!
      // Ambush triggers: kills Soldier and awards Seat 0 +4 VP (+ 1 stacked token = +5 VP)!
      final score0Before = g.scores[0];
      g.handle(1, {'type': 'reveal', 'targetIdx': 0});
      expect(g.scores[0], score0Before + 5);
      expect(g.queue, isEmpty);
      expect(g.round, 2);
      expect(g.phase, 'place');
    });
  });

  group('pickomino (虫虫烧烤派对)', () {
    test('Distinct face locking, Worm requirement, Grill claim, opponent top-tile steal & BUST penalty', () {
      final g = PickominoGame(_setup(2));
      g.start();

      // 1. Seat 0 rolls four 6s (🐛 Worm = 5 pts each -> 20 pts) and four 2s
      g.currentRoll = [2, 2, 2, 2, 6, 6, 6, 6];
      g.handle(0, {'type': 'keep', 'face': 6});
      expect(g.lockedFaces, [6]);
      expect(g.lockedSum, 20);
      expect(g.diceRemaining, 4);

      // Roll again and force four 2s (+8 pts -> lockedSum = 28)
      g.handle(0, {'type': 'roll'});
      g.currentRoll = [2, 2, 2, 2];
      // Cannot keep face 6 again since 6 is already in lockedFaces
      expect(
        () => g.handle(0, {'type': 'keep', 'face': 6}),
        throwsA(isA<GameError>()),
      );
      g.handle(0, {'type': 'keep', 'face': 2});
      expect(g.lockedSum, 28);

      // Claim tile 28 from central Grill!
      g.handle(0, {'type': 'claim'});
      expect(g.stacks[0], [28]);
      expect(g.grillTiles.contains(28), isFalse);
      expect(g.scores[0], 2); // Tile 28 is worth 2 🐛

      // 2. Seat 1's turn: achieves exact sum 28 with a Worm -> steals tile 28 from Seat 0's top of stack!
      expect(g.turn, 1);
      g.currentRoll = [6, 6, 6, 6, 4, 4, 1, 1];
      g.handle(1, {'type': 'keep', 'face': 6}); // 20 pts
      g.handle(1, {'type': 'roll'});
      g.currentRoll = [4, 4, 1, 1];
      g.handle(1, {'type': 'keep', 'face': 4}); // +8 pts = 28 pts!
      g.handle(1, {'type': 'claim'});
      expect(g.stacks[0], isEmpty);
      expect(g.stacks[1], [28]);
      expect(g.scores[1], 2);

      // 3. Give Seat 0 tile 21 on bottom and tile 25 on top, then force Seat 0 to BUST:
      // Seat 0's top tile (25) returns to grillTiles, tile 21 remains safe, and highest Grill tile (36) flips face-down!
      expect(g.turn, 0);
      g.grillTiles.remove(21);
      g.grillTiles.remove(25);
      g.stacks[0] = [21, 25];
      g.lockedFaces = [5, 6];
      g.currentRoll = [5, 6]; // Every face in currentRoll is already in lockedFaces -> BUST!
      g.handle(0, {'type': 'roll'});

      expect(g.stacks[0], [21]); // Only top tile 25 was lost!
      expect(g.grillTiles.contains(25), isTrue); // 25 returned to Grill!
      expect(g.grillTiles.contains(36), isFalse); // Highest Grill tile 36 flipped face-down!
      expect(g.flippedTiles, contains(36));
    });
  });

  test('simulate all party19 games (30 seeds per player count & option)', () {
    final failures = runSims(party19Games, n: 30);
    expect(failures, 0);
  });
}
