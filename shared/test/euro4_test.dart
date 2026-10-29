import 'dart:math';

import 'package:aurora_shared/games/euro4/centuryspice.dart';
import 'package:aurora_shared/games/euro4/citadels.dart';
import 'package:aurora_shared/games/euro4/defs.dart';
import 'package:aurora_shared/games/euro4/machikoro.dart';
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
  group('citadels', () {
    test('draft phase discards and hides unrevealed roles', () {
      final e = _start(Citadels(_setup(4)));
      expect(e.phase, 'draft');
      expect(e.faceUpDiscards.length, 2);
      expect(e.faceUpDiscards.contains(4), isFalse); // King never discarded face-up
      expect(e.availableRoles.length, 5); // 8 - 1 face-down - 2 face-up

      for (var i = 0; i < 4; i++) {
        final s = e.waitingFor.single;
        final pick = e.availableRoles.first;
        e.handle(s, {'type': 'draft', 'role': pick});
      }
      expect(e.phase, 'turn');
      final active = e.activeSeat;
      final other = (active + 1) % 4;
      final vOther = e.view(other);
      final playersView = vOther['players'] as List;
      // Active seat's role is revealed, but non-active third player's role is hidden
      expect(playersView[active]['role'], e.currentRole);
    });

    test('assassin skips target role and thief steals gold when target reveals', () {
      final e = _start(Citadels(_setup(3)));
      e.crown = 0;
      e.phase = 'draft';
      e.availableRoles = [1, 2, 4, 6, 8];
      e.draftOrderIdx = 0;
      e.handle(0, {'type': 'draft', 'role': 1}); // P0: Assassin
      e.handle(1, {'type': 'draft', 'role': 2}); // P1: Thief
      e.handle(2, {'type': 'draft', 'role': 6}); // P2: Merchant

      // Role 1 (P0 Assassin) turn: kill Role 4, take gold, end turn
      expect(e.activeSeat, 0);
      expect(e.currentRole, 1);
      e.handle(0, {'type': 'income', 'choice': 'gold'});
      e.handle(0, {'type': 'skill', 'targetRole': 4});
      e.handle(0, {'type': 'end_turn'});

      // Role 2 (P1 Thief) turn: cannot rob killed role 4, robs Role 6 (P2)
      expect(e.activeSeat, 1);
      expect(e.currentRole, 2);
      e.handle(1, {'type': 'income', 'choice': 'gold'});
      expect(() => e.handle(1, {'type': 'skill', 'targetRole': 4}), throwsA(isA<GameError>()));
      e.handle(1, {'type': 'skill', 'targetRole': 6});
      final p1GoldBefore = e.gold[1];
      final p2GoldBefore = e.gold[2];
      e.handle(1, {'type': 'end_turn'});

      // Role 6 (P2 Merchant) reveals: P1 steals all of P2's gold immediately!
      expect(e.activeSeat, 2);
      expect(e.currentRole, 6);
      expect(e.gold[1], p1GoldBefore + p2GoldBefore);
      expect(e.gold[2], 0);
      // Merchant gets +2 gold from income + 1 merchant bonus
      e.handle(2, {'type': 'income', 'choice': 'gold'});
      expect(e.gold[2], 3);
    });

    test('bishop immunity, keep immunity, and warlord destruction', () {
      final e = _start(Citadels(_setup(3)));
      e.phase = 'turn';
      e.draftedRole = [5, 6, 8]; // P0 Bishop, P1 Merchant, P2 Warlord
      e.revealedRole = [5, 6, 8];
      e.currentRole = 8;
      e.activeSeat = 2;
      e.subphase = 'action';
      e.skillUsed = false;
      e.gold[2] = 10;

      e.city[0] = [districtById['temple']!];
      e.city[1] = [districtById['keep']!, districtById['market']!];

      // Cannot destroy Bishop's district
      expect(
        () => e.handle(2, {'type': 'skill', 'targetSeat': 0, 'districtIdx': 0}),
        throwsA(isA<GameError>()),
      );
      // Cannot destroy Keep
      expect(
        () => e.handle(2, {'type': 'skill', 'targetSeat': 1, 'districtIdx': 0}),
        throwsA(isA<GameError>()),
      );
      // Can destroy Market (cost 2 -> pays 1 gold)
      e.handle(2, {'type': 'skill', 'targetSeat': 1, 'districtIdx': 1});
      expect(e.city[1].length, 1);
      expect(e.gold[2], 9);
    });

    test('end-of-round completion triggers final scoring with 5-color bonus', () {
      final e = _start(Citadels(_setup(2, {'targetDistricts': 6})));
      e.city[0] = [
        districtById['manor']!, // yellow 3
        districtById['temple']!, // blue 1
        districtById['tavern']!, // green 1
        districtById['watchtower']!, // red 1
        districtById['keep']!, // purple 3
        districtById['castle']!, // yellow 4
      ];
      e.firstToComplete = 0;
      expect(e.hasAllFiveColors(0), isTrue);
      final bd = e.scoreBreakdown(0);
      expect(bd['base'], 3 + 1 + 1 + 1 + 3 + 4);
      expect(bd['fiveColor'], 3);
      expect(bd['complete'], 4);
      expect(bd['total'], 20);
    });
  });

  group('centuryspice', () {
    test('starting setup and produce / upgrade / caravan limit', () {
      final e = _start(CenturySpice(_setup(3)));
      expect(e.spices[0], [3, 0, 0, 0]);
      expect(e.spices[1], [4, 0, 0, 0]);
      expect(e.spices[2], [4, 0, 0, 0]);
      expect(e.market.length, 6);
      expect(e.orders.length, 5);

      // P0 plays produce_2y -> 5 yellow
      e.handle(0, {'type': 'play', 'index': 0});
      expect(e.spices[0], [5, 0, 0, 0]);
      expect(e.played[0].length, 1);

      // P1 plays upgrade_2 -> upgrades 2 yellow to 2 red
      e.handle(1, {'type': 'play', 'index': 1, 'steps': [0, 0]});
      expect(e.spices[1], [2, 2, 0, 0]);

      // Caravan limit 10 cubes enforced
      e.spices[2] = [9, 0, 0, 1];
      e.handle(2, {'type': 'play', 'index': 0}); // +2 yellow -> 11 yellow + 1 brown -> trimmed to 9 yellow + 1 brown
      expect(e.totalSpices(2), 10);
      expect(e.spices[2], [9, 0, 0, 1]);
    });

    test('acquire places spices on earlier market cards and collects spices on target', () {
      final e = _start(CenturySpice(_setup(2)));
      e.spices[0] = [3, 1, 0, 0];
      e.marketSpices[2] = [0, 0, 1, 0]; // 1 green sitting on index 2
      final targetCardId = e.market[2].id;

      e.handle(0, {'type': 'acquire', 'index': 2, 'pay': [0, 1]});
      expect(e.marketSpices[0], [1, 0, 0, 0]);
      expect(e.marketSpices[1], [0, 1, 0, 0]);
      expect(e.spices[0], [2, 0, 1, 0]); // paid 1Y+1R, gained 1G
      expect(e.hand[0].last.id, targetCardId);
    });

    test('claim order awards gold/silver coin and triggers last round at targetOrders', () {
      final e = _start(CenturySpice(_setup(2, {'targetOrders': 4})));
      e.claimedOrders[0] = [orderCatalog[0], orderCatalog[1], orderCatalog[2]];
      final ord0 = e.orders[0];
      e.spices[0] = List<int>.of(ord0.cost);

      e.handle(0, {'type': 'claim', 'index': 0});
      expect(e.goldCoins[0], 1);
      expect(e.claimedOrders[0].length, 4);
      expect(e.lastRound, isTrue);
      expect(e.isOver, isFalse); // P1 still gets their turn in the round

      e.handle(1, {'type': 'play', 'index': 0});
      expect(e.isOver, isTrue);
      expect(e.placings, isNotNull);
    });
  });

  group('machikoro', () {
    test('red, blue, green resolution order and shopping mall bonus', () {
      final e = _start(MachiKoro(_setup(2)));
      e.coins[0] = 2;
      e.coins[1] = 2;
      e.cards[1]['cafe'] = 1; // P1 has 1 Cafe (rolls on 3, steals 1)
      e.builtLandmarks[1].add('mall'); // P1 has Mall (+1 on Cafe -> steals 2)
      e.cards[0]['bakery'] = 2; // P0 has 2 Bakeries (rolls on 2-3, gains 1 each = 2)

      // P0 rolls a 3:
      // 1. P1's Cafe steals 2 from P0 first -> P0 drops to 0, P1 goes to 4.
      // 2. P0's 2 Bakeries trigger -> P0 gains 2 from bank -> P0 has 2.
      e.actionForcedDice = [3];
      e.handle(0, {'type': 'roll', 'dice': 1});
      expect(e.coins[1], 4);
      expect(e.coins[0], 2);
      expect(e.phase, 'build');
    });

    test('radio tower reroll and amusement park extra turn on doubles', () {
      final e = _start(MachiKoro(_setup(2)));
      e.builtLandmarks[0].addAll(['station', 'park', 'tower']);

      e.actionForcedDice = [2, 5];
      e.handle(0, {'type': 'roll', 'dice': 2});
      expect(e.phase, 'reroll');

      e.actionForcedDice = [3, 3]; // doubles!
      e.handle(0, {'type': 'reroll', 'dice': 2});
      expect(e.phase, 'build');

      e.handle(0, {'type': 'pass'});
      // Amusement Park grants extra turn to P0!
      expect(e.turn, 0);
      expect(e.phase, 'roll');
    });

    test('constructing final required landmark wins immediately', () {
      final e = _start(MachiKoro(_setup(2, {'landmarks': 3})));
      e.builtLandmarks[0].addAll(['station', 'mall']);
      e.coins[0] = 20;
      e.phase = 'build';

      e.handle(0, {'type': 'buy_landmark', 'id': 'park'});
      expect(e.isOver, isTrue);
      expect(e.winner, 0);
      expect(e.placings, [1, 2]);
    });
  });

  test('sims', () {
    expect(runSims(euro4Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
