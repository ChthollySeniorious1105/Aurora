import 'dart:math';

import 'package:aurora_shared/games/party18/defs.dart';
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
  group('captain_sonar (深海潜艇战)', () {
    test('Hidden subPos in view, move & charge, trail collision, surface sector reveal, sonar, silence & torpedo splash/direct damage', () {
      final g = CaptainSonarGame(_setup(2));
      g.start();

      // Clear islands for deterministic navigation test
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          g.islands[r][c] = false;
        }
      }
      g.subPos[0] = [2, 2];
      g.trail[0] = [
        [2, 2],
      ];
      g.subPos[1] = [2, 5];
      g.trail[1] = [
        [2, 5],
      ];

      // Verify secret position is strictly hidden from opponent & spectator in view(seat)
      final v0 = g.view(0);
      final v1 = g.view(1);
      final vSpec = g.view(-1);
      expect(v0['myPos'], [2, 2]);
      expect(v0.containsKey('subPos'), isFalse);
      expect(v1['myPos'], [2, 5]);
      expect(vSpec['myPos'], isNull);

      // Seat 0 moves East ('E') and charges Torpedo (0)
      g.handle(0, {'type': 'move', 'dir': 'E', 'charge': 0});
      expect(g.subPos[0], [2, 3]);
      expect(g.headingLog[0], ['E']);
      expect(g.charges[0][0], 1);

      // Seat 1 moves South ('S') and charges Sonar (1)
      g.handle(1, {'type': 'move', 'dir': 'S', 'charge': 1});
      expect(g.subPos[1], [3, 5]);
      expect(g.headingLog[1], ['S']);
      expect(g.charges[1][1], 1);

      // Seat 0 cannot move West back onto own trail (2, 2)
      expect(
        () => g.handle(0, {'type': 'move', 'dir': 'W', 'charge': 0}),
        throwsA(isA<GameError>()),
      );

      // Charge Seat 0's Sonar (3), Silence (4), and Torpedo (3)
      g.charges[0] = [3, 3, 4, 0];

      // 1. Activate Sonar on Seat 1 -> reveals Row 3 and Sector 1
      g.handle(0, {'type': 'sonar', 'target': 1});
      expect(g.charges[0][1], 0);
      expect(g.sonarIntel[0]['1']?['r'], 3);
      expect(g.sonarIntel[0]['1']?['sector'], 1);

      // 2. Activate Silence: dash 1 step South to (3, 3) WITHOUT adding to headingLog!
      final logLenBefore = g.headingLog[0].length;
      g.handle(0, {'type': 'silence', 'dir': 'S', 'steps': 1});
      expect(g.subPos[0], [3, 3]);
      expect(g.headingLog[0].length, logLenBefore);
      expect(g.charges[0][2], 0);

      // 3. Fire Torpedo from (3, 3) directly at Seat 1 at (3, 5) (Manhattan dist = 2 <= 4) -> 2 Direct DMG!
      g.handle(0, {'type': 'torpedo', 'r': 3, 'c': 5});
      expect(g.hp[1], 2);
      expect(g.charges[0][0], 0);

      // 4. Fire Torpedo at (3, 4) (adjacent to both Seat 0 at (3,3) and Seat 1 at (3,5)) -> 1 Splash DMG to both!
      g.charges[0][0] = 3;
      g.handle(0, {'type': 'torpedo', 'r': 3, 'c': 4});
      expect(g.hp[0], 3);
      expect(g.hp[1], 1);

      // 5. Seat 0 Surfaces -> clears trail & headingLog, heals +1 HP, reveals Sector 0
      g.handle(0, {'type': 'surface'});
      expect(g.trail[0].length, 1);
      expect(g.headingLog[0], isEmpty);
      expect(g.hp[0], 4);
      expect(g.publicSector[0], 0);
    });
  });

  group('potion_explosion (魔法药水大爆炸)', () {
    test('Chain-reaction same-color marble explosion, potion completion, drinking & Professor Skill Tokens', () {
      final g = PotionExplosionGame(_setup(2));
      g.start();

      // Configure Lane 0 for a multi-stage chain explosion:
      // [0, 1, 2, 1, 0] -> picking idx 2 (color 2) makes idx 1 & 2 collide (both color 1 -> 2 marbles),
      // which then makes the remaining two color 0 marbles collide (2 marbles) -> total 5 marbles collected!
      g.lanes[0] = [0, 1, 2, 1, 0];

      // Configure Seat 0's first active potion to need [2, 2, 1, 0] (type 1, 6 VP)
      g.potions[0][0] = {
        'type': 1,
        'name': '爆裂魔药',
        'emoji': '🔥',
        'vp': 6,
        'need': <int>[2, 2, 1, 0],
        'filled': <int>[0, 0, 0, 0],
        'desc': '测试魔药',
      };

      g.handle(0, {'type': 'pick', 'lane': 0, 'idx': 2});
      expect(g.lastExplosions, 2);
      expect(g.lastCollected, [2, 1, 1, 0, 0]);
      expect(g.lanes[0].length, 5); // Refilled to 5 after chain reaction finishes!
      expect(g.completedPotions[0].length, 1);
      expect(g.scores[0], 6);

      // Drink the completed potion (type 1) for bonus marbles & VP
      g.handle(0, {'type': 'drink', 'potionIdx': 0});
      expect(g.completedPotions[0][0]['drunk'], isTrue);
      expect(g.scores[0], greaterThan(6));

      // Award Professor Skill Token (+4 VP) when reaching 3 of same type
      final scoreBeforeSkill = g.scores[0];
      g.completedByType[0][1] = 3;
      g.checkProfessorSkillTokens(0);
      expect(g.skillTokens[0], 1);
      expect(g.scores[0], scoreBeforeSkill + 4);
    });
  });

  group('loot (海盗劫掠船)', () {
    test('Launch merchant ship, multi-color pirate attack rules & start-of-turn sole-leader capture', () {
      final g = LootGame(_setup(2));
      g.start();

      // Give Seat 0 a 6-gold Merchant Ship, Blue Pirate (col 0, str 2), and Blue Captain (col 0, str 5)
      g.hands[0] = [
        {'kind': 'merchant', 'value': 6, 'color': -1, 'strength': 0},
        {'kind': 'pirate', 'value': 0, 'color': 0, 'strength': 2},
        {'kind': 'captain', 'value': 0, 'color': 0, 'strength': 5},
      ];
      // Give Seat 1 a Blue Pirate (col 0, str 3) and Red Pirate (col 3, str 4)
      g.hands[1] = [
        {'kind': 'pirate', 'value': 0, 'color': 0, 'strength': 3},
        {'kind': 'pirate', 'value': 0, 'color': 3, 'strength': 4},
        {'kind': 'pirate', 'value': 0, 'color': 1, 'strength': 2},
      ];

      // Turn 0: Seat 0 launches the 6-gold Merchant Ship
      g.handle(0, {'type': 'launch', 'cardIdx': 0});
      expect(g.ships.length, 1);
      expect(g.ships[0]['value'], 6);

      // Turn 1: Seat 1 attacks Ship 0 with Blue Pirate (col 0, str 3)
      g.handle(1, {'type': 'attack', 'shipIdx': 0, 'cardIdx': 0});
      expect(g.ships[0]['attacks']['1'], 3);
      expect(g.ships[0]['colors']['1'], 0);

      // Turn 0: Seat 0 tries to attack Ship 0 with Blue Pirate (col 0) -> ILLEGAL because Seat 1 already uses Blue on Ship 0!
      expect(
        () => g.handle(0, {'type': 'attack', 'shipIdx': 0, 'cardIdx': 0}),
        throwsA(isA<GameError>()),
      );

      // Seat 0 draws a card instead, passing turn back to Seat 1
      g.handle(0, {'type': 'draw'});

      // At the start of Seat 1's turn, Seat 1 holds the sole highest attack strength (3) on Ship 0 -> Captured!
      expect(g.ships, isEmpty);
      expect(g.gold[1], 6);
      expect(g.capturedShips[1], [6]);
    });
  });

  group('thats_life (百变人生)', () {
    test('Move pawn, move shared guard, Leaving-Last tile collection & Guardian Reversal scoring', () {
      final g = ThatsLifeGame(_setup(2));
      g.start();

      // Clear guards except one guard at tile 3
      g.guards = [3];
      g.tiles[3] = -6; // Negative Red Tile -6 at pos 3
      g.tiles[5] = 99; // 🍀 Guardian Tile 99 at pos 5

      // Seat 0 rolls 3 and moves Pawn 0 from 0 -> 3 (shares tile 3 with the Guard)
      g.roll = 3;
      g.handle(0, {'type': 'move_pawn', 'idx': 0});
      expect(g.pawns[0][0], 3);
      expect(g.activeTiles[3], isTrue); // Tile 0 is Start, not collected

      // Seat 1 rolls 5 and moves Pawn 0 from 0 -> 5 (lands alone on tile 5)
      g.roll = 5;
      g.handle(1, {'type': 'move_pawn', 'idx': 0});
      expect(g.pawns[1][0], 5);

      // Seat 0's turn: Seat 0 shares tile 3 with the Neutral Guard!
      // Seat 0 moves the Neutral Guard from 3 -> 5 (Pawn 0 still remains on tile 3, so tile 3 is NOT taken yet)
      g.roll = 2;
      g.handle(0, {'type': 'move_guard', 'pos': 3});
      expect(g.guards[0], 5);
      expect(g.activeTiles[3], isTrue);
      expect(g.collected[0], isEmpty);

      // Seat 1 moves Pawn 1 from 0 -> 2
      g.roll = 2;
      g.handle(1, {'type': 'move_pawn', 'idx': 1});

      // Seat 0's turn: Pawn 0 is now the VERY LAST piece standing on tile 3 (-6)!
      // Seat 0 moves Pawn 0 from 3 -> 6 -> Leaving-Last Rule triggers: Seat 0 collects tile 3 (-6)!
      g.roll = 3;
      g.handle(0, {'type': 'move_pawn', 'idx': 0});
      expect(g.activeTiles[3], isFalse);
      expect(g.collected[0], [-6]);
      expect(g.scoreOf(0), -6); // Without a Guardian tile, -6 subtracts 6 points!

      // Now give Seat 0 a 🍀 Guardian Tile (99) -> -6 flips to +6!
      g.collected[0].add(99);
      g.recalcScores();
      expect(g.scoreOf(0), 6);
      expect(g.scores[0], 6);
    });
  });

  test('simulate all party18 games (30 seeds per player count & option)', () {
    final failures = runSims(party18Games, n: 30);
    expect(failures, 0);
  });
}
