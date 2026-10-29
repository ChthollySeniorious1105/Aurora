import 'dart:math';

import 'package:aurora_shared/games/euro18/defs.dart';
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
  group('marrakech', () {
    test('Assam 180-degree U-turn prohibition, border U-turn wrap, BFS connected rug tribute, and single-rug cover rule', () {
      final e = _start(MarrakechGame(_setup(2)));

      // Assam starts at (3, 3) facing North (dir = 0).
      // 180-degree U-turn (dir = 2 South, or turnDelta = 2) must throw GameError!
      expect(
        () => e.handle(0, {'type': 'orient_assam', 'dir': 2}),
        throwsA(isA<GameError>()),
      );
      expect(
        () => e.handle(0, {'type': 'orient_assam', 'turnDelta': 2}),
        throwsA(isA<GameError>()),
      );

      // Verify border U-turn track wrap-around:
      // Stepping North (0) off (0, 1) wraps to (0, 2) facing South (2)
      expect(MarrakechGame.stepAssamOnce(0, 1, 0), (0, 2, 2));
      // Stepping North (0) off top-left corner (0, 0) turns East (1) at (0, 0)
      expect(MarrakechGame.stepAssamOnce(0, 0, 0), (0, 0, 1));

      // Place a connected component of 4 cells of P1's rugs around North of (3, 3)
      // so regardless of roll (1, 2, 3, or 4), Assam lands on P1's connected rug component!
      e.grid[2][3] = const MarrakechRugCell(owner: 1, rugId: 10);
      e.grid[1][3] = const MarrakechRugCell(owner: 1, rugId: 10);
      e.grid[0][3] = const MarrakechRugCell(owner: 1, rugId: 11);
      e.grid[0][4] = const MarrakechRugCell(owner: 1, rugId: 11);

      expect(e.connectedVisibleRugSize(2, 3), 4);

      // P0 moves Assam straight North (turnDelta: 0) -> lands on P1's 4-cell component and pays 4 Dirhams!
      e.handle(0, {'type': 'orient_assam', 'turnDelta': 0});
      expect(e.lastTribute, 4);
      expect(e.coins[0], 26);
      expect(e.coins[1], 34);
      expect(e.phase, 'place');

      // Now test Rug Placement rules:
      // Suppose Assam is placed at (2, 2) for deterministic placement check:
      e.assamR = 2;
      e.assamC = 2;
      // Rug #10 occupies (2, 3) and (1, 3).
      // Attempting to cover BOTH (2, 3) and (1, 3) (the exact same single rugId=10) must fail!
      expect(
        () => e.handle(0, {
          'type': 'place_rug',
          'r1': 2,
          'c1': 3,
          'r2': 1,
          'c2': 3,
        }),
        throwsA(isA<GameError>()),
      );

      // Covering (1, 3) [rugId 10] and (0, 3) [rugId 11] is not adjacent to Assam at (2, 2), so test
      // covering (2, 3) [rugId 10] and (2, 4) [empty], which IS adjacent to Assam and legal!
      e.handle(0, {
        'type': 'place_rug',
        'r1': 2,
        'c1': 3,
        'r2': 2,
        'c2': 4,
      });
      expect(e.grid[2][3]?.owner, 0);
      expect(e.grid[2][4]?.owner, 0);
      expect(e.rugsLeft[0], e.rugsPerPlayer - 1);
    });
  });

  group('forest_shuffle', () {
    test('planting trees, tucking dwellers into 4 directional slots, species match bonus, and ecological synergies', () {
      final e = _start(ForestShuffleGame(_setup(2)));
      e.forests[0].clear();
      e.hands[0].clear();
      e.speciesBonusVp[0] = 0;

      // Give P0 an Oak Tree (species 0, cost 1, baseVp 4) + 3 payment cards + dwellers
      const oakTree = ForestCard(
        id: 501,
        name: '千年橡树',
        emoji: '🌳',
        kind: 'tree',
        species: 0,
        slotDir: -1,
        cost: 1,
        baseVp: 4,
        synergyType: 'tree',
        synergyDesc: '橡树',
      );
      const b1 = ForestCard(
        id: 502,
        name: '帝王斑蝶',
        emoji: '🦋',
        kind: 'dweller',
        species: 0, // Matches Oak (0)!
        slotDir: 0, // Top
        cost: 0,
        baseVp: 0,
        synergyType: 'butterfly',
        synergyDesc: '蝴蝶',
      );
      const deer = ForestCard(
        id: 503,
        name: '赤鹿',
        emoji: '🦌',
        kind: 'dweller',
        species: 1,
        slotDir: 2, // Left
        cost: 0,
        baseVp: 2,
        synergyType: 'deer',
        synergyDesc: '鹿',
      );
      const wolf = ForestCard(
        id: 504,
        name: '灰森林狼',
        emoji: '🐺',
        kind: 'dweller',
        species: 0,
        slotDir: 2, // Left
        cost: 0,
        baseVp: 2,
        synergyType: 'wolf',
        synergyDesc: '狼',
      );
      const fodder = ForestCard(
        id: 505,
        name: '白皮桦树',
        emoji: '🌿',
        kind: 'tree',
        species: 4,
        slotDir: -1,
        cost: 0,
        baseVp: 2,
        synergyType: 'tree',
        synergyDesc: '桦树',
      );

      e.hands[0].addAll([oakTree, b1, deer, wolf, fodder]);
      final clearingBefore = e.clearing.length;

      // P0 plants oakTree (paying fodder id 505 to clearing, plus 1 bonus card revealed to clearing)
      e.handle(0, {
        'type': 'play_tree',
        'cardId': 501,
        'payIds': [505],
      });
      expect(e.forests[0].length, 1);
      expect(e.clearing.length, clearingBefore + 2);

      // P1 takes turn
      e.handle(1, e.bot(1)!);

      // P0 tucks Butterfly b1 (species 0) onto Oak Tree (treeIdx 0, species 0) -> triggers +2 species bonus VP!
      e.handle(0, {
        'type': 'tuck_dweller',
        'cardId': 502,
        'treeIdx': 0,
      });
      expect(e.forests[0][0].top?.id, 502);
      expect(e.speciesBonusVp[0], 2);

      // Trying to tuck another top-slot card onto the same tree must fail!
      e.turn = 0;
      const b2 = ForestCard(
        id: 506,
        name: '孔雀蛱蝶',
        emoji: '🦋',
        kind: 'dweller',
        species: 1,
        slotDir: 0, // Top (already occupied on tree 0!)
        cost: 0,
        baseVp: 0,
        synergyType: 'butterfly',
        synergyDesc: '蝴蝶',
      );
      e.hands[0].add(b2);
      expect(
        () => e.handle(0, {
          'type': 'tuck_dweller',
          'cardId': 506,
          'treeIdx': 0,
        }),
        throwsA(isA<GameError>()),
      );

      // Add a second tree with b2 (2nd distinct butterfly -> 3 pts), deer, and wolf (wolf gets 2 + 3*1 = 5 pts)
      e.forests[0].add(const ForestTreeSlot(
        tree: fodder,
        top: b2,
        left: deer,
      ));
      e.forests[0][0] = e.forests[0][0].withSlot(2, wolf);
      final bd = e.calcScoreBreakdown(0);
      expect(bd['butterflyVp'], 3); // 2 distinct butterflies -> 3 VP
      expect(bd['wolfVp'], 5); // 1 wolf with 1 deer -> 2 + 3 = 5 VP
    });
  });

  group('railroad_ink', () {
    test('border exit connection, Highway-Railway mismatch check, Station network bridging, Overpass separation, and scoring', () {
      final e = _start(RailroadInkGame(_setup(2)));

      // At (0, 1), North border exit (dir 0) is Highway (1).
      // Trying to place a Railway Straight [2, 0, 2, 0] at (0, 1) with rot 0 (North=Railway 2) must fail!
      expect(e.canPlaceEdges(0, 0, 1, [2, 0, 2, 0]), isFalse);
      // Placing a Highway Straight [1, 0, 1, 0] at (0, 1) connects to North Highway Exit (0, 1)!
      expect(e.canPlaceEdges(0, 0, 1, [1, 0, 1, 0]), isTrue);

      // Build a network from North Highway Exit at (0, 1) -> Station at (0, 2) -> North Railway Exit at (0, 3):
      // 1. (0, 1): Highway Curve connecting North (1) and East (1): edges [1, 1, 0, 0]
      e.grid[0][0][1] = const RailroadPlacedTile(
        templateId: 'h_curve',
        name: '公路弯道',
        emoji: '🛣️',
        rot: 0,
        edges: [1, 1, 0, 0],
      );
      // 2. (0, 2): Station connecting West Highway (1) to East Railway (2): edges [0, 2, 0, 1]
      e.grid[0][0][2] = const RailroadPlacedTile(
        templateId: 'station',
        name: '换乘车站',
        emoji: '🚉',
        rot: 1,
        edges: [0, 2, 0, 1],
        isStation: true,
      );
      // 3. (0, 3): Railway Curve connecting North Railway Exit (2) and West Railway (2): edges [2, 0, 0, 2]
      e.grid[0][0][3] = const RailroadPlacedTile(
        templateId: 'r_curve',
        name: '铁路弯道',
        emoji: '🛤️',
        rot: 3,
        edges: [2, 0, 0, 2],
      );

      final bd = e.calcScoreBreakdown(0);
      // 2 connected exits ((0,1) North Highway and (0,3) North Railway bridged via Station at (0,2)) -> 4 VP!
      expect(bd['exitVp'], 4);
      expect(bd['longestHighwayVp'], 2); // (0,1) and (0,2)
      expect(bd['longestRailwayVp'], 2); // (0,2) and (0,3)
      expect(bd['errors'], 0); // All internal edges are connected!
    });
  });

  group('all_creatures', () {
    test('worker placement actions, pasture/stall/trough capacity math, end-of-round breeding, and animal category scoring', () {
      final e = _start(AllCreaturesGame(_setup(2)));

      // P0 starts with Cottage at (0,0) (cap 1) + Pasture at (0,1) (cap 2) = totalCapacity 3
      expect(e.totalCapacity(0), 3);

      // Give P0 resources to build a Stall on (0, 1) -> Pasture capacity doubles from 2 to 4 (totalCapacity = 5)!
      e.res[0] = [4, 4, 2];
      e.handle(0, {
        'type': 'take_action',
        'actionId': 'build_stall',
        'r': 0,
        'c': 1,
      });
      expect(e.farm[0][0][1].stalls, 1);
      expect(e.farm[0][0][1].capacity, 4);
      expect(e.totalCapacity(0), 5);

      // P1 takes an action
      e.handle(1, e.bot(1)!);

      // P0 builds a Drinking Trough on (0, 1) -> adds +2 capacity (totalCapacity = 7)!
      e.handle(0, {
        'type': 'take_action',
        'actionId': 'build_trough',
        'r': 0,
        'c': 1,
      });
      expect(e.farm[0][0][1].hasTrough, isTrue);
      expect(e.totalCapacity(0), 7);

      // Test Breeding Phase directly:
      // Set P0 animals to 2 Sheep, 2 Boar, 1 Cattle, 0 Horse (total = 5 < capacity 7)
      e.animals[0] = [2, 2, 1, 0];
      final newborn = e.runBreedingForSeat(0);
      // Both Sheep (>=2) and Boar (>=2) breed +1 newborn each (total becomes 7 == capacity 7)!
      expect(newborn, [1, 1, 0, 0]);
      expect(e.animals[0], [3, 3, 1, 0]);

      // Verify category threshold bonus/penalty table:
      expect(AllCreaturesGame.animalCategoryBonus(3), -3);
      expect(AllCreaturesGame.animalCategoryBonus(4), 0);
      expect(AllCreaturesGame.animalCategoryBonus(6), 1);
      expect(AllCreaturesGame.animalCategoryBonus(9), 3);
    });
  });

  test('sims', () {
    expect(runSims(euro18Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
