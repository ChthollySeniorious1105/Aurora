import 'dart:math';

import 'package:aurora_shared/games/euro8/cascadia.dart';
import 'package:aurora_shared/games/euro8/defs.dart';
import 'package:aurora_shared/games/euro8/nidavellir.dart';
import 'package:aurora_shared/games/euro8/puertorico.dart';
import 'package:aurora_shared/games/euro8/starrealms.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n, [Map<String, dynamic> opts = const {}, int seed = 7]) => GameSetup(
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
  group('cascadia', () {
    test('starter habitat has 3 hexes and 2 nature tokens', () {
      final e = _start(Cascadia(_setup(2)));
      expect(e.grids[0].length, 3);
      expect(e.grids[1].length, 3);
      expect(e.natureTokens, [2, 2]);
      expect(e.market.length, 4);
    });

    test('wildlife scoring formulas (Bear, Elk, Salmon, Hawk, Fox)', () {
      final g = <(int, int), CascadiaHex>{};
      void put(int r, int c, int? animal, [List<int> terrains = const [0]]) {
        g[(r, c)] = CascadiaHex(
          r: r,
          c: c,
          terrains: terrains,
          allowedAnimals: [0, 1, 2, 3, 4],
          isKeystone: terrains.length == 1,
          animal: animal,
        );
      }

      // 2 isolated Bear pairs -> 11 pts; plus a triple of Bears (ignored!)
      put(0, 0, 0);
      put(0, 1, 0);
      put(2, 0, 0);
      put(2, 1, 0);
      put(4, 0, 0);
      put(4, 1, 0);
      put(4, 2, 0);
      expect(Cascadia.scoreBears(g), 11);

      // Elk group of 3 -> 9 pts
      put(10, 0, 1);
      put(10, 1, 1);
      put(10, 2, 1);
      expect(Cascadia.scoreElk(g), 9);

      // Salmon run of 4 -> 12 pts
      put(20, 0, 2);
      put(20, 1, 2);
      put(20, 2, 2);
      put(20, 3, 2);
      expect(Cascadia.scoreSalmon(g), 12);

      // 3 isolated Hawks -> 8 pts
      put(30, 0, 3);
      put(30, 2, 3);
      put(30, 4, 3);
      expect(Cascadia.scoreHawks(g), 8);

      // Fox at (40, 0) surrounded by Bear (0), Elk (1), Salmon (2) -> 3 distinct species -> 3 pts
      put(40, 0, 4);
      put(40, 1, 0);
      put(41, 0, 1);
      put(41, -1, 2);
      expect(Cascadia.scoreFoxes(g), 3);
    });

    test('keystone placement awards +1 nature token and split pick costs 1 token', () {
      final e = _start(Cascadia(_setup(2)));
      e.market[0] = CascadiaMarketPair(
        tile: const CascadiaTile(id: 99, terrains: [0], allowedAnimals: [0]),
        animal: 1,
      );
      e.market[1] = CascadiaMarketPair(
        tile: const CascadiaTile(id: 98, terrains: [1, 2], allowedAnimals: [1, 2]),
        animal: 0,
      );
      // Seat 0 spends 1 nature token to pair tileIdx=0 (Keystone allowing animal 0) with animalIdx=1 (animal 0)
      // and places both at (-1, 0) (adjacent to (0, 0)), gaining +1 nature token back!
      e.handle(0, {
        'type': 'turn',
        'tileIdx': 0,
        'animalIdx': 1,
        'r': -1,
        'c': 0,
        'animalR': -1,
        'animalC': 0,
      });
      expect(e.grids[0][(-1, 0)]?.animal, 0);
      expect(e.natureTokens[0], 2); // 2 - 1 (split pick) + 1 (keystone) = 2
      expect(e.turn, 1);
    });
  });

  group('puertorico', () {
    test('settler, craftsman, trader, and captain roles work end-to-end', () {
      final e = _start(PuertoRico(_setup(3)));
      // Seat 0 starts with a manned Corn (0) plantation. Pick Craftsman (role 3)!
      e.handle(0, {'type': 'pick_role', 'role': 3});
      // Seat 0 produces 1 Corn + 1 Craftsman privilege Corn = 2 Corn!
      expect(e.goods[0][0], 2);
      // Seat 1 also started with Corn -> 1 Corn; Seat 2 started with Indigo (no building yet) -> 0
      expect(e.goods[1][0], 1);

      // Now Seat 1 picks Captain (role 5)
      expect(e.turn, 1);
      e.handle(1, {'type': 'pick_role', 'role': 5});
      // Seat 1 must load Corn onto a ship (+1 VP + 1 Captain privilege = 2 VP)
      expect(e.phase, 'captain');
      expect(e.turn, 1);
      e.handle(1, {'type': 'load_ship', 'good': 0, 'ship': 0});
      expect(e.vp[1], 2);
      // Next Seat 0 must load 2 Corn onto ship 0 (+2 VP)
      expect(e.turn, 0);
      e.handle(0, {'type': 'load_ship', 'good': 0, 'ship': 0});
      expect(e.vp[0], 2);
      expect(e.cargoShips[0].count, 3);
    });

    test('builder discount and trader sale price', () {
      final e = _start(PuertoRico(_setup(3)));
      e.doubloons[0] = 5;
      // Seat 0 picks Builder (role 2) and builds Small Indigo Plant (id 0, cost 1, -1 builder privilege = 0 cost)
      e.handle(0, {'type': 'pick_role', 'role': 2});
      e.handle(0, {'type': 'build', 'buildingId': 0});
      expect(e.doubloons[0], 5);
      e.handle(1, {'type': 'pass'});
      e.handle(2, {'type': 'pass'});

      // Give Seat 1 a Coffee barrel (good 4, base price 4) and let Seat 1 pick Trader (role 4, +1 privilege = 5 doubloons)
      e.goods[1][4] = 1;
      final beforeD = e.doubloons[1];
      e.handle(1, {'type': 'pick_role', 'role': 4});
      e.handle(1, {'type': 'trade', 'good': 4});
      expect(e.doubloons[1], beforeD + 5);
    });
  });

  group('nidavellir', () {
    test('simultaneous bid, gem tie-break swap, and 0-coin Royal Treasure forging', () {
      final e = _start(Nidavellir(_setup(2)));
      expect(e.gems, [2, 1]);
      // Seat 0 bids [0, 3, 2], leaving [4, 5] in pouch -> 0-coin at Tavern 0 upgrades 5 + 4 = 9!
      // Seat 1 bids [0, 3, 2] as well -> ties with Seat 0 at Tavern 0!
      e.handle(0, {'type': 'bid', 'coins': [0, 3, 2]});
      e.handle(1, {'type': 'bid', 'coins': [0, 3, 2]});

      expect(e.phase, 'draft');
      // Seat 0 had higher gem (2 > 1), so Seat 0 drafts first at Tavern 0, and gems swap to [1, 2]!
      expect(e.draftOrder, [0, 1]);
      expect(e.gems, [1, 2]);

      e.handle(0, {'type': 'draft', 'index': 0});
      // Seat 0's highest coin should now be upgraded to 9 (5 + 4)!
      expect(e.coins[0].contains(9), isTrue);
    });

    test('completing all 5 dwarf classes triggers hero recruitment', () {
      final e = _start(Nidavellir(_setup(2)));
      // Give Seat 0 1 badge in classes 0, 1, 2, 3
      for (var c = 0; c < 4; c++) {
        e.armies[0].add(NidavellirCard(id: 200 + c, age: 1, classId: c, name: 'Test', ranks: const [5]));
      }
      // Put a class 4 card in Tavern 0
      e.taverns[0][0] = const NidavellirCard(id: 299, age: 1, classId: 4, name: 'Explorer', ranks: [8]);
      e.handle(0, {'type': 'bid', 'coins': [5, 4, 3]});
      e.handle(1, {'type': 'bid', 'coins': [2, 3, 4]});

      e.handle(0, {'type': 'draft', 'index': 0});
      expect(e.phase, 'recruit_hero');
      expect(e.pendingHeroSeat, 0);

      final heroId = e.availableHeroes.first.id;
      e.handle(0, {'type': 'recruit_hero', 'heroId': heroId});
      expect(e.heroes[0].length, 1);
      expect(e.phase, 'draft');
    });
  });

  group('starrealms', () {
    test('ally combo triggers and outpost blocks direct player attack', () {
      final e = _start(StarRealms(_setup(2)));
      // Give Seat 0 two Trade Federation (faction 0) cards in hand
      e.hands[0] = [
        const SrCard(id: 501, name: 'Fed1', faction: 0, cost: 1, trade: 2, allyHeal: 4),
        const SrCard(id: 502, name: 'Fed2', faction: 0, cost: 2, combat: 5, allyCombat: 4),
      ];
      // Give Seat 1 an Outpost with defense 4
      e.bases[1] = [
        const SrCard(id: 601, name: 'Outpost', faction: 2, cost: 4, isBase: true, isOutpost: true, defense: 4),
      ];

      e.handle(0, {'type': 'play_all'});
      // Ally heal +4 -> authority 54; combat 5 + allyCombat 4 = 9!
      expect(e.authority[0], 54);
      expect(e.combatPool, 9);

      // Cannot attack player directly while Outpost is in play!
      expect(() => e.handle(0, {'type': 'attack_player'}), throwsA(isA<GameError>()));

      // Destroy the Outpost first (costs 4 combat, leaving 5 combat)
      e.handle(0, {'type': 'attack_base', 'index': 0});
      expect(e.bases[1], isEmpty);
      expect(e.combatPool, 5);

      // Now can attack player directly!
      e.handle(0, {'type': 'attack_player'});
      expect(e.authority[1], 45);
    });
  });

  test('sims', () {
    expect(runSims(euro8Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
