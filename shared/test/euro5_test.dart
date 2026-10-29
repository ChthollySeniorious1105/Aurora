import 'dart:math';

import 'package:aurora_shared/games/euro5/biblios.dart';
import 'package:aurora_shared/games/euro5/defs.dart';
import 'package:aurora_shared/games/euro5/lasvegas.dart';
import 'package:aurora_shared/games/euro5/portroyal.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

void main() {
  group('euro5 unit tests', () {
    test('PortRoyal: ship repel vs bust, jester bonus, trade allowance & expedition claim', () {
      final def = euro5Games.firstWhere((d) => d.id == 'portroyal');
      final g = def.create(GameSetup(
        players: 3,
        options: def.defaultOptions(),
        names: const ['A', 'B', 'C'],
        bots: const [false, false, false],
        rng: Random(42),
      )) as PortRoyalGame;
      g.start();

      // Give player 1 a Jester to verify jester bust payout
      g.crew[1].add({
        'id': 'p_jester',
        'type': 'person',
        'role': 'jester',
        'name': '小丑',
        'cost': 4,
        'vp': 1,
      });

      // Force top of deck to have two yellow ships with swords=2
      g.harbor.clear();
      g.deck.add({
        'id': 's_y2',
        'type': 'ship',
        'color': 'yellow',
        'name': '黄帆商船',
        'coins': 2,
        'swords': 2,
        'skull': false,
      });
      g.deck.add({
        'id': 's_y1',
        'type': 'ship',
        'color': 'yellow',
        'name': '黄帆商船',
        'coins': 2,
        'swords': 2,
        'skull': false,
      });

      // First flip puts yellow ship into harbor
      g.handle(0, {'type': 'flip'});
      expect(g.harbor.length, 1);
      expect(g.turn, 0);

      // Second flip with 0 swords busts!
      final p1CoinsBefore = g.coins[1];
      g.handle(0, {'type': 'flip'});
      expect(g.harbor, isEmpty);
      expect(g.turn, 1); // advanced turn
      expect(g.coins[1], p1CoinsBefore + 1); // Jester triggered!

      // Now give player 1 a pirate (2 swords) so duplicate ship with 2 swords is repelled
      g.crew[1].add({
        'id': 'p_pirate',
        'type': 'person',
        'role': 'pirate',
        'name': '海盗猎人',
        'cost': 5,
        'vp': 1,
        'swords': 2,
      });
      g.deck.add({
        'id': 's_b2',
        'type': 'ship',
        'color': 'blue',
        'name': '蓝帆商船',
        'coins': 3,
        'swords': 2,
        'skull': false,
      });
      g.deck.add({
        'id': 's_b1',
        'type': 'ship',
        'color': 'blue',
        'name': '蓝帆商船',
        'coins': 3,
        'swords': 2,
        'skull': false,
      });
      g.handle(1, {'type': 'flip'});
      expect(g.harbor.length, 1);
      g.handle(1, {'type': 'flip'}); // Repelled!
      expect(g.turn, 1);
      expect(g.harbor.length, 1);
    });

    test('LasVegas: tie-breaker cancels tied leaders and awards next unique player', () {
      final def = euro5Games.firstWhere((d) => d.id == 'lasvegas');
      final g = def.create(GameSetup(
        players: 3,
        options: {'rounds': 3, 'neutral': false},
        names: const ['A', 'B', 'C'],
        bots: const [false, false, false],
        rng: Random(99),
      )) as LasVegasGame;
      g.start();

      // Set up Casino 1 with [$80k, $30k] and tied players 0 and 1 at 4 dice, player 2 at 1 die
      g.casinoBanknotes[0] = [80, 30];
      g.casinoDice[0] = [4, 4, 1];
      final m2Before = g.money[2];
      final res = g.resolveSingleCasino(0, applyMoney: true);
      expect(res['tiedSeats'], containsAll([0, 1]));
      expect(g.money[0], 0);
      expect(g.money[1], 0);
      expect(g.money[2], m2Before + 80); // Player 2 takes top banknote!
    });

    test('Biblios: gift allocation, church die adjustment, auction & tie-breaker scoring', () {
      final def = euro5Games.firstWhere((d) => d.id == 'biblios');
      final g = def.create(GameSetup(
        players: 3,
        options: def.defaultOptions(),
        names: const ['A', 'B', 'C'],
        bots: const [false, false, false],
        rng: Random(17),
      )) as BibliosGame;
      g.start();

      // Force currentCard to be a church card with 1 adjustment
      g.currentCard = {'id': 'test_ch', 'type': 'church', 'adjusts': 1, 'name': '主教手谕'};
      final oldDie0 = g.dice[0];
      g.handle(0, {'type': 'allocate', 'dest': 'keep'});
      expect(g.churchRemaining, 1);
      expect(g.waitingFor, [0]);
      g.handle(0, {'type': 'church', 'cat': 0, 'delta': 1});
      expect(g.dice[0], oldDie0 + 1);
      expect(g.churchRemaining, 0);
    });

    test('Simulate 30 games for all euro5 games & option combinations', () {
      final fails = runSims(euro5Games, n: 30);
      expect(fails, 0);
    });
  });
}
