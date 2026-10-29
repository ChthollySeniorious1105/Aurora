import '../../src/engine.dart';

/// 大炮棋 (Cannon) — David Whitcher's MSO medal-winning Town-Placement & 3-Soldier-Line Artillery wargame.
class CannonGame extends GameEngine {
  CannonGame(super.setup);

  static const List<(int, int)> kingDirs = [
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1),
  ];

  late String mode;
  late int boardSize;
  late int maxQuietMoves;
  late int maxTotalTurns;

  /// Board values:
  /// 0 = empty
  /// 1 = Player 0 Soldier (蓝军, moves UP dr = -1)
  /// 2 = Player 1 Soldier (红军, moves DOWN dr = +1)
  /// 3 = Player 0 Town (🏰 蓝方王城, on row N-1)
  /// 4 = Player 1 Town (🏰 红方王城, on row 0)
  late List<List<int>> board;

  /// 'place_town' or 'play'
  String phase = 'place_town';
  List<int?> townCol = [null, null];
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

  static int soldierOfSeat(int seat) => seat == 0 ? 1 : 2;
  static int townOfSeat(int seat) => seat == 0 ? 3 : 4;
  static int forwardDirOfSeat(int seat) => seat == 0 ? -1 : 1;
  int townRowOfSeat(int seat) => seat == 0 ? boardSize - 1 : 0;

  static bool isSoldierOf(int seat, int v) => v == soldierOfSeat(seat);
  static bool isTownOf(int seat, int v) => v == townOfSeat(seat);
  static bool isFriendlyPiece(int seat, int v) =>
      v == soldierOfSeat(seat) || v == townOfSeat(seat);
  static bool isEnemyPiece(int seat, int v) => isFriendlyPiece(1 - seat, v);

  bool inBounds(int r, int c) =>
      r >= 0 && r < boardSize && c >= 0 && c < boardSize;

  int soldierCount(int seat) {
    final s = soldierOfSeat(seat);
    var count = 0;
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (board[r][c] == s) count++;
      }
    }
    return count;
  }

  bool hasTown(int seat) {
    final t = townOfSeat(seat);
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (board[r][c] == t) return true;
      }
    }
    return false;
  }

  (int, int)? findTown(int seat) {
    final t = townOfSeat(seat);
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (board[r][c] == t) return (r, c);
      }
    }
    return null;
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    boardSize = mode == 'quick' ? 8 : 10;
    maxQuietMoves = mode == 'quick' ? 50 : 70;
    maxTotalTurns = mode == 'quick' ? 140 : 200;

    board = List.generate(boardSize, (_) => List<int>.filled(boardSize, 0));
    // Player 1 (2: 红军) on rows 1..3, cols 0, 2, 4...
    for (var r = 1; r <= 3; r++) {
      for (var c = 0; c < boardSize; c += 2) {
        board[r][c] = 2;
      }
    }
    // Player 0 (1: 蓝军) on rows N-4..N-2, cols 1, 3, 5...
    for (var r = boardSize - 4; r <= boardSize - 2; r++) {
      for (var c = 1; c < boardSize; c += 2) {
        board[r][c] = 1;
      }
    }

    phase = 'place_town';
    townCol = [null, null];
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

  /// True if (r, c) is 8-way adjacent to at least 1 enemy Soldier (or enemy piece).
  bool isAdjacentToEnemySoldier(int seat, int r, int c) {
    final enemySoldier = soldierOfSeat(1 - seat);
    for (final (dr, dc) in kingDirs) {
      final nr = r + dr;
      final nc = c + dc;
      if (inBounds(nr, nc) && board[nr][nc] == enemySoldier) {
        return true;
      }
    }
    return false;
  }

  /// Classify a 'move' action from (r1, c1) to (r2, c2) for [seat].
  /// Returns `'step'`, `'capture'`, `'retreat'`, `'cannon_slide'`, or `null` if illegal.
  String? classifyMove(int seat, int r1, int c1, int r2, int c2) {
    if (!inBounds(r1, c1) || !inBounds(r2, c2)) return null;
    if (r1 == r2 && c1 == c2) return null;
    final mySoldier = soldierOfSeat(seat);
    if (board[r1][c1] != mySoldier) return null;

    final fDir = forwardDirOfSeat(seat);
    final dr = r2 - r1;
    final dc = c2 - c1;
    final dest = board[r2][c2];

    // 1. Forward / diagonally forward 1-step to empty square
    if (dr == fDir && dc.abs() <= 1 && dest == 0) {
      return 'step';
    }

    // 2. Capture enemy Soldier or Town 1 space forward, diagonally forward, or sideways
    if ((dr == fDir || dr == 0) && dc.abs() <= 1 && isEnemyPiece(seat, dest)) {
      return 'capture';
    }

    // 3. Tactical Retreat: 2 spaces backward or diagonally backward if adjacent to enemy Soldier
    if (dr == -2 * fDir &&
        (dc == -2 || dc == 0 || dc == 2) &&
        dest == 0 &&
        isAdjacentToEnemySoldier(seat, r1, c1)) {
      final midR = (r1 + r2) ~/ 2;
      final midC = (c1 + c2) ~/ 2;
      if (board[midR][midC] == 0) {
        return 'retreat';
      }
    }

    // 4. 3-Soldier Cannon Slide: move rear-most soldier 3 steps along a 3-soldier line to empty square
    if (dest == 0) {
      for (final (udr, udc) in kingDirs) {
        if (dr == 3 * udr && dc == 3 * udc) {
          final m1r = r1 + udr;
          final m1c = c1 + udc;
          final m2r = r1 + 2 * udr;
          final m2c = c1 + 2 * udc;
          if (board[m1r][m1c] == mySoldier && board[m2r][m2c] == mySoldier) {
            return 'cannon_slide';
          }
        }
      }
    }

    return null;
  }

  /// Check if [seat] can fire a 3-Soldier Cannon from (r1, c1) at target (r2, c2).
  /// Accepts (r1, c1) as the muzzle Soldier (distance 2 or 3 to target) OR as the
  /// rear/middle Soldier of the same 3-Soldier Cannon pointing at (r2, c2).
  /// Returns `(muzzleR, muzzleC, dist)` if valid, or `null` if illegal.
  (int, int, int)? validateShoot(int seat, int r1, int c1, int r2, int c2) {
    if (!inBounds(r1, c1) || !inBounds(r2, c2)) return null;
    final mySoldier = soldierOfSeat(seat);
    if (board[r1][c1] != mySoldier) return null;
    if (!isEnemyPiece(seat, board[r2][c2])) return null;

    for (final (dr, dc) in kingDirs) {
      // Case A: (r1, c1) is the muzzle (front-most Soldier of the 3-Soldier Cannon)
      final b1r = r1 - dr;
      final b1c = c1 - dc;
      final b2r = r1 - 2 * dr;
      final b2c = c1 - 2 * dc;
      final front1r = r1 + dr;
      final front1c = c1 + dc;
      if (inBounds(b1r, b1c) &&
          inBounds(b2r, b2c) &&
          inBounds(front1r, front1c) &&
          board[b1r][b1c] == mySoldier &&
          board[b2r][b2c] == mySoldier &&
          board[front1r][front1c] == 0) {
        for (final dist in const [2, 3]) {
          if (r1 + dist * dr == r2 && c1 + dist * dc == c2) {
            return (r1, c1, dist);
          }
        }
      }

      // Case B: (r1, c1) is the rear-most Soldier of the 3-Soldier Cannon
      final m1r = r1 + dr;
      final m1c = c1 + dc;
      final muzR = r1 + 2 * dr;
      final muzC = c1 + 2 * dc;
      final gapR = r1 + 3 * dr;
      final gapC = c1 + 3 * dc;
      if (inBounds(m1r, m1c) &&
          inBounds(muzR, muzC) &&
          inBounds(gapR, gapC) &&
          board[m1r][m1c] == mySoldier &&
          board[muzR][muzC] == mySoldier &&
          board[gapR][gapC] == 0) {
        for (final dist in const [2, 3]) {
          if (muzR + dist * dr == r2 && muzC + dist * dc == c2) {
            return (muzR, muzC, dist);
          }
        }
      }
    }
    return null;
  }

  /// Enumerate all legal actions for [seat] in the current state.
  List<Map<String, dynamic>> legalActionsFor(int seat) {
    if (_over) return const [];
    if (phase == 'place_town') {
      if (seat != turn) return const [];
      return [
        for (var c = 1; c <= boardSize - 2; c++)
          {'type': 'place_town', 'c': c},
      ];
    }

    final mySoldier = soldierOfSeat(seat);
    final fDir = forwardDirOfSeat(seat);
    final actions = <Map<String, dynamic>>[];

    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (board[r][c] != mySoldier) continue;

        // 1. Step & Capture (forward / diagonally forward / sideways)
        for (final dr in [fDir, 0]) {
          for (final dc in const [-1, 0, 1]) {
            if (dr == 0 && dc == 0) continue;
            final nr = r + dr;
            final nc = c + dc;
            if (!inBounds(nr, nc)) continue;
            final kind = classifyMove(seat, r, c, nr, nc);
            if (kind != null) {
              actions.add({
                'type': 'move',
                'fromR': r,
                'fromC': c,
                'toR': nr,
                'toC': nc,
                'kind': kind,
              });
            }
          }
        }

        // 2. Tactical Retreat
        if (isAdjacentToEnemySoldier(seat, r, c)) {
          final nr = r - 2 * fDir;
          for (final dc in const [-2, 0, 2]) {
            final nc = c + dc;
            if (!inBounds(nr, nc)) continue;
            if (classifyMove(seat, r, c, nr, nc) == 'retreat') {
              actions.add({
                'type': 'move',
                'fromR': r,
                'fromC': c,
                'toR': nr,
                'toC': nc,
                'kind': 'retreat',
              });
            }
          }
        }

        // 3. Cannon Slide & Cannon Shoot along all 8 directions
        for (final (dr, dc) in kingDirs) {
          // Slide: (r, c) is rear soldier
          final sr = r + 3 * dr;
          final sc = c + 3 * dc;
          if (inBounds(sr, sc) &&
              classifyMove(seat, r, c, sr, sc) == 'cannon_slide') {
            actions.add({
              'type': 'move',
              'fromR': r,
              'fromC': c,
              'toR': sr,
              'toC': sc,
              'kind': 'cannon_slide',
            });
          }

          // Shoot: (r, c) is muzzle soldier
          final b1r = r - dr;
          final b1c = c - dc;
          final b2r = r - 2 * dr;
          final b2c = c - 2 * dc;
          final gapR = r + dr;
          final gapC = c + dc;
          if (inBounds(b1r, b1c) &&
              inBounds(b2r, b2c) &&
              inBounds(gapR, gapC) &&
              board[b1r][b1c] == mySoldier &&
              board[b2r][b2c] == mySoldier &&
              board[gapR][gapC] == 0) {
            for (final dist in const [2, 3]) {
              final tr = r + dist * dr;
              final tc = c + dist * dc;
              if (inBounds(tr, tc) && isEnemyPiece(seat, board[tr][tc])) {
                actions.add({
                  'type': 'shoot',
                  'fromR': r,
                  'fromC': c,
                  'toR': tr,
                  'toC': tc,
                  'dist': dist,
                });
              }
            }
          }
        }
      }
    }
    return actions;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);

    if (phase == 'place_town') {
      if (type != 'place_town') {
        throw GameError('当前阶段请先部署己方王城（place_town）');
      }
      final c = asInt(action['c'], -1);
      if (c < 1 || c > boardSize - 2) {
        throw GameError('王城只能部署在底线非角落列（1..${boardSize - 2}）');
      }
      final r = townRowOfSeat(seat);
      if (board[r][c] != 0) {
        throw GameError('该位置不为空');
      }
      board[r][c] = townOfSeat(seat);
      townCol[seat] = c;
      lastMove = {
        'type': 'place_town',
        'seat': seat,
        'r': r,
        'c': c,
      };
      if (seat == 0) {
        turn = 1;
      } else {
        phase = 'play';
        turn = 0;
      }
      return;
    }

    // phase == 'play'
    final fromR = asInt(action['fromR'], -1);
    final fromC = asInt(action['fromC'], -1);
    final toR = asInt(action['toR'], -1);
    final toC = asInt(action['toC'], -1);

    if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) {
      throw GameError('坐标超出棋盘范围');
    }

    final mySoldier = soldierOfSeat(seat);
    final oppSeat = 1 - seat;
    final oppTown = townOfSeat(oppSeat);

    if (type == 'move') {
      final kind = classifyMove(seat, fromR, fromC, toR, toC);
      if (kind == null) {
        throw GameError('非法移动：不符合士兵步进、近战吃子、战术撤退或三连火炮滑行规则');
      }
      final targetVal = board[toR][toC];
      final capturedTown = targetVal == oppTown;
      final capturedPiece = isEnemyPiece(seat, targetVal);

      board[fromR][fromC] = 0;
      board[toR][toC] = mySoldier;

      if (capturedPiece) {
        captured[seat]++;
        quietMoves = 0;
      } else {
        quietMoves++;
      }

      lastMove = {
        'type': 'move',
        'kind': kind,
        'seat': seat,
        'fromR': fromR,
        'fromC': fromC,
        'toR': toR,
        'toC': toC,
        'captured': targetVal,
      };

      turnCount++;

      if (capturedTown || !hasTown(oppSeat)) {
        _over = true;
        winner = seat;
        winReason = '${name(seat)} 攻陷了敌方王城，大获全胜！';
        host.log(winReason!);
        return;
      }
    } else if (type == 'shoot') {
      final shot = validateShoot(seat, fromR, fromC, toR, toC);
      if (shot == null) {
        throw GameError('非法炮击：必须由三连火炮隔 1 格空位轰击距离 2 或 3 格的敌方目标');
      }
      final (muzR, muzC, dist) = shot;
      final targetVal = board[toR][toC];
      final destroyedTown = targetVal == oppTown;

      board[toR][toC] = 0;
      captured[seat]++;
      quietMoves = 0;

      lastMove = {
        'type': 'shoot',
        'seat': seat,
        'fromR': muzR,
        'fromC': muzC,
        'toR': toR,
        'toC': toC,
        'dist': dist,
        'captured': targetVal,
      };

      turnCount++;

      if (destroyedTown || !hasTown(oppSeat)) {
        _over = true;
        winner = seat;
        winReason = '${name(seat)} 的三连火炮远程轰毁了敌方王城，大获全胜！';
        host.log(winReason!);
        return;
      }
    } else {
      throw GameError('未知操作类型：$type');
    }

    // Check if enemy has any soldiers or legal moves left
    if (soldierCount(oppSeat) == 0) {
      _over = true;
      winner = seat;
      winReason = '${name(seat)} 歼灭了全部敌方士兵，取得胜利！';
      host.log(winReason!);
      return;
    }

    final oppActions = legalActionsFor(oppSeat);
    if (oppActions.isEmpty) {
      _over = true;
      winner = seat;
      winReason = '${name(oppSeat)} 已无合法行动，${name(seat)} 获胜！';
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
    final s0 = soldierCount(0);
    final s1 = soldierCount(1);
    if (s0 != s1) {
      winner = s0 > s1 ? 0 : 1;
      winReason = '对局结束：${name(winner!)} 剩余士兵更多（$s0 : $s1）获胜！';
    } else {
      winner = -1;
      winReason = '对局结束：双方剩余兵力相同（$s0 : $s1），平局！';
    }
    host.log(winReason!);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'place_town') {
      // Prefer central columns for Town placement
      final mid = boardSize ~/ 2;
      final candidates = [mid - 1, mid, if (boardSize >= 8) mid - 2, if (boardSize >= 8) mid + 1]
          .where((c) => c >= 1 && c <= boardSize - 2)
          .toList();
      final pick = candidates[rng.nextInt(candidates.length)];
      return {'type': 'place_town', 'c': pick};
    }

    final actions = legalActionsFor(seat);
    if (actions.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.35) {
      final pick = actions[rng.nextInt(actions.length)];
      return {
        'type': pick['type'],
        'fromR': pick['fromR'],
        'fromC': pick['fromC'],
        'toR': pick['toR'],
        'toC': pick['toC'],
      };
    }

    final oppSeat = 1 - seat;
    final oppTownPos = findTown(oppSeat);
    final oppTownVal = townOfSeat(oppSeat);
    final mySoldier = soldierOfSeat(seat);
    final fDir = forwardDirOfSeat(seat);

    Map<String, dynamic>? bestAction;
    var bestScore = double.negativeInfinity;

    for (final a in actions) {
      final type = a['type'] as String;
      final fr = a['fromR'] as int;
      final fc = a['fromC'] as int;
      final tr = a['toR'] as int;
      final tc = a['toC'] as int;
      final targetVal = board[tr][tc];

      // Immediate win: capture or shoot enemy Town!
      if (targetVal == oppTownVal) {
        return {
          'type': type,
          'fromR': fr,
          'fromC': fc,
          'toR': tr,
          'toC': tc,
        };
      }

      var score = 0.0;
      if (type == 'shoot') {
        // Artillery fire destroys an enemy soldier without exposing our piece
        score += 95.0;
        if (oppTownPos != null) {
          final d = (tr - oppTownPos.$1).abs() + (tc - oppTownPos.$2).abs();
          score += (boardSize * 2 - d) * 1.5;
        }
      } else {
        final kind = a['kind'] as String? ?? 'step';
        if (kind == 'capture') {
          score += 65.0;
        } else if (kind == 'cannon_slide') {
          score += 18.0;
        } else if (kind == 'retreat') {
          score += 6.0;
        } else {
          score += 8.0;
        }

        // Bonus for advancing toward enemy Town
        if (oppTownPos != null) {
          final oldDist = (fr - oppTownPos.$1).abs() + (fc - oppTownPos.$2).abs();
          final newDist = (tr - oppTownPos.$1).abs() + (tc - oppTownPos.$2).abs();
          score += (oldDist - newDist) * 4.5;
        } else {
          score += (tr - fr) * fDir * 3.0;
        }

        // Bonus if landing at (tr, tc) aligns with friendly soldiers to form/maintain cannons
        var alignedFriends = 0;
        for (final (dr, dc) in kingDirs) {
          final nr = tr + dr;
          final nc = tc + dc;
          if (inBounds(nr, nc) && (nr != fr || nc != fc) && board[nr][nc] == mySoldier) {
            alignedFriends++;
          }
        }
        score += alignedFriends * 2.2;
      }

      score += rng.nextDouble() * 2.0;
      if (score > bestScore) {
        bestScore = score;
        bestAction = a;
      }
    }

    final chosen = bestAction ?? actions.first;
    return {
      'type': chosen['type'],
      'fromR': chosen['fromR'],
      'fromC': chosen['fromC'],
      'toR': chosen['toR'],
      'toC': chosen['toC'],
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final actions = !_over ? legalActionsFor(turn) : const <Map<String, dynamic>>[];
    return {
      'mode': mode,
      'boardSize': boardSize,
      'phase': phase,
      'turn': turn,
      'turnCount': turnCount,
      'quietMoves': quietMoves,
      'maxQuietMoves': maxQuietMoves,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'townCol': List<int?>.of(townCol),
      'captured': List<int>.of(captured),
      'soldiers': [soldierCount(0), soldierCount(1)],
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'legalActions': actions,
      'lastMove': lastMove,
    };
  }
}
