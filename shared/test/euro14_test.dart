import 'dart:math';

import 'package:aurora_shared/games/euro14/defs.dart';
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
  group('isle_of_cats', () {
    test('fish/basket cost, adjacency rule, treasure map trigger, Oshax color choice, and family/rat/room scoring', () {
      final e = _start(IsleOfCatsGame(_setup(2)));
      expect(e.fish[0], 10);
      expect(e.baskets[0], 2);

      // Put a Blue Cat (color 1, Left Field cost 3, shape I3) at slot 0
      e.islandCats[0] = const IsleCatTile(
        id: 801,
        color: 1,
        field: 0,
        shape: [(0, 0), (0, 1), (0, 2)],
      );
      // Note mapColor[0][2] == 1 (Blue Treasure Map)!
      expect(IsleOfCatsGame.mapColor[0][2], 1);

      // P0 rescues slot 0 covering (0,0), (0,1) [Rat], (0,2) [Blue Map]
      e.handle(0, {
        'type': 'rescue',
        'slot': 0,
        'cells': [
          [0, 0],
          [0, 1],
          [0, 2],
        ],
        'treasureCell': [1, 0],
      });
      expect(e.fish[0], 7); // 10 - 3 = 7
      expect(e.baskets[0], 1);
      expect(e.rareTreasures[0], 1);
      expect(e.boat[0][1][0], 7); // Bonus Treasure placed at (1,0)!
      expect(e.calcCatFamilyScore(0), 8); // 3 connected Blue cats = 8 VP

      // P1 passes so P0 can act again
      e.handle(1, {'type': 'pass'});
      expect(e.turn, 0);

      // Put an Oshax (color 6, Right Field cost 5, shape Domino) at slot 0
      e.islandCats[0] = const IsleCatTile(
        id: 802,
        color: 6,
        field: 1,
        shape: [(0, 0), (0, 1)],
      );

      // Non-adjacent placement on boat must fail!
      expect(
        () => e.handle(0, {
          'type': 'rescue',
          'slot': 0,
          'oshaxColor': 1,
          'cells': [
            [4, 7],
            [4, 8],
          ],
        }),
        throwsA(isA<GameError>()),
      );

      // Adjacent placement at (0,3),(0,4) choosing color 1 (Blue) expands family from 3 -> 5 (15 VP)!
      e.handle(0, {
        'type': 'rescue',
        'slot': 0,
        'oshaxColor': 1,
        'cells': [
          [0, 3],
          [0, 4],
        ],
      });
      expect(e.fish[0], 2); // 7 - 5 = 2
      expect(e.calcCatFamilyScore(0), 15); // 5 connected Blue cats = 15 VP!

      // Fill Room 0 completely and verify unfilledRooms drops from 6 to 5
      for (var r = 0; r < IsleOfCatsGame.rows; r++) {
        for (var c = 0; c < IsleOfCatsGame.cols; c++) {
          if (IsleOfCatsGame.roomMap[r][c] == 0 && e.boat[0][r][c] == 0) {
            e.boat[0][r][c] = 7;
          }
        }
      }
      expect(e.calcUnfilledRooms(0), 5);
    });
  });

  group('dorfromantik', () {
    test('River/Railway edge matching, exact Task fulfillment vs over-target cancellation, and Closed Flag territory', () {
      final e = _start(DorfromantikGame(_setup(2)));
      // Center (0,0) is Wheat (type 0) with active Task (taskType 0, taskTarget 4)
      expect(e.grid[(0, 0)]!.taskState, 1);

      // Set currentTile to a River tile (type 4, default edges [4, 0, 0, 4, 0, 0])
      e.currentTile = DorfromantikTile(id: 901, type: 4);
      // Placing at (0, -1) [dir 0 of (0,0)] with rot=0 puts edge[3]=4 (River) against (0,0)'s edge[0]=0 (Wheat) -> MUST throw!
      expect(
        () => e.handle(0, {'type': 'place', 'q': 0, 'r': -1, 'rot': 0}),
        throwsA(isA<GameError>()),
      );

      // Rotating by rot=1 puts edge[3]=0 (Wheat) against (0,0)'s edge[0]=0 -> succeeds!
      e.handle(0, {'type': 'place', 'q': 0, 'r': -1, 'rot': 1});
      expect(e.grid.containsKey((0, -1)), isTrue);
      expect(e.calcLongestRiver(), 1);

      // Complete the Wheat task (target 4) at (0,0) by placing 3 Wheat tiles around it:
      for (final (q, r) in const [(1, 0), (0, 1), (1, 1)]) {
        e.currentTile = DorfromantikTile(id: 910 + q + r, type: 0);
        e.handle(e.turn, {'type': 'place', 'q': q, 'r': r, 'rot': 0});
      }
      // Connected Wheat group now has exactly 4 tiles -> Task at (0,0) is Fulfilled (+4 VP)!
      expect(e.grid[(0, 0)]!.taskState, 2);
      expect(e.fulfilledTaskScore, 4);

      // Test Task Cancellation when a single placement pushes group size strictly above taskTarget:
      // Place 3 Forest tiles at (2, 0), (3, 0), (4, 0) and a Forest Task (target 4) at (2, 1) + Forest at (2, 2)
      e.grid[(2, 0)] = DorfromantikTile(id: 920, type: 1);
      e.grid[(3, 0)] = DorfromantikTile(id: 921, type: 1);
      e.grid[(4, 0)] = DorfromantikTile(id: 922, type: 1);
      e.grid[(2, 2)] = DorfromantikTile(id: 923, type: 1);
      // Connecting them at (2, 1) with a Task Bubble of target 4 creates a group of 5 > 4 -> Cancelled (taskState = 3)!
      e.currentTile = DorfromantikTile(id: 924, type: 1, taskType: 1, taskTarget: 4);
      e.handle(e.turn, {'type': 'place', 'q': 2, 'r': 1, 'rot': 0});
      expect(e.grid[(2, 1)]!.taskState, 3);
      expect(e.cancelledTasksCount, 1);

      // Test Closed Flag Territory: put a Village Flag tile at (5, 0) and surround all 6 neighbors with non-Village tiles
      e.grid[(5, 0)] = DorfromantikTile(id: 930, type: 2, hasFlag: true);
      for (final nb in DorfromantikGame.neighbors(5, 0)) {
        e.grid.putIfAbsent(nb, () => DorfromantikTile(id: 940, type: 0));
      }
      expect(e.calcClosedFlagScore(), greaterThanOrEqualTo(1));
    });
  });

  group('my_city', () {
    test('first building touches River, no single building crosses River, Gold +2 VP, and 2x2 same-color block +4 VP', () {
      final e = _start(MyCityGame(_setup(2)));
      e.currentCard = const MyCityCard(
        id: 701,
        color: 1,
        name: '住宅·双联屋',
        shape: [(0, 0), (0, 1)],
      );

      // First building NOT touching River (row 3 or 4) must fail!
      expect(
        () => e.handle(0, {
          'type': 'build',
          'cells': [
            [1, 2],
            [1, 3],
          ],
        }),
        throwsA(isA<GameError>()),
      );

      // Single building crossing over the River (row 3 and row 4) must fail!
      expect(
        () => e.handle(0, {
          'type': 'build',
          'cells': [
            [3, 1],
            [4, 1],
          ],
        }),
        throwsA(isA<GameError>()),
      );

      // Valid first building along North riverbank at (3, 1), (3, 2)
      e.handle(0, {
        'type': 'build',
        'cells': [
          [3, 1],
          [3, 2],
        ],
      });
      expect(e.building[0][3][1], 1);
      expect(e.building[0][3][2], 1);

      // P1 passes (-1 penalty)
      e.handle(1, {'type': 'pass'});
      expect(e.passPenalties[1], 1);

      // Next card: Yellow Domino at (2, 1), (2, 2) -> forms a 2x2 Yellow block with (3,1),(3,2) AND covers Gold if placed on (2,5)!
      e.currentCard = const MyCityCard(
        id: 702,
        color: 1,
        name: '住宅·双联屋',
        shape: [(0, 0), (0, 1)],
      );
      e.board[0][2][1] = 3; // Gold Nugget at (2, 1)
      // Wait: if P1 was turn 1 for card 2, advance P1 first if needed
      if (e.turn == 1) {
        e.handle(1, {'type': 'retire'});
      }
      e.handle(0, {
        'type': 'build',
        'cells': [
          [2, 1],
          [2, 2],
        ],
      });
      expect(e.calcCoveredGold(0), 1);
      expect(e.calcSquareBlocks(0), 1); // 2x2 Yellow block at (2..3, 1..2)!
    });
  });

  group('planet_unknown', () {
    test('S.U.S.A.N. rotation, dual-track advance, milestone triggers, and Row/Column Meteor blocking', () {
      final e = _start(PlanetUnknownGame(_setup(2, {'gridSize': 6})));
      expect(e.phase, 'rotate');
      expect(e.turn, 0);

      // Commander (P0) rotates S.U.S.A.N. to rot = 2
      e.handle(0, {'type': 'rotate', 'rot': 2});
      expect(e.susanRot, 2);
      expect(e.phase, 'place');
      expect(e.depotForSeat(0), 2);
      expect(e.depotForSeat(1), 3);

      // Put a custom tile in Depot 2 slot 0: tracks (0: Civ, 2: Biomass), hasMeteor: true, Domino shape
      e.depots[2][0] = const PlanetTile(
        id: 601,
        trackA: 0,
        trackB: 2,
        hasMeteor: true,
        shape: [(0, 0), (0, 1)],
      );
      // Pre-set P0's Civ (0) and Biomass (2) tracks to 2 so advancing +1 hits milestone 3 on both!
      e.tracks[0][0] = 2;
      e.tracks[0][2] = 2;

      // P0 places on (1, 1) [has Lifepod 🌟] and (1, 2)
      e.handle(0, {
        'type': 'place',
        'slot': 0,
        'cells': [
          [1, 1],
          [1, 2],
        ],
      });
      expect(e.tracks[0][0], 3);
      expect(e.tracks[0][2], 3);
      expect(e.civCards[0], 1); // Hit Civ level 3 milestone!
      expect(e.biomassPatches[0], 1); // Hit Biomass level 3 milestone (+1x1 patch)!
      expect(e.rescuedLifepods[0], greaterThanOrEqualTo(1)); // Rescued Lifepod at (1,1)!
      expect(e.meteors[0][1][1], isTrue); // Meteor placed at (1,1)

      // Fill all of Row 1 on P0's planet: because (1,1) has an uncleared Meteor, Row 1 is NOT complete yet!
      for (var c = 0; c < e.gridSize; c++) {
        e.planet[0][1][c] = 1;
      }
      expect(e.isRowComplete(0, 1), isFalse);

      // Advance Rover track (3) -> clears the Meteor at (1,1) -> Row 1 is now complete and scores +3 Medal VP!
      e.advanceTrack(0, 3);
      expect(e.meteors[0][1][1], isFalse);
      expect(e.isRowComplete(0, 1), isTrue);
      expect(e.calcRowColMedalScore(0), greaterThanOrEqualTo(3));
    });
  });

  test('sims', () {
    expect(runSims(euro14Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
