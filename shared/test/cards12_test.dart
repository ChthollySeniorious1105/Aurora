import 'dart:math';

import 'package:aurora_shared/games/cards12/defs.dart';
import 'package:aurora_shared/games/cards12/skullking.dart';
import 'package:aurora_shared/games/cards12/tarot.dart';
import 'package:aurora_shared/games/cards12/tichu.dart';
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
  group('Tichu (地主牌)', () {
    test('56-card deck, 100 total card points, and special card combinations (MJ, DOG, PHX, DRG, Bombs)', () {
      final deck = buildTichuDeck();
      expect(deck.length, 56);
      final totalPts = deck.fold<int>(0, (s, c) => s + tichuCardPoints(c));
      expect(totalPts, 100);

      // Phoenix single rank = lastSingle + 0.5, beats A(14) but CANNOT beat Dragon(15)
      final aceSingle = evaluateTichuCombo(['AS'])!;
      final phxOnAce = evaluateTichuCombo(['PHX'], lastSingleRank: aceSingle.rank)!;
      final drgSingle = evaluateTichuCombo(['DRG'])!;
      final phxOnDrg = evaluateTichuCombo(['PHX'], lastSingleRank: drgSingle.rank)!;
      expect(phxOnAce.rank, 14.5);
      expect(canBeatTichuCombo(phxOnAce, aceSingle), isTrue);
      expect(canBeatTichuCombo(drgSingle, phxOnAce), isTrue);
      expect(canBeatTichuCombo(phxOnDrg, drgSingle), isFalse);

      // Four-of-a-kind bomb beats Dragon, and Straight Flush bomb beats Four-of-a-kind bomb
      final fourBomb = evaluateTichuCombo(cs('7S 7H 7D 7C'))!;
      final sfBomb = evaluateTichuCombo(cs('3S 4S 5S 6S 7S'))!;
      expect(fourBomb.isBomb, isTrue);
      expect(sfBomb.isBomb, isTrue);
      expect(canBeatTichuCombo(fourBomb, drgSingle), isTrue);
      expect(canBeatTichuCombo(sfBomb, fourBomb), isTrue);

      // Phoenix wildcard in straight and full house
      final phxStraight = evaluateTichuCombo(cs('MJ 2S PHX 4D 5C'))!;
      expect(phxStraight.type, 'straight');
      expect(phxStraight.rank, 5.0);
    });

    test('Dog transfers lead to partner, Mahjong Wish enforces rank, and Dragon gift to opponent', () {
      final g = TichuGame(_setup(4, {'targetScore': 200}))..start();
      g.hands = [
        cs('DOG DRG AS KS'),
        cs('9S 8S 7S 6S'),
        cs('MJ 2S 3S 4S'),
        cs('TS JS QS KH'),
      ];
      g.turn = 0;

      // Seat 0 leads DOG -> lead immediately transfers to partner Seat 2!
      g.handle(0, {'type': 'play', 'cards': ['DOG']});
      expect(g.turn, 2);

      // Seat 2 leads MJ and declares Wish for rank 10 ('T')
      g.handle(2, {'type': 'play', 'cards': ['MJ'], 'wish': 10});
      expect(g.activeWish, 10);
      expect(g.turn, 3);

      // Seat 3 holds 'TS' and can legally beat 'MJ'(1) -> cannot pass or play 'JS'!
      expect(() => g.handle(3, {'type': 'pass'}), throwsA(isA<GameError>()));
      expect(
        () => g.handle(3, {'type': 'play', 'cards': ['JS']}),
        throwsA(isA<GameError>()),
      );

      // Seat 3 plays 'TS' -> fulfills the Mahjong wish!
      g.handle(3, {'type': 'play', 'cards': ['TS']});
      expect(g.activeWish, isNull);

      // Seat 0 plays 'DRG' (Dragon), everyone passes -> enters 'give_dragon' phase!
      g.handle(0, {'type': 'play', 'cards': ['DRG']});
      g.handle(1, {'type': 'pass'});
      g.handle(2, {'type': 'pass'});
      g.handle(3, {'type': 'pass'});
      expect(g.phase, 'give_dragon');
      expect(g.turn, 0);

      // Cannot give Dragon trick to partner (2), must give to opponent (1 or 3)
      expect(
        () => g.handle(0, {'type': 'give_dragon', 'target': 2}),
        throwsA(isA<GameError>()),
      );
      g.handle(0, {'type': 'give_dragon', 'target': 1});
      expect(g.phase, 'play');
      expect(g.capturedCards[1], containsAll(['MJ', 'TS', 'DRG']));
    });

    test('Tichu call (+100) and 1-2 Double Victory (200:0)', () {
      final g = TichuGame(_setup(4, {'targetScore': 200}))..start();
      g.hands = [
        cs('AS'),
        cs('2S 3S'),
        cs('KS'),
        cs('4S 5S'),
      ];
      g.playedFirstCard = [false, false, false, false];
      g.turn = 0;

      // Seat 0 calls Tichu before playing first card
      g.handle(0, {'type': 'call_tichu'});
      expect(g.tichuCalled[0], isTrue);

      // Seat 0 plays AS and goes out 1st!
      g.handle(0, {'type': 'play', 'cards': ['AS']});
      expect(g.finishOrder, [0]);

      g.handle(1, {'type': 'pass'});
      g.handle(2, {'type': 'pass'});
      g.handle(3, {'type': 'pass'});

      // Lead goes to Seat 1; Seat 1 leads 2S, Partner Seat 2 beats with KS and goes out 2nd!
      expect(g.turn, 1);
      g.handle(1, {'type': 'play', 'cards': ['2S']});
      g.handle(2, {'type': 'play', 'cards': ['KS']});

      // Seats 0 and 2 (Team 0) finished 1st & 2nd -> 200:0 + 100 Tichu = 300:0 -> game over!
      expect(g.isOver, isTrue);
      expect(g.lastHandSummary!['doubleVictory'], isTrue);
      expect(g.teamScores[0], 300);
      expect(g.teamScores[1], 0);
      expect(g.placings, [1, 2, 1, 2]);
    });
  });

  group('Tarot (法国塔罗牌 Jeu de Tarot)', () {
    test('78-card deck, 91.0 total points, Oudler dynamic target (56/51/41/36), and mandatory overtrump', () {
      final deck = buildTarotDeck();
      expect(deck.length, 78);
      final totalPts = deck.fold<double>(0, (s, c) => s + tarotCardPoints(c));
      expect(totalPts, closeTo(91.0, 1e-6));

      expect(tarotTargetPoints(0), 56);
      expect(tarotTargetPoints(1), 51);
      expect(tarotTargetPoints(2), 41);
      expect(tarotTargetPoints(3), 36);

      // Test mandatory trump & overtrump when void in led suit ('S')
      final trick = [
        {'seat': 0, 'card': 'KS'},
        {'seat': 1, 'card': 'T10'},
      ];
      // Hand is void in 'S', holds T5, T15, T0, and 9H -> must overtrump T10 with T15 (or play T0)!
      final legal = getTarotLegalCards(cs('T0 T5 T15 9H'), trick);
      expect(legal, unorderedEquals(['T0', 'T15']));

      // If all trumps in hand are < T10, must still play a trump (undertrump) or T0
      final legalUnder = getTarotLegalCards(cs('T0 T5 T8 9H'), trick);
      expect(legalUnder, unorderedEquals(['T0', 'T5', 'T8']));
    });

    test('Garde sans bid, Fool retention in owner score pile, and Petit au Bout (+10 * mult)', () {
      final g = TarotGame(_setup(3, {'rounds': 1}))..start();
      final f = g.forehand;
      final m = (f + 1) % 3;
      final r = (f + 2) % 3;

      // Forehand bids Garde sans (3 -> x4 multiplier) -> goes straight to 'play'
      g.handle(f, {'type': 'bid', 'bid': 3});
      expect(g.phase, 'play');
      expect(g.declarer, f);

      // Fast-forward to the final trick:
      // Declarer (f) already has 3 Oudlers (T0, T1, T21 -> target 36) and 45 pts in declarerCaptured
      g.tricksPlayed = g.totalTricks - 1;
      g.declarerCaptured = cs('T21 KS KH KD KC QS QH QD QC'); // > 36 pts + T21
      g.defenderCaptured = [];
      g.hands[f] = ['T1']; // Petit on final trick!
      g.hands[m] = ['T0']; // Defender plays The Fool -> stays with defenders!
      g.hands[r] = ['2S'];
      g.turn = f;

      g.handle(f, {'type': 'play', 'card': 'T1'});
      g.handle(m, {'type': 'play', 'card': 'T0'});
      g.handle(r, {'type': 'play', 'card': '2S'});

      expect(g.isOver, isTrue);
      // T1 won the final trick for Declarer -> +10 * 4 = +40 Petit au Bout bonus!
      expect(g.lastHandSummary!['petitBonus'], 40);
      // T0 stayed with Defenders, while T1 went to Declarer (2 Oudlers: T21, T1 -> target 41)
      expect(g.defenderCaptured, contains('T0'));
      expect(g.lastHandSummary!['oudlerCount'], 2);
      expect(g.lastHandSummary!['targetPoints'], 41);
      expect(g.lastHandSummary!['declarerWon'], isTrue);
      expect(g.scores[f], greaterThan(0));
    });
  });

  group('Skull King (骷髅王)', () {
    test('70-card deck and Rock-Paper-Scissors hierarchy (MER lures SK +40, SK beats PIR +30)', () {
      final deck = buildSkullKingDeck();
      expect(deck.length, 70);

      // 1. Skull King beats Pirates (+30 per Pirate, including Tigress as Pirate)
      final resSk = resolveSkullKingTrick([
        {'seat': 0, 'card': '14B'},
        {'seat': 1, 'card': 'PIR'},
        {'seat': 2, 'card': 'TIG', 'mode': 'pirate'},
        {'seat': 3, 'card': 'SK'},
      ]);
      expect(resSk.winnerSeat, 3);
      expect(resSk.bonusPoints, 60); // 2 pirates * 30

      // 2. Mermaid lures Skull King (+40), even when a Pirate is also in the trick!
      final resMer = resolveSkullKingTrick([
        {'seat': 0, 'card': 'PIR'},
        {'seat': 1, 'card': 'SK'},
        {'seat': 2, 'card': 'MER'},
      ]);
      expect(resMer.winnerSeat, 2);
      expect(resMer.bonusPoints, 40);

      // 3. Pirate beats Mermaid when Skull King is absent
      final resPir = resolveSkullKingTrick([
        {'seat': 0, 'card': 'MER'},
        {'seat': 1, 'card': 'PIR'},
      ]);
      expect(resPir.winnerSeat, 1);

      // 4. All Escapes -> trick leader wins
      final resEsc = resolveSkullKingTrick([
        {'seat': 2, 'card': 'ESC'},
        {'seat': 0, 'card': 'TIG', 'mode': 'escape'},
        {'seat': 1, 'card': 'ESC'},
      ]);
      expect(resEsc.winnerSeat, 2);
    });

    test('simultaneous bidding, Tigress mode choice, and exact vs zero bid scoring', () {
      final g = SkullKingGame(_setup(3, {'rounds': 4}))..start();
      // Round 1 of 4-round mode deals 2 cards each
      expect(g.roundCards, 2);
      expect(g.phase, 'bid');
      expect(g.waitingFor, [0, 1, 2]);

      g.hands = [
        cs('MER 14B'),
        cs('SK ESC'),
        cs('TIG 2Y'),
      ];

      // Simultaneous bids: Seat 0 bids 2, Seat 1 bids 0, Seat 2 bids 1
      g.handle(0, {'type': 'bid', 'bid': 2});
      g.handle(1, {'type': 'bid', 'bid': 0});
      g.handle(2, {'type': 'bid', 'bid': 1});
      expect(g.phase, 'play');

      // Trick 1: Seat 0 plays MER, Seat 1 plays SK, Seat 2 plays TIG as escape
      // Seat 0 wins with MER luring SK (+40 bonus)!
      g.turn = 0;
      g.handle(0, {'type': 'play', 'card': 'MER'});
      g.handle(1, {'type': 'play', 'card': 'SK'});
      g.handle(2, {'type': 'play', 'card': 'TIG', 'mode': 'escape'});
      expect(g.tricksWon[0], 1);
      expect(g.roundBonus[0], 40);

      // Trick 2: Seat 0 leads 14B, Seat 1 plays ESC, Seat 2 plays 2Y -> Seat 0 wins!
      g.handle(0, {'type': 'play', 'card': '14B'});
      g.handle(1, {'type': 'play', 'card': 'ESC'});
      g.handle(2, {'type': 'play', 'card': '2Y'});

      // End of round 1:
      // Seat 0: bid 2, won 2 -> +20*2 + 40 = +80
      // Seat 1: bid 0, won 0 (in 2-card round) -> +10*2 = +20
      // Seat 2: bid 1, won 0 -> -10*|1-0| = -10
      expect(g.scores, [80, 20, -10]);
    });
  });

  test('bot simulations for cards12Games (count: 30)', () {
    expect(runSims(cards12Games, n: 30), 0);
  });
}
