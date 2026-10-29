import 'dart:math';

import 'package:aurora_shared/games/cards9/defs.dart';
import 'package:aurora_shared/games/cards9/koikoi.dart';
import 'package:aurora_shared/games/cards9/piquet.dart';
import 'package:aurora_shared/games/cards9/thecrew.dart';
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
  group('Koi-Koi (花札·来来)', () {
    test('48-card categorization and Yaku scoring including Sake Cup dual role', () {
      expect(kHanafudaCards.length, 48);
      expect(kBrightCards.length, 5);
      expect(kAnimalCards.length, 9);
      expect(kRibbonCards.length, 10);
      expect(
        kHanafudaCards.where((c) => c.category == 'chaff').length,
        24,
      );

      // 五光 (10), 四光 (8), 雨四光 (7), 三光 (5)
      expect(computeKoiKoiYaku([0, 8, 28, 40, 44]).points, 10);
      expect(computeKoiKoiYaku([0, 8, 28, 44]).points, 8);
      expect(computeKoiKoiYaku([0, 8, 28, 40]).points, 7);
      expect(computeKoiKoiYaku([0, 8, 28]).points, 5);
      expect(computeKoiKoiYaku([0, 8, 40]).points, 0); // Rain-man + 2 brights is not 三光

      // 猪鹿蝶 (5), 花见酒 (5), 月见酒 (5), 赤短+青短 (10)
      expect(computeKoiKoiYaku([20, 24, 36]).points, 5);
      expect(computeKoiKoiYaku([8, 32]).points, 5);
      expect(computeKoiKoiYaku([28, 32]).points, 5);
      // 赤短 (1,5,9) + 青短 (21,33,37) = 10 + 短(6-4=2) = 12
      expect(computeKoiKoiYaku([1, 5, 9, 21, 33, 37]).points, 12);

      // Sake Cup (32) counts as both Animal and Chaff!
      final nineChaffPlusCup = [2, 3, 6, 7, 10, 11, 14, 15, 18, 32];
      expect(computeKoiKoiYaku(nineChaffPlusCup).points, 1); // 10 chaff -> 1 pt
    });

    test('hand/stock capture, 3-on-field sweep, and koikoi vs shobu multipliers', () {
      final g = KoiKoiGame(_setup(2, {'rounds': 3}))..start();
      g.turn = 0;
      g.step = 'hand';
      // Put 3 Jan cards (1, 2, 3) on field and 2 Feb cards (5, 6) on field
      g.field = [1, 2, 3, 5, 6];
      g.hands = [
        [0, 12], // P0 has Jan Crane (0)
        [16, 20],
      ];
      g.stock = [4]; // Stock top is Feb Bush Warbler (4), matching 2 Feb cards on field!
      g.captured = [
        [8, 28, 44], // P0 already has 3 Brights
        [],
      ];
      g.lastYakuPoints = [5, 0];
      g.calledKoiKoi = [false, true]; // Opponent (P1) previously called Koi-Koi!

      // P0 plays 0 (Jan): sweeps all 3 Jan cards (1, 2, 3) from field!
      // Then draws 4 (Feb) from stock -> 2 Feb cards (5, 6) on field -> enters 'stock' step!
      g.handle(0, {'type': 'play_hand', 'card': 0});
      expect(g.captured[0], containsAll([0, 1, 2, 3]));
      expect(g.step, 'stock');
      expect(g.drawnCard, 4);

      // P0 chooses to match 5 from field -> now has 四光 (0, 8, 28, 44 = 8 pts > 5 pts) -> enters 'koikoi' phase!
      g.handle(0, {'type': 'match_stock', 'match': 5});
      expect(g.step, 'koikoi');

      // P0 declares 'shobu': base = 8 (>=7 so ×2 = 16), opponent called Koi-Koi (×2 = 32)!
      g.handle(0, {'type': 'shobu'});
      expect(g.scores[0], 32);
      expect(g.round, 2);
    });
  });

  group('The Crew (星际探险队)', () {
    test('Commander has R4, task drafting, radio communication rules, and mission completion', () {
      final g = TheCrewGame(_setup(3, {'missions': 1, 'difficulty': 'normal'}))..start();
      expect(g.hands[g.commander].contains('R4'), isTrue);
      expect(g.phase, 'draft_tasks');
      expect(g.turn, g.commander);

      // Set up 2 tasks with token '1' on task 0
      g.tasks = [
        {'card': 'B9', 'token': '1', 'owner': null, 'completed': false, 'completedOrder': null},
        {'card': 'G9', 'token': null, 'owner': null, 'completed': false, 'completedOrder': null},
      ];
      final c0 = g.commander;
      final c1 = (c0 + 1) % 3;
      final c2 = (c0 + 2) % 3;

      g.handle(c0, {'type': 'take_task', 'index': 0});
      g.handle(c1, {'type': 'take_task', 'index': 1});
      expect(g.phase, 'play');
      expect(g.turn, c0);

      // Set up hands for radio communication & trick play
      g.hands[c0] = ['B9', 'B5', 'B1', 'R4'];
      g.hands[c1] = ['B2', 'G9', 'P3', 'Y3'];
      g.hands[c2] = ['B3', 'G2', 'P4', 'Y4'];

      // Middle card 'B5' and Rocket 'R4' cannot be communicated
      expect(
        () => g.handle(c0, {'type': 'communicate', 'card': 'B5'}),
        throwsA(isA<GameError>()),
      );
      expect(
        () => g.handle(c0, {'type': 'communicate', 'card': 'R4'}),
        throwsA(isA<GameError>()),
      );
      // Highest card 'B9' can be communicated
      g.handle(c0, {'type': 'communicate', 'card': 'B9'});
      expect(g.radio[c0]!['position'], 'highest');

      // Trick 1: c0 leads B9, c1 must follow Blue (plays B2), c2 plays B3 -> c0 wins task 0 ('B9' [1])!
      g.handle(c0, {'type': 'play', 'card': 'B9'});
      expect(
        () => g.handle(c1, {'type': 'play', 'card': 'G9'}),
        throwsA(isA<GameError>()),
      );
      g.handle(c1, {'type': 'play', 'card': 'B2'});
      g.handle(c2, {'type': 'play', 'card': 'B3'});
      expect(g.tasks[0]['completed'], isTrue);

      // Trick 2: c0 leads P1? Give c0 'G1' so c1 can win 'G9' (task 1)
      g.hands[c0].add('G1');
      g.handle(c0, {'type': 'play', 'card': 'G1'});
      g.handle(c1, {'type': 'play', 'card': 'G9'});
      g.handle(c2, {'type': 'play', 'card': 'G2'});

      // Both tasks completed in valid order -> 1-mission campaign won!
      expect(g.isOver, isTrue);
      expect(g.campaignWon, isTrue);
      expect(g.placings, [1, 1, 1]);
    });
  });

  group('Piquet (皮克牌)', () {
    test('exchange phase, Carte Blanche, Point/Sequence/Set declarations, and Repique (+60)', () {
      final g = PiquetGame(_setup(2, {'target': 100}))..start();
      expect(g.phase, 'exchange');
      expect(g.turn, g.elder);

      // Elder must discard 1..5 cards (0 is illegal)
      expect(
        () => g.handle(g.elder, {'type': 'exchange', 'cards': <String>[]}),
        throwsA(isA<GameError>()),
      );
      g.handle(g.elder, {'type': 'exchange', 'cards': [g.hands[g.elder].first]});
      expect(g.turn, g.younger);
      // Younger may discard 0 cards
      g.handle(g.younger, {'type': 'exchange', 'cards': <String>[]});
      expect(g.phase, 'play');

      // Set up Elder (seat 0) with Carte Blanche (no J/Q/K) + 6-card Spade sequence + 4 Tens (Quatorze)
      // Wait: 7S,8S,9S,TS + 4 Tens (TS,TH,TD,TC) + AS,AH,AD,AC (4 Aces = 14)
      // No J/Q/K -> Carte Blanche (+10)!
      // Point: 5 Spades (7S,8S,9S,TS,AS) = 5 pts
      // Sequence: 4 Spades (7S,8S,9S,TS) = 4 pts
      // Sets: 4 Aces (14) + 4 Tens (14) = 28 pts
      // Total declarations = 10 + 5 + 4 + 28 = 47 >= 30 -> triggers Repique (+60) = 107 pts!
      g.hands[0] = cs('7S 8S 9S TS AS TH TD TC AH AD AC 7H');
      g.hands[1] = cs('JS QS KS JD QD KD JC QC KC 8H 9H 8D');
      g.declarationsScored = false;
      g.handPoints = [0, 0];
      g.turn = 0;

      g.handle(0, {'type': 'play', 'card': 'AS'});
      expect(g.declarationsScored, isTrue);
      expect(g.repiqueAwarded, isTrue);
      // 107 declaration + Repique + 1 for leading = 108
      expect(g.handPoints[0], 108);
    });

    test('12 no-trump tricks, Capot (+40), and Pique (+30)', () {
      final g = PiquetGame(_setup(2, {'target': 60}))..start();
      g.phase = 'play';
      g.declarationsScored = true;
      g.handPoints = [29, 0]; // Seat 0 at 29, Seat 1 at 0
      g.tricksPlayed = 11;
      g.tricksWon = [11, 0];
      g.hands = [
        ['AS'],
        ['7S'],
      ];
      g.turn = 0;
      g.leader = 0;

      // Seat 0 leads AS (+1 pt -> reaches 30 while opp is 0 -> Pique +30!)
      g.handle(0, {'type': 'play', 'card': 'AS'});
      expect(g.piqueAwarded, isTrue);
      expect(g.handPoints[0], 60);

      // Seat 1 follows 7S -> Seat 0 wins 12th trick (+1 last trick + 40 Capot = 101)
      g.handle(1, {'type': 'play', 'card': '7S'});
      expect(g.scores[0], 101);
      expect(g.isOver, isTrue);
      expect(g.placings, [1, 2]);
    });
  });

  test('bot simulations for cards9Games (count: 30)', () {
    expect(runSims(cards9Games, n: 30), 0);
  });
}
