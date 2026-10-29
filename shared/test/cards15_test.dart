import 'dart:math';

import 'package:aurora_shared/games/cards15/defs.dart';
import 'package:aurora_shared/games/cards15/fox_in_the_forest.dart';
import 'package:aurora_shared/games/cards15/schafkopf.dart';
import 'package:aurora_shared/games/cards15/wizard.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n, [Map<String, dynamic> opts = const {}, int seed = 1]) =>
    GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, true),
      rng: Random(seed),
    );

void main() {
  group('schafkopf (巴伐利亚羊头牌 Schafkopf)', () {
    test('32-card deck sums to 120 points and permanent top trumps count is 14 (Ruf/Solo) or 4 (Wenz)', () {
      final deck = buildSchafkopfDeck();
      expect(deck.length, 32);
      final totalPts = deck.fold<int>(0, (acc, c) => acc + schafkopfCardPoints(c));
      expect(totalPts, 120);

      for (final c in const ['ruf', 'solo_C', 'solo_S', 'solo_H', 'solo_D']) {
        final trumps = deck.where((card) => isSchafkopfTrump(card, c)).toList();
        expect(trumps.length, 14, reason: 'Contract $c must have 14 trumps');
      }
      final wenzTrumps = deck.where((card) => isSchafkopfTrump(card, 'wenz')).toList();
      expect(wenzTrumps.length, 4);
      expect(wenzTrumps.toSet(), {'JC', 'JS', 'JH', 'JD'});
    });

    test('Trump order QC > QS > QH > QD > JC > JS > JH > JD > A > T > K > 9 > 8 > 7 and Wenz order', () {
      expect(schafkopfCardStrength('QC', 'ruf', 'TRUMP'),
          greaterThan(schafkopfCardStrength('QS', 'ruf', 'TRUMP')));
      expect(schafkopfCardStrength('QD', 'ruf', 'TRUMP'),
          greaterThan(schafkopfCardStrength('JC', 'ruf', 'TRUMP')));
      expect(schafkopfCardStrength('JD', 'ruf', 'TRUMP'),
          greaterThan(schafkopfCardStrength('AH', 'ruf', 'TRUMP')));
      expect(schafkopfCardStrength('TH', 'ruf', 'TRUMP'),
          greaterThan(schafkopfCardStrength('KH', 'ruf', 'TRUMP')));

      // In Wenz, Obers (Q) are NOT trump and lose to Aces/10s/Kings of their suit
      expect(isSchafkopfTrump('QC', 'wenz'), isFalse);
      expect(schafkopfCardStrength('KC', 'wenz', 'C'),
          greaterThan(schafkopfCardStrength('QC', 'wenz', 'C')));
      expect(schafkopfCardStrength('JD', 'wenz', 'C'),
          greaterThan(schafkopfCardStrength('AC', 'wenz', 'C')));
    });

    test('Rufspiel secret partner, >= 61 threshold, Schneider (>= 91) and Schwarz (120)', () {
      final g = SchafkopfGame(_setup(4, {'rounds': 1}))..start();
      g.hands[0] = ['QC', 'QS', 'QH', 'QD', 'JC', 'JS', 'AH', '7C'];
      g.hands[1] = ['AC', 'TC', 'KC', '9C', '8C', '7S', '8S', '9S'];
      g.hands[2] = ['JH', 'JD', 'TH', 'KH', '9H', '8H', '7H', 'AS'];
      g.hands[3] = ['TS', 'KS', 'AD', 'TD', 'KD', '9D', '8D', '7D'];

      g.handle(0, {'type': 'ruf', 'ace': 'AC'});
      expect(g.phase, 'play');
      expect(g.contract, 'ruf');
      expect(g.declarer, 0);
      expect(g.partner, 1);
      // Partner is hidden from seat 2 before AC is played
      expect(g.view(2)['partner'], isNull);

      // Simulate round end with 95 points for declarer side (0 & 1) -> Schneider win!
      for (var s = 0; s < 4; s++) {
        g.hands[s].clear();
      }
      g.handPoints[0] = 65;
      g.handPoints[1] = 30;
      g.handPoints[2] = 25;
      g.handPoints[3] = 0;
      g.tricksWon[0] = 5;
      g.tricksWon[1] = 2;
      g.tricksWon[2] = 1;
      g.tricksWon[3] = 0;
      g.resolveRound();

      expect(g.lastHandSummary!['declarerWon'], isTrue);
      expect(g.lastHandSummary!['declarerPoints'], 95);
      expect(g.lastHandSummary!['schneider'], isTrue);
      expect(g.lastHandSummary!['schwarz'], isFalse);
      expect(g.isOver, isTrue);
      expect(g.placings, [1, 1, 3, 3]);
    });
  });

  group('wizard (巫师预测牌 Wizard)', () {
    test('60-card deck, First Wizard wins, All Jesters first Jester wins, Jester lead suit deferral', () {
      final deck = buildWizardDeck();
      expect(deck.length, 60);
      expect(deck.where(isWizardCard).length, 4);
      expect(deck.where(isJesterCard).length, 4);
      expect(deck.where(isStandardWizardCard).length, 52);

      // First Wizard wins even when a second Wizard is played later
      final trick1 = [
        {'seat': 0, 'card': 'AH'},
        {'seat': 1, 'card': 'W2'},
        {'seat': 2, 'card': 'W1'},
      ];
      expect(wizardTrickWinner(trick1, 'H'), 1);

      // All Jesters -> first Jester wins
      final trick2 = [
        {'seat': 2, 'card': 'J3'},
        {'seat': 0, 'card': 'J1'},
        {'seat': 1, 'card': 'J4'},
      ];
      expect(wizardTrickWinner(trick2, 'S'), 2);

      // Jester led first, then 9D -> led suit is 'D'
      final partial = [
        {'seat': 0, 'card': 'J1'},
        {'seat': 1, 'card': '9D'},
      ];
      expect(wizardTrickLeadSuit(partial), 'D');

      // Wizard led first -> no led suit restriction (null)
      final wizLead = [
        {'seat': 0, 'card': 'W1'},
        {'seat': 1, 'card': '9D'},
      ];
      expect(wizardTrickLeadSuit(wizLead), isNull);
    });

    test('Exact bid (+20 + 10*b) and missed bid (-10*d) scoring', () {
      expect(wizardRoundScore(0, 0), 20);
      expect(wizardRoundScore(3, 3), 50);
      expect(wizardRoundScore(2, 0), -20);
      expect(wizardRoundScore(1, 4), -30);
    });
  });

  group('fox_in_the_forest (林中狐影 The Fox in the Forest)', () {
    test('33-card deck and Humble vs. Greedy scoring table', () {
      final deck = buildFoxDeck();
      expect(deck.length, 33);
      expect(foxTrickScore(0), 6);
      expect(foxTrickScore(3), 6);
      expect(foxTrickScore(4), 1);
      expect(foxTrickScore(5), 2);
      expect(foxTrickScore(6), 3);
      expect(foxTrickScore(7), 6);
      expect(foxTrickScore(9), 6);
      expect(foxTrickScore(10), 0);
      expect(foxTrickScore(13), 0);
    });

    test('Odd card powers: 1(Swan), 3(Fox), 5(Woodcutter), 7(Treasure), 9(Witch), 11(Monarch)', () {
      final g = FoxInTheForestGame(_setup(2, {'rounds': 1}))..start();
      g.decreeCard = '2B'; // Trump suit = 0 (Bells 'B')
      g.stock = ['10M', '8K'];
      g.leader = 0;
      g.turn = 0;

      // Test 11 (Monarch): Seat 0 leads '11K', Seat 1 has ['1K', '4K', '8K', '2M'] -> must play '1K' or '8K'
      g.hands[0] = ['11K', '3K', '5M', '9K'];
      g.hands[1] = ['1K', '4K', '8K', '7K'];
      g.handle(0, {'type': 'play', 'card': '11K'});
      expect(g.legalCards(1).toSet(), {'1K', '8K'});
      expect(() => g.handle(1, {'type': 'play', 'card': '4K'}), throwsA(isA<GameError>()));

      // Test 1 (Swan): Seat 1 plays '1K' and loses to '11K', so Seat 1 leads the next trick!
      g.handle(1, {'type': 'play', 'card': '1K'});
      expect(g.tricksWon[0], 1);
      expect(g.leader, 1);
      expect(g.turn, 1);

      // Test 3 (Fox) & 7 (Treasure): Seat 1 plays '7K', Seat 0 plays '3K' and swaps decreeCard '2B' with '9K' (new trump = Keys 'K')
      g.handle(1, {'type': 'play', 'card': '7K'});
      g.handle(0, {'type': 'play', 'card': '3K'});
      expect(g.phase, 'fox_swap');
      g.handle(0, {'type': 'fox_swap', 'card': '9K'});
      expect(g.decreeCard, '9K');
      expect(g.trumpSuit, 1); // Keys
      // Seat 1 won the trick with '7K' vs '3K' and gained +1 Treasure bonus for the '7K'
      expect(g.tricksWon[1], 1);
      expect(g.bonusPoints[1], 1);

      // Test 5 (Woodcutter): Seat 1 plays '4K', Seat 0 has no Keys so plays '5M' -> draws '10M' and discards '2B'
      g.handle(1, {'type': 'play', 'card': '4K'});
      g.handle(0, {'type': 'play', 'card': '5M'});
      expect(g.phase, 'woodcutter_discard');
      expect(g.hands[0].contains('10M'), isTrue);
      g.handle(0, {'type': 'woodcutter_discard', 'card': '2B'});
      expect(g.stock.last, '2B');

      // Test 9 (Witch): Single '9' in trick acts as trump suit, two '9's cancel out
      expect(
        foxTrickWinner([
          {'seat': 0, 'card': '10K'},
          {'seat': 1, 'card': '9M'}, // single 9 becomes trump (0 = Bells)
        ], 0),
        1,
      );
      expect(
        foxTrickWinner([
          {'seat': 0, 'card': '9K'},
          {'seat': 1, 'card': '9M'}, // two 9s -> neither becomes trump (0 = Bells), leader wins
        ], 0),
        0,
      );
    });
  });

  test('bot simulations (30 runs per option/player combination)', () {
    expect(runSims(cards15Games, n: 30), 0);
  });
}
