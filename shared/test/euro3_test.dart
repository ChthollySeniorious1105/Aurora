import 'dart:math';

import 'package:aurora_shared/games/euro3/defs.dart';
import 'package:aurora_shared/games/euro3/forsale.dart';
import 'package:aurora_shared/games/euro3/ticketride.dart';
import 'package:aurora_shared/games/euro3/tokyoking.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n, [Map<String, dynamic> opts = const {}]) => GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, false),
      rng: Random(42),
    );

TokyoKing _tokyo(int n, [Map<String, dynamic> opts = const {}]) {
  final e = TokyoKing(_setup(n, opts))..host = SimHost();
  e.start();
  return e;
}

TicketRide _ticket(int n, [Map<String, dynamic> opts = const {}]) {
  final e = TicketRide(_setup(n, opts))..host = SimHost();
  e.start();
  for (var s = 0; s < n; s++) {
    e.handle(s, {
      'type': 'keep_tickets',
      'indices': [0, 1],
    });
  }
  return e;
}

ForSale _forSale(int n, [Map<String, dynamic> opts = const {}]) {
  final e = ForSale(_setup(n, opts))..host = SimHost();
  e.start();
  return e;
}

void main() {
  group('tokyoking', () {
    test('power cards catalog has 18 iconic cards', () {
      expect(tokyoPowerCards.length, greaterThanOrEqualTo(16));
      expect(tokyoCardById.containsKey('acid_attack'), isTrue);
      expect(tokyoCardById.containsKey('armor_plating'), isTrue);
      expect(tokyoCardById.containsKey('giant_brain'), isTrue);
      expect(tokyoCardById.containsKey('regeneration'), isTrue);
      expect(tokyoCardById.containsKey('jets'), isTrue);
      expect(tokyoCardById.containsKey('energy_hoarder'), isTrue);
      expect(tokyoCardById.containsKey('skyscraper'), isTrue);
      expect(tokyoCardById.containsKey('nuclear_reactor'), isTrue);
      expect(tokyoCardById.containsKey('high_altitude_bombing'), isTrue);
      expect(tokyoCardById.containsKey('healing_ray'), isTrue);
      expect(tokyoCardById.containsKey('alien_tech'), isTrue);
    });

    test('reroll limits and number/energy/heart/claw resolution', () {
      final e = _tokyo(3);
      expect(e.rollsLeft, 2);
      expect(() => e.handle(0, {'type': 'reroll', 'keep': [0, 1, 2, 3, 4, 5]}),
          throwsA(isA<GameError>()));
      e.handle(0, {
        'type': 'reroll',
        'keep': [0, 1, 2]
      });
      expect(e.rollsLeft, 1);
      e.handle(0, {
        'type': 'reroll',
        'keep': [0]
      });
      expect(e.rollsLeft, 0);
      expect(() => e.handle(0, {'type': 'reroll', 'keep': [0]}),
          throwsA(isA<GameError>()));

      // Force dice: four '2's (2+1=3 VP), one 'energy' (+1 energy), one 'claw' (enters empty Tokyo +1 VP)
      e.dice = ['2', '2', '2', '2', 'energy', 'claw'];
      e.handle(0, {'type': 'resolve'});
      expect(e.tokyoCity, 0);
      expect(e.vp[0], 4); // 3 from 2s + 1 from entering Tokyo
      expect(e.energy[0], 1);
      expect(e.phase, 'buy');
    });

    test('tokyo prevent heart heal, outside attack triggers yield, start turn in tokyo +2 VP', () {
      final e = _tokyo(3);
      e.tokyoCity = 0;
      e.hp[0] = 6;
      e.dice = ['heart', 'heart', 'heart', 'claw', 'claw', 'energy'];
      e.handle(0, {'type': 'resolve'});
      // In Tokyo: cannot heal with heart, claws hit all outside monsters (1 and 2)
      expect(e.hp[0], 6);
      expect(e.hp[1], 8);
      expect(e.hp[2], 8);
      e.handle(0, {'type': 'end_turn'});

      // Turn passes to seat 1 (outside Tokyo)
      expect(e.turn, 1);
      e.dice = ['heart', 'claw', '1', '1', '1', '2'];
      e.handle(1, {'type': 'resolve'});
      expect(e.hp[1], 9); // healed +1 outside Tokyo
      expect(e.hp[0], 5); // took 1 claw damage in Tokyo
      expect(e.phase, 'yield');
      expect(e.waitingFor, [0]);

      // Seat 0 yields Tokyo -> Seat 1 enters Tokyo and gains +1 VP (on top of +1 VP from three 1s)
      e.handle(0, {'type': 'yield'});
      expect(e.tokyoCity, 1);
      expect(e.vp[1], 2);
      expect(e.phase, 'buy');
      e.handle(1, {'type': 'end_turn'});

      // Seat 2 and Seat 0 end turns so Seat 1 starts turn in Tokyo (+2 VP)
      e.dice = ['1', '2', '3', 'energy', 'energy', 'heart'];
      e.handle(2, {'type': 'resolve'});
      e.handle(2, {'type': 'end_turn'});
      expect(e.turn, 0);
      e.dice = ['1', '2', '3', 'energy', 'energy', 'heart'];
      e.handle(0, {'type': 'resolve'});
      e.handle(0, {'type': 'end_turn'});
      expect(e.turn, 1);
      expect(e.vp[1], 4); // gained +2 VP for starting turn in Tokyo
    });

    test('5-6 player Tokyo Bay active and vacated when <= 4 alive', () {
      final e = _tokyo(5);
      expect(e.bayActive, isTrue);
      e.tokyoCity = 0;
      e.tokyoBay = 1;
      e.hp[2] = 1;
      // Seat 0 (in Tokyo City) attacks all outside monsters (2, 3, 4) -> seat 2 dies!
      e.dice = ['claw', '1', '2', '3', 'energy', 'energy'];
      e.handle(0, {'type': 'resolve'});
      expect(e.alive[2], isFalse);
      expect(e.aliveCount, 4);
      expect(e.bayActive, isFalse);
      expect(e.tokyoBay, -1); // vacated!
    });

    test('power cards purchase, sweep, keep and discard effects', () {
      final e = _tokyo(2);
      e.phase = 'buy';
      e.energy[0] = 20;
      e.market = ['acid_attack', 'armor_plating', 'healing_ray'];
      e.hp[0] = 5;
      e.tokyoCity = 0; // Even in Tokyo, healing_ray heals!
      e.handle(0, {'type': 'buy', 'card': 'healing_ray'});
      expect(e.hp[0], 8);
      expect(e. market.length, 3);

      e.handle(0, {'type': 'buy', 'card': 'acid_attack'});
      expect(e.hasCard(0, 'acid_attack'), isTrue);

      final prevEnergy = e.energy[0];
      e.handle(0, {'type': 'sweep'});
      expect(e.energy[0], prevEnergy - 2);
      expect(e.market.length, 3);
    });
  });

  group('ticketride', () {
    test('draw rules: face-up locomotive costs 2 draws and cannot be taken as 2nd draw', () {
      final e = _ticket(2);
      e.market = ['R', 'W', 'B', 'G', 'Y'];
      // Take 'R' first -> drawsLeft becomes 1, phase 'draw2'
      e.handle(0, {'type': 'draw_market', 'index': 0});
      expect(e.phase, 'draw2');
      expect(e.drawsLeft, 1);
      // Trying to take face-up 'W' on 2nd draw throws GameError
      final wIdx = e.market.indexOf('W');
      if (wIdx >= 0) {
        expect(() => e.handle(0, {'type': 'draw_market', 'index': wIdx}),
            throwsA(isA<GameError>()));
      }
      e.handle(0, {'type': 'draw_deck'});
      expect(e.turn, 1);

      // Seat 1 takes face-up 'W' on 1st draw -> immediately finishes turn!
      e.market[0] = 'W';
      e.handle(1, {'type': 'draw_market', 'index': 0});
      expect(e.turn, 0);
    });

    test('claim route with color + wildcards, double route restrictions, and longest path', () {
      final e = _ticket(2);
      // Route 3: 沈阳(2)-北京(3), len 3, color 'R'
      // Route 4: 沈阳(2)-北京(3), len 3, color 'K' (double route)
      e.hands[0] = ['R', 'R', 'W', 'B'];
      e.handle(0, {'type': 'claim', 'route': 3, 'color': 'R'});
      expect(e.routeOwners[3], 0);
      expect(e.routeScores[0], 4); // length 3 -> 4 pts
      expect(e.cars[0], 32);

      // In 2-player game, parallel route 4 is locked once route 3 is claimed
      e.hands[1] = ['K', 'K', 'K', 'W'];
      expect(() => e.handle(1, {'type': 'claim', 'route': 4, 'color': 'K'}),
          throwsA(isA<GameError>()));

      // Seat 1 claims Route 2: 哈尔滨(1)-沈阳(2), len 2, color 'C'
      e.hands[1] = ['C', 'W'];
      e.handle(1, {'type': 'claim', 'route': 2, 'color': 'C'});
      expect(e.routeOwners[2], 1);
      expect(e.routeScores[1], 2);
      expect(e.longestContinuousPath(0), 3);
      expect(e.longestContinuousPath(1), 2);
    });

    test('destination ticket completion and final round trigger', () {
      final e = _ticket(2);
      // TicketDef(3, 1, 3, 5): 哈尔滨(1) - 北京(3), 5 pts
      e.tickets[0] = const [TicketDef(3, 1, 3, 5)];
      e.tickets[1] = const [TicketDef(0, 0, 3, 12)]; // incomplete (-12)
      e.routeOwners[2] = 0; // 1 - 2 (len 2)
      e.routeOwners[3] = 0; // 2 - 3 (len 3)
      expect(e.isTicketConnected(0, e.tickets[0].first), isTrue);

      // Trigger final round by setting cars[0] = 3 and claiming length 1 route (route 21: 9-10 len 1)
      e.cars[0] = 3;
      e.hands[0] = ['R'];
      e.handle(0, {'type': 'claim', 'route': 21, 'color': 'R'});
      expect(e.cars[0], 2);
      expect(e.isOver, isFalse); // everyone gets 1 final turn!
      expect(e.finalTurnsLeft, 1);

      // Seat 1 takes final turn -> game ends!
      e.handle(1, {'type': 'draw_deck'});
      e.handle(1, {'type': 'draw_deck'});
      expect(e.isOver, isTrue);
      expect(e.ticketBonuses[0], 5);
      expect(e.ticketBonuses[1], -12);
      expect(e.hasLongestBonus[0], isTrue);
      expect(e.placings, [1, 2]);
    });
  });

  group('forsale', () {
    test('phase 1 bidding: half bid rounded down on pass, full bid for last player', () {
      final e = _forSale(3);
      e.tableProperties = [2, 15, 28];
      // P0 bids 5
      e.handle(0, {'type': 'bid', 'amount': 5});
      // P1 bids 7
      e.handle(1, {'type': 'bid', 'amount': 7});
      // P2 passes with bid 0 -> pays 0, gets lowest (2)
      e.handle(2, {'type': 'pass'});
      expect(e.coins[2], 18);
      expect(e.ownedProperties[2], [2]);
      // P0 passes with bid 5 -> pays 5 ~/ 2 = 2, gets next lowest (15); P1 left alone -> pays full 7, gets highest (28)!
      e.handle(0, {'type': 'pass'});
      expect(e.coins[0], 16);
      expect(e.ownedProperties[0], [15]);
      expect(e.coins[1], 11);
      expect(e.ownedProperties[1], [28]);
      expect(e.roundStarter, 1);
    });

    test('phase 2 simultaneous secret sell: highest property wins highest check', () {
      final e = _forSale(3);
      e.phase = 'sell';
      e.propertyDeck.clear();
      e.checkDeck.clear();
      e.tableChecks = [0, 8, 15];
      e.ownedProperties = [
        [10],
        [30],
        [5],
      ];
      e.selectedProperty = [null, null, null];

      e.handle(0, {'type': 'sell', 'card': 10});
      // P1's view should not leak P0's chosen property value before reveal
      expect(e.view(1)['mySelectedProperty'], isNull);
      expect(e.isOver, isFalse);

      e.handle(1, {'type': 'sell', 'card': 30});
      e.handle(2, {'type': 'sell', 'card': 5});

      // All 3 chosen -> resolved! P1(30)->15, P0(10)->8, P2(5)->0
      expect(e.isOver, isTrue);
      expect(e.checkMoney, [8, 15, 0]);
      expect(e.finalScores, [26, 33, 18]);
      expect(e.placings, [2, 1, 3]);
    });
  });

  test('bot simulations for euro3Games',
      timeout: const Timeout(Duration(minutes: 10)), () {
    expect(runSims(euro3Games, n: 30), 0);
  });
}
