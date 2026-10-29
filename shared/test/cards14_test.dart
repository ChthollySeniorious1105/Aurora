import 'dart:math';

import 'package:aurora_shared/games/cards14/defs.dart';
import 'package:aurora_shared/games/cards14/golf_cards.dart';
import 'package:aurora_shared/games/cards14/hanamikoji.dart';
import 'package:aurora_shared/games/cards14/jass.dart';
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
  group('jass (瑞士雅斯牌 Schieber Jass)', () {
    test('36-card deck sums to 152 card points (+5 final trick = 157) in all 6 contracts', () {
      final deck = buildJassDeck();
      expect(deck.length, 36);
      for (final c in jassContracts) {
        final sum = deck.fold<int>(0, (acc, card) => acc + jassCardPoints(card, c));
        expect(sum, 152, reason: 'Contract $c must have 152 card points');
      }
    });

    test('Trump, Obenabe, and Undenufe rank and point orders', () {
      // Trump ('S'): J (20) > 9 (14) > A (11) > K (4) > Q (3) > T (10) > 8 (0) > 7 > 6
      expect(jassCardPoints('JS', 'S'), 20);
      expect(jassCardPoints('9S', 'S'), 14);
      expect(jassCardPoints('JH', 'S'), 2);
      expect(jassCardPoints('9H', 'S'), 0);
      expect(jassCardStrength('JS', 'S', 'H'), greaterThan(jassCardStrength('9S', 'S', 'H')));
      expect(jassCardStrength('9S', 'S', 'S'), greaterThan(jassCardStrength('AS', 'S', 'S')));
      expect(jassCardStrength('6S', 'S', 'H'), greaterThan(jassCardStrength('AH', 'S', 'H')));

      // Obenabe ('O'): A (11) > K (4) > Q (3) > J (2) > T (10) > 9 (0) > 8 (8) > 7 > 6
      expect(jassCardPoints('8H', 'O'), 8);
      expect(jassCardPoints('AH', 'O'), 11);
      expect(jassCardStrength('AH', 'O', 'H'), greaterThan(jassCardStrength('KH', 'O', 'H')));

      // Undenufe ('U'): 6 (11) > 7 (0) > 8 (8) > 9 (0) > T (10) > J (2) > Q (3) > K (4) > A (0)
      expect(jassCardPoints('6D', 'U'), 11);
      expect(jassCardPoints('8D', 'U'), 8);
      expect(jassCardPoints('AD', 'U'), 0);
      expect(jassCardStrength('6D', 'U', 'D'), greaterThan(jassCardStrength('7D', 'U', 'D')));
      expect(jassCardStrength('7D', 'U', 'D'), greaterThan(jassCardStrength('AD', 'U', 'D')));
    });

    test('Schieben passes contract choice to partner, forehand still leads trick 1', () {
      final g = JassGame(_setup(4, {'rounds': 1}))..start();
      expect(g.phase, 'choose_contract');
      expect(g.forehand, 0);
      expect(g.turn, 0);

      // Forehand passes contract selection to partner (seat 2)
      g.handle(0, {'type': 'schieben'});
      expect(g.schiebenUsed, isTrue);
      expect(g.turn, 2);

      // Partner cannot schieben again
      expect(() => g.handle(2, {'type': 'schieben'}), throwsA(isA<GameError>()));

      // Partner selects Undenufe ('U')
      g.handle(2, {'type': 'choose_contract', 'contract': 'U'});
      expect(g.phase, 'play');
      expect(g.contract, 'U');
      // Forehand (seat 0) still leads the first trick
      expect(g.turn, 0);
      expect(g.leader, 0);
    });

    test('Final trick +5 bonus and clean sweep Match (+100 -> 257)', () {
      final g = JassGame(_setup(2, {'rounds': 1}))..start();
      g.handle(0, {'type': 'choose_contract', 'contract': 'O'});
      g.hands[0] = ['AS'];
      g.hands[1] = ['6S'];
      g.tricksWon[0] = 8;
      g.handPoints[0] = 136; // previous 8 tricks
      g.handle(0, {'type': 'play', 'card': 'AS'});
      g.handle(1, {'type': 'play', 'card': '6S'});
      // AS (11) + 6S (0) + 5 (final trick) = 16 -> 136 + 16 = 152 + 100 (Match) = 252
      expect(g.isOver, isTrue);
      expect(g.scores[0], 136 + 11 + 5 + 100);
      expect(g.placings, [1, 2]);
    });
  });

  group('golf_cards (高尔夫九宫格纸牌 Golf 9-Card)', () {
    test('Card values and vertical Column Cancellation (同列三消归零)', () {
      expect(golfCardValue('KS'), 0);
      expect(golfCardValue('AS'), 1);
      expect(golfCardValue('2H'), -2);
      expect(golfCardValue('9D'), 9);
      expect(golfCardValue('QC'), 10);
      expect(golfCardValue('BJ'), -5);
      expect(golfCardValue('RJ'), -5);

      // Column 0 (indices 0, 3, 6) has three Qs -> 0 pts for column 0!
      // Column 1 (indices 1, 4, 7) has KS(0), AS(1), 2S(-2) -> -1 pt
      // Column 2 (indices 2, 5, 8) has 5S(5), 5H(5), 6D(6) -> 16 pts
      final grid = [
        'QS', 'KS', '5S',
        'QH', 'AS', '5H',
        'QD', '2S', '6D',
      ];
      expect(isGolfColumnCancelled(grid, 0), isTrue);
      expect(isGolfColumnCancelled(grid, 1), isFalse);
      expect(isGolfColumnCancelled(grid, 2), isFalse);
      expect(scoreGolfGrid(grid), 0 + (-1) + 16);
    });

    test('Draw, swap, discard_flip, and final round trigger when all 9 revealed', () {
      final g = GolfCardsGame(_setup(2, {'holes': 1}))..start();
      for (var s = 0; s < 2; s++) {
        expect(g.revealed[s].where((x) => x).length, 2);
      }
      // Seat 0 draws from stock and flips an unrevealed card
      g.handle(0, {'type': 'draw_stock'});
      expect(g.phase, 'act');
      final revealedSlot = g.revealed[0].indexOf(true);
      expect(() => g.handle(0, {'type': 'discard_flip', 'slot': revealedSlot}),
          throwsA(isA<GameError>()));
      final hiddenSlot = g.revealed[0].indexOf(false);
      g.handle(0, {'type': 'discard_flip', 'slot': hiddenSlot});
      expect(g.revealed[0][hiddenSlot], isTrue);
      expect(g.turn, 1);

      // Suppose seat 1 reveals their last hidden card via take_discard
      for (var i = 0; i < 8; i++) {
        g.revealed[1][i] = true;
      }
      g.revealed[1][8] = false;
      g.handle(1, {'type': 'take_discard', 'slot': 8});
      expect(g.firstOutSeat, 1);
      expect(g.isOver, isFalse);
      expect(g.turn, 0);

      // Seat 0 takes 1 final turn -> hole ends and all cards flip face-up
      g.handle(0, {'type': 'take_discard', 'slot': 0});
      expect(g.isOver, isTrue);
      expect(g.revealed[0].every((x) => x), isTrue);
      expect(g.placings, isNotNull);
    });
  });

  group('hanamikoji (花见小路 Hanamikoji)', () {
    test('Deck has 21 cards matching [2,2,2,3,3,4,5], 4 actions and favor tie rule', () {
      final deck = buildHanamikojiDeck();
      expect(deck.length, 21);
      final g = HanamikojiGame(_setup(2))..start();
      // Start player drew 1 card (6 + 1 = 7), other has 6, 1 removed, 7 left in deck
      expect(g.hands[g.turn].length, 7);
      expect(g.hands[1 - g.turn].length, 6);
      expect(g.deck.length, 7);

      // Action 0: Secret
      g.hands[0] = [6, 6, 5, 4, 3, 2, 1];
      g.handle(0, {'type': 'secret', 'cardIdx': 0});
      expect(g.secretCard[0], 6);
      expect(g.actionsLeft[0][0], isFalse);
      expect(g.turn, 1);

      // Action 1: Discard (by seat 1)
      g.hands[1] = [0, 0, 1, 2, 3, 4, 5];
      g.handle(1, {'type': 'discard', 'cards': [0, 1]});
      expect(g.discardedCards[1].length, 2);
      expect(g.actionsLeft[1][1], isFalse);
      expect(g.turn, 0);

      // Action 2: Gift (by seat 0)
      g.hands[0] = [6, 5, 4, 3, 2, 1];
      g.handle(0, {'type': 'gift', 'cards': [0, 1, 2]});
      expect(g.phase, 'pick_gift');
      expect(g.turn, 1);
      g.handle(1, {'type': 'pick_gift', 'index': 0}); // P1 picks 6, P0 gets 5 & 4
      expect(g.played[1][6], 1);
      expect(g.played[0][5], 1);
      expect(g.played[0][4], 1);
      expect(g.turn, 1);

      // Action 3: Compete (by seat 1)
      g.hands[1] = [3, 3, 4, 5, 2, 1];
      g.handle(1, {'type': 'compete', 'pairA': [0, 1], 'pairB': [2, 3]});
      expect(g.phase, 'pick_pair');
      expect(g.turn, 0);
      g.handle(0, {'type': 'pick_pair', 'pair': 1}); // P0 picks [4, 5], P1 gets [3, 3]
      expect(g.played[0][4], 2);
      expect(g.played[0][5], 2);
      expect(g.played[1][3], 2);
    });

    test('Victory by >= 4 Geishas or >= 11 Charm points, ties keep existing favor', () {
      final g = HanamikojiGame(_setup(2))..start();
      g.favor = [0, 1, -1, -1, -1, -1, -1];
      g.played = [
        [1, 1, 0, 0, 1, 1, 1], // P0 has 1 on g=0,1 (ties!), and 1 on g=4(3),5(4),6(5) -> 12 charm
        [1, 1, 0, 0, 0, 0, 0],
      ];
      g.secretCard = [null, null];
      g.resolveRound();
      // Ties on g=0 and g=1 keep favor[0]=0 and favor[1]=1 unchanged!
      expect(g.favor[0], 0);
      expect(g.favor[1], 1);
      expect(g.favor[4], 0);
      expect(g.favor[5], 0);
      expect(g.favor[6], 0);
      expect(g.charmPointsFor(0), 2 + 3 + 4 + 5);
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.placings, [1, 2]);
    });
  });

  test('bot simulations (30 runs per option/player combination)', () {
    expect(runSims(cards14Games, n: 30), 0);
  });
}
