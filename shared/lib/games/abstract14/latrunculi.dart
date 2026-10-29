import '../../src/engine.dart';

/// 古罗马夹击棋 (Latrunculi / Ludus Latrunculorum) — Classic Roman Rook-Slide Custodial Capture & Dux Commander game.
class LatrunculiGame extends GameEngine {
  LatrunculiGame(super.setup);

  static const List<(int, int)> orthoDirs = [
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
  ];

  static const List<((int, int), (int, int), (int, int))> cornerTraps = [
    ((0, 0), (0, 1), (1, 0)),
    ((0, 7), (0, 6), (1, 7)),
    ((7, 0), (6, 0), (7, 1)),
    ((7, 7), (6, 7), (7, 6)),
  ];

  late String mode;
  late int targetCaptures;
  late int maxQuietMoves;
  late int maxTotalTurns;

  /// 8x8 board:
  /// 0 = empty
  /// 1 = Player 0 Legionary (⚔️ 白方罗马军团兵)
  /// 2 = Player 1 Legionary (⚔️ 黑方迦太基军团兵)
  /// 3 = Player 0 Dux (🦅 白方统帅)
  /// 4 = Player 1 Dux (🦅 黑方统帅)
  late List<List<int>> board;
  List<int> captured = [0, 0];

  int turn = 0;
  int turnCount = 0;
  int quietMoves = 0;
  bool _over = false;
  int? winner; // 0, 1, or -1 for draw
  String? winReason;
  Map<String, dynamic>? lastMove;

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get canResign => true;

  @override
  bool get canDraw => true;

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (winner == null || winner == -1) return const [1, 1];
    return rankWinners(2, [winner!]);
  }

  static bool inBounds(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  static int legionaryOfSeat(int seat) => seat == 0 ? 1 : 2;
  static int duxOfSeat(int seat) => seat == 0 ? 3 : 4;

  static bool isFriendlyPiece(int seat, int v) =>
      v == legionaryOfSeat(seat) || v == duxOfSeat(seat);
  static bool isEnemyPiece(int seat, int v) => isFriendlyPiece(1 - seat, v);
  static bool isDuxPiece(int v) => v == 3 || v == 4;

  int legionaryCount(int seat) {
    final leg = legionaryOfSeat(seat);
    var count = 0;
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if (board[r][c] == leg) count++;
      }
    }
    return count;
  }

  (int, int)? findDux(int seat) {
    final d = duxOfSeat(seat);
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if (board[r][c] == d) return (r, c);
      }
    }
    return null;
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    targetCaptures = mode == 'quick' ? 5 : 7;
    maxQuietMoves = mode == 'quick' ? 40 : 60;
    maxTotalTurns = mode == 'quick' ? 120 : 180;

    board = List.generate(8, (_) => List<int>.filled(8, 0));
    for (var c = 0; c < 8; c++) {
      board[0][c] = 2; // Player 1 Legionaries on row 0
      board[7][c] = 1; // Player 0 Legionaries on row 7
    }
    board[1][3] = 4; // Player 1 Dux at (1, 3)
    board[6][4] = 3; // Player 0 Dux at (6, 4)

    captured = [0, 0];
    turn = 0;
    turnCount = 0;
    quietMoves = 0;
    _over = false;
    winner = null;
    winReason = null;
    lastMove = null;
  }

  @override
  void resign(int seat) {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = 1 - seat;
    winReason = '${name(seat)} 认输，${name(winner!)} 获胜！';
    host.log(winReason!);
  }

  @override
  void agreeDraw() {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = -1;
    winReason = '双方同意和棋';
    host.log(winReason!);
  }

  /// Classify a move from `(r1, c1)` to `(r2, c2)` for [seat].
  /// Returns `'slide'`, `'dux_jump'`, or `null` if illegal.
  String? classifyMove(int seat, int r1, int c1, int r2, int c2) {
    if (!inBounds(r1, c1) || !inBounds(r2, c2)) return null;
    if (r1 == r2 && c1 == c2) return null;
    final p = board[r1][c1];
    if (!isFriendlyPiece(seat, p)) return null;
    if (board[r2][c2] != 0) return null;
    if (r1 != r2 && c1 != c2) return null;

    final dr = (r2 - r1).sign;
    final dc = (c2 - c1).sign;
    final dist = (r2 - r1).abs() + (c2 - c1).abs();

    // Check unobstructed orthogonal Rook slide
    var clear = true;
    for (var step = 1; step < dist; step++) {
      if (board[r1 + step * dr][c1 + step * dc] != 0) {
        clear = false;
        break;
      }
    }
    if (clear) return 'slide';

    // Dux vault/jump over an orthogonally adjacent piece onto empty square at distance 2
    if (isDuxPiece(p) && dist == 2 && board[r1 + dr][c1 + dc] != 0) {
      return 'dux_jump';
    }

    return null;
  }

  /// Return all legal destination squares `(toR, toC, kind)` from `(fromR, fromC)` for [seat].
  List<(int, int, String)> legalTargetsFrom(int seat, int fromR, int fromC) {
    if (!inBounds(fromR, fromC)) return const [];
    final p = board[fromR][fromC];
    if (!isFriendlyPiece(seat, p)) return const [];

    final targets = <(int, int, String)>[];
    for (final (dr, dc) in orthoDirs) {
      for (var step = 1; step < 8; step++) {
        final nr = fromR + step * dr;
        final nc = fromC + step * dc;
        if (!inBounds(nr, nc)) break;
        if (board[nr][nc] == 0) {
          targets.add((nr, nc, 'slide'));
        } else {
          // Blocked by a piece at step: if step == 1 and moving piece is Dux, check vault to step == 2
          if (step == 1 && isDuxPiece(p)) {
            final jr = fromR + 2 * dr;
            final jc = fromC + 2 * dc;
            if (inBounds(jr, jc) && board[jr][jc] == 0) {
              targets.add((jr, jc, 'dux_jump'));
            }
          }
          break;
        }
      }
    }
    return targets;
  }

  List<Map<String, dynamic>> legalMovesFor(int seat) {
    if (_over) return const [];
    final moves = <Map<String, dynamic>>[];
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if (!isFriendlyPiece(seat, board[r][c])) continue;
        for (final (tr, tc, kind) in legalTargetsFrom(seat, r, c)) {
          moves.add({
            'type': 'move',
            'fromR': r,
            'fromC': c,
            'toR': tr,
            'toC': tc,
            'kind': kind,
          });
        }
      }
    }
    return moves;
  }

  /// Compute which enemy Legionaries would be captured if [seat] moves a piece to `(r2, c2)`.
  /// Assumes the moving piece is already placed at `board[r2][c2]`.
  List<(int, int)> findCustodialCapturesAt(int seat, int r2, int c2) {
    final enemyLeg = legionaryOfSeat(1 - seat);
    final caps = <(int, int)>{};

    // 1. Orthogonal 2-side sandwich capture
    for (final (dr, dc) in orthoDirs) {
      final nr = r2 + dr;
      final nc = c2 + dc;
      final br = r2 + 2 * dr;
      final bc = c2 + 2 * dc;
      if (inBounds(nr, nc) &&
          inBounds(br, bc) &&
          board[nr][nc] == enemyLeg &&
          isFriendlyPiece(seat, board[br][bc])) {
        caps.add((nr, nc));
      }
    }

    // 2. Corner trap capture
    for (final (corner, n1, n2) in cornerTraps) {
      if ((r2 == n1.$1 && c2 == n1.$2) || (r2 == n2.$1 && c2 == n2.$2)) {
        final (cr, cc) = corner;
        if (board[cr][cc] == enemyLeg &&
            isFriendlyPiece(seat, board[n1.$1][n1.$2]) &&
            isFriendlyPiece(seat, board[n2.$1][n2.$2])) {
          caps.add((cr, cc));
        }
      }
    }

    return caps.toList();
  }

  /// True if the Dux of [duxSeat] is surrounded on all orthogonal sides (by at least one enemy piece)
  /// or has 0 legal moves while orthogonally hemmed in.
  bool isDuxSurrounded(int duxSeat) {
    final pos = findDux(duxSeat);
    if (pos == null) return true;
    final (dr0, dc0) = pos;
    final attackerSeat = 1 - duxSeat;

    var allOrthoOccupied = true;
    var attackerOrthoCount = 0;
    for (final (dr, dc) in orthoDirs) {
      final nr = dr0 + dr;
      final nc = dc0 + dc;
      if (!inBounds(nr, nc)) continue;
      final v = board[nr][nc];
      if (v == 0) {
        allOrthoOccupied = false;
        break;
      }
      if (isFriendlyPiece(attackerSeat, v)) {
        attackerOrthoCount++;
      }
    }

    if (!allOrthoOccupied || attackerOrthoCount == 0) return false;

    // If all orthogonal sides are occupied by the attacker (or if Dux also has 0 legal moves), Dux is surrounded!
    var allAttacker = true;
    for (final (dr, dc) in orthoDirs) {
      final nr = dr0 + dr;
      final nc = dc0 + dc;
      if (inBounds(nr, nc) && !isFriendlyPiece(attackerSeat, board[nr][nc])) {
        allAttacker = false;
        break;
      }
    }
    if (allAttacker) return true;

    return legalTargetsFrom(duxSeat, dr0, dc0).isEmpty;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你走子');

    final type = asStr(action['type']);
    if (type != 'move') {
      throw GameError('未知操作类型：$type');
    }

    final fromR = asInt(action['fromR'], -1);
    final fromC = asInt(action['fromC'], -1);
    final toR = asInt(action['toR'], -1);
    final toC = asInt(action['toC'], -1);

    final kind = classifyMove(seat, fromR, fromC, toR, toC);
    if (kind == null) {
      throw GameError('非法移动：必须沿正交方向无遮挡滑行，或使用统帅跳过相邻一子落入空位');
    }

    final movingPiece = board[fromR][fromC];
    board[fromR][fromC] = 0;
    board[toR][toC] = movingPiece;

    final caps = findCustodialCapturesAt(seat, toR, toC);
    for (final (cr, cc) in caps) {
      board[cr][cc] = 0;
    }

    if (caps.isNotEmpty) {
      captured[seat] += caps.length;
      quietMoves = 0;
    } else {
      quietMoves++;
    }

    turnCount++;
    lastMove = {
      'type': 'move',
      'kind': kind,
      'seat': seat,
      'piece': movingPiece,
      'fromR': fromR,
      'fromC': fromC,
      'toR': toR,
      'toC': toC,
      'capturedCells': [
        for (final (cr, cc) in caps) [cr, cc],
      ],
    };

    final oppSeat = 1 - seat;

    // 1. Check Dux surrounded win condition
    if (isDuxSurrounded(oppSeat)) {
      _over = true;
      winner = seat;
      winReason = '${name(seat)} 四面合围困住了敌方统帅（Dux），大获全胜！';
      host.log(winReason!);
      return;
    }

    // 2. Check Legionary capture threshold win condition
    if (captured[seat] >= targetCaptures || legionaryCount(oppSeat) <= (8 - targetCaptures)) {
      _over = true;
      winner = seat;
      winReason = '${name(seat)} 已夹吃俘获 ${captured[seat]} 名敌方军团兵，取得胜利！';
      host.log(winReason!);
      return;
    }

    // 3. Check if opponent has any legal moves
    if (legalMovesFor(oppSeat).isEmpty) {
      _over = true;
      winner = seat;
      winReason = '${name(oppSeat)} 已无合法走步，${name(seat)} 获胜！';
      host.log(winReason!);
      return;
    }

    if (quietMoves >= maxQuietMoves || turnCount >= maxTotalTurns) {
      _adjudicate();
      return;
    }

    turn = oppSeat;
  }

  void _adjudicate() {
    _over = true;
    final l0 = legionaryCount(0);
    final l1 = legionaryCount(1);
    if (l0 != l1) {
      winner = l0 > l1 ? 0 : 1;
      winReason = '对局结束：${name(winner!)} 剩余更多军团兵（$l0 : $l1）获胜！';
    } else if (captured[0] != captured[1]) {
      winner = captured[0] > captured[1] ? 0 : 1;
      winReason = '对局结束：${name(winner!)} 俘获更多敌兵（${captured[0]} : ${captured[1]}）获胜！';
    } else {
      winner = -1;
      winReason = '对局结束：双方剩余兵力相同（$l0 : $l1），平局！';
    }
    host.log(winReason!);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final moves = legalMovesFor(seat);
    if (moves.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.35) {
      final pick = moves[rng.nextInt(moves.length)];
      return {
        'type': 'move',
        'fromR': pick['fromR'],
        'fromC': pick['fromC'],
        'toR': pick['toR'],
        'toC': pick['toC'],
      };
    }

    final oppSeat = 1 - seat;
    final oppDuxPos = findDux(oppSeat);
    final enemyLeg = legionaryOfSeat(oppSeat);

    Map<String, dynamic>? bestMove;
    var bestScore = double.negativeInfinity;

    for (final m in moves) {
      final fr = m['fromR'] as int;
      final fc = m['fromC'] as int;
      final tr = m['toR'] as int;
      final tc = m['toC'] as int;
      final movingPiece = board[fr][fc];

      board[fr][fc] = 0;
      board[tr][tc] = movingPiece;

      final caps = findCustodialCapturesAt(seat, tr, tc);
      final savedCaps = <(int, int, int)>[];
      for (final (cr, cc) in caps) {
        savedCaps.add((cr, cc, board[cr][cc]));
        board[cr][cc] = 0;
      }

      final surroundsDux = isDuxSurrounded(oppSeat);

      // Check if landing at (tr, tc) exposes our Legionary to immediate sandwich capture next turn
      var exposedPenalty = 0.0;
      if (botLevel >= 1 && movingPiece == legionaryOfSeat(seat)) {
        for (final (dr, dc) in orthoDirs) {
          final side1R = tr + dr;
          final side1C = tc + dc;
          final side2R = tr - dr;
          final side2C = tc - dc;
          if (inBounds(side1R, side1C) &&
              inBounds(side2R, side2C) &&
              isFriendlyPiece(oppSeat, board[side1R][side1C]) &&
              board[side2R][side2C] == 0) {
            exposedPenalty += 18.0;
          }
        }
      }

      // Bonus for moving adjacent to enemy Legionaries or enemy Dux to set up sandwiches
      var setupBonus = 0.0;
      for (final (dr, dc) in orthoDirs) {
        final nr = tr + dr;
        final nc = tc + dc;
        if (!inBounds(nr, nc)) continue;
        if (board[nr][nc] == enemyLeg) {
          setupBonus += 4.5;
        }
      }
      if (oppDuxPos != null) {
        final d = (tr - oppDuxPos.$1).abs() + (tc - oppDuxPos.$2).abs();
        if (d == 1) setupBonus += 9.0;
      }

      // Restore board
      for (final (cr, cc, val) in savedCaps) {
        board[cr][cc] = val;
      }
      board[tr][tc] = 0;
      board[fr][fc] = movingPiece;

      if (surroundsDux) {
        return {
          'type': 'move',
          'fromR': fr,
          'fromC': fc,
          'toR': tr,
          'toC': tc,
        };
      }

      final score = caps.length * 75.0 +
          setupBonus -
          exposedPenalty +
          rng.nextDouble() * 2.0;
      if (score > bestScore) {
        bestScore = score;
        bestMove = m;
      }
    }

    final chosen = bestMove ?? moves.first;
    return {
      'type': 'move',
      'fromR': chosen['fromR'],
      'fromC': chosen['fromC'],
      'toR': chosen['toR'],
      'toC': chosen['toC'],
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final moves = !_over ? legalMovesFor(turn) : const <Map<String, dynamic>>[];
    return {
      'mode': mode,
      'targetCaptures': targetCaptures,
      'turn': turn,
      'turnCount': turnCount,
      'quietMoves': quietMoves,
      'maxQuietMoves': maxQuietMoves,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'captured': List<int>.of(captured),
      'legionaries': [legionaryCount(0), legionaryCount(1)],
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'legalMoves': moves,
      'lastMove': lastMove,
    };
  }
}
