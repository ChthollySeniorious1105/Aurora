import 'dart:math';

import 'package:aurora_shared/games/party7/canstop.dart';
import 'package:aurora_shared/games/party7/defs.dart';
import 'package:aurora_shared/games/party7/qwirkle.dart';
import 'package:aurora_shared/games/party7/saboteur.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(
  int n, {
  Map<String, dynamic> opts = const {},
  bool bots = false,
  int seed = 7,
}) =>
    GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, bots),
      rng: Random(seed),
    );

T _start<T extends GameEngine>(T e) {
  final h = SimHost();
  e.host = h;
  e.start();
  h.runPending();
  return e;
}

void main() {
  group('Can\'t Stop (canstop)', () {
    test('heights and legal pairings with runner limit and claimed columns', () {
      expect(canStopHeights[2], 3);
      expect(canStopHeights[7], 13);
      expect(canStopHeights[12], 3);

      // 2 runners already on {4, 7}; dice [1, 2, 5, 6]
      // Pairings: (3, 11), (6, 8), (7, 7)
      // Since 2 runners are active, (3, 11) and (6, 8) can only place 1 new runner each -> [3], [11], [6], [8]
      // While (7, 7) uses existing runner 7 twice -> [7, 7]
      final choices = canStopLegalChoices([1, 2, 5, 6], {4: 2, 7: 5}, {});
      expect(
        choices,
        containsAll([
          [3],
          [11],
          [6],
          [8],
          [7, 7],
        ]),
      );

      // When 3 runners are active on {2, 3, 4} and column 7 is claimed:
      // Dice [5, 5, 6, 6] -> pairings are (10, 12), (11, 11), (11, 11) -> NO legal choice!
      final bustChoices = canStopLegalChoices([5, 5, 6, 6], {2: 1, 3: 1, 4: 1}, {7: 0});
      expect(bustChoices, isEmpty);
    });

    test('advance, bust, stop, claim column and win at targetCols', () {
      final g = _start(CanStopGame(_setup(2, opts: {'targetCols': 2})));
      g.turn = 0;
      g.camps[0][2] = 2; // 1 step away from summit (height 3)
      g.applyDiceRoll([1, 1, 2, 3]); // pairings include (2, 5)
      expect(g.phase, 'choose_pair');
      g.handle(0, {
        'type': 'choose_pair',
        'cols': [2, 5],
      });
      expect(g.runners[2], 3);
      expect(g.runners[5], 1);
      expect(g.phase, 'decide');

      // Stop and claim column 2
      g.handle(0, {'type': 'stop'});
      expect(g.claimed[2], 0);
      expect(g.camps[0][2], 3);
      expect(g.camps[0][5], 1);
      expect(g.runners, isEmpty);
      expect(g.turn, 1);

      // Player 1 gets 3 runners on {3, 4, 5}, then rolls [6, 6, 6, 5] -> bust!
      g.runners = {3: 2, 4: 2, 5: 2};
      g.phase = 'decide';
      g.applyDiceRoll([6, 6, 6, 5]); // sums are (12, 11) -> not in {3, 4, 5}
      expect(g.lastEvent?['type'], 'bust');
      expect(g.turn, 0);
      expect(g.runners, isEmpty);

      // Player 0 claims second column (12) to win immediately
      g.camps[0][12] = 2;
      g.applyDiceRoll([6, 6, 2, 2]);
      g.handle(0, {
        'type': 'choose_pair',
        'cols': [4, 12],
      });
      g.handle(0, {'type': 'stop'});
      expect(g.claimed[12], 0);
      expect(g.isOver, isTrue);
      expect(g.placings, [1, 2]);
    });
  });

  group('Qwirkle (qwirkle)', () {
    test('line validation and multi-line + Qwirkle scoring', () {
      // Same color (0), distinct shapes (0, 1, 2)
      expect(qwirkleIsValidLine([qwirkleTile(0, 0), qwirkleTile(0, 1), qwirkleTile(0, 2)]), isTrue);
      // Duplicate tile in line is invalid
      expect(qwirkleIsValidLine([qwirkleTile(0, 0), qwirkleTile(0, 0)]), isFalse);
      // Mixed color and shape is invalid
      expect(qwirkleIsValidLine([qwirkleTile(0, 0), qwirkleTile(1, 2)]), isFalse);

      // Build a 5-tile horizontal line of color 0 (shapes 0..4) at row 0, cols 0..4
      final board = <(int, int), int>{
        for (var s = 0; s < 5; s++) (0, s): qwirkleTile(0, s),
      };
      // Completing the 6th tile at (0, 5) with shape 5 scores 6 + 6 = 12 (Qwirkle!)
      final ev = qwirkleValidateAndScore(board, [
        (r: 0, c: 5, tile: qwirkleTile(0, 5)),
      ]);
      expect(ev.valid, isTrue);
      expect(ev.qwirkles, 1);
      expect(ev.score, 12);
    });

    test('place, swap, and endgame +6 bonus', () {
      final g = _start(QwirkleGame(_setup(2, opts: {'copies': 2})));
      g.turn = 0;
      g.hands[0] = [qwirkleTile(0, 0), qwirkleTile(0, 1), qwirkleTile(1, 0)];
      g.handle(0, {
        'type': 'place',
        'placements': [
          {'r': 0, 'c': 0, 'tile': qwirkleTile(0, 0)},
          {'r': 0, 'c': 1, 'tile': qwirkleTile(0, 1)},
        ],
      });
      expect(g.scores[0], 2);
      expect(g.turn, 1);

      // Player 1 swaps 2 tiles
      final beforeBag = g.bag.length;
      g.handle(1, {
        'type': 'swap',
        'indices': [0, 1],
      });
      expect(g.bag.length, beforeBag);
      expect(g.turn, 0);

      // Empty bag and let player 0 play their last tile to trigger +6 endgame bonus
      g.bag.clear();
      g.hands[0] = [qwirkleTile(0, 2)];
      g.handle(0, {
        'type': 'place',
        'placements': [
          {'r': 0, 'c': 2, 'tile': qwirkleTile(0, 2)},
        ],
      });
      // Line of 3 (3 pts) + 6 bonus for emptying hand = +9 -> total 11
      expect(g.scores[0], 11);
      expect(g.isOver, isTrue);
      expect(g.placings, [1, 2]);
    });
  });

  group('Saboteur (saboteur)', () {
    test('role counts, hidden roles, tool break/repair, map, rockfall, and gold win', () {
      final g = _start(SaboteurGame(_setup(4, opts: {'rounds': 1})));
      expect(g.roles.where((r) => r == 'saboteur').length, 1);
      expect(g.roles.where((r) => r == 'digger').length, 3);
      expect(g.view(0)['roles'], isNull);
      expect(g.view(0)['myRole'], g.roles[0]);

      g.turn = 0;
      g.roles = ['digger', 'saboteur', 'digger', 'digger'];
      g.goalTypes = ['stone', 'gold', 'stone']; // (2, 8) is gold!

      // Player 0 plays map on goalIndex 1
      g.hands[0] = [
        {'id': 101, 'kind': 'action', 'action': 'map'},
      ];
      g.handle(0, {'type': 'action', 'index': 0, 'goalIndex': 1});
      expect((g.view(0)['goals'] as List)[1]['knownType'], 'gold');
      expect((g.view(1)['goals'] as List)[1]['knownType'], isNull);

      // Player 1 breaks Player 0's pickaxe
      g.turn = 1;
      g.hands[1] = [
        {'id': 102, 'kind': 'action', 'action': 'break', 'tool': 'pickaxe'},
      ];
      g.handle(1, {'type': 'action', 'index': 0, 'target': 0});
      expect(g.brokenTools[0], contains('pickaxe'));

      // Player 0 cannot place a path card while pickaxe is broken
      g.turn = 0;
      g.hands[0] = [
        {
          'id': 103,
          'kind': 'path',
          'edges': ['N', 'E', 'S', 'W'],
          'deadEnd': false,
        },
        {
          'id': 104,
          'kind': 'action',
          'action': 'repair',
          'tools': ['pickaxe', 'lantern'],
        },
      ];
      expect(
        () => g.handle(0, {'type': 'place_path', 'index': 0, 'r': 2, 'c': 1}),
        throwsA(isA<GameError>()),
      );

      // Player 0 repairs own pickaxe
      g.handle(0, {'type': 'action', 'index': 1, 'target': 0, 'tool': 'pickaxe'});
      expect(g.brokenTools[0], isEmpty);

      // Build continuous path from (2, 0) to (2, 6), then place (2, 7) to reach Gold at (2, 8)
      for (var c = 1; c <= 6; c++) {
        g.grid[(2, c)] = {
          'id': 200 + c,
          'kind': 'path',
          'edges': ['E', 'W'],
          'deadEnd': false,
        };
      }
      g.turn = 0;
      g.hands[0] = [
        {
          'id': 300,
          'kind': 'path',
          'edges': ['E', 'W'],
          'deadEnd': false,
        },
      ];
      g.handle(0, {'type': 'place_path', 'index': 0, 'r': 2, 'c': 7});
      expect(g.revealedGoals[1], isTrue);
      expect(g.isOver, isTrue);
      expect(g.roundSummary?['winnerTeam'], 'digger');
      expect(g.gold[0], greaterThan(0));
      expect(g.gold[1], 0);
    });
  });

  test('party7 sims (30 games per player count & option)', () {
    expect(runSims(party7Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
