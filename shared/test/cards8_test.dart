import 'dart:math';

import 'package:aurora_shared/games/cards8/defs.dart';
import 'package:aurora_shared/games/cards8/red7.dart';
import 'package:aurora_shared/games/cards8/scopa.dart';
import 'package:aurora_shared/games/cards8/sixtysix.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n, Map<String, dynamic> opts, {int seed = 1}) => GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, true),
      rng: Random(seed),
    );

void main() {
  group('Sixty-Six (六十六点)', () {
    test('swap trump jack, marriage declaration, and reaching 66', () {
      final g = SixtySixGame(_setup(2, {'target': 3}))..start();
      g.turn = 0;
      g.leader = 0;
      g.trumpSuit = 'S';
      g.trumpCard = 'AS';
      g.stock = ['JD', 'QD', 'AS'];
      g.hands = [
        ['JS', 'KS', 'QS', 'AH', 'TH'],
        ['JD', 'QD', 'KD', 'JC', 'QC'],
      ];
      g.tricksWon = [1, 0];
      g.cardPoints = [20, 0];
      g.marriagePoints = [0, 0];

      // Swap JS with trumpCard AS
      expect(g.canSwapTrump(0), isTrue);
      g.handle(0, {'type': 'swap_trump'});
      expect(g.trumpCard, 'JS');
      expect(g.hands[0].contains('AS'), isTrue);

      // Lead KS while holding QS -> +40 Royal Marriage -> 20 + 40 = 60 pts
      g.handle(0, {'type': 'play', 'card': 'KS'});
      expect(g.marriagePoints[0], 40);
      expect(g.effectivePoints(0), 60);

      // Follower plays JD (stock is open, no obligation to follow suit)
      // Winner is 0, gains 4 + 2 = 6 pts -> 66 pts -> wins hand with 3 game points (opp 0 tricks)!
      g.handle(1, {'type': 'play', 'card': 'JD'});
      expect(g.gameScores[0], 3);
      expect(g.isOver, isTrue);
      expect(g.placings, [1, 2]);
    });

    test('close stock and strict following rules', () {
      final g = SixtySixGame(_setup(2, {'target': 7}))..start();
      g.turn = 0;
      g.leader = 0;
      g.trumpSuit = 'H';
      g.trumpCard = 'AH';
      g.stock = ['JD', 'QD', 'AH'];
      g.hands = [
        ['KS', 'AS', 'TH', 'KH', 'QH'],
        ['TS', 'JS', 'JC', 'QC', 'KC'],
      ];

      g.handle(0, {'type': 'close'});
      expect(g.closed, isTrue);

      // Seat 0 leads KS
      g.handle(0, {'type': 'play', 'card': 'KS'});
      // Seat 1 has TS (higher same suit) and JS (lower same suit). Must play TS!
      expect(
        () => g.handle(1, {'type': 'play', 'card': 'JC'}),
        throwsA(isA<GameError>()),
      );
      expect(
        () => g.handle(1, {'type': 'play', 'card': 'JS'}),
        throwsA(isA<GameError>()),
      );
      g.handle(1, {'type': 'play', 'card': 'TS'});
      expect(g.tricksWon[1], 1);
    });
  });

  group('Scopa (斯科帕)', () {
    test('single card priority, sum capture, and scopa bonus', () {
      final g = ScopaGame(_setup(2, {'targetScore': 6}))..start();
      g.turn = 0;
      g.table = ['3D', '4H', '7S'];
      g.hands = [
        ['7D', '5C'],
        ['AD', '2C'],
      ];
      g.deck = ['KD', 'KH'];

      // Playing 7D when 7S and (3D+4H) are on table: MUST capture single card 7S!
      expect(
        () => g.handle(0, {
          'type': 'play',
          'card': '7D',
          'capture': ['3D', '4H'],
        }),
        throwsA(isA<GameError>()),
      );
      g.handle(0, {
        'type': 'play',
        'card': '7D',
        'capture': ['7S'],
      });
      expect(g.captured[0], containsAll(['7D', '7S']));
      expect(g.table, ['3D', '4H']);

      // Seat 1 trails AD
      g.handle(1, {'type': 'play', 'card': 'AD', 'capture': <String>[]});
      expect(g.table, ['3D', '4H', 'AD']);

      // Seat 0 plays 5C: must capture 4H + AD = 5
      g.handle(0, {
        'type': 'play',
        'card': '5C',
        'capture': ['4H', 'AD'],
      });
      expect(g.table, ['3D']);
    });

    test('primiera and end-of-hand scoring', () {
      expect(calcPrimiera(['7D', '7H', '7S', '7C']), 84);
      expect(calcPrimiera(['6D', 'AH']), 18 + 16);

      final g = ScopaGame(_setup(2, {'targetScore': 6}))..start();
      g.table = ['2C'];
      g.deck = [];
      g.hands = [[], []];
      g.lastCapturer = 0;
      g.scopas = [2, 0];
      g.captured = [
        ['7D', '7H', '7S', '7C', 'AD', '2D', '3D', '4D', '5D', '6D'],
        ['KH', 'QH', 'JH'],
      ];
      g.finishHand();
      // Seat 0 wins: Most Cards (+1), Most Coins (+1), Settebello 7D (+1), Primiera (+1), +2 Scopas = 6 pts
      expect(g.scores[0], 6);
      expect(g.isOver, isTrue);
      expect(g.placings, [1, 2]);
    });
  });

  group('Red7 (红七)', () {
    test('all 7 canvas rules evaluate accurately', () {
      final pal = ['R7', 'O5', 'Y5', 'G4', 'B3', 'I2', 'V1'];
      // 6 Red: highest single card -> R7 (power 76)
      expect(evaluateRed7Palette(pal, 6).subset, ['R7']);
      // 5 Orange: most of one number -> O5, Y5 (count 2, top O5=55)
      expect(evaluateRed7Palette(pal, 5).count, 2);
      expect(evaluateRed7Palette(pal, 5).topPower, 55);
      // 4 Yellow: most of one color -> 1 each, best is R7
      expect(evaluateRed7Palette(['R7', 'R2', 'B6'], 4).count, 2);
      // 3 Green: most even cards -> G4, I2 (count 2)
      expect(evaluateRed7Palette(pal, 3).count, 2);
      // 2 Blue: most different colors -> all 7 colors
      expect(evaluateRed7Palette(pal, 2).count, 7);
      // 1 Indigo: longest run -> 1,2,3,4,5 (count 5)
      expect(evaluateRed7Palette(pal, 1).count, 5);
      // 0 Violet: most cards < 4 -> B3, I2, V1 (count 3)
      expect(evaluateRed7Palette(pal, 0).count, 3);
    });

    test('must win at end of turn or fold', () {
      final g = Red7Game(_setup(2, {'rounds': 1}))..start();
      g.turn = 0;
      g.canvasColor = 6; // Red: highest card
      g.palettes = [
        ['B3'],
        ['R6'],
      ];
      g.hands = [
        ['V2', 'O4', 'R7'],
        ['G5'],
      ];
      g.folded = [false, false];

      // Playing V2 to palette leaves B3 as max, losing to R6 -> illegal!
      expect(
        () => g.handle(0, {'type': 'play', 'palette': 'V2'}),
        throwsA(isA<GameError>()),
      );
      // Playing V2 to canvas changes rule to Violet (<4): seat 0 has B3 (count 1), seat 1 has none (count 0) -> legal!
      g.handle(0, {'type': 'play', 'canvas': 'V2'});
      expect(g.canvasColor, 0);
      expect(g.turn, 1);

      // Seat 1 folds -> Seat 0 wins the 1-round game and gets 3 pts (for B3)
      g.handle(1, {'type': 'fold'});
      expect(g.scores[0], 3);
      expect(g.isOver, isTrue);
      expect(g.placings, [1, 2]);
    });
  });

  test('bot simulations for cards8Games (count: 30)', () {
    expect(runSims(cards8Games, n: 30), 0);
  });
}
