import 'dart:math';

import 'package:aurora_shared/games/euro17/defs.dart';
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
  group('verdant', () {
    test('checkerboard parity validation, directional window light matching, room color bonus, fertilizer, and potting', () {
      final e = _start(VerdantGame(_setup(2)));

      // Clear P0's grid for deterministic testing
      for (var r = 0; r < VerdantGame.rows; r++) {
        for (var c = 0; c < VerdantGame.cols; c++) {
          e.grid[0][r][c] = const VerdantCell();
        }
      }
      e.roomBonusVp[0] = 0;
      e.tokenVp[0] = 0;
      e.pottedCount[0] = 0;

      // Place a Room at (0, 1) (odd parity: 0 + 1 == 1) with color 0 (🟩) and West window light = 0 (☀️)
      // Lights order: [N, E, S, W] -> index 3 is West (facing (0, 0)), index 2 is South (facing (1, 1))
      e.grid[0][0][1] = const VerdantCell(
        room: VerdantRoomCard(
          id: 901,
          name: '测试阳光房',
          emoji: '🏡',
          color: 0,
          lights: [1, 1, 0, 0], // S=0 (☀️), W=0 (☀️)
        ),
      );

      // Put a Plant in plantRow[0] requiring light 0 (☀️), color 0 (🟩), targetVerdancy 3, vp 6
      e.plantRow[0] = const VerdantPlantCard(
        id: 902,
        name: '测试琴叶榕',
        emoji: '🌿',
        color: 0,
        light: 0, // ☀️
        targetVerdancy: 3,
        vp: 6,
      );
      // Put a Fertilizer token (+2🌿) in tokenRow[0]
      e.tokenRow[0] = const VerdantToken(
        id: 903,
        name: '有机液肥',
        emoji: '🧪',
        isFertilizer: true,
        value: 2,
      );
      e.roomThumbs[0] = 0;

      // Trying to place a Plant on an odd parity cell (1, 0) must fail!
      expect(
        () => e.handle(0, {
          'type': 'draft',
          'col': 0,
          'pickPlant': true,
          'r': 1,
          'c': 0,
        }),
        throwsA(isA<GameError>()),
      );

      // Place Plant at (0, 0) (even parity) and apply Fertilizer (+2🌿) to (0, 0):
      // - Adjacent Room at (0, 1) has West window (dir 3) == 0 (☀️) matching Plant's light 0 -> +1🌿!
      // - Adjacent Room at (0, 1) has color 0 == Plant's color 0 -> +1 Room Color Bonus VP!
      // - Fertilizer adds +2🌿 -> total Verdancy = 1 + 2 = 3 == targetVerdancy (3) -> Potted!
      // - Unchosen Room in col 0 receives +1 Green Thumb (👍)!
      e.handle(0, {
        'type': 'draft',
        'col': 0,
        'pickPlant': true,
        'r': 0,
        'c': 0,
        'fertR': 0,
        'fertC': 0,
      });

      final placedPlant = e.grid[0][0][0].plant!;
      expect(placedPlant.potted, isTrue);
      expect(placedPlant.currentVerdancy, 3);
      expect(placedPlant.potBonus, 3); // First potted plant gets +3 VP pot bonus
      expect(e.roomBonusVp[0], 1);
      expect(e.roomThumbs[0], 1); // 1 👍 placed on unchosen Room in col 0
      expect(e.calcPlantVp(0), 9); // 6 VP + 3 pot bonus
    });
  });

  group('santa_monica', () {
    test('bottom row drafting, slide-down refill, sand dollar economy to fill activity rings, and top row drafting', () {
      final e = _start(SantaMonicaGame(_setup(2)));
      e.shells[0] = 2;
      e.vipPool[0] = 1;
      e.touristPool[0] = 1;

      const topCard = SantaMonicaCard(
        id: 801,
        name: '顶层摩天轮',
        emoji: '🎡',
        rowType: 0, // Beach
        featureTag: 1,
        gainShells: 1,
        ringCap: 1,
        ringVp: 4,
      );
      const bottomCard = SantaMonicaCard(
        id: 802,
        name: '底层冲浪滩',
        emoji: '🏄',
        rowType: 0, // Beach
        featureTag: 0,
        gainShells: 2,
        spawnTourists: 1,
        ringCap: 1,
        ringVp: 5,
      );
      e.display[0][0] = topCard;
      e.display[1][0] = bottomCard;

      // Spend 1 Sand Dollar (🐚) to move VIP into initial Beach card at (0, 0) (which has ringCap=1, ringVp=3)
      e.handle(0, {'type': 'spend_shell', 'r': 0, 'c': 0});
      expect(e.shells[0], 1);
      expect(e.tableau[0][0][0]!.ringDone, isTrue);
      expect(e.calcRingVp(0), 3);

      // Spending 1 shell does not end turn; now P0 drafts bottomCard from col 0 into slotC 1
      e.handle(0, {'type': 'draft', 'col': 0, 'slotC': 1});
      expect(e.tableau[0][0][1]?.id, 802);
      expect(e.shells[0], 3); // 1 + 2 gainShells
      // Top card (id 801) slid down to bottom row display[1][0]!
      expect(e.display[1][0]?.id, 801);

      // P1 takes a full turn
      while (e.turn == 1) {
        e.handle(1, e.bot(1)!);
      }

      // P0 now has 3 shells -> can spend 2 shells to draft directly from Top Row (row 0, col 1)!
      final topCol1Id = e.display[0][1]!.id;
      final topCol1RowType = e.display[0][1]!.rowType;
      e.handle(0, {
        'type': 'spend_shell',
        'mode': 'top_draft',
        'col': 1,
        'slotC': 2,
      });
      expect(e.tableau[0][topCol1RowType][2]?.id, topCol1Id);
    });
  });

  group('guild_explorers', () {
    test('contiguous region completion spawns permanent village, tower escalating coins, and era reset preserves villages', () {
      final e = _start(GuildExplorersGame(_setup(2)));

      // Set current Explore Card to Grassland (terrainType: 1, maxCells: 3)
      e.currentCard = const GuildExploreCard(
        id: 701,
        name: '平原开拓令',
        emoji: '🌾',
        terrainType: 1,
        maxCells: 3,
      );

      // Around Capital (3, 3), cells (2, 3) and (2, 2) form a 2-cell Grassland (1) region!
      // Trying to explore a disconnected cell (0, 3) not adjacent to (3, 3) must fail!
      expect(
        () => e.handle(0, {
          'type': 'explore',
          'cells': [
            [0, 3]
          ],
        }),
        throwsA(isA<GameError>()),
      );

      // Explore both (2, 3) and (2, 2) -> completes the contiguous Grassland region and spawns a Permanent Village (🏠)!
      e.handle(0, {
        'type': 'explore',
        'cells': [
          [2, 3],
          [2, 2],
        ],
      });
      expect(e.explored[0][2][3], isTrue);
      expect(e.explored[0][2][2], isTrue);
      expect(e.countVillages(0), 1);
      expect(e.villages[0][2][2] || e.villages[0][2][3], isTrue);
      expect(e.villageVp[0], greaterThan(0));

      // Trigger End-of-Era cleanup: all Explorer Cubes are removed (except Capital (3,3)),
      // while Permanent Villages stay on the map!
      e.endCurrentEra();
      expect(e.explored[0][2][3], isFalse);
      expect(e.explored[0][2][2], isFalse);
      expect(e.explored[0][3][3], isTrue);
      expect(e.countVillages(0), 1);

      // In the new Era, P0 can start exploring directly adjacent to their Permanent Village at (2, 2)!
      // Cell (1, 2) is adjacent to (2, 2) (and NOT adjacent to (3, 3)):
      expect(e.isConnectedToHubOrExplored(0, 1, 2), isTrue);
    });
  });

  group('little_town', () {
    test('8-neighbor spatial gathering, opponent building 1-coin activation fee, construction, and round-end feeding', () {
      final e = _start(LittleTownGame(_setup(2)));
      e.res[0] = [2, 2, 0, 0];
      e.res[1] = [0, 0, 2, 2];
      e.coins[0] = 3;
      e.coins[1] = 3;

      // Place a Building owned by P1 at (1, 1) that produces +2 VP and +2 Coins
      e.buildings[1][1] = const LittleTownPlacedBuilding(
        owner: 1,
        card: LittleTownBuildingCard(
          id: 601,
          name: '商会金库',
          emoji: '🏦',
          buildVp: 4,
          outCoins: 2,
          outVp: 2,
        ),
      );

      // P0 places a worker at empty grass (1, 0):
      // Surrounding 8 neighbors of (1, 0) include:
      // - (0, 0) which has map[0][0] == 1 (🌲 Wood) -> +1 Wood
      // - (2, 1) which has map[2][1] == 2 (🪨 Stone) -> +1 Stone
      // - (1, 1) which has P1's Building -> P0 pays 1 Coin to P1 and gains +2 Coins, +2 VP!
      e.handle(0, {'type': 'gather', 'r': 1, 'c': 0});
      expect(e.res[0][0], 3); // 2 + 1 Wood
      expect(e.res[0][1], 3); // 2 + 1 Stone
      expect(e.coins[1], 4); // P1 received +1 Coin activation fee!
      expect(e.coins[0], 4); // 3 - 1 fee + 2 outCoins = 4
      expect(e.vp[0], 2); // +2 outVp

      // P1 builds a building from market[0] onto empty grass (2, 2)
      e.res[1] = [5, 5, 5, 5];
      final bCard = e.market[0];
      e.handle(1, {'type': 'build', 'marketIdx': 0, 'r': 2, 'c': 2});
      expect(e.buildings[2][2]?.owner, 1);
      expect(e.vp[1], bCard.buildVp);
    });
  });

  test('sims', () {
    expect(runSims(euro17Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
