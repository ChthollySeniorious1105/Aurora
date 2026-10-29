import 'dart:math';

import 'package:aurora_shared/games/party5/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

void main() {
  group('IncanGold engine unit tests', () {
    IncanGold createGame({int players = 4, int rounds = 5, int seed = 42}) {
      final setup = GameSetup(
        players: players,
        options: {'rounds': rounds},
        names: [for (var i = 0; i < players; i++) 'P$i'],
        bots: List.filled(players, false),
        rng: Random(seed),
      );
      final g = IncanGold(setup);
      g.start();
      return g;
    }

    test('sole leaver claims path gems and all revealed artifacts', () {
      final g = createGame(players: 3);
      // Set up deterministic state in round 1
      g.inTemple = [true, true, true];
      g.pocket = [4, 4, 4];
      g.chest = [0, 0, 0];
      g.pathGems = 5;
      g.pathArtifacts = [5, 10];
      g.choices.clear();
      // Put a safe treasure card on top of deck for the remaining players
      g.deck.add({'kind': 'treasure', 'value': 6});

      // Player 0 leaves alone; Players 1 and 2 continue
      g.handle(0, {'type': 'leave'});
      g.handle(1, {'type': 'go'});
      g.handle(2, {'type': 'go'});

      // Player 0 gets pocket (4) + all pathGems (5) + artifacts (5+10=15) = 24
      expect(g.chest[0], 24);
      expect(g.artifactsClaimed[0], 2);
      expect(g.pathArtifacts, isEmpty);
      expect(g.inTemple[0], isFalse);

      // Players 1 and 2 split the flipped 6-gem treasure card (3 each)
      expect(g.pocket[1], 7);
      expect(g.pocket[2], 7);
    });

    test('multiple leavers split path gems and leave artifacts behind', () {
      final g = createGame(players: 3);
      g.inTemple = [true, true, true];
      g.pocket = [2, 2, 2];
      g.chest = [0, 0, 0];
      g.pathGems = 5;
      g.pathArtifacts = [5];
      g.choices.clear();
      g.deck.add({'kind': 'treasure', 'value': 4});

      // Players 0 and 1 leave together; Player 2 goes
      g.handle(0, {'type': 'leave'});
      g.handle(1, {'type': 'leave'});
      g.handle(2, {'type': 'go'});

      // 5 path gems split among 2 leavers -> 2 each, 1 remains on path; artifact stays on path
      expect(g.chest[0], 4);
      expect(g.chest[1], 4);
      expect(g.pathArtifacts, [5]);
      // Remaining 1 path gem + 0 remainder from 4-gem card with 1 explorer = 1
      expect(g.pathGems, 1);
      expect(g.pocket[2], 6);
    });

    test('second identical hazard collapses temple and removes hazard copy', () {
      final g = createGame(players: 3, rounds: 3);
      g.inTemple = [true, true, true];
      g.pocket = [6, 6, 6];
      g.chest = [10, 0, 0];
      g.roundHazards['snake'] = 1;
      g.choices.clear();
      // Force next card to be the 2nd snake hazard
      g.deck.add({'kind': 'hazard', 'hazard': 'snake', 'name': '毒蛇'});

      g.handle(0, {'type': 'go'});
      g.handle(1, {'type': 'go'});
      g.handle(2, {'type': 'go'});

      // Round 1 collapsed and advanced to Round 2; snake copies reduced from 3 to 2
      expect(g.round, 2);
      expect(g.hazardCopies['snake'], 2);
      expect(g.chest[0], 10);
      expect(g.chest[1], 0);
      expect(g.chest[2], 0);
      expect(g.roundHistory.first['collapsed'], isTrue);
    });
  });

  group('CamelUp engine unit tests', () {
    CamelUp createGame({int players = 4, int trackLen = 16, int seed = 7}) {
      final setup = GameSetup(
        players: players,
        options: {'trackLen': trackLen},
        names: [for (var i = 0; i < players; i++) 'P$i'],
        bots: List.filled(players, false),
        rng: Random(seed),
      );
      final g = CamelUp(setup);
      g.start();
      return g;
    }

    test('camel stacking carries camels on top and lands on top at destination', () {
      final g = createGame();
      g.stacks.clear();
      g.desertTiles.clear();
      // Space 2 has [0 (bottom), 1 (middle), 2 (top)]
      // Space 4 has [3 (bottom), 4 (top)]
      g.stacks[2] = [0, 1, 2];
      g.stacks[4] = [3, 4];

      // Camel 1 moves 2 steps -> carries [1, 2] to space 4 on top of [3, 4], leaving [0] at space 2
      g.moveCamel(1, 2);
      expect(g.stacks[2], [0]);
      expect(g.stacks[4], [3, 4, 1, 2]);
      // Ranking should be: top of space 4 down to bottom, then space 2 -> [2, 1, 4, 3, 0]
      expect(g.camelRanking, [2, 1, 4, 3, 0]);
    });

    test('oasis (+1 on top) and mirage (-1 underneath) tiles work and award +1 coin', () {
      final g = createGame();
      g.stacks.clear();
      g.desertTiles.clear();
      g.stacks[2] = [0, 1];
      g.stacks[5] = [2];
      g.stacks[3] = [3, 4];

      // Place player 1's Oasis (+1) at space 4
      g.turn = 1;
      g.handle(1, {'type': 'desert', 'space': 4, 'dir': 1});
      final coinsBefore = g.coins[1];

      // Move camel 0 by 2 steps -> lands on space 4 (Oasis) -> moves to space 5 on top of [2]
      g.moveCamel(0, 2);
      expect(g.coins[1], coinsBefore + 1);
      expect(g.stacks[5], [2, 0, 1]);

      // Place player 2's Mirage (-1) at space 4 (now empty)
      g.turn = 2;
      g.desertTiles.clear();
      g.handle(2, {'type': 'desert', 'space': 4, 'dir': -1});
      g.stacks[5] = [2, 1];
      g.stacks[2] = [0];
      final coins2Before = g.coins[2];

      // Move camel 0 from space 2 by 2 steps -> lands on space 4 (Mirage) -> pushed back to space 3 UNDERNEATH [3, 4]
      g.moveCamel(0, 2);
      expect(g.coins[2], coins2Before + 1);
      expect(g.stacks[3], [0, 3, 4]);
    });

    test('race bet secret visibility and end-of-game settlement', () {
      final g = createGame(players: 3, trackLen: 12);
      g.turn = 0;
      g.handle(0, {'type': 'race_bet', 'camel': 2, 'bet': 'win'});
      // Player 0 sees their own bet camel (2), Player 1 sees -1 while game is running
      expect((g.view(0)['winBets'] as List).first['camel'], 2);
      expect((g.view(1)['winBets'] as List).first['camel'], -1);

      // Force camel 2 near finish line so next roll crosses >= 12
      g.stacks.clear();
      g.stacks[11] = [2];
      g.stacks[1] = [0, 1, 3, 4];
      g.unrolledCamels = [2];
      g.turn = 1;
      g.handle(1, {'type': 'roll'});

      expect(g.isOver, isTrue);
      expect(g.placings, isNotNull);
      // Player 0 gets +8 for first correct win bet (started with 3 -> 11 coins)
      expect(g.coins[0], 11);
      // After game over, everyone sees race bet camels
      expect((g.view(1)['winBets'] as List).first['camel'], 2);
    });
  });

  test('simulate 30 games for all party5 games', () {
    final failures = runSims(party5Games, n: 30);
    expect(failures, 0);
  });
}
