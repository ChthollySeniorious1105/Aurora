import 'dart:math';

import 'package:aurora_shared/games/party17/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int players, {Map<String, dynamic>? options, int seed = 42}) {
  return GameSetup(
    players: players,
    options: options ?? const {},
    names: [for (var i = 0; i < players; i++) 'P$i'],
    bots: List<bool>.filled(players, false),
    hostSeat: 0,
    rng: Random(seed),
  );
}

void main() {
  group('burgle_bros (神偷小队)', () {
    test('Peek, move, alarm trigger, hack suppression, safe-cracking & guard patrol stealth loss', () {
      final g = BurgleBrosGame(_setup(2));
      g.start();

      // Clear internal walls for deterministic movement test
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 3; c++) {
          g.vWalls[r][c] = false;
        }
      }
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 4; c++) {
          g.hWalls[r][c] = false;
        }
      }

      // Configure rooms around (3, 0):
      // (2, 0) = Computer (5), (3, 1) = Laser Alarm (3), (2, 1) = Safe (1), (1, 1) = Escape (2)
      g.rooms[2][0] = 5;
      g.rooms[3][1] = 3;
      g.rooms[2][1] = 1;
      g.rooms[1][1] = 2;

      // Peek (2, 0) for 1 AP
      g.handle(0, {'type': 'peek', 'r': 2, 'c': 0});
      expect(g.apLeft, 3);
      expect(g.revealed[2][0], isTrue);

      // Move to (2, 0) Computer room (1 AP) and Hack (1 AP)
      g.handle(0, {'type': 'move', 'r': 2, 'c': 0});
      g.handle(0, {'type': 'hack'});
      expect(g.hackTokens, 1);
      expect(g.apLeft, 1);

      // Move to (2, 1) Safe (1 AP) and end turn
      g.handle(0, {'type': 'move', 'r': 2, 'c': 1});
      expect(g.apLeft, 0);
      g.handle(0, {'type': 'end_turn'});

      // Seat 1 moves into (3, 1) Laser Alarm: consumes hackToken without raising guardSpeed!
      final oldSpeed = g.guardSpeed;
      g.handle(1, {'type': 'move', 'r': 3, 'c': 1});
      expect(g.hackTokens, 0);
      expect(g.guardSpeed, oldSpeed);

      // Seat 1 moves back to (3, 0) and then re-enters (3, 1) with 0 hackTokens -> triggers alarm!
      g.handle(1, {'type': 'move', 'r': 3, 'c': 0});
      g.handle(1, {'type': 'move', 'r': 3, 'c': 1});
      expect(g.guardTarget, [3, 1]);
      expect(g.guardSpeed, oldSpeed + 1);
      g.handle(1, {'type': 'end_turn'});

      // Seat 0 on Safe (2, 1) adds die and cracks Safe
      final needed = g.safeDigits;
      g.crackedDigits.addAll(needed.take(needed.length - 1));
      g.handle(0, {'type': 'add_die'});
      g.crackAttempts = 2; // guarantees final digit cracks
      g.handle(0, {'type': 'crack'});
      expect(g.safeCracked, isTrue);
      expect(g.lootCarrier, 0);

      // Move Seat 0 to (1, 1) Escape Helipad -> escapes!
      g.handle(0, {'type': 'move', 'r': 1, 'c': 1});
      expect(g.escaped[0], isTrue);
    });
  });

  group('broom_service (魔女速递)', () {
    test('4-role selection, Coward immediate effect & Brave cancellation takeover', () {
      final g = BroomServiceGame(_setup(3, options: const {'rounds': 4}));
      g.start();

      expect(g.phase, 'select');
      g.handle(0, {'type': 'select', 'roles': [0, 4, 5, 7]});
      g.handle(1, {'type': 'select', 'roles': [0, 1, 4, 6]});
      g.handle(2, {'type': 'select', 'roles': [0, 2, 3, 7]});

      expect(g.phase, 'lead');
      expect(g.turn, 0);

      final s0StartScore = g.scores[0];
      final s1StartScore = g.scores[1];
      final s2StartScore = g.scores[2];

      // Seat 0 leads Role 0 (Mountain Witch) as BRAVE -> claims braveSeat = 0 (not resolved yet)
      g.handle(0, {'type': 'play', 'role': 0, 'mode': 'brave'});
      expect(g.phase, 'follow');
      expect(g.braveSeat, 0);
      expect(g.scores[0], s0StartScore);

      // Seat 1 holds Role 0 and chooses COWARD -> immediately gets safe VP (+4 with potion)
      g.handle(1, {'type': 'play', 'role': 0, 'mode': 'coward'});
      expect(g.scores[1], greaterThan(s1StartScore));
      expect(g.braveSeat, 0); // Seat 0 still holds Brave spot

      // Seat 2 holds Role 0 and chooses BRAVE -> CANCELS Seat 0 and wins the Brave effect & next lead!
      g.handle(2, {'type': 'play', 'role': 0, 'mode': 'brave'});
      expect(g.scores[0], s0StartScore); // Seat 0 got nothing!
      expect(g.scores[2], greaterThan(s2StartScore + 4)); // Seat 2 got Brave tower reward!
      expect(g.leader, 2);
      expect(g.turn, 2);
      expect(g.phase, 'lead');
    });
  });

  group('mahe (马埃岛海龟竞速)', () {
    test('1-3 dice multiplier (Sum * Count <= 7), bust to 0, piggyback stack carrying & Egg card wrap', () {
      final g = MaheGame(_setup(3));
      g.start();

      // Seat 0 starts with d1 = 3, rolls d2 = 3 -> sum = 6 <= 7, stops for 6 * 2 = 12 spaces!
      g.dice = [3];
      g.handle(0, {'type': 'roll', 'die': 3});
      expect(g.dice, [3, 3]);
      expect(g.moveSteps, 12);
      g.handle(0, {'type': 'stop'});
      expect(g.pos[0], 12);
      expect(g.stacks[12], [0]);

      // Seat 1 rolls d1 = 4, d2 = 2 -> stops for 6 * 2 = 12 spaces -> lands on space 12 ON TOP of Seat 0!
      g.dice = [4];
      g.handle(1, {'type': 'roll', 'die': 2});
      g.handle(1, {'type': 'stop'});
      expect(g.pos[1], 12);
      expect(g.stacks[12], [0, 1]); // 0 at bottom, 1 on top!

      // Seat 2 busts: d1 = 5, rolls d2 = 4 -> sum 9 > 7 -> BUST back to 0!
      g.dice = [5];
      g.handle(2, {'type': 'roll', 'die': 4});
      expect(g.lastBusted, isTrue);
      expect(g.pos[2], 0);

      // Now it is Seat 0's turn again (turn == 0), but Seat 1 is on top of Seat 0 at space 12!
      expect(g.turn, 0);
      expect(g.controller, 1);
      expect(g.waitingFor, [1]);

      // Top turtle (Seat 1) rolls 3 dice: [2, 2, 3] -> sum = 7 <= 7 -> advances 7 * 3 = 21 spaces!
      // Both Seat 0 and Seat 1 move from 12 -> 12 + 21 = 33 -> wraps to 12 and Top turtle (Seat 1) claims Egg!
      g.dice = [2, 2];
      g.handle(1, {'type': 'roll', 'die': 3});
      expect(g.pos[0], 12);
      expect(g.pos[1], 12);
      expect(g.eggs[1], isNotEmpty);
      expect(g.scores[1], greaterThan(0));
    });
  });

  group('stockpile (股市大亨)', () {
    test('Private insider forecast hiding, supply piles, bidding, selling, Stock Split (>10) & Bankruptcy (<1)', () {
      final g = StockpileGame(_setup(3, options: const {'rounds': 4}));
      g.start();

      // Verify private insider info is hidden from other seats in view(seat)
      final v0 = g.view(0);
      final v1 = g.view(1);
      expect(v0['myInsiderCorp'], g.insiderCorp[0]);
      expect(v1['myInsiderCorp'], g.insiderCorp[1]);
      expect(g.view(-1)['myInsiderCorp'], isNull);

      // Phase 1: 'supply'
      expect(g.phase, 'supply');
      g.handle(0, {'type': 'supply', 'upPile': 0, 'downPile': 1});
      g.handle(1, {'type': 'supply', 'upPile': 1, 'downPile': 2});
      g.handle(2, {'type': 'supply', 'upPile': 2, 'downPile': 0});

      // Phase 2: 'bid'
      expect(g.phase, 'bid');
      final firstTurn = g.turn;
      g.handle(firstTurn, {'type': 'bid', 'pile': 0, 'amount': 3});
      g.handle(g.turn, {'type': 'bid', 'pile': 1, 'amount': 2});
      g.handle(g.turn, {'type': 'bid', 'pile': 2, 'amount': 0});

      // Phase 3: 'sell' & Forecast resolution with Stock Split and Bankruptcy
      expect(g.phase, 'sell');
      // Set Corp 0 price to 8 with forecast +4 -> 12 (>10 -> Stock Split!)
      // Set Corp 1 price to 2 with forecast -3 -> -1 (<1 -> Bankruptcy!)
      g.prices[0] = 8;
      g.shares[0][0] = 3;
      g.splitShares[0][0] = 0;

      g.prices[1] = 2;
      g.shares[0][1] = 4;

      g.publicCorp = 0;
      g.publicShift = 4;
      g.insiderCorp[0] = 1;
      g.insiderShift[0] = -3;
      g.insiderCorp[1] = 2;
      g.insiderShift[1] = 2;
      g.insiderCorp[2] = 3;
      g.insiderShift[2] = -1;

      g.handle(0, {'type': 'sell', 'counts': [0, 0, 0, 0, 0, 0]});
      g.handle(1, {'type': 'sell', 'counts': [0, 0, 0, 0, 0, 0]});
      g.handle(2, {'type': 'sell', 'counts': [0, 0, 0, 0, 0, 0]});

      // Corp 0 split: Seat 0's 3 shares doubled into 6 splitShares, price reset to 6
      expect(g.splitShares[0][0], 6);
      expect(g.shares[0][0], 0);
      expect(g.prices[0], 6);

      // Corp 1 went bankrupt: Seat 0's unsplit shares wiped out to 0, price reset to 5
      expect(g.shares[0][1], 0);
      expect(g.prices[1], 5);
    });
  });

  test('simulate all party17 games (30 seeds per player count & option)', () {
    final failures = runSims(party17Games, n: 30);
    expect(failures, 0);
  });
}
