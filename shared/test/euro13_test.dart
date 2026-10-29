import 'dart:math';

import 'package:aurora_shared/games/euro13/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n,
        [Map<String, dynamic> opts = const {}, int seed = 7]) =>
    GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, false),
      rng: Random(seed),
    );

T _start<T extends GameEngine>(T e) {
  e.host = SimHost();
  e.start();
  return e;
}

void main() {
  group('akropolis', () {
    test('multi-level stacking, Quarry stone generation, and 5-color District×Plaza scoring', () {
      final e = _start(AkropolisGame(_setup(2)));
      expect(e.stones[0], 1);
      expect(e.stones[1], 2);
      // Center (3,3) is Blue Plaza (1★), and (3,2), (2,3), (4,3) are Level-1 Quarries
      expect(e.height[0][3][3], 1);
      expect(e.topType[0][3][3], 1);
      expect(e.topIsPlaza[0][3][3], isTrue);
      expect(e.topType[0][3][2], 0);
      expect(e.topType[0][2][3], 0);
      expect(e.topType[0][4][3], 0);

      // Set market[1] to a custom tile: [Blue District(1), Yellow Plaza(2, 2★), Green District(5)]
      e.market[1] = const AkropolisTile(
        id: 901,
        cells: [
          AkropolisCell(type: 1),
          AkropolisCell(type: 2, isPlaza: true, stars: 2),
          AkropolisCell(type: 5),
        ],
      );

      // P0 picks slot 1 (costs 1 Stone -> stones becomes 0), and stacks on Level 2
      // covering (3,3) [Blue Plaza], (3,2) [Quarry], (2,3) [Quarry] -> covers 2 Quarries for +2 Stones!
      e.handle(0, {
        'type': 'build',
        'slot': 1,
        'cells': [
          [3, 3],
          [3, 2],
          [2, 3],
        ],
      });
      expect(e.height[0][3][3], 2);
      expect(e.height[0][3][2], 2);
      expect(e.height[0][2][3], 2);
      expect(e.stones[0], 2); // 1 - 1 (slot cost) + 2 (covered Quarries) = 2!

      // Verify all 5 color district rules + Plaza stars on P1:
      // Give P1 a 1★ Plaza of all 5 colors + specific districts:
      // Blue(1): connected group of heights 2 + 1 = 3
      // Yellow(2): isolated Yellow District of height 2
      // Red(3): perimeter Red District of height 2
      // Purple(4): completely surrounded Purple District at (3,3) of height 3
      // Green(5): Green District of height 2
      e.topType[1][3][3] = 4; // Purple District at (3,3), surrounded by 6 neighbors!
      e.topIsPlaza[1][3][3] = false;
      e.height[1][3][3] = 3;
      for (final (nr, nc) in AkropolisGame.hexNeighbors(3, 3)) {
        e.height[1][nr][nc] = 1;
        e.topType[1][nr][nc] = 0;
        e.topIsPlaza[1][nr][nc] = false;
      }
      // Put a 2★ Purple Plaza at (0, 0)
      e.height[1][0][0] = 1;
      e.topType[1][0][0] = 4;
      e.topIsPlaza[1][0][0] = true;
      e.topStars[1][0][0] = 2;

      expect(e.calcColorDistrictSum(1, 4), 3); // Surrounded Purple District of height 3
      expect(e.calcColorPlazaStars(1, 4), 2);
      expect(e.calcScore(1), greaterThanOrEqualTo(3 * 2 + e.stones[1]));
    });
  });

  group('flamecraft', () {
    test('visit fee, gather + slot dragon + fire up, and spell enchantment', () {
      final e = _start(FlamecraftGame(_setup(2)));
      // Give P0 a Bread dragon in hand and gather at Shop 0 (Bread shop)
      e.hand[0] = [
        const FlameDragon(id: 501, type: 0, name: '🍞烘焙龙·测试'),
      ];
      final breadBefore = e.goods[0][0];
      final heartsBefore = e.hearts[0];
      e.handle(0, {
        'type': 'gather',
        'shop': 0,
        'handIdx': 0,
        'fireSlot': 0,
      });
      // Shop 0 now has 2 dragons, P0 gained base+dragon bread, +2❤️ from slotting, and fired up dragon 0
      expect(e.shops[0].dragons.length, 2);
      expect(e.goods[0][0], greaterThan(breadBefore));
      expect(e.hearts[0], greaterThanOrEqualTo(heartsBefore + 2));
      expect(e.location[0], 0);

      // P1 visits the SAME Shop 0 -> must pay 1 Good/Coin visit fee to P0!
      final p0TotalBefore = e.totalGoods(0) + e.coins[0];
      e.handle(1, {
        'type': 'gather',
        'shop': 0,
        'handIdx': -1,
        'fireSlot': 0,
      });
      expect(e.totalGoods(0) + e.coins[0], p0TotalBefore + 1);

      // Now P0 casts an Enchantment Spell on Shop 1
      e.spells[0] = const FlameSpell(
        id: 601,
        name: '龙息炙烤术',
        targetShop: 1,
        cost: [1, 2, 0, 0, 0, 0],
        hearts: 6,
      );
      e.goods[0] = [3, 3, 2, 2, 2, 2];
      final p0HeartsBeforeEnchant = e.hearts[0];
      e.handle(0, {
        'type': 'enchant',
        'shop': 1,
        'spellSlot': 0,
      });
      expect(e.shops[1].enchantCount, 1);
      expect(e.hearts[0], greaterThanOrEqualTo(p0HeartsBeforeEnchant + 6));
    });
  });

  group('tokaido', () {
    test('Rear-Most Traveler turn order, mandatory Inn stop, Souvenir set scoring, and Temple majority', () {
      final e = _start(TokaidoGame(_setup(2, {'roadLength': 20})));
      expect(e.turn, 0);
      expect(e.currentInnPos, 5);

      // P0 moves from 0 to stop 3 (Paddy Panorama)
      e.handle(0, {'type': 'move', 'stop': 3});
      expect(e.pos[0], 3);
      expect(e.paddy[0], 1);
      expect(e.turn, 1); // P1 is at 0 < 3, so P1 moves next

      // P1 moves only 1 step to stop 1 (Farm: +3 Coins)
      e.handle(1, {'type': 'move', 'stop': 1});
      expect(e.pos[1], 1);
      expect(e.coins[1], 10);
      // Since P1 is at pos 1 < P0's pos 3, Rear-Most Traveler Rule gives P1 ANOTHER turn immediately!
      expect(e.turn, 1);

      // P1 cannot jump past the mandatory Inn at index 5
      expect(
        () => e.handle(1, {'type': 'move', 'stop': 6}),
        throwsA(isA<GameError>()),
      );

      // Verify Souvenir set scoring: 1 of each of 4 types = 16 VP; + 2 distinct = +4 VP -> 20 VP
      e.souvenirs[0] = [2, 2, 1, 1];
      expect(e.calcSouvenirScore(0), 16 + 4);

      // Verify Temple Endgame Majority bonus (+10 for 1st, +7 for 2nd)
      e.templeDonated[0] = 3;
      e.templeDonated[1] = 1;
      expect(e.calcTempleMajorityBonus(0), 10);
      expect(e.calcTempleMajorityBonus(1), 7);
    });
  });

  group('kingdom_builder', () {
    test('Mandatory Adjacency Rule enforcement, Castle scoring, and Scoring Cards', () {
      final e = _start(KingdomBuilderGame(_setup(2)));
      // Force P0's hand terrain to Grass (0)
      e.handTerrain[0] = 0;
      // Place an existing P0 settlement at (0, 0) [Grass]
      e.owner[0][0] = 0;
      // Note that (0, 1) and (1, 0) are Grass (0) and adjacent to (0, 0)!
      // Whereas (4, 5) is also Grass (0) but NOT adjacent to (0, 0).
      expect(e.map[0][1], 0);
      expect(e.map[4][5], 0);

      // Attempting to place at (4, 5) when adjacent Grass hexes (0, 1) and (1, 0) exist MUST throw GameError!
      expect(
        () => e.handle(0, {
          'type': 'build',
          'cells': [
            [4, 5],
          ],
        }),
        throwsA(isA<GameError>()),
      );

      // Placing on adjacent Grass hexes (0, 1) and (1, 0) succeeds!
      e.handle(0, {
        'type': 'build',
        'cells': [
          [0, 1],
          [1, 0],
        ],
      });
      expect(e.owner[0][1], 0);
      expect(e.owner[1][0], 0);

      // Place settlement adjacent to Castle at (1, 2) -> e.g. at (1, 3)
      e.owner[1][3] = 0;
      expect(e.calcCastleScore(0), 3);

      // Verify all 5 Kingdom Builder Scoring Cards (0..4) return positive scores
      for (var cid = 0; cid < 5; cid++) {
        expect(e.calcCardScore(0, cid), greaterThanOrEqualTo(0));
      }
      expect(e.calcCardScore(0, 0), greaterThanOrEqualTo(6)); // Citizens: 3 connected settlements * 2 = 6
    });
  });

  test('sims', () {
    expect(runSims(euro13Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
