import 'dart:math';

import 'package:aurora_shared/games/cards17/defs.dart';
import 'package:aurora_shared/games/cards17/five_hundred.dart';
import 'package:aurora_shared/games/cards17/schotten_totten.dart';
import 'package:aurora_shared/games/cards17/truco.dart';
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
  group('truco (南美特鲁科牌 Truco)', () {
    test('40-card deck, dynamic Manilha cyclic-above viraCard, and C > H > S > D > 3 > 2 > A > K > J > Q > 7 > 6 > 5 > 4', () {
      final deck = buildTrucoDeck();
      expect(deck.length, 40);

      // Cyclic Manilha rank above viraCard in [4, 5, 6, 7, Q, J, K, A, 2, 3]
      expect(trucoManilhaRank('7H'), 'Q');
      expect(trucoManilhaRank('QD'), 'J');
      expect(trucoManilhaRank('JS'), 'K');
      expect(trucoManilhaRank('3C'), '4');

      // When viraCard = '7H', Manilhas are 'QC > QH > QS > QD'
      expect(trucoCardStrength('QC', '7H'), greaterThan(trucoCardStrength('QH', '7H')));
      expect(trucoCardStrength('QH', '7H'), greaterThan(trucoCardStrength('QS', '7H')));
      expect(trucoCardStrength('QS', '7H'), greaterThan(trucoCardStrength('QD', '7H')));
      expect(trucoCardStrength('QD', '7H'), greaterThan(trucoCardStrength('3C', '7H')));
      expect(trucoCardStrength('3C', '7H'), greaterThan(trucoCardStrength('2S', '7H')));
      expect(trucoCardStrength('JC', '7H'), greaterThan(trucoCardStrength('7C', '7H')));

      // Non-Manilha equal ranks tie the trick (Empate = -1)
      expect(
        trucoTrickWinner(
          [
            {'seat': 0, 'card': '3S'},
            {'seat': 1, 'card': '3H'},
          ],
          '7H',
          players: 2,
        ),
        -1,
      );
    });

    test('Best-of-3 Empate tie-breaking and Escalating Truco! (1 -> 3 -> 6 -> 9 -> 12) with accept, raise, fold', () {
      // Tie-break rules:
      // Trick 1 tied (-1), Trick 2 won by Side 1 -> Side 1 wins immediately!
      expect(trucoHandWinner([-1, 1]), 1);
      // Trick 1 won by Side 0, Trick 2 tied (-1) -> Side 0 wins immediately!
      expect(trucoHandWinner([0, -1]), 0);
      // Trick 1 won by Side 0, Trick 2 won by Side 1, Trick 3 tied (-1) -> Side 0 (Trick 1 winner) wins!
      expect(trucoHandWinner([0, 1, -1]), 0);

      // Escalating Truco challenge in 2p
      final g = TrucoGame(_setup(2, {'targetScore': 12}))..start();
      g.turn = 0;
      g.leader = 0;
      g.handStake = 1;
      g.lastTrucoCallerSide = -1;

      // Seat 0 calls Truco! (proposes 3)
      g.handle(0, {'type': 'truco'});
      expect(g.phase, 'respond_truco');
      expect(g.proposedStake, 3);
      expect(g.waitingFor, [1]);

      // Seat 1 re-raises to Seis! (accepts 3, proposes 6)
      g.handle(1, {'type': 'raise'});
      expect(g.phase, 'respond_truco');
      expect(g.handStake, 3);
      expect(g.proposedStake, 6);
      expect(g.waitingFor, [0]);

      // Seat 0 re-raises to Nove! (accepts 6, proposes 9)
      g.handle(0, {'type': 'raise'});
      expect(g.handStake, 6);
      expect(g.proposedStake, 9);
      expect(g.waitingFor, [1]);

      // Seat 1 accepts 9!
      g.handle(1, {'type': 'accept'});
      expect(g.phase, 'play');
      expect(g.handStake, 9);
      expect(g.turn, 0);

      // Next turn, Seat 1 calls Doze! (proposes 12) and Seat 0 folds -> Seat 1 wins 9 points!
      g.viraCard = '4D'; // Manilha = '5'
      g.hands[0] = ['6D', '7D', 'QD'];
      g.hands[1] = ['5C', '5H', '3S'];
      g.handle(0, {'type': 'play', 'card': '6D'});
      expect(g.turn, 1);
      g.handle(1, {'type': 'truco'});
      expect(g.phase, 'respond_truco');
      expect(g.proposedStake, 12);
      g.handle(0, {'type': 'fold'});
      expect(g.sideScores[1], 9);
    });
  });

  group('five_hundred (五百分桥牌 Five Hundred)', () {
    test('33/43-card deck, Avondale scoring table, and Joker > Right Bower > Left Bower (same-color J) trump hierarchy', () {
      expect(buildFiveHundredDeck(3).length, 33);
      expect(buildFiveHundredDeck(4).length, 43);

      // Avondale ladder: 6S=40, 6C=60, 6D=80, 6H=100, 6NT=120 ... 8H=300, 8NT=320, Misère=250
      expect(fiveHundredBidValue(6, 'S'), 40);
      expect(fiveHundredBidValue(6, 'C'), 60);
      expect(fiveHundredBidValue(6, 'D'), 80);
      expect(fiveHundredBidValue(6, 'H'), 100);
      expect(fiveHundredBidValue(6, 'NT'), 120);
      expect(fiveHundredBidValue(8, 'H'), 300);
      expect(fiveHundredBidValue(8, 'NT'), 320);
      expect(fiveHundredBidValue(0, 'MISERE'), 250);

      // In Hearts ('H') contract: 'JK' > 'JH' (Right Bower) > 'JD' (Left Bower, counts as 'H'!) > 'AH'
      expect(fiveHundredEffectiveSuit('JK', 'H'), 'H');
      expect(fiveHundredEffectiveSuit('JH', 'H'), 'H');
      expect(fiveHundredEffectiveSuit('JD', 'H'), 'H'); // Left Bower belongs to Hearts, NOT Diamonds!
      expect(fiveHundredCardStrength('JK', 'H', 'H'),
          greaterThan(fiveHundredCardStrength('JH', 'H', 'H')));
      expect(fiveHundredCardStrength('JH', 'H', 'H'),
          greaterThan(fiveHundredCardStrength('JD', 'H', 'H')));
      expect(fiveHundredCardStrength('JD', 'H', 'H'),
          greaterThan(fiveHundredCardStrength('AH', 'H', 'H')));
    });

    test('Bidding, Kitty 3-card discard exchange, Left Bower suit-following, and contract scoring', () {
      final g = FiveHundredGame(_setup(3, {'rounds': 1}))..start();
      g.forehand = 0;
      g.turn = 0;
      g.hands[0] = ['JK', 'JS', 'JC', 'AS', 'KS', 'QS', 'TS', '9S', '8S', '7S'];
      g.kitty = ['AH', 'KH', '7D'];

      // Seat 0 bids 7S (140 pts), Seat 1 and Seat 2 pass
      g.handle(0, {'type': 'bid', 'tricks': 7, 'strain': 'S'});
      g.handle(1, {'type': 'pass'});
      g.handle(2, {'type': 'pass'});

      expect(g.phase, 'kitty');
      expect(g.declarer, 0);
      expect(g.contractValue, 140);
      expect(g.hands[0].length, 13);

      // Seat 0 discards 3 cards from the 13-card hand
      g.handle(0, {'type': 'discard', 'cards': ['7D', '7S', '8S']});
      expect(g.phase, 'play');
      expect(g.hands[0].length, 10);

      // Seat 0 leads 'AS' (Spades trump); Seat 1 has 'JC' (Left Bower of Spades!) and '7C' -> MUST play 'JC'!
      g.hands[0] = ['AS'];
      g.hands[1] = ['JC', '7C'];
      g.hands[2] = ['9C'];
      g.tricksWon = [6, 2, 1];
      g.handle(0, {'type': 'play', 'card': 'AS'});
      expect(g.legalCards(1), ['JC']);
      g.handle(1, {'type': 'play', 'card': 'JC'}); // Left Bower beats AS!
      g.handle(2, {'type': 'play', 'card': '9C'});

      // Seat 1 won the last trick with Left Bower -> Seat 0 ended with 6 tricks (< 7S contract) -> Set (-140)!
      // Seat 1 won 3 tricks (+30), Seat 2 won 1 trick (+10)
      expect(g.lastHandSummary!['contractMade'], isFalse);
      expect(g.scores, [-140, 30, 10]);
      expect(g.isOver, isTrue);
    });
  });

  group('schotten_totten (苏格兰边境战 Schotten Totten)', () {
    test('54-card deck and Formation hierarchy: Color Run(5) > Three of a Kind(4) > Color(3) > Run(2) > Sum(1)', () {
      final deck = buildSchottenDeck();
      expect(deck.length, 54);

      expect(schottenEvaluateFormation(['R7', 'R8', 'R9']), (5, 24)); // Color Run
      expect(schottenEvaluateFormation(['R8', 'B8', 'G8']), (4, 24)); // Three of a Kind
      expect(schottenEvaluateFormation(['B2', 'B5', 'B9']), (3, 16)); // Color
      expect(schottenEvaluateFormation(['R4', 'B5', 'G6']), (2, 15)); // Run
      expect(schottenEvaluateFormation(['R2', 'B5', 'Y9']), (1, 16)); // Sum

      expect(schottenFormationScore(['R1', 'R2', 'R3']),
          greaterThan(schottenFormationScore(['R9', 'B9', 'G9'])));
      expect(schottenFormationScore(['R1', 'B1', 'G1']),
          greaterThan(schottenFormationScore(['Y6', 'Y8', 'Y9'])));

      // Tie-break by firstToThree
      expect(
        schottenCompareFormations(['R7', 'R8', 'R9'], ['B7', 'B8', 'B9'], firstToThree: 1),
        1,
      );
    });

    test('Proof-of-Impossibility Claim using board-visible cards and 3-adjacent / 5-total win condition', () {
      final g = SchottenTottenGame(_setup(2, {'rounds': 1}))..start();

      // Stone 0: Seat 0 has Color Run ['R7', 'R8', 'R9'] (score 524, unbeatable!) and opponent has 0 cards
      g.stones[0][0] = ['R7', 'R8', 'R9'];
      g.firstToThree[0] = 0;
      expect(g.canClaimStone(0, 0), isTrue);

      // Stone 1: Seat 0 has ['B6', 'B7', 'B8'] (Color Run 21, score 521).
      // Opponent has ['G7', 'G8'] on Stone 1 — could beat Seat 0 ONLY with 'G9' (Color Run 24, score 524).
      // Before 'G9' is played on the board, Seat 0 CANNOT claim Stone 1!
      g.stones[1][0] = ['B6', 'B7', 'B8'];
      g.stones[1][1] = ['G7', 'G8'];
      g.firstToThree[1] = 0;
      expect(g.canClaimStone(0, 1), isFalse);

      // Once 'G9' is visibly played on Stone 5, Opponent can no longer make ['G7','G8','G9'] on Stone 1!
      // Next best for Opponent with ['G7','G8'] is 'G6' (Color Run 21, score 521), which ties Seat 0 and loses to firstToThree!
      g.stones[5][0] = ['G9'];
      expect(g.canClaimStone(0, 1), isTrue);

      // Claim Stones 0, 1, and 2 (3 adjacent stones!) -> immediate victory for Seat 0!
      g.stones[2][0] = ['Y7', 'Y8', 'Y9'];
      g.firstToThree[2] = 0;
      g.handle(0, {'type': 'claim', 'stone': 0});
      g.handle(0, {'type': 'claim', 'stone': 1});
      expect(g.isOver, isFalse);
      g.handle(0, {'type': 'claim', 'stone': 2});
      expect(g.isOver, isTrue);
      expect(g.placings, [1, 2]);
    });
  });

  test('bot simulations (30 runs per option/player combination)', () {
    expect(runSims(cards17Games, n: 30), 0);
  });
}
