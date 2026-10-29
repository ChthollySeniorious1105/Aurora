import 'dart:math';

import 'package:aurora_shared/games/cards18/bezique.dart';
import 'package:aurora_shared/games/cards18/defs.dart';
import 'package:aurora_shared/games/cards18/scout.dart';
import 'package:aurora_shared/games/cards18/tute.dart';
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
  group('tute (西班牙图特牌 Tute)', () {
    test('40-card Spanish deck, rank hierarchy A > 3 > K > Q > J > 7 > 6 > 5 > 4 > 2, and 120 card points', () {
      final deck = buildTuteDeck();
      expect(deck.length, 40);

      // Total card points across the 40-card deck = 120
      final totalPts = deck.fold<int>(0, (sum, c) => sum + tuteCardPoints(c));
      expect(totalPts, 120);

      // Rank order: A(9) > 3(8) > K(7) > Q(6) > J(5) > 7(4) > 6(3) > 5(2) > 4(1) > 2(0)
      expect(tuteRankOrder('AO'), greaterThan(tuteRankOrder('3O')));
      expect(tuteRankOrder('3O'), greaterThan(tuteRankOrder('KO')));
      expect(tuteRankOrder('KO'), greaterThan(tuteRankOrder('QO')));
      expect(tuteRankOrder('QO'), greaterThan(tuteRankOrder('JO')));
      expect(tuteRankOrder('JO'), greaterThan(tuteRankOrder('7O')));
      expect(tuteRankOrder('7O'), greaterThan(tuteRankOrder('2O')));
    });

    test('Strict Spanish Following Rules (Montar & Fallar) and Cantes (+40/+20) & Tute (4K/4Q) declarations', () {
      // 1. Montar: follower holds led suit ('C') and can beat 'KC' -> must play '3C' or 'AC'
      expect(
        tuteLegalCards(
          ['AC', '3C', '4C', 'AO'],
          [
            {'seat': 0, 'card': 'KC'},
          ],
          'O',
          strict: true,
        ),
        ['AC', '3C'],
      );

      // 2. Follower holds led suit ('C') but cannot beat 'AC' -> must still follow 'C'
      expect(
        tuteLegalCards(
          ['7C', '4C', 'AO'],
          [
            {'seat': 0, 'card': 'AC'},
          ],
          'O',
          strict: true,
        ),
        ['7C', '4C'],
      );

      // 3. Fallar: void in led suit ('C'), holds trumps ('O'), earlier trump '7O' in trick -> must overtrump with 'KO'!
      expect(
        tuteLegalCards(
          ['KO', '2O', 'AE'],
          [
            {'seat': 0, 'card': 'AC'},
            {'seat': 1, 'card': '7O'},
          ],
          'O',
          strict: true,
        ),
        ['KO'],
      );

      // 4. Declarations: Las Cuarenta (+40 in trump), Veinte (+20 in non-trump), and Tute (4 Kings instant win)
      final g = TuteGame(_setup(2, {'rounds': 1}))..start();
      g.trumpSuit = 'O';
      g.turn = 0;
      g.sideTricksWon[0] = 1;
      g.hands[0] = ['KO', 'QO', 'KC', 'QC', 'KE', 'KB', '7B', '2B'];

      // Declare Las Cuarenta (trump K+Q = +40)
      g.handle(0, {'type': 'cante', 'suit': 'O'});
      expect(g.handCantePoints[0], 40);

      // Declare Veinte (non-trump K+Q = +20)
      g.handle(0, {'type': 'cante', 'suit': 'C'});
      expect(g.handCantePoints[0], 60);

      // Declare Tute (all 4 Kings in hand -> instant hand win!)
      g.handle(0, {'type': 'tute'});
      expect(g.isOver, isTrue);
      expect(g.placings, [1, 2]);
    });
  });

  group('bezique (法国贝济克牌 Bezique)', () {
    test('64-card double deck, A > T > K > Q > J > 9 > 8 > 7 rank order, and all Meld point values', () {
      final deck = buildBeziqueDeck();
      expect(deck.length, 64);

      expect(beziqueRankOrder('AS_0'), greaterThan(beziqueRankOrder('TS_0')));
      expect(beziqueRankOrder('TS_0'), greaterThan(beziqueRankOrder('KS_0')));
      expect(beziqueRankOrder('KS_0'), greaterThan(beziqueRankOrder('QS_0')));

      // Verify Double Bezique (500), Trump Sequence (250), Four Aces (100), Bezique (40), Royal Marriage (40)
      final hand = [
        'QS_0',
        'QS_1',
        'JD_0',
        'JD_1',
        'AH_0',
        'TH_0',
        'KH_0',
        'QH_0',
        'JH_0',
        'AS_0',
        'AD_0',
        'AC_0',
      ];
      final melds = beziqueAvailableMelds(hand, 'H', <String>{});
      final byType = {for (final m in melds) m['type']: m['points']};
      expect(byType['double_bezique'], 500);
      expect(byType['trump_sequence'], 250);
      expect(byType['four_aces'], 100);
      expect(byType['bezique'], 40);
      expect(byType['royal_marriage'], 40);
    });

    test('Stage 1 trick-and-meld flow & Stage 2 strict following + Brisques (A/T +10) + Final Trick (+10)', () {
      final g = BeziqueGame(_setup(2, {'rounds': 1}))..start();
      g.trumpSuit = 'H';
      g.trumpCard = '9H_0';
      g.stock = ['8C_0', '9H_0'];
      g.turn = 0;
      g.leader = 0;
      g.hands[0] = ['AH_0', 'QS_0', 'JD_0'];
      g.hands[1] = ['7S_0', '8S_0', '9D_0'];

      // Trick 1 in Stage 1: Seat 0 leads AH_0 (+10 Brisque), Seat 1 plays 7S_0 (no suit obligation in Stage 1)
      g.handle(0, {'type': 'play', 'card': 'AH_0'});
      g.handle(1, {'type': 'play', 'card': '7S_0'});

      // Seat 0 won 1 Brisque (+10 pts) and enters 'meld' phase since QS_0 + JD_0 (Bezique +40) is in hand!
      expect(g.scores[0], 10);
      expect(g.phase, 'meld');

      // Seat 0 declares Bezique (+40 pts) -> draws last 2 cards of stock -> enters Stage 2!
      g.handle(0, {'type': 'meld', 'meld': 'bezique'});
      expect(g.scores[0], 50);
      expect(g.stage, 2);
      expect(g.stock.isEmpty, isTrue);

      // In Stage 2, followers MUST follow suit and beat the led card if able (or trump if void)
      g.hands[0] = ['KS_0', '7S_1'];
      g.hands[1] = ['AS_0', '8S_0'];
      g.handle(0, {'type': 'play', 'card': 'KS_0'});
      expect(g.legalCards(1), ['AS_0']); // Must head the trick with AS_0!
      g.handle(1, {'type': 'play', 'card': 'AS_0'});
      expect(g.scores[1], 10); // +10 Brisque for AS_0

      // Final Trick: Seat 1 leads 8S_0, Seat 0 plays 7S_1 -> Seat 1 wins Final Trick (+10)!
      g.handle(1, {'type': 'play', 'card': '8S_0'});
      g.handle(0, {'type': 'play', 'card': '7S_1'});

      // Seat 1 won 1 Brisque AS_0 (+10) + Final Trick (+10) = 20 pts
      expect(g.scores[1], 20);
      expect(g.isOver, isTrue);
    });
  });

  group('scout (马戏星探 SCOUT)', () {
    test('45 dual-number cards, whole-hand flip reversal, and Set vs Run climbing hierarchy', () {
      final deck = buildScoutDeck();
      expect(deck.length, 45);

      // Flipping hand [[2, 9], [5, 8], [7, 8]] reverses order and swaps top/bottom -> [[8, 7], [8, 5], [9, 2]]
      expect(
        scoutFlipHand([
          [2, 9],
          [5, 8],
          [7, 8],
        ]),
        [
          [8, 7],
          [8, 5],
          [9, 2],
        ],
      );

      // Combo hierarchy:
      // 1. More cards beats fewer cards: 3-card Run [1,2,3] beats 2-card Set [9,9]
      expect(
        scoutBeatsStage(
          [
            [1, 5],
            [2, 6],
            [3, 7],
          ],
          [
            [9, 1],
            [9, 2],
          ],
        ),
        isTrue,
      );

      // 2. Equal card count: Set [2,2] beats Run [8,9]
      expect(
        scoutBeatsStage(
          [
            [2, 5],
            [2, 6],
          ],
          [
            [8, 1],
            [9, 2],
          ],
        ),
        isTrue,
      );
      expect(
        scoutBeatsStage(
          [
            [8, 1],
            [9, 2],
          ],
          [
            [2, 5],
            [2, 6],
          ],
        ),
        isFalse,
      );

      // 3. Descending Run [6,5,4] beats Ascending Run [3,4,5]
      expect(
        scoutBeatsStage(
          [
            [6, 1],
            [5, 2],
            [4, 3],
          ],
          [
            [3, 1],
            [4, 2],
            [5, 3],
          ],
        ),
        isTrue,
      );
    });

    test('Orient flip, Show capture, Scout insertion + owner token, Scout & Show, and round-end exemption', () {
      final g = ScoutGame(_setup(3, {'rounds': 1}))..start();
      g.hands[0] = [
        [2, 8],
        [4, 8],
        [9, 1],
      ];
      g.hands[1] = [
        [5, 2],
        [5, 4],
        [3, 7],
      ];
      g.hands[2] = [
        [6, 1],
        [7, 2],
      ];

      // Flip phase: Seat 0 flips entire hand -> [[1, 9], [8, 4], [8, 2]]
      g.handle(0, {'type': 'orient', 'flip': true});
      g.handle(1, {'type': 'orient', 'flip': false});
      g.handle(2, {'type': 'orient', 'flip': false});
      expect(g.phase, 'play');
      expect(g.hands[0], [
        [1, 9],
        [8, 4],
        [8, 2],
      ]);

      // Seat 0 Shows pair of 8s (indices 1..2) -> stageCards = [[8,4], [8,2]], Seat 0 has 1 card left [[1,9]]
      g.handle(0, {'type': 'show', 'start': 1, 'end': 2});
      expect(g.stageCards.length, 2);
      expect(g.stageOwner, 0);

      // Seat 1 uses Scout & Show: scouts right card [8,2] flipped as [2,8] into index 2, Wait — or scouts [8,4]
      // Let's have Seat 1 Scout left card [8,4] without flipping into index 0 -> Seat 0 gets +1 scoutToken!
      g.handle(1, {
        'type': 'scout',
        'endSide': 'left',
        'flip': false,
        'insertAt': 0,
      });
      expect(g.scoutTokens[0], 1);
      expect(g.stageCards.length, 1); // Only [8, 2] remains on stage!

      // Seat 2 uses Scout & Show: scouts [8,2] unflipped at index 2 to make [6, 7, 8] 3-card run, then Shows 0..2 to empty hand!
      g.hands[2] = [
        [6, 1],
        [7, 2],
      ];
      g.handle(2, {
        'type': 'scout_and_show',
        'endSide': 'left',
        'flip': false,
        'insertAt': 2,
        'start': 0,
        'end': 2,
      });
      // Seat 2 played all 3 cards [6, 7, 8] in a single Show after Scouting -> empties hand and ends round!
      expect(g.isOver, isTrue);
      expect(g.lastRoundSummary!['roundEnder'], 2);
      expect(g.lastRoundSummary!['handPenalties'][2], 0);
    });
  });

  test('bot simulations (30 runs per option/player combination)', () {
    expect(runSims(cards18Games, n: 30), 0);
  });
}
