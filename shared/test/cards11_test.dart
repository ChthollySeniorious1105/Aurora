import 'dart:math';

import 'package:aurora_shared/games/cards11/bohnanza.dart';
import 'package:aurora_shared/games/cards11/defs.dart';
import 'package:aurora_shared/games/cards11/pinochle.dart';
import 'package:aurora_shared/games/cards11/skat.dart';
import 'package:aurora_shared/games/cards11/yaniv.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

List<String> cs(String s) => s.split(' ');

GameSetup _setup(int n, Map<String, dynamic> opts, {int seed = 1}) => GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, true),
      rng: Random(seed),
    );

void main() {
  group('Skat (德国斯卡特)', () {
    test('32-card deck, 120 total points, and 4 Jacks (JC > JS > JH > JD) trump hierarchy', () {
      final deck = buildSkatDeck();
      expect(deck.length, 32);
      final totalPts = deck.fold<int>(0, (s, c) => s + skatCardPoints(c));
      expect(totalPts, 120);

      // In Suit ('H') and Grand ('G'), all 4 Jacks belong to 'TRUMP'
      for (final j in ['JC', 'JS', 'JH', 'JD']) {
        expect(skatEffectiveSuit(j, 'H'), 'TRUMP');
        expect(skatEffectiveSuit(j, 'G'), 'TRUMP');
        expect(skatEffectiveSuit(j, 'N'), skatPrintedSuit(j));
      }
      expect(
        skatTrickStrength('JC', 'H', 'TRUMP'),
        greaterThan(skatTrickStrength('JS', 'H', 'TRUMP')),
      );
      expect(
        skatTrickStrength('JS', 'H', 'TRUMP'),
        greaterThan(skatTrickStrength('JH', 'H', 'TRUMP')),
      );
      expect(
        skatTrickStrength('JH', 'H', 'TRUMP'),
        greaterThan(skatTrickStrength('JD', 'H', 'TRUMP')),
      );
      expect(
        skatTrickStrength('JD', 'H', 'TRUMP'),
        greaterThan(skatTrickStrength('AH', 'H', 'TRUMP')),
      );
      expect(
        skatTrickStrength('TH', 'H', 'TRUMP'),
        greaterThan(skatTrickStrength('KH', 'H', 'TRUMP')),
      );
    });

    test('bid, take_skat, contract selection, and >= 61 point victory', () {
      final g = SkatGame(_setup(3, {'rounds': 1}))..start();
      expect(g.phase, 'bid');
      final f = g.forehand;
      final m = (f + 1) % 3;
      final r = (f + 2) % 3;

      g.handle(f, {'type': 'bid', 'value': 18});
      g.handle(m, {'type': 'pass'});
      g.handle(r, {'type': 'pass'});

      expect(g.phase, 'skat');
      expect(g.declarer, f);

      // Give declarer known 10 cards + 2 skat cards
      g.hands[f] = cs('JC JS JH JD AC TC KC QC 9C 8C');
      g.skat = cs('AD TD'); // 21 pts in skat!
      g.handle(f, {'type': 'take_skat', 'discards': ['AD', 'TD']});
      expect(g.phase, 'contract');
      expect(g.trickPoints[f], 21);

      g.handle(f, {'type': 'contract', 'contract': 'C'});
      expect(g.phase, 'play');

      // Play 10 tricks where declarer sweeps all 10 tricks (Schwarz + Schneider = 120 pts)
      g.hands[m] = cs('AS TS KS QS 9S 8S 7S 9D 8D 7D');
      g.hands[r] = cs('AH TH KH QH 9H 8H 7H KD QD 7C');

      for (var t = 0; t < 10; t++) {
        final lead = g.turn;
        final c0 = g.legalCards(lead).first;
        g.handle(lead, {'type': 'play', 'card': c0});
        final s1 = g.turn;
        g.handle(s1, {'type': 'play', 'card': g.legalCards(s1).first});
        final s2 = g.turn;
        g.handle(s2, {'type': 'play', 'card': g.legalCards(s2).first});
      }

      expect(g.isOver, isTrue);
      expect(g.lastHandSummary!['declarerWon'], isTrue);
      expect(g.lastHandSummary!['declarerPoints'], 120);
      expect(g.lastHandSummary!['schneider'], isTrue);
      expect(g.lastHandSummary!['schwarz'], isTrue);
      expect(g.scores[f], greaterThan(0));
    });

    test('Null Hand contract loses if Declarer takes even 1 trick', () {
      final g = SkatGame(_setup(3, {'rounds': 1}))..start();
      final f = g.forehand;
      final m = (f + 1) % 3;
      final r = (f + 2) % 3;

      g.handle(f, {'type': 'bid', 'value': 23});
      g.handle(m, {'type': 'pass'});
      g.handle(r, {'type': 'pass'});

      g.handle(f, {'type': 'hand'});
      g.handle(f, {'type': 'contract', 'contract': 'N'});
      expect(g.handGame, isTrue);
      expect(g.phase, 'play');

      // Fast-forward to 10th trick where declarer wins 1 trick -> loses -70 (2 * 35)!
      g.tricksPlayed = 9;
      g.tricksWon = [0, 5, 4];
      g.hands[f] = ['AS'];
      g.hands[m] = ['7S'];
      g.hands[r] = ['8S'];
      g.turn = f;

      g.handle(f, {'type': 'play', 'card': 'AS'});
      g.handle(m, {'type': 'play', 'card': '7S'});
      g.handle(r, {'type': 'play', 'card': '8S'});

      expect(g.isOver, isTrue);
      expect(g.lastHandSummary!['declarerWon'], isFalse);
      expect(g.scores[f], -70);
    });
  });

  group('Pinochle (皮诺克)', () {
    test('meld combinations: Flush/Run (150), Royal/Common Marriage, Double Pinochle (300), Arounds, Dix', () {
      final deck = buildPinochleDeck();
      expect(deck.length, 48);

      // Trump = 'S':
      // Run of Spades (AS, TS, KS, QS, JS) = 150
      // Double Pinochle (2x QS + 2x JD) = 300
      // Dix (9S) = 10
      // Common Marriage in Hearts (KH + QH) = 20
      // Four Aces (AS, AH, AD, AC) = 100
      final hand = cs('AS TS KS QS JS QS JD JD 9S KH QH AH AD AC');
      final meld = evaluatePinochleMelds(hand, 'S');
      expect(meld.points, 150 + 300 + 10 + 20 + 100);
    });

    test('bid, meld, and 12 tricks totaling 250 trick points with first-played tiebreak', () {
      final g = PinochleGame(_setup(4, {'rounds': 1}))..start();
      expect(g.phase, 'bid');
      final f = g.forehand;
      g.handle(f, {'type': 'bid', 'value': 200, 'trump': 'S'});
      g.handle((f + 1) % 4, {'type': 'pass'});
      g.handle((f + 2) % 4, {'type': 'pass'});
      g.handle((f + 3) % 4, {'type': 'pass'});

      expect(g.phase, 'meld');
      expect(g.declarer, f);
      expect(g.trumpSuit, 'S');

      g.handle(f, {'type': 'meld'});
      expect(g.phase, 'play');

      // Play all 12 tricks using legal cards
      while (!g.isOver) {
        final s = g.turn;
        final c = g.legalCards(s).first;
        g.handle(s, {'type': 'play', 'card': c});
      }

      // Total trick points across all 4 seats must equal 250!
      final totalTrickPts =
          (g.lastHandSummary!['trickPoints'] as List<int>).fold<int>(0, (a, b) => a + b);
      expect(totalTrickPts, 250);
    });
  });

  group('Yaniv (雅尼夫)', () {
    test('card values, single/set/run (with joker wildcard) discard validation', () {
      expect(yanivCardValue('BJ'), 0);
      expect(yanivCardValue('RJ'), 0);
      expect(yanivCardValue('AS'), 1);
      expect(yanivCardValue('7H'), 7);
      expect(yanivCardValue('JD'), 10);
      expect(yanivCardValue('KC'), 10);

      expect(isValidYanivDiscard(['9S']), isTrue);
      expect(isValidYanivDiscard(['7S', '7H', '7D']), isTrue);
      expect(isValidYanivDiscard(['7S', '8H']), isFalse);
      expect(isValidYanivDiscard(['3S', '4S', '5S']), isTrue);
      expect(isValidYanivDiscard(['3S', 'BJ', '5S']), isTrue);
      expect(isValidYanivDiscard(['3S', 'BJ', '7S']), isFalse);
    });

    test('successful Yaniv call vs Assaf (+30 penalty) and 50/100 halving bonus', () {
      final g = YanivGame(_setup(3, {'targetLimit': 100}))..start();
      g.scores = [20, 40, 10];
      g.hands = [
        cs('AS 2S 3S'), // sum = 6
        cs('5H 5D'), // sum = 10 -> 40 + 10 = 50 -> halves to 25!
        cs('KH QD'), // sum = 20 -> 10 + 20 = 30
      ];
      g.turn = 0;

      g.handle(0, {'type': 'yaniv'});
      expect(g.lastRoundSummary!['assaf'], isFalse);
      expect(g.scores[0], 20); // +0
      expect(g.scores[1], 25); // 40 + 10 = 50 -> halved to 25!
      expect(g.scores[2], 30); // 10 + 20 = 30

      // Now test Assaf: Seat 0 calls Yaniv with 6, but Seat 2 has 4 (<= 6)!
      g.hands = [
        cs('AS 2S 3S'), // sum = 6 -> Assaf! +30 + 6 = +36
        cs('TH'), // sum = 10 -> +10
        cs('AD 3D'), // sum = 4 (lowest <= 6) -> +0!
      ];
      g.turn = 0;
      g.handle(0, {'type': 'yaniv'});
      expect(g.lastRoundSummary!['assaf'], isTrue);
      expect(g.scores[0], 20 + 36);
      expect(g.scores[1], 25 + 10);
      expect(g.scores[2], 30 + 0);
    });
  });

  group('Bohnanza (种豆得豆)', () {
    test('104-card deck, locked hand[0] planting, Bean Protection Rule, and market flow', () {
      final deck = buildBohnanzaDeck();
      expect(deck.length, 104);
      expect(bohnanzaHarvestGold(0, 2), 2); // Garden Bean: 2 cards = 2G
      expect(bohnanzaHarvestGold(0, 3), 3); // Garden Bean: 3 cards = 3G
      expect(bohnanzaHarvestGold(7, 4), 1); // Blue Bean: 4 cards = 1G
      expect(bohnanzaHarvestGold(7, 10), 4); // Blue Bean: 10 cards = 4G

      final g = BohnanzaGame(_setup(3, {'deckCycles': 1}))..start();
      g.hands[0] = [1, 2, 3, 4, 5]; // hand[0] is 1 (Red Bean)
      g.fields[0] = [
        [3, 3], // 2 Soy Beans in field 0
        [4], // 1 Green Bean in field 1
      ];
      g.turn = 0;
      g.step = 'plant';

      // Bean Protection Rule: cannot harvest field 1 (1 bean) while field 0 has 2 beans!
      expect(
        () => g.handle(0, {'type': 'harvest', 'field': 1}),
        throwsA(isA<GameError>()),
      );

      // Harvesting field 0 (2 Soy Beans = 1 Gold) is legal!
      g.handle(0, {'type': 'harvest', 'field': 0});
      expect(g.gold[0], 1);
      expect(g.fields[0][0], isEmpty);

      // Must plant hand[0] (which is bean 1) into field 0
      g.handle(0, {'type': 'plant', 'field': 0});
      expect(g.fields[0][0], [1]);
      expect(g.hands[0], [2, 3, 4, 5]); // hand[0] was removed, order preserved!

      // End Step 1 -> flips 2 cards into market
      g.handle(0, {'type': 'done_plant'});
      expect(g.step, 'market');
      expect(g.market.length, 2);

      // Gift both market cards to opponents -> draws 3 cards to the BACK of hand[0]
      final beforeHand = List<int>.of(g.hands[0]);
      g.handle(0, {'type': 'gift_market', 'index': 0, 'target': 1});
      g.handle(0, {'type': 'gift_market', 'index': 0, 'target': 2});

      expect(g.turn, 1);
      expect(g.step, 'plant');
      expect(g.hands[0].length, beforeHand.length + 3);
      expect(g.hands[0].sublist(0, beforeHand.length), beforeHand);
    });
  });

  test('bot simulations for cards11Games (count: 30)', () {
    expect(runSims(cards11Games, n: 30), 0);
  });
}
