import '../../src/engine.dart';

const String konaneRules = '''
# 夏威夷跳棋 Konane 规则说明

## 游戏概述
夏威夷跳棋（Kōnane，又称“夏威夷西洋跳棋”）是古代夏威夷皇室与贵族世代传承的纯策略跳吃棋类。游戏开始时，棋盘被黑白两色棋子**完全填满**并呈网格交错排列（`(r + c) % 2 == 0` 为黑子 `1`，`(r + c) % 2 == 1` 为白子 `2`）。

## 开局取子阶段（Opening Removal）
- **第 1 手（黑方 / 座位 0）**：黑方必须从棋盘的**中心格**或**四角格**中移除 1 枚黑子（`remove`），创造棋盘上的第一个空位。
- **第 2 手（白方 / 座位 1）**：白方必须从该空位**正交相邻（上下左右）**的格子里移除 1 枚白子，此时棋盘上出现两个相邻空位，正式进入跳吃阶段。

## 跳吃阶段（Jumping Phase）
- **强制正交跳吃**：从第 3 手（黑方）起，每回合玩家**必须**走一步合法的**正交跳吃（Orthogonal Jump Capture）**，不存在不吃子的普通移动。
- **单跳**：将己方一枚棋子沿上、下、左、右任一正交方向，越过紧邻的 1 枚敌方棋子，落入其后方紧邻的空格中，并将被越过的敌方棋子从棋盘上移除。
- **同方向直线连跳（Multi-jump）**：
  - 如果完成一次跳吃落地后，沿着**同一个正交方向（严禁中途拐弯）**前方依然呈 `敌子 -> 空格` 交替排列，该棋子可以选择在同一回合内继续沿该直线连续跳跃 2 次、3 次或更多次，一次性移除沿途所有被越过的敌方棋子！
  - 连跳并非强制到底：只要至少完成 1 次合法跳吃，玩家即可在沿途任意一个合法落点停下。

## 胜负判定（Last Player to Move Wins）
- 游戏无平局！当轮到某位玩家行动时，如果棋盘上**没有任何合法的正交跳吃步**，该玩家立即落败，**走出最后一步跳吃的玩家获胜**！
''';

class KonaneJump {
  final int fromR;
  final int fromC;
  final int toR;
  final int toC;
  final List<List<int>> captured;

  const KonaneJump({
    required this.fromR,
    required this.fromC,
    required this.toR,
    required this.toC,
    required this.captured,
  });

  int get steps => captured.length;

  Map<String, dynamic> toJson() => {
        'fromR': fromR,
        'fromC': fromC,
        'toR': toR,
        'toC': toC,
        'captured': captured,
      };
}

class KonaneGame extends GameEngine {
  late final int size;
  late List<List<int>> board;

  /// 'remove_black' -> 'remove_white' -> 'jump'
  String phase = 'remove_black';
  int turn = 0;
  int moveCount = 0;
  final List<int> captured = [0, 0];

  bool over = false;
  int? winner;
  String? winReason;
  Map<String, dynamic>? lastMove;

  KonaneGame(super.setup) {
    size = setup.opt<int>('size', 6);
  }

  static const List<(int, int)> _dirs4 = [
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
  ];

  bool inBounds(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;

  bool isCorner(int r, int c) =>
      (r == 0 || r == size - 1) && (c == 0 || c == size - 1);

  bool isCenter(int r, int c) {
    final mid1 = size ~/ 2 - 1;
    final mid2 = size ~/ 2;
    return (r == mid1 || r == mid2) && (c == mid1 || c == mid2);
  }

  @override
  void start() {
    board = List.generate(
      size,
      (r) => List.generate(size, (c) => (r + c) % 2 == 0 ? 1 : 2),
    );
    phase = 'remove_black';
    turn = 0;
    moveCount = 0;
    captured[0] = 0;
    captured[1] = 0;
    over = false;
    winner = null;
    winReason = null;
    lastMove = null;
    host.log('夏威夷跳棋开始：${size}×$size 棋盘，请黑方先从中心或角落移除 1 枚黑子！');
  }

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get canResign => !over;

  @override
  void resign(int seat) {
    if (over) throw GameError('游戏已结束');
    if (seat < 0 || seat >= 2) throw GameError('无效座位');
    over = true;
    winner = 1 - seat;
    winReason = 'resign';
    host.log('${name(seat)} 认输，${name(winner!)} 获胜！');
  }

  @override
  bool get canDraw => !over;

  @override
  void agreeDraw() {
    if (over) throw GameError('游戏已结束');
    over = true;
    winner = -1;
    winReason = 'draw';
    host.log('双方同意和棋！');
  }

  @override
  List<int>? get placings {
    if (!over) return null;
    if (winner == 0) return const [1, 2];
    if (winner == 1) return const [2, 1];
    return const [1, 1];
  }

  /// Legal cells `[r, c]` that [seat] can remove during the opening phase.
  List<List<int>> legalRemovalsFor(int seat) {
    if (seat == 0 && phase == 'remove_black') {
      final res = <List<int>>[];
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (board[r][c] == 1 && (isCorner(r, c) || isCenter(r, c))) {
            res.add([r, c]);
          }
        }
      }
      return res;
    }
    if (seat == 1 && phase == 'remove_white') {
      final res = <List<int>>[];
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (board[r][c] != 2) continue;
          var adjEmpty = false;
          for (final (dr, dc) in _dirs4) {
            final nr = r + dr, nc = c + dc;
            if (inBounds(nr, nc) && board[nr][nc] == 0) {
              adjEmpty = true;
              break;
            }
          }
          if (adjEmpty) res.add([r, c]);
        }
      }
      return res;
    }
    return const [];
  }

  /// All legal single/multi-jumps in a straight orthogonal line for [seat] on [grid].
  List<KonaneJump> legalJumpsFor(int seat, [List<List<int>>? grid]) {
    final b = grid ?? board;
    final me = seat + 1;
    final opp = 2 - seat;
    final jumps = <KonaneJump>[];

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (b[r][c] != me) continue;
        for (final (dr, dc) in _dirs4) {
          final capSoFar = <List<int>>[];
          var k = 1;
          while (true) {
            final midR = r + (2 * k - 1) * dr;
            final midC = c + (2 * k - 1) * dc;
            final landR = r + (2 * k) * dr;
            final landC = c + (2 * k) * dc;
            if (!inBounds(midR, midC) || !inBounds(landR, landC)) break;
            if (b[midR][midC] != opp || b[landR][landC] != 0) break;
            capSoFar.add([midR, midC]);
            jumps.add(
              KonaneJump(
                fromR: r,
                fromC: c,
                toR: landR,
                toC: landC,
                captured: [for (final p in capSoFar) List<int>.of(p)],
              ),
            );
            k++;
          }
        }
      }
    }
    return jumps;
  }

  /// Validates and returns the captured enemy cells if `(fromR, fromC) -> (toR, toC)`
  /// is a legal orthogonal single or multi-jump in the same straight line for [seat].
  List<List<int>>? validateJump(int seat, int fromR, int fromC, int toR, int toC, [List<List<int>>? grid]) {
    final b = grid ?? board;
    if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) return null;
    if (fromR == toR && fromC == toC) return null;
    if (fromR != toR && fromC != toC) return null; // Must be orthogonal

    final me = seat + 1;
    final opp = 2 - seat;
    if (b[fromR][fromC] != me) return null;

    final dist = (toR - fromR).abs() + (toC - fromC).abs();
    if (dist < 2 || dist % 2 != 0) return null;

    final steps = dist ~/ 2;
    final dr = (toR - fromR).sign;
    final dc = (toC - fromC).sign;

    final jumped = <List<int>>[];
    for (var k = 1; k <= steps; k++) {
      final midR = fromR + (2 * k - 1) * dr;
      final midC = fromC + (2 * k - 1) * dc;
      final landR = fromR + (2 * k) * dr;
      final landC = fromC + (2 * k) * dc;
      if (b[midR][midC] != opp || b[landR][landC] != 0) {
        return null;
      }
      jumped.add([midR, midC]);
    }
    return jumped;
  }

  int _countEmptyCells() {
    var count = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] == 0) count++;
      }
    }
    return count;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (type == 'remove') {
      if (phase != 'remove_black' && phase != 'remove_white') {
        throw GameError('开局取子阶段已结束，请进行跳吃');
      }
      var r = asInt(action['r'], -1);
      var c = asInt(action['c'], -1);
      if ((r < 0 || c < 0) && action['pos'] is List && (action['pos'] as List).length >= 2) {
        final pos = action['pos'] as List;
        r = asInt(pos[0], -1);
        c = asInt(pos[1], -1);
      }
      if (!inBounds(r, c)) throw GameError('坐标超出棋盘范围');

      final legal = legalRemovalsFor(seat);
      if (!legal.any((p) => p[0] == r && p[1] == c)) {
        if (seat == 0) {
          throw GameError('黑方开局只能从中心或四角移除一枚黑子');
        } else {
          throw GameError('白方开局只能移除与空位正交相邻的一枚白子');
        }
      }

      board[r][c] = 0;
      moveCount++;
      lastMove = {
        'type': 'remove',
        'seat': seat,
        'r': r,
        'c': c,
      };

      if (phase == 'remove_black') {
        phase = 'remove_white';
        turn = 1;
        host.log('${name(0)} 移除了 (${r + 1}, ${c + 1}) 的黑子，请白方移除相邻白子。');
      } else {
        phase = 'jump';
        turn = 0;
        host.log('${name(1)} 移除了 (${r + 1}, ${c + 1}) 的白子，进入跳吃阶段！');
        _checkGameOverAfterMove(seat);
      }
      return;
    }

    if (type == 'jump') {
      // Allow direct jump tests when board was manually set up with >= 2 empty cells
      if (phase != 'jump') {
        if (_countEmptyCells() >= 2) {
          phase = 'jump';
        } else {
          throw GameError('开局阶段请先移除棋子');
        }
      }

      var fromR = asInt(action['fromR'], -1);
      var fromC = asInt(action['fromC'], -1);
      var toR = asInt(action['toR'], -1);
      var toC = asInt(action['toC'], -1);
      if ((fromR < 0 || fromC < 0) && action['from'] is List && (action['from'] as List).length >= 2) {
        final f = action['from'] as List;
        fromR = asInt(f[0], -1);
        fromC = asInt(f[1], -1);
      }
      if ((toR < 0 || toC < 0) && action['to'] is List && (action['to'] as List).length >= 2) {
        final t = action['to'] as List;
        toR = asInt(t[0], -1);
        toC = asInt(t[1], -1);
      }

      final jumped = validateJump(seat, fromR, fromC, toR, toC);
      if (jumped == null) {
        throw GameError('非法跳吃：必须沿同一直线正交越过敌子落入空格');
      }

      final me = seat + 1;
      board[fromR][fromC] = 0;
      for (final p in jumped) {
        board[p[0]][p[1]] = 0;
      }
      board[toR][toC] = me;
      captured[seat] += jumped.length;
      moveCount++;

      lastMove = {
        'type': 'jump',
        'seat': seat,
        'fromR': fromR,
        'fromC': fromC,
        'toR': toR,
        'toC': toC,
        'captured': jumped,
      };

      if (jumped.length > 1) {
        host.log('${name(seat)} 直线连跳 ${jumped.length} 子！');
      }

      turn = 1 - seat;
      _checkGameOverAfterMove(seat);
      return;
    }

    throw GameError('无效操作类型');
  }

  void _checkGameOverAfterMove(int moverSeat) {
    final nextSeat = 1 - moverSeat;
    final nextMoves = legalJumpsFor(nextSeat);
    if (nextMoves.isEmpty) {
      over = true;
      winner = moverSeat;
      winReason = 'no_moves';
      host.log('${name(nextSeat)} 已无合法跳吃步，${name(moverSeat)} 获胜！');
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final legalRemovals = over ? const <List<int>>[] : legalRemovalsFor(turn);
    final legalJumps = (over || phase != 'jump')
        ? const <Map<String, dynamic>>[]
        : [for (final j in legalJumpsFor(turn)) j.toJson()];

    String? resultText;
    if (over) {
      if (winner == -1 || winner == null) {
        resultText = '双方和棋！';
      } else if (winReason == 'resign') {
        resultText = '${name(winner!)} 获胜（对手认输）！';
      } else {
        resultText = '${name(winner!)} 获胜（对手无子可跳）！';
      }
    }

    return {
      'size': size,
      'phase': phase,
      'turn': turn,
      'moveCount': moveCount,
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'captured': List<int>.of(captured),
      'legalRemovals': legalRemovals,
      'legalJumps': legalJumps,
      'lastMove': lastMove,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'result': resultText,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    if (phase == 'remove_black' || phase == 'remove_white') {
      final removals = legalRemovalsFor(seat);
      if (removals.isEmpty) return null;
      // Prefer center removals in medium/hard mode
      if (botLevel >= 1 && seat == 0) {
        final centers = removals.where((p) => isCenter(p[0], p[1])).toList();
        if (centers.isNotEmpty) {
          final pick = centers[rng.nextInt(centers.length)];
          return {'type': 'remove', 'r': pick[0], 'c': pick[1]};
        }
      }
      final pick = removals[rng.nextInt(removals.length)];
      return {'type': 'remove', 'r': pick[0], 'c': pick[1]};
    }

    final jumps = legalJumpsFor(seat);
    if (jumps.isEmpty) return null;
    if (botLevel == 0) {
      final pick = jumps[rng.nextInt(jumps.length)];
      return {
        'type': 'jump',
        'fromR': pick.fromR,
        'fromC': pick.fromC,
        'toR': pick.toR,
        'toC': pick.toC,
      };
    }

    final me = seat + 1;
    final oppSeat = 1 - seat;
    var bestJump = jumps.first;
    var bestScore = double.negativeInfinity;

    for (final j in jumps) {
      final sim = [for (final r in board) List<int>.of(r)];
      sim[j.fromR][j.fromC] = 0;
      for (final p in j.captured) {
        sim[p[0]][p[1]] = 0;
      }
      sim[j.toR][j.toC] = me;

      final oppMoves = legalJumpsFor(oppSeat, sim);
      if (oppMoves.isEmpty) {
        // Immediate win!
        return {
          'type': 'jump',
          'fromR': j.fromR,
          'fromC': j.fromC,
          'toR': j.toR,
          'toC': j.toC,
        };
      }
      final myMoves = legalJumpsFor(seat, sim);
      // Maximize mobility differential (my moves - 2.2 * opp moves) + multi-jump bonus
      final score = myMoves.length * 10.0 - oppMoves.length * 22.0 + j.steps * 4.0 + rng.nextDouble() * 1.5;
      if (score > bestScore) {
        bestScore = score;
        bestJump = j;
      }
    }

    return {
      'type': 'jump',
      'fromR': bestJump.fromR,
      'fromC': bestJump.fromC,
      'toR': bestJump.toR,
      'toC': bestJump.toC,
    };
  }
}
