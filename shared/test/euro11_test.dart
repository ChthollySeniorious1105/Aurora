import 'dart:math';

import 'package:aurora_shared/games/euro11/calico.dart';
import 'package:aurora_shared/games/euro11/defs.dart';
import 'package:aurora_shared/games/euro11/photosynthesis.dart';
import 'package:aurora_shared/games/euro11/stoneage.dart';
import 'package:aurora_shared/games/euro11/takenoko.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n, [Map<String, dynamic> opts = const {}, int seed = 7]) => GameSetup(
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
  group('calico', () {
    test('5x5 quilt setup with 3 goal cells and 10 empty interior spaces', () {
      final e = _start(Calico(_setup(2)));
      expect(e.emptySpacesOf(0), 10);
      expect(e.quilt[0][1][2]?['goal'], 'AAA-BBB');
      expect(e.quilt[0][2][1]?['goal'], 'AA-BB-CC');
      expect(e.quilt[0][2][3]?['goal'], 'A-B-C-D-E-F');
      expect(e.hands[0].length, 2);
      expect(e.market.length, 3);
    });

    test('placing a patch and drafting from market', () {
      final e = _start(Calico(_setup(2)));
      final s = e.turn;
      final placedTile = Map<String, int>.of(e.hands[s][0]);
      final draftedTile = Map<String, int>.of(e.market[1]);
      e.handle(s, {'type': 'place', 'handIdx': 0, 'r': 2, 'c': 2, 'marketIdx': 1});
      expect(e.quilt[s][2][2]?['color'], placedTile['color']);
      expect(e.quilt[s][2][2]?['pattern'], placedTile['pattern']);
      expect(e.hands[s][0], draftedTile);
      expect(e.emptySpacesOf(s), 9);
      expect(e.turn, 1 - s);
    });

    test('three-layer scoring: goal 7/11 VP, color buttons + rainbow, and cats', () {
      final e = _start(Calico(_setup(1)));
      // Fill the 6 neighbors of Goal (1,2) 'AAA-BBB' so BOTH color (3 of 0, 3 of 1) and pattern (3 of 0, 3 of 1) match -> 11 Gold VP
      final nbs = Calico.goalNeighbors(1, 2);
      expect(nbs.length, 6);
      for (var i = 0; i < 6; i++) {
        final (r, c) = nbs[i];
        final val = i < 3 ? 0 : 1;
        e.quilt[0][r][c] = {'color': val, 'pattern': val};
      }
      final goals = e.evaluateGoals(0);
      final g0 = goals.firstWhere((g) => g['r'] == 1 && g['c'] == 2);
      expect(g0['colorOk'], isTrue);
      expect(g0['patternOk'], isTrue);
      expect(g0['vp'], 11);

      // Make pattern only match on (1,2) -> 7 Blue VP
      e.quilt[0][nbs[0].$1][nbs[0].$2] = {'color': 5, 'pattern': 0};
      final g0Blue = e.evaluateGoals(0).firstWhere((g) => g['r'] == 1 && g['c'] == 2);
      expect(g0Blue['colorOk'], isFalse);
      expect(g0Blue['patternOk'], isTrue);
      expect(g0Blue['vp'], 7);
    });
  });

  group('takenoko', () {
    test('place plot adjacent to pond auto-irrigates and grows 1 bamboo', () {
      final e = _start(Takenoko(_setup(2)));
      final s = e.turn;
      e.handle(s, {'type': 'place_plot', 'q': 1, 'r': 0, 'color': 0});
      final p = e.plots[(1, 0)]!;
      expect(p.color, 0);
      expect(p.irrigated, isTrue);
      expect(p.bambooHeight, 1);
    });

    test('gardener grows bamboo on destination and adjacent same-color plots, panda eats', () {
      final e = _start(Takenoko(_setup(2)));
      final s = e.turn;
      e.handle(s, {'type': 'place_plot', 'q': 1, 'r': 0, 'color': 0});
      e.handle(s, {'type': 'place_plot', 'q': 0, 'r': 1, 'color': 0});
      // Reset heights to 1 before testing move_gardener & move_panda
      final s2 = e.turn;
      e.plots[(1, 0)]!.bambooHeight = 1;
      e.plots[(0, 1)]!.bambooHeight = 1;
      e.eaten[s2] = [0, 0, 0];
      e.gardenerPos = (0, 0);
      e.pandaPos = (0, 0);
      e.actionsLeft = 2;
      e.handle(s2, {'type': 'move_gardener', 'to': [1, 0]});
      expect(e.plots[(1, 0)]!.bambooHeight, 2);
      expect(e.plots[(0, 1)]!.bambooHeight, 2);

      // Move panda to (1,0) and eat 1 green bamboo
      e.handle(s2, {'type': 'move_panda', 'to': [1, 0]});
      expect(e.plots[(1, 0)]!.bambooHeight, 1);
      expect(e.eaten[s2][0], 1);
    });

    test('claiming targetGoals awards +2 VP Emperor Bonus and triggers final round', () {
      final e = _start(Takenoko(_setup(2, {'targetGoals': 4})));
      final s = e.turn;
      e.completedGoals[s].addAll([
        const TakenokoGoal(id: 'T1', kind: 'plot', title: 't1', vp: 2, color: 0, count: 1),
        const TakenokoGoal(id: 'T2', kind: 'plot', title: 't2', vp: 2, color: 0, count: 1),
        const TakenokoGoal(id: 'T3', kind: 'plot', title: 't3', vp: 2, color: 0, count: 1),
      ]);
      e.eaten[s][0] = 2;
      e.goals[s] = [
        const TakenokoGoal(id: 'T4', kind: 'panda', title: '吃2绿竹', vp: 3, color: 0, count: 2),
      ];
      e.handle(s, {'type': 'claim_goal', 'index': 0});
      expect(e.emperorSeat, s);
      expect(e.finalRound, isTrue);
      expect(e.score[s], 3 + 2); // 3 VP goal + 2 VP Emperor bonus
    });
  });

  group('photosynthesis', () {
    test('19 hexes with soil richness 1..3 and shadow raycasting', () {
      final e = _start(Photosynthesis(_setup(2)));
      expect(Photosynthesis.allHexes.length, 19);
      expect(Photosynthesis.soilRichness(0, 0), 3);
      expect(Photosynthesis.soilRichness(1, 0), 2);
      expect(Photosynthesis.soilRichness(2, 0), 1);

      e.board.clear();
      e.sunDir = 0; // ray direction (1, 0)
      e.board[(-1, 0)] = PsTree(owner: 0, size: 2); // Medium tree casts 2-hex shadow onto (0,0) and (1,0)
      e.board[(0, 0)] = PsTree(owner: 1, size: 2); // shadowed (otherSize 2 >= max(2, 1))
      e.board[(1, 0)] = PsTree(owner: 1, size: 3); // NOT shadowed (otherSize 2 < max(3, 2))
      expect(e.isShadowed((0, 0)), isTrue);
      expect(e.isShadowed((1, 0)), isFalse);
    });

    test('plant, grow, and harvest large tree for soil VP', () {
      final e = _start(Photosynthesis(_setup(2)));
      final s = e.turn;
      e.board.clear();
      e.board[(1, 0)] = PsTree(owner: s, size: 2);
      e.light[s] = 10;
      e.activatedThisRound.clear();

      // Plant seed at center (0,0) from (1,0)
      e.handle(s, {'type': 'plant', 'q': 0, 'r': 0});
      expect(e.board[(0, 0)]!.size, 0);
      expect(e.light[s], 9);

      // Grow (1,0) from Medium (2) -> Large (3) costing 3 light
      e.handle(s, {'type': 'grow', 'q': 1, 'r': 0});
      expect(e.board[(1, 0)]!.size, 3);
      expect(e.light[s], 6);

      // Next round: harvest (1,0) for Soil 2 top token (17 VP)
      e.activatedThisRound.clear();
      e.handle(s, {'type': 'harvest', 'q': 1, 'r': 0});
      expect(e.board.containsKey((1, 0)), isFalse);
      expect(e.score[s], 17);
    });
  });

  group('stoneage', () {
    test('worker placement, resource resolution, and civilization scoring', () {
      final e = _start(StoneAge(_setup(2)));
      final s0 = e.turn;
      final s1 = 1 - s0;
      e.handle(s0, {'type': 'place', 'loc': 'field', 'count': 1});
      e.handle(s1, {'type': 'place', 'loc': 'tool', 'count': 1});
      e.handle(s0, {'type': 'place', 'loc': 'hut', 'count': 2});
      e.handle(s1, {'type': 'place', 'loc': 'hunt', 'count': 4});
      e.handle(s0, {'type': 'place', 'loc': 'hunt', 'count': 2});

      expect(e.phase, 'resolve');
      e.handle(e.turn, {'type': 'resolve'});
      e.handle(e.turn, {'type': 'resolve'});

      expect(e.agri[s0], 1);
      expect(e.workers[s0], 6);
      expect(e.tools[s1], 1);

      // Test science symbols count^2 + multiplier scoring
      e.greenSymbols[0].addAll([0, 1, 2, 3]); // 4^2 = 16 VP
      e.multipliers[0]['workers'] = 2; // 2 * 6 workers = 12 VP
      final bd = e.scoreBreakdown(0);
      expect(bd['scienceVp'], 16);
      expect(bd['multiplierVp'], 12);
    });
  });

  test('sims', () {
    expect(runSims(euro11Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
