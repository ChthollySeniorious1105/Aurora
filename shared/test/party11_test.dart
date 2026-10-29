import 'dart:math';

import 'package:aurora_shared/games/party11/cashnguns.dart';
import 'package:aurora_shared/games/party11/defs.dart';
import 'package:aurora_shared/games/party11/highsociety.dart';
import 'package:aurora_shared/games/party11/mascarade.dart';
import 'package:aurora_shared/games/party11/sherlock13.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n, {Map<String, dynamic> opts = const {}, bool bots = false, int seed = 7}) => GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, bots),
      rng: Random(seed),
    );

T _start<T extends GameEngine>(T e) {
  final h = SimHost();
  e.host = h;
  e.start();
  h.runPending();
  return e;
}

void main() {
  group('High Society (highsociety)', () {
    test('normal auction: passing takes back bid, winner spends bid', () {
      final g = _start(HighSocietyGame(_setup(3)));
      expect(g.hands[0], kHighSocietyMoney);
      expect(g.handSum(0), 106);
      g.currentCard = kHighSocietyDeck.firstWhere((c) => c.id == 'lux_8');
      g.turn = 0;

      g.handle(0, {'type': 'bid', 'cards': [6]});
      expect(g.highestBid, 6);
      expect(g.handSum(0), 100);
      // Bid must strictly exceed current highest bid
      expect(() => g.handle(1, {'type': 'bid', 'cards': [6]}), throwsA(isA<GameError>()));
      g.handle(1, {'type': 'bid', 'cards': [10]});
      expect(g.highestBid, 10);

      // P2 passes (had 0 bid)
      g.handle(2, {'type': 'pass'});
      expect(g.handSum(2), 106);

      // P0 passes -> immediately takes back their 6k bid into hand!
      g.handle(0, {'type': 'pass'});
      expect(g.handSum(0), 106);
      // P1 wins luxury 8 and spends their 10k bid
      expect(g.handSum(1), 96);
      expect(g.prestigeOf(1), 8);
      expect(g.turn, 1);
    });

    test('reverse auction on disgrace card: first passer keeps money, others lose bids', () {
      final g = _start(HighSocietyGame(_setup(3)));
      g.currentCard = kHighSocietyDeck.firstWhere((c) => c.id == 'passe');
      g.turn = 0;

      g.handle(0, {'type': 'bid', 'cards': [4]});
      g.handle(1, {'type': 'bid', 'cards': [8]});
      // P2 is the first to pass: takes Passé (-5) and keeps all 106k; P0 loses 4k, P1 loses 8k!
      g.handle(2, {'type': 'pass'});
      expect(g.handSum(2), 106);
      expect(g.handSum(0), 102);
      expect(g.handSum(1), 98);
      expect(g.won[2].any((c) => c.id == 'passe'), isTrue);
    });

    test('4th dark-green card triggers immediate game end and poorest player is eliminated', () {
      final g = _start(HighSocietyGame(_setup(3)));
      // Give P0 huge prestige (10 * 2 = 20) but lowest money (50k)
      g.hands[0] = [25, 20, 4]; // 49k (poorest!)
      g.hands[1] = [25, 20, 15, 10]; // 70k
      g.hands[2] = [25, 20, 15, 12]; // 72k
      g.won[0] = [
        kHighSocietyDeck.firstWhere((c) => c.id == 'lux_10'),
        kHighSocietyDeck.firstWhere((c) => c.id == 'mult_1'),
      ];
      g.won[1] = [kHighSocietyDeck.firstWhere((c) => c.id == 'lux_5')];
      g.won[2] = [kHighSocietyDeck.firstWhere((c) => c.id == 'lux_2')];

      g.darkGreenCount = 3;
      g.deck = [kHighSocietyDeck.firstWhere((c) => c.id == 'scandale')];
      g.flipNextCard();

      expect(g.isOver, isTrue);
      expect(g.isPoorest(0), isTrue);
      expect(g.placings![1], 1); // P1 wins despite P0 having higher prestige
      expect(g.placings![2], 2);
      expect(g.placings![0], 3); // Poorest player eliminated -> last place
    });

    test('faux pas discards luxury card when player has 2+ luxuries', () {
      final g = _start(HighSocietyGame(_setup(3)));
      g.won[0] = [
        kHighSocietyDeck.firstWhere((c) => c.id == 'lux_3'),
        kHighSocietyDeck.firstWhere((c) => c.id == 'lux_9'),
      ];
      g.currentCard = kHighSocietyDeck.firstWhere((c) => c.id == 'faux_pas');
      g.turn = 0;

      // P0 passes first on Faux Pas -> must choose which luxury card to discard
      g.handle(0, {'type': 'pass'});
      expect(g.phase, 'faux_pas');
      expect(g.waitingFor, [0]);
      g.handle(0, {'type': 'discard_luxury', 'card': 'lux_3'});
      expect(g.prestigeOf(0), 9);
      expect(g.phase, 'auction');
    });
  });

  group('Cash n Guns (cashnguns)', () {
    test('standoff: ducking avoids bang, standing victim takes wound and loses loot split', () {
      final g = _start(CashNGunsGame(_setup(3)));
      expect(g.ammo[0].where((b) => b == 'click').length, 5);
      expect(g.ammo[0].where((b) => b == 'bang').length, 3);

      // P0 aims bang at P1, P1 aims bang at P2, P2 aims click at P0
      g.handle(0, {'type': 'aim', 'target': 1, 'bullet': 'bang'});
      g.handle(1, {'type': 'aim', 'target': 2, 'bullet': 'bang'});
      g.handle(2, {'type': 'aim', 'target': 0, 'bullet': 'click'});
      expect(g.phase, 'courage');

      // P0 stays, P1 stays (gets shot by P0!), P2 ducks (avoids P1's bang!)
      g.handle(0, {'type': 'courage', 'choice': 'stay'});
      g.handle(1, {'type': 'courage', 'choice': 'stay'});
      g.handle(2, {'type': 'courage', 'choice': 'duck'});

      expect(g.wounds[0], 0);
      expect(g.wounds[1], 1); // Hit by P0's bang
      expect(g.wounds[2], 0); // Ducked out safely
      // Only P0 is unscathed & standing -> P0 drafts all 8 loot cards
      expect(g.phase, 'loot');
      expect(g.looters, [0]);
    });

    test('diamonds majority bonus and painting set collection scoring', () {
      final g = _start(CashNGunsGame(_setup(3)));
      g.lootWon[0] = [
        const LootCard(id: 'd1', kind: 'diamond', value: 5000, name: 'D'),
        const LootCard(id: 'd2', kind: 'diamond', value: 1000, name: 'D'),
      ];
      g.lootWon[1] = [
        const LootCard(id: 'p1', kind: 'painting', value: 0, name: 'P'),
        const LootCard(id: 'p2', kind: 'painting', value: 0, name: 'P'),
        const LootCard(id: 'p3', kind: 'painting', value: 0, name: 'P'),
      ];
      // P0 has 2 diamonds -> 6,000 + 60,000 majority bonus = 66,000
      expect(g.totalCash(0), 66000);
      // P1 has 3 paintings -> 30,000
      expect(g.totalCash(1), 30000);
    });
  });

  group('Mascarade (mascarade)', () {
    test('swap and peek hide cards properly in view', () {
      final g = _start(MascaradeGame(_setup(3)));
      g.roles = [2, 3, 4]; // King, Queen, Thief
      g.turn = 0;

      // P0 swaps with P1 for real
      g.handle(0, {'type': 'swap', 'target': 1, 'doSwap': true});
      expect(g.roles[0], 3);
      expect(g.roles[1], 2);
      expect(g.view(0)['myRole'], -1);
      expect(g.view(1)['myRole'], -1);

      // P1 peeks at own card
      g.handle(1, {'type': 'peek'});
      expect(g.view(1)['peekedRole'], 2);
      expect(g.view(0)['peekedRole'], isNull);
    });

    test('claim challenge: real holder executes power and liars pay 1 coin to courthouse', () {
      final g = _start(MascaradeGame(_setup(3)));
      g.roles = [3, 2, 4]; // P0 has Queen(3), P1 has King(2), P2 has Thief(4)
      g.turn = 0;

      // P0 bluffs King(2)
      g.handle(0, {'type': 'claim', 'role': 2});
      expect(g.phase, 'challenge');
      // P1 challenges (actually holds King!), P2 also challenges (bluffing!)
      g.handle(1, {'type': 'challenge'});
      g.handle(2, {'type': 'challenge'});

      // P1 gets +3 coins from King (6 -> 9); P0 and P2 each pay 1 coin to Courthouse (6 -> 5)
      expect(g.coins[1], 9);
      expect(g.coins[0], 5);
      expect(g.coins[2], 5);
      expect(g.courthouse, 2);
    });

    test('cheat wins immediately at >= 10 coins and bankruptcy ends game', () {
      final g = _start(MascaradeGame(_setup(3)));
      g.coins[0] = 10;
      g.turn = 0;
      g.handle(0, {'type': 'claim', 'role': 6}); // Cheat
      g.handle(1, {'type': 'pass'});
      g.handle(2, {'type': 'pass'});
      expect(g.isOver, isTrue);
      expect(g.cheatWinner, 0);
      expect(g.placings![0], 1);
    });
  });

  group('Sherlock 13 (sherlock13)', () {
    test('inquiries and accusation deduction', () {
      final g = _start(Sherlock13Game(_setup(3)));
      g.culprit = 2; // Moriarty [1, 4, 7]
      g.hands[0] = [0, 1, 3, 4];
      g.hands[1] = [5, 6, 7, 8];
      g.hands[2] = [9, 10, 11, 12];
      g.turn = 0;

      expect(g.view(0)['culprit'], -1);
      g.handle(0, {'type': 'ask_all', 'symbol': 7}); // Skull (on 2, 3, 12)
      // P0 has 3, P2 has 12, P1 has none
      expect(g.publicHasSymbol[0][7], isTrue);
      expect(g.publicHasSymbol[1][7], isFalse);
      expect(g.publicHasSymbol[2][7], isTrue);

      g.handle(1, {'type': 'ask_one', 'target': 2, 'symbol': 7});
      expect(g.knownExactCounts[1]['2:7'], 1);

      // P2 accuses wrong suspect -> eliminated
      g.handle(2, {'type': 'accuse', 'suspect': 0});
      expect(g.eliminated[2], isTrue);
      expect(g.isOver, isFalse);

      // P0 accuses actual culprit (2) -> wins immediately!
      g.handle(0, {'type': 'accuse', 'suspect': 2});
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.placings, [1, 2, 2]);
    });
  });

  test('party11 sims (30 games per player count and option)', () {
    expect(runSims(party11Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
