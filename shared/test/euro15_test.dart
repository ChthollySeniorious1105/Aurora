import 'dart:math';

import 'package:aurora_shared/games/euro15/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n,
        [Map<String, dynamic> opts = const {}, int seed = 7]) =>
    GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, false),
      rng: Random(seed),
    );

T _start<T extends GameEngine>(T e) {
  e.host = SimHost();
  e.start();
  return e;
}

void main() {
  group('harmonies', () {
    test('3D token stacking rules, 6 terrain scoring rules, and Animal Card habitat cube placement', () {
      final e = _start(HarmoniesGame(_setup(2)));

      // Put a pouch with [0 (Trunk), 0 (Trunk), 1 (Canopy)] at pouch 0
      e.pouches[0] = [0, 0, 1];
      // Put a custom Animal Card at market 0: 🦉 Owl requires 3-tall Tree (top=1, h=3) adjacent to Field (top=4, h>=1)
      e.animalMarket[0] = const HarmoniesAnimalCard(
        id: 801,
        name: '猫头鹰',
        emoji: '🦉',
        anchorToken: 1,
        anchorHeight: 3,
        adjToken: 4,
        adjMinHeight: 1,
      );
      // Pre-place a Yellow Field (4) at (2, 3) and (2, 4) -> contiguous group of 2 Fields = 5 VP!
      e.stacks[0][2][3] = [4];
      e.stacks[0][2][4] = [4];
      expect(e.calcFieldScore(0), 5);

      // Stacking a Yellow Field (4) on a non-empty cell must be illegal!
      expect(HarmoniesGame.canStackToken([0], 4), isFalse);
      // Stacking a Red Building (3) on 2 Trunks [0, 0] must be illegal (max height 2 for Building)!
      expect(HarmoniesGame.canStackToken([0, 0], 3), isFalse);
      expect(HarmoniesGame.canStackToken([2], 3), isTrue); // 2-tall Building on Mountain is legal

      // P0 drafts pouch 0 and stacks all 3 tokens onto (2, 2) sequentially -> [0, 0, 1] (3-tall Tree = 7 VP!)
      // AND claims animalMarket[0] -> automatically places 1 animal cube on (2, 2) (+4 VP)!
      e.handle(0, {
        'type': 'draft',
        'pouch': 0,
        'claimAnimal': 0,
        'cells': [
          [2, 2],
          [2, 2],
          [2, 2],
        ],
      });

      expect(e.stacks[0][2][2], [0, 0, 1]);
      expect(e.calcTreeScore(0), 7);
      expect(e.animalAt[0][2][2], 801);
      expect(e.calcAnimalScore(0), 4);

      // Verify Mountain adjacency rule: lonely 3-tall mountain scores 0, adjacent mountains score 7 + 1 = 8!
      e.stacks[0][0][0] = [2, 2, 2];
      expect(e.calcMountainScore(0), 0);
      e.stacks[0][0][1] = [2];
      expect(e.calcMountainScore(0), 8);

      // Verify River longest chain: 4 connected water cells -> 2 + (4 - 2)*3 = 8 VP
      e.stacks[0][4][0] = [5];
      e.stacks[0][4][1] = [5];
      e.stacks[0][4][2] = [5];
      e.stacks[0][4][3] = [5];
      expect(e.calcRiverScore(0), 8);
    });
  });

  group('next_station_london', () {
    test('straight-line segments, intermediate station block, segment crossing block, Switch-Track, and Thames/Interchange/Tourist scoring', () {
      final e = _start(NextStationLondonGame(_setup(2)));
      // Active line in round 1 is Line 0 (Purple 🟪), starting at station 4: (1, 2), district 1
      expect(e.activeLine, 0);
      expect(NextStationLondonGame.startStationForLine(0), 4);

      // Force currentCard to Wild without switchTrack
      e.currentCard = const LondonStationCard(id: 99, symbol: 4, switchTrack: false);

      // Connecting 4 (1,2) -> 6 (1,6) passes directly through station 5 (1,4) -> MUST fail!
      expect(
        () => e.handle(0, {'type': 'connect', 'from': 4, 'to': 6}),
        throwsA(isA<GameError>()),
      );

      // Connect 4 (1,2) -> 10 (3,2) [vertical]
      e.handle(0, {'type': 'connect', 'from': 4, 'to': 10});
      e.handle(1, {'type': 'pass'});

      // Next card: Wild without switchTrack -> connecting from 4 (still an endpoint) or 10 (the other endpoint) works;
      // connect 10 (3,2) -> 13 (4,3) [diagonal across Thames River (r=3 to r=4) + Tourist Site ⭐ at 13!]
      e.currentCard = const LondonStationCard(id: 100, symbol: 4, switchTrack: false);
      e.handle(0, {'type': 'connect', 'from': 10, 'to': 13});
      e.handle(1, {'type': 'pass'});

      // Now station 10 is in the MIDDLE of Line 0 (endpoints are 4 and 13).
      // Without switchTrack, branching from 10 must fail!
      e.currentCard = const LondonStationCard(id: 101, symbol: 4, switchTrack: false);
      expect(
        () => e.handle(0, {'type': 'connect', 'from': 10, 'to': 12}),
        throwsA(isA<GameError>()),
      );

      // With switchTrack = true (🔀), branching from middle station 10 -> 12 succeeds!
      e.currentCard = const LondonStationCard(id: 102, symbol: 4, switchTrack: true);
      e.handle(0, {'type': 'connect', 'from': 10, 'to': 12});

      // Verify Line 0 score: stations {4 (dist 1), 10 (dist 4), 13 (dist 4), 12 (dist 3)}
      // Distinct districts = 3 ({1, 4, 3}), Max in 1 district = 2 (dist 4 has 10 & 13),
      // Thames crossings = 2 (10->13 and 10->12 both cross row 3.5!)
      // Line 0 score = 3 * 2 + 2 * 2 = 10 VP! Plus Tourist Site 13 (+2 VP) = 12 VP!
      expect(e.calcLineScore(0, 0), 10);
      expect(e.calcTouristScore(0), 2);

      // Also verify segment crossing prohibition: segment (10:(3,2) -> 16:(5,4)) crosses (11:(3,4) -> 15:(5,2))
      expect(NextStationLondonGame.segmentsCross(10, 16, 11, 15), isTrue);
    });
  });

  group('living_forest', () {
    test('Solitary 3-limit push-your-luck, Magic Fragment banish, 4 forest actions, and 12-relic victory', () {
      final e = _start(LivingForestGame(_setup(2)));
      expect(e.phase, 'draw');

      // Rig P0's drawPile with 3 Solitary cards on top
      const solCard = GuardianAnimalCard(
        id: 901,
        tier: 1,
        name: '孤狼',
        emoji: '🐺',
        cost: 3,
        elements: [3, 3, 3, 2, 1],
        isSolitary: true,
      );
      e.drawPile[0] = [solCard, solCard, solCard, solCard];

      // Draw 2 Solitary cards -> still in 'draw' phase with 2 Solitary
      e.handle(0, {'type': 'draw'});
      e.handle(0, {'type': 'draw'});
      expect(e.solitaryCount(0), 2);
      expect(e.phase, 'draw');

      // Spend 1 Magic Fragment ('fragment') to banish a Solitary card -> drops back to 1 Solitary!
      e.handle(0, {'type': 'fragment'});
      expect(e.fragments[0], 0);
      expect(e.solitaryCount(0), 1);

      // Stop drawing voluntarily with < 3 Solitary -> gets 2 distinct Actions!
      e.handle(0, {'type': 'stop_draw'});
      expect(e.phase, 'action');
      expect(e.actionsLeft, 2);

      // Action 1: extinguish fire (adds to fires[0])
      final prevFires = e.fires[0];
      e.handle(0, {'type': 'extinguish', 'slot': 0, 'all': true});
      expect(e.fires[0], greaterThan(prevFires));
      expect(e.actionsLeft, 1);

      // Taking the SAME action ('extinguish') again in the same turn must fail!
      expect(
        () => e.handle(0, {'type': 'extinguish', 'slot': 0}),
        throwsA(isA<GameError>()),
      );

      // Action 2: plant a tree at (1, 1) (adjacent to starting tree at (1, 2))
      e.treeMarket[0] = const ForestTreeTile(
        id: 950,
        name: '测试神木',
        emoji: '🌳',
        cost: 2,
        bonusElem: 4,
        bonusAmount: 2,
      );
      e.handle(0, {'type': 'plant', 'slot': 0, 'r': 1, 'c': 1});
      expect(e.trees[0], 2);

      // Now it is P1's turn; set P0's fires to 12 and let P1 finish the round -> game ends!
      e.fires[0] = 12;
      e.handle(1, {'type': 'stop_draw'});
      e.handle(1, {'type': 'pass'});
      expect(e.isOver, isTrue);
      expect(e.placings![0], 1);
    });
  });

  group('project_l', () {
    test('piece upgrade, single placement, Master Action across multiple puzzles, and puzzle completion piece return + reward', () {
      final e = _start(ProjectLGame(_setup(2)));
      // P0 starts with 1 L1_dot (shape 0) and 1 L2_bar (shape 1)
      expect(e.reserve[0][0], 1);
      expect(e.reserve[0][1], 1);

      // Action 1: upgrade L2_bar (shape 1, level 2) -> L3_I (shape 2, level 3)
      // Upgrading directly from level 1 (shape 0) to level 3 (shape 2) must fail!
      expect(
        () => e.handle(0, {'type': 'upgrade', 'from': 0, 'to': 2}),
        throwsA(isA<GameError>()),
      );
      e.handle(0, {'type': 'upgrade', 'from': 1, 'to': 2});
      expect(e.reserve[0][1], 0);
      expect(e.reserve[0][2], 1);
      expect(e.actionsLeft, 2);

      // Give P0 two custom active puzzles:
      // Puzzle A: 3-cell horizontal recessed [(1,0),(1,1),(1,2)], VP = 2, rewardShape = 4 (L4_O)
      // Puzzle B: 1-cell recessed [(0,0)], VP = 1, rewardShape = 1 (L2_bar)
      final maskA = List.generate(4, (_) => List.filled(4, false));
      maskA[1][0] = true;
      maskA[1][1] = true;
      maskA[1][2] = true;
      final maskB = List.generate(4, (_) => List.filled(4, false));
      maskB[0][0] = true;

      e.activePuzzles[0] = [
        ProjectLPuzzle(id: 501, tier: 0, vp: 2, rewardShape: 4, recessed: maskA),
        ProjectLPuzzle(id: 502, tier: 0, vp: 1, rewardShape: 1, recessed: maskB),
      ];

      // Action 2: Master Action ('master') places L3_I onto Puzzle A AND L1_dot onto Puzzle B in 1 action!
      // Both puzzles complete immediately -> both pieces return to reserve[0], +3 VP scored, and rewards (shape 4 & shape 1) gained!
      e.handle(0, {
        'type': 'master',
        'placements': [
          {
            'slot': 0,
            'shape': 2,
            'cells': [
              [1, 0],
              [1, 1],
              [1, 2],
            ],
          },
          {
            'slot': 1,
            'shape': 0,
            'cells': [
              [0, 0],
            ],
          },
        ],
      });

      expect(e.activePuzzles[0], isEmpty);
      expect(e.score[0], 3); // 2 + 1 VP
      expect(e.completedCount[0], 2);
      // Returned pieces: shape 2 (1) and shape 0 (1); Rewards: shape 4 (1) and shape 1 (1)
      expect(e.reserve[0][0], 1);
      expect(e.reserve[0][1], 1);
      expect(e.reserve[0][2], 1);
      expect(e.reserve[0][4], 1);
    });
  });

  test('sims', () {
    expect(runSims(euro15Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
