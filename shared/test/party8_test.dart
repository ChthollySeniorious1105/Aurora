import 'dart:math';

import 'package:aurora_shared/games/party8/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int players, [Map<String, dynamic> opts = const {}]) =>
    GameSetup(
      players: players,
      options: opts,
      names: [for (var i = 0; i < players; i++) 'P$i'],
      bots: List.filled(players, false),
      rng: Random(42),
    );

void main() {
  group('Qwixx (快克骰子)', () {
    test('ascending/descending order, row locking with >=5 crosses, and penalties', () {
      final g = QwixxGame(_setup(2, {'lockTarget': 2}));
      g.start();
      g.w1 = 3;
      g.w2 = 4; // sum = 7
      g.colorDice = [5, 2, 1, 6];

      // White step: P0 crosses 7 in Red (row 0, asc), P1 crosses 7 in Green (row 2, desc)
      g.handle(0, {'type': 'white', 'row': 0});
      g.handle(1, {'type': 'white', 'row': 2});
      expect(g.step, 'color');
      expect(g.sheets[0][0], [7]);
      expect(g.sheets[1][2], [7]);

      // P0 cannot cross <= 7 in Red row
      g.w1 = 2;
      g.colorDice[0] = 3; // 2+3 = 5 <= 7
      expect(
        () => g.handle(0, {'type': 'color', 'row': 0, 'num': 5}),
        throwsA(isA<GameError>()),
      );

      // P0 passes color step -> no penalty since P0 crossed in white step
      g.handle(0, {'type': 'color', 'row': -1});
      expect(g.penalties[0], 0);
      expect(g.turn, 1);
      expect(g.step, 'white');

      // P1 passes both white and color -> gets 1 penalty
      g.handle(0, {'type': 'white', 'row': -1});
      g.handle(1, {'type': 'white', 'row': -1});
      g.handle(1, {'type': 'color', 'row': -1});
      expect(g.penalties[1], 1);

      // Test locking rightmost number (12 in row 0 requires >= 5 crosses)
      g.sheets[0][0] = [2, 3, 4, 5]; // only 4 crosses
      g.w1 = 6;
      g.w2 = 6; // sum = 12
      expect(g.canCross(0, 0, 12), isFalse);
      g.sheets[0][0] = [2, 3, 4, 5, 6]; // 5 crosses
      expect(g.canCross(0, 0, 12), isTrue);
      g.handle(0, {'type': 'white', 'row': 0});
      g.handle(1, {'type': 'white', 'row': -1});
      expect(g.locked[0], isTrue);
      expect(g.lockBonus[0][0], isTrue);
      // 6 numbers + 1 lock bonus = 7 crosses -> 7 * 8 ~/ 2 = 28 pts
      expect(g.rowScore(0, 0), 28);
    });
  });

  group('Deep Sea Adventure (深海冒险)', () {
    test('oxygen drain, leapfrog movement, pickup/drop, and round compaction', () {
      final g = DeepSeaGame(_setup(2, {'rounds': 2}));
      g.start();
      expect(g.path.length, 32);
      expect(g.oxygen, 25);
      expect(g.phase, 'dir');

      // P0 dives down and picks up a tile
      g.handle(0, {'type': 'dir', 'dir': 'down'});
      expect(g.pos[0], greaterThanOrEqualTo(1));
      expect(g.phase, 'tile');
      final p0Pos = g.pos[0];
      g.handle(0, {'type': 'tile', 'act': 'pickup'});
      expect(g.carried[0].length, 1);
      expect(g.path[p0Pos]['blank'], isTrue);

      // P1 dives down
      expect(g.turn, 1);
      g.handle(1, {'type': 'dir', 'dir': 'down'});
      g.handle(1, {'type': 'tile', 'act': 'stay'});

      // Back to P0: oxygen must decrease by carried[0].length (1)
      expect(g.turn, 0);
      expect(g.oxygen, 24);

      // P0 turns back
      g.handle(0, {'type': 'dir', 'dir': 'back'});
      expect(g.turningBack[0], isTrue);
    });
  });

  group('Karuba (卡鲁巴寻宝)', () {
    test('place tiles, move adventurer along connected path, collect gold and enter temple', () {
      final g = KarubaGame(_setup(2, {'tiles': 24}));
      g.start();

      // Adventurer 0 (Blue) starts at (1, -1), entry is (1, 0), temple entry is (0, 4), temple is (-1, 4)
      // Place a connected path for seat 0 from (1, 0) -> (0, 0) -> (0, 1) -> (0, 2) -> (0, 3) -> (0, 4)
      // Let's set up tiles directly on seat 0's grid to test multi-step path & temple entry
      g.grids[0][1][0] = {'id': 11, 'dirs': [0, 1, 2, 3], 'gold': false, 'crystal': false};
      g.grids[0][0][0] = {'id': 15, 'dirs': [0, 1, 2, 3], 'gold': true, 'crystal': false};
      g.grids[0][0][4] = {'id': 11, 'dirs': [0, 1, 2, 3], 'gold': false, 'crystal': false};

      // Force currentTile to have 4 exits (tile 11)
      g.currentTile = 11;
      // Move Adventurer 0 from beach (1,-1) -> (1,0) -> (0,0) (2 steps) and collect gold (+2)
      g.handle(0, {'type': 'move', 'adv': 0, 'targetR': 0, 'targetC': 0});
      g.handle(1, {'type': 'place', 'r': 0, 'c': 0});
      expect(g.advR[0][0], 0);
      expect(g.advC[0][0], 0);
      expect(g.scores[0], 2);
      expect(g.grids[0][0][0]!['gold'], isFalse);

      // Teleport Adv 0 to (0, 4) (temple entry cell) and move into Temple (-1, 4)
      g.advR[0][0] = 0;
      g.advC[0][0] = 4;
      g.currentTile = 11;
      g.handle(0, {'type': 'move', 'adv': 0, 'targetR': -1, 'targetC': 4});
      g.handle(1, {'type': 'place', 'r': 0, 'c': 1});
      expect(g.inTemple[0][0], isTrue);
      expect(g.scores[0], 2 + 5); // +5 first temple treasure
      expect(g.templeTreasures[0], [4, 3, 2]);
    });
  });

  test('simulate party8 games (30 runs per combo)', () {
    final failures = runSims(party8Games, n: 30);
    expect(failures, 0);
  });
}
