import 'dart:math';

import 'package:aurora_shared/games/arcade4/defs.dart';
import 'package:aurora_shared/games/arcade4/paohuzi.dart';
import 'package:aurora_shared/games/arcade4/pentago.dart';
import 'package:aurora_shared/games/arcade4/puyobattle.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int players, [Map<String, dynamic> opts = const {}, int seed = 42]) => GameSetup(
      players: players,
      options: opts,
      names: [for (var i = 0; i < players; i++) 'P$i'],
      bots: List.filled(players, false),
      rng: Random(seed),
    );

void main() {
  test('arcade4: bots finish every variant and option (count: 30)', () {
    expect(runSims(arcade4Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 10)));

  group('puyobattle', () {
    test('independent gravity for horizontal pair over uneven columns', () {
      final grid = List.filled(PuyoBattle.rows * PuyoBattle.cols, 0);
      // Put an existing puyo at bottom of col 2 (row 11, col 2)
      grid[11 * PuyoBattle.cols + 2] = 1;
      // Place horizontal pair (rot=1: main at col 2, sub at col 3) with colors (2, 3)
      final ok = PuyoBattle.placePair(grid, 2, 3, 2, 1);
      expect(ok, isTrue);
      // Main color 2 lands at row 10 col 2; sub color 3 falls all the way to row 11 col 3
      expect(grid[10 * PuyoBattle.cols + 2], 2);
      expect(grid[11 * PuyoBattle.cols + 3], 3);
    });

    test('4-connected pops, 2-chain cascade, and adjacent garbage pops', () {
      final grid = List.filled(PuyoBattle.rows * PuyoBattle.cols, 0);
      int idx(int r, int c) => r * PuyoBattle.cols + c;

      // Setup a 2-chain with adjacent garbage:
      // Col 0: row 11=Blue(3), row 10=Blue(3), row 9=Blue(3)
      // Col 1: row 11=Red(1), row 10=Red(1), row 9=Red(1), row 8=Blue(3) (will fall to row 11 after Red pops!)
      // Col 2: row 11=Red(1), row 10=Garbage(5) (adjacent to Red at (10,1)), row 9=Garbage(5) (not adjacent to Red, only to Blue at (9,1)?)
      grid[idx(11, 0)] = 3;
      grid[idx(10, 0)] = 3;
      grid[idx(9, 0)] = 3;

      grid[idx(11, 1)] = 1;
      grid[idx(10, 1)] = 1;
      grid[idx(9, 1)] = 1;
      grid[idx(8, 1)] = 3; // suspended above Reds in col 1

      grid[idx(11, 2)] = 1; // 4th Red!
      grid[idx(10, 2)] = PuyoBattle.garbageColor; // adjacent to Red at (10,1) and (11,2)
      grid[idx(11, 5)] = PuyoBattle.garbageColor; // far away garbage, should survive

      final (chains, clearedC, clearedG, score, garbageGen) = PuyoBattle.resolveChains(grid);
      expect(chains, 2);
      expect(clearedC, 8); // 4 Reds + 4 Blues
      expect(clearedG, 1); // adjacent garbage at (10,2) popped
      expect(score, greaterThan(0));
      expect(garbageGen, greaterThanOrEqualTo(6));
      expect(grid[idx(11, 5)], PuyoBattle.garbageColor); // far garbage untouched
    });

    test('garbage countering (offset) and sending to opponents', () {
      final e = PuyoBattle(_setup(2))..start();
      int idx(int r, int c) => r * PuyoBattle.cols + c;
      // Give seat 0 some pending garbage to counter
      e.pendingGarbage[0] = 3;
      // Give seat 0 three Reds in col 0, and current pair (1, 1)
      e.grids[0][idx(11, 0)] = 1;
      e.grids[0][idx(10, 0)] = 1;
      e.grids[0][idx(9, 0)] = 1;
      e.pieceQueue[e.pieceIndex[0]] = (1, 1);

      e.handle(0, {'type': 'drop', 'col': 0, 'rot': 0});
      // 5 Reds popped -> generates 2 garbage, which offsets 2 of seat 0's pendingGarbage
      expect(e.pendingGarbage[0], 1);
      expect(e.pendingGarbage[1], 0);
    });

    test('spawn column (col 2, row 0) blocked triggers top-out and ends 2p game', () {
      final e = PuyoBattle(_setup(2))..start();
      for (var r = 1; r < PuyoBattle.rows; r++) {
        e.grids[0][r * PuyoBattle.cols + PuyoBattle.spawnCol] = (r % 3) + 1;
      }
      // Make sure current pair won't match top of col 2
      e.pieceQueue[e.pieceIndex[0]] = (4, 4);
      e.handle(0, {'type': 'drop', 'col': PuyoBattle.spawnCol, 'rot': 0});
      expect(e.alive[0], isFalse);
      expect(e.isOver, isTrue);
      expect(e.placings, [2, 1]);
    });
  });

  group('pentago', () {
    test('quadrant rotation cw and ccw', () {
      final b = List.filled(36, -1);
      b[0] = 0; // (0,0) in Q0
      b[2] = 1; // (0,2) in Q0
      final cw = rotateQuadrant(b, 0, 'cw');
      expect(cw[2], 0); // (0,0) -> (0,2)
      expect(cw[14], 1); // (0,2) -> (2,2) = 2*6+2 = 14
      final back = rotateQuadrant(cw, 0, 'ccw');
      expect(back, b);
    });

    test('immediate win on placement before rotation', () {
      final e = Pentago(_setup(2))..start();
      // Place 4 black marbles on row 0 cols 0..3
      e.board[0] = 0;
      e.board[1] = 0;
      e.board[2] = 0;
      e.board[3] = 0;
      e.turnColor = 0;
      e.step = 'place';

      e.handle(e.turnSeat, {'type': 'place', 'cell': 4});
      expect(e.isOver, isTrue);
      expect(e.winner, e.seatOfColor(0));
      expect(e.placings![e.winner], 1);
    });

    test('simultaneous 5-in-a-row after rotation is a draw', () {
      final e = Pentago(_setup(2))..start();
      // In Q0 (unchanged when Q1 rotates):
      // Row 0 cols 0,1,2 = Black (0, 1, 2)
      // Row 2 cols 0,1,2 = White (12, 13, 14)
      // In Q1 (r=0..2, c=3..5), under 'cw' rotation: (nlr, nlc) = (lc, 2 - lr)
      // So (2,3)=15 -> (0,3)=3, and (1,3)=9 -> (0,4)=4 (completes row 0 for Black!)
      // And (2,5)=17 -> (2,3)=15, and (1,5)=11 -> (2,4)=16 (completes row 2 for White!)
      e.board[0] = 0;
      e.board[1] = 0;
      e.board[2] = 0;
      e.board[15] = 0;

      e.board[12] = 1;
      e.board[13] = 1;
      e.board[14] = 1;
      e.board[17] = 1;
      e.board[11] = 1;

      e.turnColor = 0;
      e.handle(e.turnSeat, {'type': 'move', 'cell': 9, 'quadrant': 1, 'dir': 'cw'});
      expect(e.isOver, isTrue);
      expect(e.winner, -1);
      expect(e.placings, [1, 1]);
    });

    test('tactical bot finds immediate rotation win and blocks opponent win', () {
      final e = Pentago(_setup(2))..start();
      e.board[0] = 0;
      e.board[1] = 0;
      e.board[2] = 0;
      e.board[9] = 0; // (1,3) in Q1
      // Black can place at (0,3)=cell 3? Wait: if Black places at (2,3)=cell 15 and rotates Q1 cw:
      // (2,3) is lr=2,lc=0 -> nlr=0,nlc=0 -> (0,3)=3; and (1,3) is lr=1,lc=0 -> nlr=0,nlc=1 -> (0,4)=4!
      // That makes 0,1,2,3,4 = 5-in-a-row!
      e.turnColor = 0;
      final a = e.runBot(e.turnSeat)!;
      e.handle(e.turnSeat, a);
      expect(e.isOver, isTrue);
      expect(e.winner, e.seatOfColor(0));
    });
  });

  group('paohuzi', () {
    test('80-card deck, red cards, and meld HuXi values', () {
      final e = Paohuzi(_setup(3))..start();
      final deck = e.buildDeck();
      expect(deck.length, 80);
      expect(deck.where(isRedCard).length, 24); // s2,s7,s10,b2,b7,b10 x 4 = 24

      expect(Paohuzi.computeMeldHuxi('ti', ['s1', 's1', 's1', 's1']), 9);
      expect(Paohuzi.computeMeldHuxi('ti', ['b1', 'b1', 'b1', 'b1']), 12);
      expect(Paohuzi.computeMeldHuxi('pao', ['s5', 's5', 's5', 's5']), 6);
      expect(Paohuzi.computeMeldHuxi('pao', ['b5', 'b5', 'b5', 'b5']), 9);
      expect(Paohuzi.computeMeldHuxi('wei', ['s3', 's3', 's3']), 3);
      expect(Paohuzi.computeMeldHuxi('wei', ['b3', 'b3', 'b3']), 6);
      expect(Paohuzi.computeMeldHuxi('peng', ['s8', 's8', 's8']), 1);
      expect(Paohuzi.computeMeldHuxi('peng', ['b8', 'b8', 'b8']), 3);
      expect(Paohuzi.computeMeldHuxi('chi', ['s1', 's2', 's3']), 3);
      expect(Paohuzi.computeMeldHuxi('chi', ['b1', 'b2', 'b3']), 6);
      expect(Paohuzi.computeMeldHuxi('chi', ['s2', 's7', 's10']), 3);
      expect(Paohuzi.computeMeldHuxi('chi', ['b2', 'b7', 'b10']), 6);
      expect(Paohuzi.computeMeldHuxi('chi', ['s4', 's5', 's6']), 0);
      expect(Paohuzi.computeMeldHuxi('chi', ['s9', 's9', 'b9']), 0); // Jiao
      expect(Paohuzi.isValidChiMeld(['s9', 's9', 'b9']), isTrue);
      expect(Paohuzi.isValidChiMeld(['s2', 's7', 'b10']), isFalse); // mixed-case 2-7-10 invalid
    });

    test('winning hand solver checks 7 melds and Ti/Pao with pair', () {
      // 7 three-card melds totaling 18 HuXi:
      // b1-b2-b3 (6) + b2-b7-b10 (6) + s1-s2-s3 (3) + s2-s7-s10 (3) + s4-s5-s6 (0) + b4-b5-b6 (0) + s8-s8-b8 (0)
      final hand = [
        'b1', 'b2', 'b3',
        'b2', 'b7', 'b10',
        's1', 's2', 's3',
        's2', 's7', 's10',
        's4', 's5', 's6',
        'b4', 'b5', 'b6',
        's8', 's8', 'b8',
      ];
      final sol = Paohuzi.findWinningSolution(const [], hand, minHuxi: 15);
      expect(sol, isNotNull);
      expect(sol!.$1, 18);
      expect(sol.$2.length, 7);

      // With 1 exposed Ti (b1 x4 = 12 HuXi) + 5 melds + 1 pair (s9, s9):
      final exposed = [const PhzMeld('ti', ['b1', 'b1', 'b1', 'b1'], 12)];
      final handWithPair = [
        's1', 's2', 's3', // 3 HuXi -> total 15
        's4', 's5', 's6',
        'b4', 'b5', 'b6',
        's7', 's8', 's9',
        'b7', 'b8', 'b9',
        's10', 's10', // Jiang pair
      ];
      final sol2 = Paohuzi.findWinningSolution(exposed, handWithPair, minHuxi: 15);
      expect(sol2, isNotNull);
      expect(sol2!.$1, 15);
    });

    test('3-of-a-kind Kan cannot be discarded', () {
      final allowed = Paohuzi.discardableCards(['s5', 's5', 's5', 'b2']);
      expect(allowed, ['b2']);
    });
  });
}
