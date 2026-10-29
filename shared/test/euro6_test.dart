import 'dart:math';

import 'package:aurora_shared/games/euro6/cacao.dart';
import 'package:aurora_shared/games/euro6/defs.dart';
import 'package:aurora_shared/games/euro6/imhotep.dart';
import 'package:aurora_shared/games/euro6/pointsalad.dart';
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
  group('pointsalad', () {
    test('deck scaling and initial setup', () {
      for (var p = 2; p <= 6; p++) {
        final e = _start(PointSalad(_setup(p)));
        final totalPiles = e.piles.fold<int>(0, (s, l) => s + l.length);
        final totalMarket = e.market.where((c) => c != null).length;
        expect(totalMarket, 6);
        expect(totalPiles + totalMarket, 36 * p);
      }

      final quick = _start(PointSalad(_setup(3, {'deckSize': 'quick'})));
      final qTotal = quick.piles.fold<int>(0, (s, l) => s + l.length) + 6;
      expect(qTotal, 18 * 3);
    });

    test('scoring formulas evaluate accurately', () {
      final allV = [
        [3, 2, 1, 1, 1, 2], // seat 0: has at least 1 of all 6 veggies
        [1, 4, 0, 2, 1, 0], // seat 1
      ];

      expect(
        PointSalad.evalCard(
          const PsCard(id: 1, veggie: 0, rule: 'per_one', v1: 0, label: ''),
          0,
          allV,
        ),
        6,
      );
      expect(
        PointSalad.evalCard(
          const PsCard(id: 2, veggie: 0, rule: 'per_two', v1: 0, v2: 1, label: ''),
          0,
          allV,
        ),
        5,
      );
      expect(
        PointSalad.evalCard(
          const PsCard(id: 3, veggie: 0, rule: 'pair', v1: 0, v2: 1, label: ''),
          0,
          allV,
        ),
        10,
      );
      expect(
        PointSalad.evalCard(
          const PsCard(id: 4, veggie: 0, rule: 'trio', v1: 0, v2: 1, v3: 5, label: ''),
          0,
          allV,
        ),
        16,
      );
      expect(
        PointSalad.evalCard(
          const PsCard(id: 5, veggie: 0, rule: 'pos_neg', v1: 0, v2: 1, label: ''),
          0,
          allV,
        ),
        7,
      );
      expect(
        PointSalad.evalCard(
          const PsCard(id: 6, veggie: 0, rule: 'most', v1: 0, label: ''),
          0,
          allV,
        ),
        10,
      );
      expect(
        PointSalad.evalCard(
          const PsCard(id: 7, veggie: 0, rule: 'least', v1: 0, label: ''),
          1,
          allV,
        ),
        7,
      );
      expect(
        PointSalad.evalCard(
          const PsCard(id: 8, veggie: 0, rule: 'even_odd', v1: 1, label: ''),
          0,
          allV,
        ),
        7,
      );
      expect(
        PointSalad.evalCard(
          const PsCard(id: 9, veggie: 0, rule: 'even_odd', v1: 0, label: ''),
          0,
          allV,
        ),
        4,
      );
      expect(
        PointSalad.evalCard(
          const PsCard(id: 10, veggie: 0, rule: 'variety', v1: -1, label: ''),
          0,
          allV,
        ),
        12,
      );
      expect(
        PointSalad.evalCard(
          const PsCard(id: 11, veggie: 0, rule: 'variety', v1: 0, label: ''),
          0,
          allV,
        ),
        5,
      );
    });

    test('flip point card, take veggies, market refill and pile splitting', () {
      final e = _start(PointSalad(_setup(2)));
      // Seat 0 takes a point card
      final topCard = e.piles[0].last;
      e.handle(0, {'type': 'take_point', 'pile': 0});
      expect(e.pointCards[0].length, 1);
      expect(e.turn, 1);

      // Seat 1 takes 2 veggies from market slots 0 and 1 (column 0)
      final v0 = e.market[0]!.veggie;
      final v1 = e.market[1]!.veggie;
      final expectedVeg = List<int>.filled(6, 0);
      expectedVeg[v0]++;
      expectedVeg[v1]++;
      e.handle(1, {'type': 'take_veggies', 'slots': [0, 1]});
      expect(e.veggies[1], expectedVeg);
      expect(e.market[0], isNotNull);
      expect(e.market[1], isNotNull);
      expect(e.turn, 0);

      // Seat 0 flips their point card to its veggie side (at most once per turn)
      e.handle(0, {'type': 'flip', 'index': 0});
      expect(e.pointCards[0], isEmpty);
      expect(e.veggies[0][topCard.veggie], 1);
      expect(() => e.handle(0, {'type': 'flip', 'index': 0}), throwsA(isA<GameError>()));

      // Test pile splitting when pile 0 is emptied
      e.piles[0].clear();
      e.piles[1] = List.generate(
        6,
        (i) => PsCard(id: 100 + i, veggie: i % 6, rule: 'per_one', v1: 0, label: 'test'),
      );
      e.piles[2].clear();
      e.handle(0, {'type': 'take_veggies', 'slots': [0, 1]});
      // Market slots 0 and 1 should be refilled and remaining piles balanced
      expect(e.market[0], isNotNull);
      expect(e.market[1], isNotNull);
    });
  });

  group('cacao', () {
    test('board starts with plant1 at (0,1) and market2 at (1,0)', () {
      final e = _start(Cacao(_setup(2)));
      expect(e.jungleBoard[(0, 1)], 'plant1');
      expect(e.jungleBoard[(1, 0)], 'market2');
      expect(e.jungleMarket.length, 2);
      expect(e.hands[0].length, 3);
    });

    test('placing worker at (0,0) harvests cacao before selling at market', () {
      final e = _start(Cacao(_setup(2)));
      // Give seat 0 a [0, 2, 2, 0] tile (East=2 facing (0,1) plant1, South=2 facing (1,0) market2)
      e.hands[0][0] = [0, 2, 2, 0];
      e.handle(0, {'type': 'place_worker', 'handIdx': 0, 'r': 0, 'c': 0, 'rot': 0});
      // Harvests 2 cacao from (0,1), then sells 2 cacao at (1,0) for 4 gold!
      expect(e.cacao[0], 0);
      expect(e.gold[0], 4);
      expect(e.turn, 1);
    });

    test('second worker adjacent to empty jungle cell triggers jungle placement and activates all touching workers', () {
      final e = _start(Cacao(_setup(2)));
      e.hands[0][0] = [1, 1, 1, 1];
      e.hands[1][0] = [1, 1, 1, 1];
      e.jungleMarket
        ..clear()
        ..addAll(['mine2', 'water']);

      // Seat 0 places at (0, 0) (touches (0,1) and (1,0), also adjacent to (-1,0) and (0,-1))
      e.handle(0, {'type': 'place_worker', 'handIdx': 0, 'r': 0, 'c': 0, 'rot': 0});
      // Seat 1 places at (-1, 1) (touches (0,1) plant1, and shares empty jungle cell (-1, 0) with (0, 0)!)
      e.handle(1, {'type': 'place_worker', 'handIdx': 0, 'r': -1, 'c': 1, 'rot': 0});
      expect(e.phase, 'place_jungle');
      expect(e.pendingJungleCells, contains((-1, 0)));

      final g0Before = e.gold[0];
      final g1Before = e.gold[1];
      // Seat 1 places 'mine2' (marketIdx 0) at (-1, 0): both seat 0 at (0,0) and seat 1 at (-1,1) have 1 worker facing (-1,0)
      e.handle(1, {'type': 'place_jungle', 'marketIdx': 0, 'r': -1, 'c': 0});
      expect(e.phase, 'place_worker');
      expect(e.jungleBoard[(-1, 0)], 'mine2');
      expect(e.gold[0], g0Before + 2);
      expect(e.gold[1], g1Before + 2);
    });

    test('temple end-game scoring awards +6 for 1st and +3 for 2nd', () {
      final e = _start(Cacao(_setup(2)));
      e.jungleBoard[(2, 1)] = 'temple';
      e.workerBoard[(1, 1)] = const PlacedWorker(seat: 0, edges: [1, 1, 3, 1]); // South=3 facing (2,1)
      e.workerBoard[(3, 1)] = const PlacedWorker(seat: 1, edges: [2, 1, 1, 1]); // North=2 facing (2,1)
      final out = [0, 0];
      e.computeTemplesInto(out);
      expect(out, [6, 3]);
    });
  });

  group('imhotep', () {
    test('initial sled stones and quarry/load/sail actions', () {
      final e = _start(Imhotep(_setup(4)));
      expect(e.sled, [2, 3, 4, 5]);
      // Seat 0 loads onto ship 0 (size 2, minRequired 1)
      e.handle(0, {'type': 'load', 'ship': 0, 'slot': 0});
      expect(e.sled[0], 1);
      expect(e.ships[0].canSail, isTrue);

      // Seat 1 sails ship 0 to Pyramid (dest 1)
      e.handle(1, {'type': 'sail', 'ship': 0, 'dest': 1});
      expect(e.ships[0].sailed, isTrue);
      expect(e.vp[0], imhotepPyramidValues[0]); // 2 VP for first pyramid slot
      expect(e.destShip[1], 0);

      // Seat 2 quarries (+1 stone since sled starts at 4, capped at 5)
      e.handle(2, {'type': 'quarry'});
      expect(e.sled[2], 5);

      // Seat 3 cannot quarry when sled is already at 5
      expect(() => e.handle(3, {'type': 'quarry'}), throwsA(isA<GameError>()));
    });

    test('burial chamber connected group scoring and obelisk ranking', () {
      // 3-row grid:
      // col 0: [0, 0, 1]
      // col 1: [0, 1, 1]
      // Seat 0 has connected component of size 3: (0,0), (1,0), (0,1) -> 6 pts
      // Seat 1 has connected component of size 3: (2,0), (1,1), (2,1) -> 6 pts
      final stones = [0, 0, 1, 0, 1, 1];
      expect(Imhotep.scoreBurialForSeat(stones, 0), 6);
      expect(Imhotep.scoreBurialForSeat(stones, 1), 6);

      // Group of 5 -> 15 pts, group of 6 -> 17 pts
      expect(Imhotep.burialGroupPoints(4), 10);
      expect(Imhotep.burialGroupPoints(5), 15);
      expect(Imhotep.burialGroupPoints(6), 17);

      expect(Imhotep.scoreObelisks([4, 2, 1, 0]), [12, 6, 3, 0]);
    });

    test('sailing all 4 ships scores temple and advances round', () {
      final e = _start(Imhotep(_setup(2)));
      for (var i = 0; i < 4; i++) {
        e.ships[i].slots.fillRange(0, e.ships[i].minRequired, i % 2);
      }
      e.handle(0, {'type': 'sail', 'ship': 0, 'dest': 2}); // Temple: 1 stone of seat 0
      e.handle(1, {'type': 'sail', 'ship': 1, 'dest': 1}); // Pyramid
      e.handle(0, {'type': 'sail', 'ship': 2, 'dest': 3}); // Burial
      final vp0Before = e.vp[0];
      e.handle(1, {'type': 'sail', 'ship': 3, 'dest': 4}); // Obelisk -> 4th ship sails, round ends!
      expect(e.round, 2);
      expect(e.vp[0], vp0Before + 1); // +1 VP from visible stone in Temple
    });
  });

  test('sims', () {
    expect(runSims(euro6Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
