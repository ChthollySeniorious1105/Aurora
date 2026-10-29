import 'dart:math';

import 'package:aurora_shared/games/euro12/defs.dart';
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
  group('barenpark', () {
    test('polyomino placement, Pit protection, icon supply gains, and Bear Statue award', () {
      final e = _start(BarenparkGame(_setup(2, {'gridSize': '6x6'})));
      expect(e.rows, 6);
      expect(e.cols, 6);

      // In 6x6 mode, Zone 0 is r in 0..2, c in 0..2, with Pit (icon==4) at (1, 1)
      expect(e.icons[0][1][1], 4);
      final g1 = BarenTile(id: 900, key: 'g1', vp: 0);
      e.inventory[0] = [g1];

      // Cannot cover Bear Statue Pit at (1, 1)
      expect(e.canPlaceTile(0, g1, 1, 1), isFalse);
      expect(
        () => e.handle(0, {'type': 'place', 'invIdx': 0, 'r': 1, 'c': 1}),
        throwsA(isA<GameError>()),
      );

      // Place a 1x2 tile (g2) covering (0, 0) and (0, 1) where (0, 1) has icon 1 (🚧 Wheelbarrow)
      final g2 = BarenTile(id: 901, key: 'g2', vp: 0);
      e.inventory[0] = [g2];
      e.handle(0, {
        'type': 'place',
        'invIdx': 0,
        'r': 0,
        'c': 0,
        'rot': 0,
        'flip': false,
        'gains': ['g3'],
      });
      expect(e.grid[0][0][0], 'g2');
      expect(e.grid[0][0][1], 'g2');
      expect(e.inventory[0].length, 1);
      expect(e.inventory[0].first.key, 'g3');

      // P1 passes and gains a 1x1 green tile
      final p1InvBefore = e.inventory[1].length;
      e.handle(1, {'type': 'pass'});
      expect(e.inventory[1].length, p1InvBefore + 1);

      // Fill all remaining non-pit cells of Zone 0 for P0 except (2, 2), then place 1x1 at (2, 2)
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          if (r == 1 && c == 1) continue; // Pit
          if (r == 2 && c == 2) continue; // Leave for final placement
          e.grid[0][r][c] = 'g1';
        }
      }
      e.inventory[0] = [BarenTile(id: 902, key: 'g1', vp: 0)];
      final topStatue = e.statues.first; // 16 VP
      e.handle(0, {'type': 'place', 'invIdx': 0, 'r': 2, 'c': 2});
      expect(e.zoneStatues[0][0], topStatue);
      expect(e.score[0], greaterThanOrEqualTo(topStatue));
    });
  });

  group('nova_luna', () {
    test('Moon Wheel selection, time-track turn order, and orthogonal color chain task completion', () {
      final e = _start(NovaLunaGame(_setup(2)));
      expect(e.moonPos, 0);
      expect(e.availableWheelSlots(), [1, 2, 3]);

      // Set up specific tiles on wheel slots 1, 2, 3
      // Slot 1: Cyan (0), cost 2, task [[2, 2]] (needs 2 Red in adjacent chain)
      e.wheel[1] = const NovaTile(
        id: 501,
        color: 0,
        cost: 2,
        tasks: [
          [2, 2]
        ],
      );
      // Slot 2: Red (2), cost 1, task []
      e.wheel[2] = const NovaTile(id: 502, color: 2, cost: 1, tasks: []);
      // Slot 3: Red (2), cost 4, task []
      e.wheel[3] = const NovaTile(id: 503, color: 2, cost: 4, tasks: []);

      // P0 picks slot 1 (cost 2) and places at center (3, 3)
      e.handle(0, {'type': 'pick', 'wheelSlot': 1, 'r': 3, 'c': 3});
      expect(e.moonPos, 1);
      expect(e.timePos[0], 2);
      expect(e.turn, 1); // P1 is at timePos 0 < 2, so P1 goes next!

      // P1 picks slot 2 (cost 1) -> P1 moves to timePos 1, which is STILL < P0's timePos 2!
      e.handle(1, {'type': 'pick', 'wheelSlot': 2, 'r': 3, 'c': 3});
      expect(e.timePos[1], 1);
      expect(e.turn, 1); // P1 gets another turn immediately because 1 < 2!

      // Now verify color-chain task completion for P0:
      // P0 has tile 501 at (3, 3) needing [Red(2), Red(2)].
      // Place a Red tile at (3, 4) (adjacent to 3,3) -> only 1 Red so far.
      e.tableau[0][3][4] =
          PlacedNovaTile(const NovaTile(id: 504, color: 2, cost: 1, tasks: []));
      expect(e.recalcTasks(0), 0);
      expect(e.tableau[0][3][3]!.doneTasks[0], isFalse);

      // Place a second Red tile at (3, 5) (orthogonally connected to (3, 4), forming a 2-tile Red chain!)
      e.tableau[0][3][5] =
          PlacedNovaTile(const NovaTile(id: 505, color: 2, cost: 1, tasks: []));
      expect(e.recalcTasks(0), 1);
      expect(e.tableau[0][3][3]!.doneTasks[0], isTrue);
      expect(e.disksLeft[0], e.initialDisks - 1);
    });
  });

  group('tiny_towns', () {
    test('Master Builder resource call, recipe construction, and town scoring', () {
      final e = _start(TinyTownsGame(_setup(2)));
      expect(e.phase, 'call');
      expect(e.builderSeat, 0);

      // P0 calls Wood (0)
      e.handle(0, {'type': 'call_resource', 'res': 0});
      expect(e.phase, 'place');
      expect(e.calledRes, 0);

      // Pre-place Stone (4) at (0, 1) for P0 so placing Wood (0) at (0, 0) forms a Well [Wood(0), Stone(4)]
      e.grid[0][0][1] = 4;
      e.handle(0, {'type': 'place_res', 'r': 0, 'c': 0});
      // Since P0 now has a valid Well build at [(0,0), (0,1)], P0 can construct Well (15) at (0,0)!
      e.handle(0, {
        'type': 'build',
        'building': 15,
        'cells': [
          [0, 0],
          [0, 1]
        ],
        'at': [0, 0],
      });
      expect(e.grid[0][0][0], 15);
      expect(e.grid[0][0][1], -1);

      // Verify Cottage + Farm + Abbey + Well scoring
      e.grid[0] = [
        [15, 10, 11, 12], // Well(15) adj to Cottage(10), plus Farm(11) and Abbey(12)
        [13, 13, 16, 14], // 2 Taverns(13)=5, TradingPost(16)=2, Theater(14)
        [10, 10, 10, 15],
        [16, 16, 16, 16],
      ];
      final sc = e.recalcScore(0);
      // 4 Cottages all fed by 1 Farm = 12 VP; Abbey = 4 * 4 = 16 VP; 2 Taverns = 5 VP; 5 TradingPosts = 10 VP; Wells + Theater > 0; 0 empty penalty!
      expect(sc, greaterThan(40));
    });
  });

  group('canvas', () {
    test('Inspiration token market economy and 3-card transparent layering', () {
      final e = _start(CanvasGame(_setup(2)));
      expect(e.tokens[0], 4);
      expect(e.hand[0].length, 3);

      // P0 takes card at slot 2 -> pays 2 tokens (placed on slots 0 and 1)
      e.handle(0, {'type': 'take', 'slot': 2});
      expect(e.tokens[0], 2);
      expect(e.tokensOn[0], 1);
      expect(e.tokensOn[1], 1);
      expect(e.hand[0].length, 4);

      // P1 takes card at slot 0 -> pays 0 tokens and gains the 1 token sitting on slot 0!
      e.handle(1, {'type': 'take', 'slot': 0});
      expect(e.tokens[1], 5);

      // Test transparent layering order [bottom, middle, top] for P0:
      const bottom = CanvasCard(
        id: 801,
        titlePart: '晨曦',
        zones: [CanvasZone(0, 0), CanvasZone(1, 1), CanvasZone(2, 2)],
      );
      const middle = CanvasCard(
        id: 802,
        titlePart: '迷雾',
        zones: [null, CanvasZone(3, 3), null],
      );
      const top = CanvasCard(
        id: 803,
        titlePart: '星空',
        zones: [null, null, CanvasZone(4, 4)],
      );
      e.hand[0] = [bottom, middle, top];
      e.handle(0, {
        'type': 'paint',
        'cards': [0, 1, 2],
      });
      expect(e.gallery[0].length, 1);
      final mp = e.gallery[0].first;
      expect(mp.title, '《晨曦·迷雾·星空》');
      // Zone 0 comes from bottom (0,0), Zone 1 from middle (3,3), Zone 2 from top (4,4)
      expect(mp.finalZones[0]!.color, 0);
      expect(mp.finalZones[1]!.color, 3);
      expect(mp.finalZones[2]!.color, 4);
      expect(e.score[0], greaterThan(0));
    });
  });

  test('sims', () {
    expect(runSims(euro12Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
