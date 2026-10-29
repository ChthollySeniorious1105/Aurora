import 'dart:math';

import 'package:aurora_shared/games/cards10/canasta.dart';
import 'package:aurora_shared/games/cards10/daifugo.dart';
import 'package:aurora_shared/games/cards10/defs.dart';
import 'package:aurora_shared/games/cards10/germanwhist.dart';
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
  group('German Whist (德国惠斯特)', () {
    test('setup: 13 cards each, 26 in stock, trumpSuit matches first upCard', () {
      final e = GermanWhist(_setup(2, {'hands': 1}))..start();
      expect(e.hands[0].length, 13);
      expect(e.hands[1].length, 13);
      expect(e.stock.length, 26);
      expect(e.upCard, isNotNull);
      expect(e.trumpSuit, GermanWhist.cardSuit(e.upCard!));
      expect(e.phase, 'forhand');
    });

    test('Phase 1 (forhand): must follow suit, winner gets upCard, loser gets next stock card, no points scored', () {
      final e = GermanWhist(_setup(2, {'hands': 1}))..start();
      e.trumpSuit = 'S';
      e.stock = ['AH', '2C', 'KD', '3D'];
      e.hands[0] = cs('KH 5D');
      e.hands[1] = cs('9H AS');
      e.turn = 0;
      e.trick = [];

      // Player 0 leads KH
      e.handle(0, {'type': 'play', 'card': 'KH'});
      // Player 1 has 9H so cannot play AS (must follow suit H)
      expect(() => e.handle(1, {'type': 'play', 'card': 'AS'}), throwsA(isA<GameError>()));
      e.handle(1, {'type': 'play', 'card': '9H'});

      // Player 0 won the trick: takes upCard 'AH', Player 1 gets '2C'
      expect(e.phase1Tricks, [1, 0]);
      expect(e.scores, [0, 0]);
      expect(e.hands[0].contains('AH'), isTrue);
      expect(e.knownUpCards[0], ['AH']);
      expect(e.hands[1].contains('2C'), isTrue);
      expect(e.upCard, 'KD');
      expect(e.turn, 0);
    });

    test('Phase 2 (endgame): entered when stock is empty, tricks score (phase2Tricks - 6)', () {
      final e = GermanWhist(_setup(2, {'hands': 1}))..start();
      e.trumpSuit = 'S';
      e.stock = [];
      e.phase = 'endgame';
      e.phase2Tricks = [7, 5];
      e.hands[0] = ['AS'];
      e.hands[1] = ['KH'];
      e.turn = 0;
      e.trick = [];

      e.handle(0, {'type': 'play', 'card': 'AS'});
      e.handle(1, {'type': 'play', 'card': 'KH'});

      expect(e.phase2Tricks, [8, 5]);
      expect(e.scores, [2, 0]); // 8 - 6 = 2 points
      expect(e.isOver, isTrue);
      expect(e.placings, [1, 2]);
    });
  });

  group('Canasta (卡纳斯塔)', () {
    test('deck has 108 cards, point values and red/black 3 classification', () {
      final deck = Canasta.buildDeck();
      expect(deck.length, 108);
      expect(Canasta.cardPoints('RJ'), 50);
      expect(Canasta.cardPoints('2S'), 20);
      expect(Canasta.cardPoints('AH'), 20);
      expect(Canasta.cardPoints('KS'), 10);
      expect(Canasta.cardPoints('8D'), 10);
      expect(Canasta.cardPoints('7C'), 5);
      expect(Canasta.cardPoints('3S'), 5);
      expect(Canasta.isRedThree('3H'), isTrue);
      expect(Canasta.isBlackThree('3S'), isTrue);
    });

    test('take_pile blocked by Black 3, legal with 2 natural matching cards', () {
      final e = Canasta(_setup(2, {'hands': 1}))..start();
      e.turn = 0;
      e.phase = 'draw';
      e.hands[0] = cs('9S 9H 5D 6C');
      e.discardPile = ['7D', '3S'];
      // Blocked by Black 3 on top
      expect(e.canTakePile(0), isFalse);
      expect(() => e.handle(0, {'type': 'take_pile'}), throwsA(isA<GameError>()));

      // Top is 9D: player 0 has 9S and 9H (2 natural matching cards)
      e.discardPile = ['4C', '7D', '9D'];
      expect(e.canTakePile(0), isTrue);
      e.handle(0, {'type': 'take_pile'});
      expect(e.phase, 'play');
      expect(e.discardPile, isEmpty);
      expect(e.melds[0]['9']!.length, 3);
      expect(e.hands[0].contains('4C'), isTrue);
      expect(e.hands[0].contains('7D'), isTrue);
    });

    test('meld validation, Natural Canasta (+500), Mixed Canasta (+300), and Going Out (+100)', () {
      final e = Canasta(_setup(2, {'hands': 1}))..start();
      e.turn = 0;
      e.phase = 'play';
      e.redThrees = [[], []];
      e.melds = [{}, {}];
      e.scores = [0, 0];
      e.hands[0] = cs('8S 8H 8D 8C 8S 8H 8D 5C');
      e.hands[1] = cs('4S 4H');

      // Cannot meld with > 3 wildcards or < 2 naturals
      e.hands[0].addAll(cs('2S 2H 2D 2C'));
      expect(
        () => e.handle(0, {'type': 'meld', 'rank': '8', 'cards': cs('8S 8H 2S 2H 2D 2C')}),
        throwsA(isA<GameError>()),
      );
      for (final w in cs('2S 2H 2D 2C')) {
        e.hands[0].remove(w);
      }

      // Form a 7-card Natural Canasta of 8s
      e.handle(0, {'type': 'meld', 'rank': '8', 'cards': cs('8S 8H 8D 8C 8S 8H 8D')});
      expect(e.hasCanasta(0), isTrue);
      expect(e.countCanastas(0, natural: true), 1);

      // Discard last card '5C' to Go Out!
      e.handle(0, {'type': 'discard', 'card': '5C'});
      expect(e.isOver, isTrue);
      // Score for seat 0: 500 (Natural Canasta) + 100 (Going Out) + 7 * 10 (seven 8s) = 670
      expect(e.scores[0], 670);
      expect(e.placings, [1, 2]);
    });
  });

  group('Daifugo (大富豪)', () {
    test('Revolution reverses non-joker rank order while Jokers stay highest', () {
      expect(Daifugo.rankStrength('3', false) < Daifugo.rankStrength('2', false), isTrue);
      expect(Daifugo.rankStrength('3', true) > Daifugo.rankStrength('2', true), isTrue);
      expect(Daifugo.rankStrength('BJ', true) > Daifugo.rankStrength('3', true), isTrue);
      expect(Daifugo.rankStrength('RJ', true) > Daifugo.rankStrength('BJ', true), isTrue);

      final e = Daifugo(_setup(3, {'rounds': 1}))..start();
      e.turn = 0;
      e.revolution = false;
      e.resetTrick();
      e.hands = [
        cs('5S 5H 5D 5C 3H'),
        cs('4S 2D'),
        cs('6S 7D'),
      ];

      // Playing four 5s triggers Revolution!
      e.handle(0, {'type': 'play', 'cards': cs('5S 5H 5D 5C')});
      expect(e.revolution, isTrue);
      expect(e.turn, 1);

      // Pass around so seat 0 leads again
      e.handle(1, {'type': 'pass'});
      e.handle(2, {'type': 'pass'});
      expect(e.turn, 0);

      // Now under Revolution, seat 1 leads 2D (weakest!) and seat 2's 6S beats 2D? Wait: 6(12 in rev) > 2(3 in rev)!
      e.turn = 1;
      e.handle(1, {'type': 'play', 'cards': ['2D']});
      e.handle(2, {'type': 'play', 'cards': ['6S']});
      expect(e.table!['rank'], '6');
    });

    test('8-Giri (8切) and Spade 3 Counter (♠3) clear the table immediately', () {
      final e = Daifugo(_setup(3, {'rounds': 1, 'spade3': true}))..start();
      e.turn = 0;
      e.revolution = false;
      e.resetTrick();
      e.hands = [
        cs('8S 8H 9D'),
        cs('BJ KS'),
        cs('3S QD'),
      ];

      // Seat 0 plays pair of 8s -> 8-Giri clears table and seat 0 leads again!
      e.handle(0, {'type': 'play', 'cards': cs('8S 8H')});
      expect(e.table, isNull);
      expect(e.turn, 0);

      // Seat 0 leads 9D, seat 1 plays single BJ, seat 2 counters with 3S!
      e.handle(0, {'type': 'play', 'cards': ['9D']});
      e.handle(1, {'type': 'play', 'cards': ['BJ']});
      expect(e.table!['rank'], 'BJ');
      expect(e.turn, 2);
      e.handle(2, {'type': 'play', 'cards': ['3S']});
      expect(e.table, isNull);
      expect(e.turn, 2);
    });

    test('multi-round exchange between Daifugo and Daihinmin', () {
      final e = Daifugo(_setup(3, {'rounds': 3}))..start();
      e.hands = [
        cs('3S 4S 9H'),
        cs('5S 6S KH'),
        cs('2S RJ 7C'),
      ];
      e.startExchange(0, 2);
      expect(e.phase, 'exchange');
      // Daihinmin (seat 2) gave 2 strongest cards ('RJ', '2S') to Daifugo (seat 0)
      expect(e.exchangeTribute, containsAll(['RJ', '2S']));
      expect(e.hands[0], containsAll(['RJ', '2S']));
      // Daifugo (seat 0) returns 2 weakest cards ('3S', '4S') to Daihinmin (seat 2)
      e.handle(0, {'type': 'exchange', 'cards': cs('3S 4S')});
      expect(e.phase, 'play');
      expect(e.hands[2], containsAll(['3S', '4S']));
    });
  });

  test('bot simulations (count: 30)', () {
    expect(runSims(cards10Games, n: 30), 0);
  });
}
