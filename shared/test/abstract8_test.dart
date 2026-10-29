import 'dart:math';

import 'package:aurora_shared/games/abstract8/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup({
  Map<String, dynamic> options = const {},
  int seed = 42,
}) =>
    GameSetup(
      players: 2,
      options: options,
      names: const ['Alice', 'Bob'],
      bots: const [false, false],
      hostSeat: 0,
      rng: Random(seed),
    );

void main() {
  group('ZÈRTZ (zertz) unit tests', () {
    test('board initialization, place marble & remove free outer ring', () {
      final g = ZertzGame(_setup());
      g.start();
      expect(g.cells.length, 37);
      expect(g.supply, {'W': 6, 'G': 8, 'B': 10});

      // Center cell (0,0) is not a free outer ring; outer corner (-3, 0) is a free outer ring
      final centerIdx = g.coordToIdx[(0, 0)]!;
      final cornerIdx = g.coordToIdx[(-3, 0)]!;
      final anotherOuterIdx = g.coordToIdx[(3, 0)]!;
      expect(g.isFreeVacantRing(centerIdx), isFalse);
      expect(g.isFreeVacantRing(cornerIdx), isTrue);

      // Cannot remove center ring
      expect(
        () => g.handle(0, {
          'type': 'place',
          'color': 'W',
          'placeCell': centerIdx,
          'removeCell': centerIdx,
        }),
        throwsA(isA<GameError>()),
      );

      // Valid place & remove outer ring
      g.handle(0, {
        'type': 'place',
        'color': 'W',
        'placeCell': centerIdx,
        'removeCell': cornerIdx,
      });
      expect(g.cells[centerIdx].marble, 'W');
      expect(g.cells[cornerIdx].hasRing, isFalse);
      expect(g.supply['W'], 5);
      expect(g.turn, 1);

      // Check tournament 48-ring option
      final g48 = ZertzGame(_setup(options: {'board': 48}));
      g48.start();
      expect(g48.cells.length, 48);
      expect(g48.isFreeVacantRing(anotherOuterIdx), isFalse);
    });

    test('mandatory capture & multi-jump chain', () {
      final g = ZertzGame(_setup());
      g.start();
      final c0 = g.coordToIdx[(0, 0)]!;
      final c1 = g.coordToIdx[(1, 0)]!;
      final c2 = g.coordToIdx[(2, 0)]!;
      final c3 = g.coordToIdx[(1, 1)]!;
      final c4 = g.coordToIdx[(0, 2)]!;

      // Set up a double-jump chain: c0('W') -> jumps c1('G') to c2 -> jumps c3('B') to c4
      g.cells[c0].marble = 'W';
      g.cells[c1].marble = 'G';
      g.cells[c3].marble = 'B';

      // Attempting a 'place' move when a capture exists must fail
      final freeIdx = g.coordToIdx[(-3, 0)]!;
      final emptyIdx = g.coordToIdx[(-2, 0)]!;
      expect(
        () => g.handle(0, {
          'type': 'place',
          'color': 'B',
          'placeCell': emptyIdx,
          'removeCell': freeIdx,
        }),
        throwsA(isA<GameError>()),
      );

      // First jump: c0 -> c2 over c1
      g.handle(0, {'type': 'capture', 'from': c0, 'to': c2});
      expect(g.captured[0]['G'], 1);
      expect(g.turn, 0); // Must continue jumping with the same marble at c2!
      expect(g.mustContinueFrom, c2);

      // Second jump: c2 -> c4 over c3
      g.handle(0, {'type': 'capture', 'from': c2, 'to': c4});
      expect(g.captured[0]['B'], 1);
      expect(g.mustContinueFrom, isNull);
      expect(g.turn, 1);
    });

    test('isolation bonus captures disconnected filled island & win condition', () {
      final g = ZertzGame(_setup());
      g.start();
      // Remove all rings except two connected rings (0,0) and (1,0), plus (2,0) as bridge to (3,0)
      for (final c in g.cells) {
        c.hasRing = false;
      }
      final r0 = g.coordToIdx[(0, 0)]!;
      final r1 = g.coordToIdx[(1, 0)]!;
      final r2 = g.coordToIdx[(2, 0)]!;
      final r3 = g.coordToIdx[(3, 0)]!;
      g.cells[r0].hasRing = true;
      g.cells[r1].hasRing = true;
      g.cells[r2].hasRing = true;
      g.cells[r3].hasRing = true;

      // Put 3 White marbles already on r0, and player 0 already has 2 White marbles
      g.captured[0]['W'] = 2;
      g.cells[r0].marble = 'W';

      // Player 0 places 'W' on r1 and removes r2, isolating the filled island {r0, r1}!
      g.handle(0, {
        'type': 'place',
        'color': 'W',
        'placeCell': r1,
        'removeCell': r2,
      });

      // Both r0 and r1 were isolated and completely filled -> player 0 captures 2 White marbles (total 4 W -> wins!)
      expect(g.captured[0]['W'], 4);
      expect(g.cells[r0].hasRing, isFalse);
      expect(g.cells[r1].hasRing, isFalse);
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
    });
  });

  group('Fog of War Chess (fogchess) unit tests', () {
    test('initial visibility hides opponent side and reveals own pieces + legal targets', () {
      final g = FogChessGame(_setup());
      g.start();

      final v0 = g.view(0);
      final b0 = (v0['board'] as List).map((r) => (r as List).cast<String>()).toList();
      // White (seat 0) sees rows 7, 6 (own pieces) and rows 5, 4 (pawn 1-step & 2-step + knight jumps)
      for (var c = 0; c < 8; c++) {
        expect(b0[7][c], isNot('?'));
        expect(b0[6][c], 'wP');
        expect(b0[5][c], '');
        expect(b0[4][c], '');
        // Black's ranks (rows 0..3) are completely shrouded in Fog '?'
        expect(b0[0][c], '?');
        expect(b0[1][c], '?');
        expect(b0[2][c], '?');
        expect(b0[3][c], '?');
      }

      // Spectator (-1) sees only '?' while game is in progress
      final vSpec = g.view(-1);
      final bSpec = (vSpec['board'] as List).map((r) => (r as List).cast<String>()).toList();
      expect(bSpec[7][4], '?');
      expect(bSpec[0][4], '?');
    });

    test('no check restriction and immediate win upon capturing opponent King', () {
      final g = FogChessGame(_setup());
      g.start();
      // Clear board and place White King at (7,4), White Rook at (4,4), Black King at (0,4)
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          g.board[r][c] = null;
        }
      }
      g.board[7][4] = FogPiece(0, 'K');
      g.board[4][4] = FogPiece(0, 'R');
      g.board[0][4] = FogPiece(1, 'K');
      g.board[1][3] = FogPiece(1, 'Q');

      // White can see Black's King at (0,4) along the Rook ray!
      final v0 = g.view(0);
      final b0 = (v0['board'] as List).map((r) => (r as List).cast<String>()).toList();
      expect(b0[0][4], 'bK');

      // White captures Black's King directly -> immediate win!
      g.handle(0, {
        'type': 'move',
        'from': [4, 4],
        'to': [0, 4],
      });
      expect(g.isOver, isTrue);
      expect(g.winner, 0);

      // Once game is over, full board is revealed to everyone including spectators
      final vSpecAfter = g.view(-1);
      final bSpecAfter = (vSpecAfter['board'] as List).map((r) => (r as List).cast<String>()).toList();
      expect(bSpecAfter[1][3], 'bQ');
    });
  });

  group('Stratego (stratego) unit tests', () {
    test('hidden opponent ranks, Scout long move, Miner defuses Bomb, Spy defeats Marshal, Flag capture wins', () {
      final g = StrategoGame(_setup(options: {'size': 'quick', 'setup': 'auto'}));
      g.start();

      // Verify opponent's unrevealed pieces have rank == null and code == '?' in view(0)
      final v0 = g.view(0);
      final b0 = v0['board'] as List;
      final oppCell = (b0[0] as List)[0] as Map<String, dynamic>;
      expect(oppCell['owner'], 1);
      expect(oppCell['rank'], isNull);
      expect(oppCell['code'], '?');

      // Test swapping two own pieces before first move
      g.handle(0, {
        'type': 'swap',
        'from': [6, 0],
        'to': [7, 0],
      });

      // Clear board for controlled combat scenarios
      for (var r = 0; r < g.gridSize; r++) {
        for (var c = 0; c < g.gridSize; c++) {
          g.board[r][c] = null;
        }
      }
      // Keep flags and set up combat pieces on the board
      g.board[7][7] = StrategoPiece(id: 1, owner: 0, rank: 0);
      g.board[0][7] = StrategoPiece(id: 101, owner: 1, rank: 0);
      g.board[5][0] = StrategoPiece(id: 2, owner: 0, rank: 1);
      g.board[4][0] = StrategoPiece(id: 102, owner: 1, rank: 10);
      g.board[5][1] = StrategoPiece(id: 3, owner: 0, rank: 11);
      g.board[4][1] = StrategoPiece(id: 103, owner: 1, rank: 8);
      g.board[3][3] = StrategoPiece(id: 4, owner: 0, rank: 3);
      g.board[2][3] = StrategoPiece(id: 104, owner: 1, rank: 11);
      g.board[3][0] = StrategoPiece(id: 105, owner: 1, rank: 10);
      g.board[5][7] = StrategoPiece(id: 5, owner: 0, rank: 2);

      // 1. Spy (1) attacks Marshal (10) -> Spy defeats Marshal!
      g.turn = 0;
      g.handle(0, {
        'type': 'move',
        'from': [5, 0],
        'to': [4, 0],
      });
      expect(g.board[4][0]?.owner, 0);
      expect(g.board[4][0]?.rank, 1);
      expect(g.board[4][0]?.revealed, isTrue);

      // 2. Black Colonel (8) attacks Bomb (11) -> Colonel is destroyed, Bomb stays and is revealed
      g.handle(1, {
        'type': 'move',
        'from': [4, 1],
        'to': [5, 1],
      });
      expect(g.board[5][1]?.owner, 0);
      expect(g.board[5][1]?.rank, 11);
      expect(g.board[5][1]?.revealed, isTrue);

      // 3. White Miner (3) attacks Black Bomb (11) -> Miner defuses Bomb!
      g.handle(0, {
        'type': 'move',
        'from': [3, 3],
        'to': [2, 3],
      });
      expect(g.board[2][3]?.owner, 0);
      expect(g.board[2][3]?.rank, 3);

      // 4. Black Marshal (10) attacks White Spy (1) -> Marshal wins when Marshal is attacker!
      g.handle(1, {
        'type': 'move',
        'from': [3, 0],
        'to': [4, 0],
      });
      expect(g.board[4][0]?.owner, 1);
      expect(g.board[4][0]?.rank, 10);

      // 5. White Scout (2) moves across multiple empty squares to capture Black Flag (0) at (0,7)!
      g.handle(0, {
        'type': 'move',
        'from': [5, 7],
        'to': [0, 7],
      });
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
    });
  });

  test('simulate 30 full bot games for all abstract8Games options and bot levels', () {
    final failures = runSims(abstract8Games, n: 30);
    expect(failures, 0);
  });
}
