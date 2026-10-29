import 'dart:math';

import 'package:aurora_shared/games/cards19/defs.dart';
import 'package:aurora_shared/games/cards19/linko.dart';
import 'package:aurora_shared/games/cards19/mus.dart';
import 'package:aurora_shared/games/cards19/tressette.dart';
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
  group('mus (西班牙穆斯牌 Mus)', () {
    test('8-King rule (3 == K, 2 == A) and 4-Category comparisons (Grande, Chica, Pares, Juego)', () {
      final deck = buildMusDeck();
      expect(deck.length, 40);

      // 3 counts as K(8) and 2 counts as A(1)
      expect(musEffectiveRank('3O'), 'K');
      expect(musEffectiveRank('KO'), 'K');
      expect(musEffectiveRank('2C'), 'A');
      expect(musEffectiveRank('AC'), 'A');
      expect(musRankStrength('3O'), musRankStrength('KO'));
      expect(musRankStrength('2C'), musRankStrength('AC'));

      // 1. Grande: lexicographical from highest to lowest
      expect(
        musCompareGrande(['KO', '3C', '7E', 'AB'], ['KO', 'QC', 'QE', 'QB']),
        greaterThan(0),
      );

      // 2. Chica: lexicographical from lowest to highest (A/2 is best!)
      expect(
        musCompareChica(['AO', '2C', '7E', 'KB'], ['AO', '4C', '4E', '4B']),
        greaterThan(0),
      );

      // 3. Pares: Duples (Four-of-a-Kind or Two Pair) > Medias (Three-of-a-Kind) > Par (One Pair)
      final duples = ['KO', '3C', '7E', '7B']; // Two pair: K/3 & 7/7
      final medias = ['KO', '3C', 'KE', '4B']; // Three Kings
      final par = ['QO', 'QC', '7E', '4B']; // Pair of Queens
      expect(musEvaluatePares(duples)['type'], 'duples');
      expect(musEvaluatePares(medias)['type'], 'medias');
      expect(musEvaluatePares(par)['type'], 'par');
      expect(musComparePares(duples, medias), greaterThan(0));
      expect(musComparePares(medias, par), greaterThan(0));

      // 4. Juego hierarchy: 31 (Best!) > 32 > 40 > 37 > 36 > 35 > 34 > 33
      expect(musHandSum(['KO', '3C', 'QE', 'AB']), 31); // 10 + 10 + 10 + 1 = 31
      expect(musHandSum(['KO', '3C', 'QE', '2B']), 31); // 2 also counts as 1!
      final juegoOrder = [31, 32, 40, 37, 36, 35, 34, 33];
      for (var i = 0; i < juegoOrder.length - 1; i++) {
        expect(
          musJuegoStrength(juegoOrder[i]),
          greaterThan(musJuegoStrength(juegoOrder[i + 1])),
        );
      }
    });

    test('Mus discard negotiation, Cortar cut, Envido/Fold (Deje), and Órdago instant match resolution', () {
      final g = MusGame(_setup(2, {'targetScore': 30}))..start();
      g.dealer = 1;
      g.mano = 0;
      g.turn = 0;
      g.hands[0] = ['KO', '3C', 'QE', 'AB']; // Two Kings, Q, A -> sum = 31 (Best Juego!)
      g.hands[1] = ['QO', 'JC', '7E', '6B']; // No pair, sum = 33

      // Both players agree to 'mus' -> enter 'discard', discard 0 cards, then Seat 0 chooses 'cortar'
      g.handle(0, {'type': 'mus'});
      g.handle(1, {'type': 'mus'});
      expect(g.phase, 'discard');
      g.handle(0, {'type': 'discard', 'cards': const <String>[]});
      g.handle(1, {'type': 'discard', 'cards': const <String>[]});
      expect(g.phase, 'mus');

      g.handle(0, {'type': 'cortar'});
      expect(g.phase, 'bet');
      expect(g.stage, 0); // Stage 0: Grande

      // Stage 0 (Grande): Seat 0 bets Envido (+2), Seat 1 folds (No quiero) -> Seat 0 gets +1 Deje immediately!
      g.handle(0, {'type': 'envido', 'amount': 2});
      g.handle(1, {'type': 'fold'});
      expect(g.scores[0], 1);
      expect(g.stage, 1); // Advances to Stage 1: Chica

      // Stage 1 (Chica): Seat 0 shouts Órdago!, Seat 1 accepts (Quiero) -> immediate showdown on Chica!
      // Seat 0 has 'AB' (rank 1), Seat 1 lowest is '6B' (rank 4) -> Seat 0 wins Chica and the match!
      g.handle(0, {'type': 'ordago'});
      g.handle(1, {'type': 'accept'});
      expect(g.isOver, isTrue);
      expect(g.placings, [1, 2]);
    });
  });

  group('tressette (意大利特雷塞特牌 Tressette)', () {
    test('40-card Italian deck, 3 > 2 > A > K > Q > J > 7 > 6 > 5 > 4 rank order, thirds scoring, and Napoli / Bongioco melds', () {
      final deck = buildTressetteDeck();
      expect(deck.length, 40);

      // Rank hierarchy: 3 > 2 > A > K > Q > J > 7 > 6 > 5 > 4
      expect(tressetteRankOrder('3D'), greaterThan(tressetteRankOrder('2D')));
      expect(tressetteRankOrder('2D'), greaterThan(tressetteRankOrder('AD')));
      expect(tressetteRankOrder('AD'), greaterThan(tressetteRankOrder('KD')));
      expect(tressetteRankOrder('KD'), greaterThan(tressetteRankOrder('QD')));
      expect(tressetteRankOrder('QD'), greaterThan(tressetteRankOrder('JD')));
      expect(tressetteRankOrder('JD'), greaterThan(tressetteRankOrder('7D')));
      expect(tressetteRankOrder('7D'), greaterThan(tressetteRankOrder('4D')));

      // Total thirds across the 40-card deck = 4 Aces (12 thirds) + 20 Figures (20 thirds) = 32 thirds (+ 3 Ultima = 35 thirds -> 11 full pts)
      final deckThirds = deck.fold<int>(0, (sum, c) => sum + tressetteCardThirds(c));
      expect(deckThirds, 32);
      expect(tressetteThirdsToFullPoints(deckThirds + 3), 11);

      // Accuse: Napoli (3D + 2D + AD = +3 pts) & Bongioco (Four 3s = +4 pts)
      final hand = ['3D', '2D', 'AD', '3C', '3S', '3B', '7D', '6D', '5D', '4D'];
      final accuse = tressetteAvailableAccuse(hand);
      final byId = {for (final m in accuse) m['id']: m['points']};
      expect(byId['napoli_D'], 3);
      expect(byId['bongioco_3_4'], 4);
    });

    test('No-trump trick resolution, mandatory suit following, Accusa declaration on Trick 1, and Ultima (+3 thirds)', () {
      final g = TressetteGame(_setup(2, {'rounds': 1}))..start();
      g.stock = [];
      g.turn = 0;
      g.leader = 0;
      g.trickNumber = 1;
      g.hands[0] = ['3D', '2D', 'AD'];
      g.hands[1] = ['KD', '3S', 'AS'];

      // Seat 0 declares Napoli in Denari (+3 full points) on Trick 1 before playing
      g.handle(0, {'type': 'accusa', 'id': 'napoli_D'});
      expect(g.handMeldPoints[0], 3);

      // Trick 1: Seat 0 leads AD, Seat 1 MUST follow suit 'D' with 'KD' (cannot play 3S)
      g.handle(0, {'type': 'play', 'card': 'AD'});
      expect(g.legalCards(1), ['KD']);
      g.handle(1, {'type': 'play', 'card': 'KD'});
      // AD (rank 7) beats KD (rank 6); AD(3) + KD(1) = 4 thirds
      expect(g.handCardThirds[0], 4);

      // Trick 2: Seat 0 leads 2D, Seat 1 is void in D and plays 3S (off-suit 3S cannot win because there is NO trump!)
      g.handle(0, {'type': 'play', 'card': '2D'});
      g.handle(1, {'type': 'play', 'card': '3S'});
      // Seat 0 wins Trick 2 (2D(1) + 3S(1) = 2 thirds -> total 6 thirds)
      expect(g.handCardThirds[0], 6);

      // Trick 3 (Last Trick / Ultima): Seat 0 leads 3D, Seat 1 plays AS
      g.handle(0, {'type': 'play', 'card': '3D'});
      g.handle(1, {'type': 'play', 'card': 'AS'});
      // Seat 0 wins 3D(1) + AS(3) + Ultima(3) = +7 thirds -> total 13 thirds (4 full pts) + 3 Napoli pts = 7 pts!
      expect(g.isOver, isTrue);
      expect(g.scores[0], 7);
      expect(g.placings, [1, 2]);
    });
  });

  group('linko (林科抢牌 Linko!)', () {
    test('109-card deck (Ranks 1..13 x 8 + 5 Jokers X=14), equal-count lower-rank Snatch, and (+tableau - hand) scoring', () {
      final deck = buildLinkoDeck();
      expect(deck.length, 109);
      expect(deck.where((c) => c == 14).length, 5);
      expect(deck.where((c) => c == 7).length, 8);

      final g = LinkoGame(_setup(2, {'rounds': 1}))..start();
      expect(g.hands[0].length, 13);
      expect(g.hands[1].length, 13);
      expect(g.pool.length, 6);

      // Set up a specific tableau & hand scenario to verify Linko Snatch
      g.turn = 0;
      g.hands[0] = [9, 9, 12];
      g.hands[1] = [5, 5, 3, 4];
      g.tableau[0] = [];
      g.tableau[1] = [
        {
          'rank': 6,
          'count': 2,
          'jokers': 0,
          'cards': [6, 6],
        },
        {
          'rank': 11,
          'count': 2,
          'jokers': 0,
          'cards': [11, 11],
        },
        {
          'rank': 4,
          'count': 3,
          'jokers': 0,
          'cards': [4, 4, 4],
        },
      ];

      // Seat 0 plays two 9s (rank: 9, count: 2) -> snatches Seat 1's [6, 6] (same count 2, lower rank 6 < 9),
      // while [11, 11] (rank 11 > 9) and [4, 4, 4] (count 3 != 2) remain untouched!
      g.handle(0, {'type': 'play', 'rank': 9, 'count': 2, 'jokers': 0});
      expect(g.phase, 'snatch');
      expect(g.pendingSnatches.length, 1);
      expect(g.pendingSnatches.first['rank'], 6);
      expect(g.tableau[1].length, 2);

      // Seat 0 chooses 'return' (force Seat 1 to take [6, 6] back into hand)
      g.handle(0, {'type': 'snatch_choice', 'choice': 'return'});
      expect(g.phase, 'play');
      expect(g.hands[1].where((c) => c == 6).length, 2);

      // Seat 1 plays pair of 5s -> no snatch
      g.handle(1, {'type': 'play', 'rank': 5, 'count': 2, 'jokers': 0});
      expect(g.turn, 0);

      // Seat 0 plays last card [12] -> empties hand and ends round immediately!
      g.handle(0, {'type': 'play', 'rank': 12, 'count': 1, 'jokers': 0});
      expect(g.isOver, isTrue);
      // Seat 0 has 3 cards in tableau ([9,9], [12]) and 0 cards in hand -> score = +3 - 0 = 3
      expect(g.scores[0], 3);
    });
  });

  test('bot simulations (30 runs per option/player combination)', () {
    expect(runSims(cards19Games, n: 30), 0);
  });
}
