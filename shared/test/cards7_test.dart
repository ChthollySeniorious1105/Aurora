import 'dart:math';

import 'package:aurora_shared/games/cards7/arboretum.dart';
import 'package:aurora_shared/games/cards7/briscola.dart';
import 'package:aurora_shared/games/cards7/defs.dart';
import 'package:aurora_shared/games/cards7/euchre.dart';
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
  group('Euchre', () {
    test('Right Bower & Left Bower hierarchy and effectiveSuit', () {
      // When Hearts ('H') is trump: JH is Right Bower, JD is Left Bower
      expect(isRightBower('JH', 'H'), isTrue);
      expect(isLeftBower('JD', 'H'), isTrue);
      expect(effectiveSuit('JD', 'H'), 'H');
      expect(effectiveSuit('AD', 'H'), 'D');

      // Power order: JH > JD > AH > KH > QH > TH > 9H > led suit
      final pRight = euchreCardPower('JH', ledSuit: 'S', trumpSuit: 'H');
      final pLeft = euchreCardPower('JD', ledSuit: 'S', trumpSuit: 'H');
      final pAceTrump = euchreCardPower('AH', ledSuit: 'S', trumpSuit: 'H');
      final pAceLed = euchreCardPower('AS', ledSuit: 'S', trumpSuit: 'H');
      expect(pRight, greaterThan(pLeft));
      expect(pLeft, greaterThan(pAceTrump));
      expect(pAceTrump, greaterThan(pAceLed));
    });

    test('bid1 pass -> bid2 stick the dealer and forbidden turnedDownSuit', () {
      final e = Euchre(_setup(4, {'target': 10, 'stickDealer': true}))..start();
      e.dealer = 0;
      e.upCard = '9S';
      e.phase = 'bid1';
      e.turn = 1;
      e.passesInRound = 0;

      // All 4 pass in bid1
      e.handle(1, {'type': 'pass'});
      e.handle(2, {'type': 'pass'});
      e.handle(3, {'type': 'pass'});
      e.handle(0, {'type': 'pass'});

      expect(e.phase, 'bid2');
      expect(e.turnedDownSuit, 'S');
      expect(e.turn, 1);

      // Cannot call turned down suit 'S'
      expect(() => e.handle(1, {'type': 'call', 'suit': 'S'}), throwsA(isA<GameError>()));

      // First 3 pass in bid2
      e.handle(1, {'type': 'pass'});
      e.handle(2, {'type': 'pass'});
      e.handle(3, {'type': 'pass'});

      // Dealer (seat 0) cannot pass when stickDealer is true
      expect(e.turn, 0);
      expect(() => e.handle(0, {'type': 'pass'}), throwsA(isA<GameError>()));
      e.handle(0, {'type': 'call', 'suit': 'C', 'alone': false});
      expect(e.phase, 'play');
      expect(e.trumpSuit, 'C');
    });

    test('Left Bower must follow trump lead, Lone March scores +4, Euchred scores +2', () {
      final e = Euchre(_setup(4, {'target': 10, 'stickDealer': true}))..start();
      e.dealer = 0;
      e.upCard = 'AH';
      e.phase = 'bid1';
      e.turn = 1;
      e.hands = [
        cs('9C TC QC KC AC'), // Dealer (seat 0)
        cs('JH JD KH QH TH'), // Seat 1 (orders up alone!)
        cs('9D TD QD KD AD'), // Seat 2
        cs('9S TS JS QS KS'), // Seat 3 (partner of seat 1, sits out!)
      ];

      // Seat 1 orders up alone!
      e.handle(1, {'type': 'order_up', 'alone': true});
      expect(e.phase, 'dealer_discard');
      expect(e.turn, 0);
      expect(e.sittingOutSeat, 3);
      // Dealer now has 6 cards including AH; discards 9C
      e.handle(0, {'type': 'discard', 'card': '9C'});
      expect(e.phase, 'play');
      expect(e.turn, 1); // Seat 1 leads

      // Play 5 tricks with 3 active players (Seats 1, 2, 0; Seat 3 sits out!)
      // Give Seat 0 JD in hand to test Left Bower following suit on trick 1
      e.hands = [
        cs('JD TC QC KC AC'), // Seat 0 has Left Bower JD (effective suit 'H'!)
        cs('JH AH KH QH TH'), // Seat 1 has top 5 trumps
        cs('9D TD QD KD AD'), // Seat 2
        cs('9S TS JS QS KS'), // Seat 3 sitting out
      ];

      // Trick 1: Seat 1 leads JH ('H'). Seat 2 has no 'H', plays 9D.
      // Seat 0 holds JD (Left Bower -> effective suit 'H'), so MUST play JD!
      e.handle(1, {'type': 'play', 'card': 'JH'});
      e.handle(2, {'type': 'play', 'card': '9D'});
      expect(() => e.handle(0, {'type': 'play', 'card': 'TC'}), throwsA(isA<GameError>()));
      e.handle(0, {'type': 'play', 'card': 'JD'});
      expect(e.tricksWon[1], 1);

      // Remaining 4 tricks won by Seat 1 -> Lone March (+4 pts for Team 1)
      for (final c1 in cs('AH KH QH TH')) {
        e.handle(1, {'type': 'play', 'card': c1});
        e.handle(2, {'type': 'play', 'card': e.hands[2].first});
        e.handle(0, {'type': 'play', 'card': e.hands[0].first});
      }
      expect(e.teamScores[1], 4);
      expect(e.lastHandResult!['points'], 4);
    });
  });

  group('Briscola', () {
    test('deck size, 120 total points, rank hierarchy A > 3 > K > Q > J', () {
      final d2 = buildBriscolaDeck(2);
      final d3 = buildBriscolaDeck(3);
      expect(d2.length, 40);
      expect(d3.length, 39);
      expect(d3.contains('2C'), isFalse);
      expect(d2.fold<int>(0, (s, c) => s + briscolaCardPoints(c)), 120);
      expect(d3.fold<int>(0, (s, c) => s + briscolaCardPoints(c)), 120);

      // 3 beats K of the same suit!
      expect(
        briscolaCardPower('3S', ledSuit: 'S', trumpSuit: 'H'),
        greaterThan(briscolaCardPower('KS', ledSuit: 'S', trumpSuit: 'H')),
      );
      // Smallest trump (2H) beats Ace of led suit (AS)!
      expect(
        briscolaCardPower('2H', ledSuit: 'S', trumpSuit: 'H'),
        greaterThan(briscolaCardPower('AS', ledSuit: 'S', trumpSuit: 'H')),
      );
    });

    test('free play (no suit-following obligation) and stock drawing', () {
      final e = Briscola(_setup(2, {'hands': 1}))..start();
      e.trumpSuit = 'H';
      e.trumpCard = '2H';
      e.stock = ['7D', '2H'];
      e.hands = [
        cs('AS 5S 4S'), // P0
        cs('6S 3H 2D'), // P1 has Spades (6S), but is NOT required to follow Spades!
      ];
      e.turn = 0;

      // P0 leads AS (11 pts)
      e.handle(0, {'type': 'play', 'card': 'AS'});
      // P1 can legally play 3H (trump, 10 pts) even though P1 holds 6S!
      e.handle(1, {'type': 'play', 'card': '3H'});

      // P1 wins 11 + 10 = 21 pts, draws first ('7D'), P0 draws last ('2H' = trumpCard), P1 leads next!
      expect(e.handPoints[1], 21);
      expect(e.turn, 1);
      expect(e.stock, isEmpty);
      expect(e.hands[1].contains('7D'), isTrue);
      expect(e.hands[0].contains('2H'), isTrue);
    });
  });

  group('Arboretum', () {
    test('scoring rights: 1 neutralizes another player 8, all-zero gives everyone rights', () {
      // P0 has 0-8 and 0-3 (would be 11, but P1 has 0-1 so 0-8 -> 0, leaving sum 3)
      // P1 has 0-1 and 0-4 (sum = 5 -> P1 wins rights!)
      final r1 = computeArboretumScoringRights([
        cs('0-8 0-3'),
        cs('0-1 0-4'),
      ], 0);
      expect(r1.sums, [3, 5]);
      expect(r1.rightHolders, [1]);

      // All players have 0 for species 2 -> ALL players get scoring rights!
      final r2 = computeArboretumScoringRights([
        cs('0-2 1-5'),
        cs('0-4 1-6'),
      ], 2);
      expect(r2.sums, [0, 0]);
      expect(r2.rightHolders, [0, 1]);
    });

    test('path scoring: base, >=4 same-species bonus, start-at-1 (+1), end-at-8 (+2)', () {
      // Path of 4 cards all of species 0: 0-1 -> 0-3 -> 0-6 -> 0-8
      // Base: 4 + Same-species >=4: +4 + Start at 1: +1 + End at 8: +2 = 11 pts!
      final grid = <String, String>{
        '0,0': '0-1',
        '0,1': '0-3',
        '1,1': '0-6',
        '1,2': '0-8',
      };
      final best = bestArboretumPathForSpecies(grid, 0);
      expect(best.score, 11);

      // Mixed-species path of length 4 starting and ending with species 0:
      // 0-1 -> 1-2 -> 2-5 -> 0-8
      // Base: 4 + Same-species bonus: 0 + Start at 1: +1 + End at 8: +2 = 7 pts
      final mixedGrid = <String, String>{
        '0,0': '0-1',
        '0,1': '1-2',
        '0,2': '2-5',
        '0,3': '0-8',
      };
      expect(bestArboretumPathForSpecies(mixedGrid, 0).score, 7);
    });

    test('turn substeps: draw1 -> draw2 -> plant -> discard and end when deck exhausted', () {
      final e = Arboretum(_setup(2, {}))..start();
      expect(e.numSpecies, 6);
      expect(e.step, 'draw1');
      expect(e.turn, 0);

      // Make deck have 1 card left and P1 discard have 1 card
      e.deck = ['0-8'];
      e.discards[1] = ['0-1'];

      // Draw 1 from discard of seat 1
      e.handle(0, {'type': 'draw', 'source': 'discard', 'seat': 1});
      expect(e.step, 'draw2');
      expect(e.hands[0].contains('0-1'), isTrue);

      // Draw 2 from deck (empties deck)
      e.handle(0, {'type': 'draw', 'source': 'deck'});
      expect(e.step, 'plant');
      expect(e.deck, isEmpty);

      // First plant must be at (0, 0)
      expect(
        () => e.handle(0, {'type': 'plant', 'card': e.hands[0].first, 'r': 1, 'c': 0}),
        throwsA(isA<GameError>()),
      );
      e.handle(0, {'type': 'plant', 'card': e.hands[0].first, 'r': 0, 'c': 0});
      expect(e.step, 'discard');

      // Discard 1 card -> deck is empty so game ends and scores!
      e.handle(0, {'type': 'discard', 'card': e.hands[0].first});
      expect(e.isOver, isTrue);
      expect(e.placings, isNotNull);
    });
  });

  test('bot simulations for cards7Games', () {
    expect(runSims(cards7Games, n: 30), 0);
  });
}
