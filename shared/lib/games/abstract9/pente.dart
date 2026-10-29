import '../../src/engine.dart';

const String penteRules = '''
# 夹吃五子棋 Pente 规则说明

## 游戏概述
夹吃五子棋（Pente）是由 Gary Gabrel 于 1977 年设计的经典抽象策略棋类，巧妙融合了**五子连珠**与**双子夹吃（Custodial Pair Capture）**两大核心机制。两名玩家分别执黑棋（座位 0，先手）与白棋（座位 1，后手），在网格交叉点上轮流落子。

## 核心规则
- **轮流落子**：每回合玩家将一枚己方颜色的棋子放置在棋盘任意空交叉点上。
- **双子夹吃（Custodial Pair Capture）**：
  - 当你落下一枚棋子后，如果在横、竖、斜任意 8 个方向上，恰好与已有的另一枚己方棋子将**恰好连续两枚敌方棋子**夹在中间（即形成 `己 - 敌 - 敌 - 己` 的紧邻排列），这两枚被夹住的敌方棋子会**立即从棋盘上提走移除**！
  - 每次提走一对（2 枚）敌方棋子，你的已夹吃对数 `+1`。
  - 一步落子如果同时在多个方向上形成 `己 - 敌 - 敌 - 己`，则所有方向上被夹住的敌方棋子对都会被同时提走并计入对数。
  - **严格两子**：只有恰好两枚连续敌子才会被夹吃；单枚敌子（`己 - 敌 - 己`）或三枚及以上连续敌子（`己 - 敌 - 敌 - 敌 - 己`）不会被夹吃。
  - **主动入夹安全**：主动将棋子落入敌方棋子之间（例如形成 `敌 - 己 - 己 - 敌`）是完全安全的，不会触发自杀或被自动提走；只有落子方主动完成合围时才会触发夹吃。

## 双重获胜条件
任意玩家率先达成以下两个条件之一即刻获胜：
- **五子连珠**：在横、竖、正斜、反斜任意方向上形成连续 **5 枚或以上** 的己方棋子。
- **夹吃达标**：累计夹吃提走达到目标对数的敌方棋子（标准模式为 **5 对 = 10 子**，快速模式为 **4 对 = 8 子**）。

## 房间选项
- **棋盘尺寸（size）**：支持 `13×13 标准` 与 `11×11 快速`。
- **夹吃胜目标（targetPairs）**：支持 `5 对 (10子 标准)` 与 `4 对 (8子 快速)`。
''';

class PenteGame extends GameEngine {
  late final int size;
  late final int targetPairs;

  late List<List<int>> board;
  final List<int> capturedPairs = [0, 0];
  int turn = 0;
  int moveCount = 0;
  bool over = false;
  int? winner;
  String? winReason;
  List<List<int>> winningLine = [];
  Map<String, dynamic>? lastMove;

  PenteGame(super.setup) {
    size = setup.opt<int>('size', 13);
    targetPairs = setup.opt<int>('targetPairs', 5);
  }

  static const List<(int, int)> _dirs8 = [
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1),
  ];

  static const List<(int, int)> _axes4 = [
    (0, 1),
    (1, 0),
    (1, 1),
    (1, -1),
  ];

  @override
  void start() {
    board = List.generate(size, (_) => List.filled(size, 0));
    capturedPairs[0] = 0;
    capturedPairs[1] = 0;
    turn = 0;
    moveCount = 0;
    over = false;
    winner = null;
    winReason = null;
    winningLine = [];
    lastMove = null;
    host.log('夹吃五子棋开始：${size}×$size 棋盘，达成五子连珠或夹吃 $targetPairs 对（${targetPairs * 2}子）即获胜！');
  }

  bool inBounds(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;

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

  /// Finds an unbroken line of >= 5 stones of [color] passing through (r, c), or null.
  List<List<int>>? findFiveInARowFrom(int r, int c, int color) {
    if (!inBounds(r, c) || board[r][c] != color) return null;
    for (final (dr, dc) in _axes4) {
      final line = <List<int>>[];
      var nr = r;
      var nc = c;
      while (inBounds(nr - dr, nc - dc) && board[nr - dr][nc - dc] == color) {
        nr -= dr;
        nc -= dc;
      }
      while (inBounds(nr, nc) && board[nr][nc] == color) {
        line.add([nr, nc]);
        nr += dr;
        nc += dc;
      }
      if (line.length >= 5) return line;
    }
    return null;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你落子');

    final type = asStr(action['type']);
    if (type != 'place') throw GameError('无效操作类型');

    var r = asInt(action['r'], -1);
    var c = asInt(action['c'], -1);
    if ((r < 0 || c < 0) && action['pos'] is List && (action['pos'] as List).length >= 2) {
      final pos = action['pos'] as List;
      r = asInt(pos[0], -1);
      c = asInt(pos[1], -1);
    }
    if (!inBounds(r, c)) throw GameError('坐标超出棋盘范围');
    if (board[r][c] != 0) throw GameError('该交叉点已有棋子');

    final me = seat + 1;
    final opp = 2 - seat;
    board[r][c] = me;
    moveCount++;

    final capturedCells = <List<int>>[];
    for (final (dr, dc) in _dirs8) {
      final r1 = r + dr, c1 = c + dc;
      final r2 = r + 2 * dr, c2 = c + 2 * dc;
      final r3 = r + 3 * dr, c3 = c + 3 * dc;
      if (inBounds(r3, c3) &&
          board[r1][c1] == opp &&
          board[r2][c2] == opp &&
          board[r3][c3] == me) {
        board[r1][c1] = 0;
        board[r2][c2] = 0;
        capturedPairs[seat]++;
        capturedCells.add([r1, c1]);
        capturedCells.add([r2, c2]);
      }
    }

    lastMove = {
      'seat': seat,
      'r': r,
      'c': c,
      'captured': capturedCells,
    };

    if (capturedCells.isNotEmpty) {
      final pairsJustCaptured = capturedCells.length ~/ 2;
      host.log(
        '${name(seat)} 落子 (${r + 1}, ${c + 1}) 夹吃 $pairsJustCaptured 对敌子（累计 ${capturedPairs[seat]}/$targetPairs 对）！',
      );
    }

    final fiveLine = findFiveInARowFrom(r, c, me);
    if (fiveLine != null) {
      over = true;
      winner = seat;
      winReason = 'five';
      winningLine = fiveLine;
      host.log('${name(seat)} 连成五子，获胜！');
      return;
    }

    if (capturedPairs[seat] >= targetPairs) {
      over = true;
      winner = seat;
      winReason = 'capture';
      host.log('${name(seat)} 累计夹吃 ${capturedPairs[seat]} 对棋子，获胜！');
      return;
    }

    var hasEmpty = false;
    for (var rr = 0; rr < size && !hasEmpty; rr++) {
      for (var cc = 0; cc < size; cc++) {
        if (board[rr][cc] == 0) {
          hasEmpty = true;
          break;
        }
      }
    }

    if (!hasEmpty) {
      over = true;
      winReason = 'full';
      if (capturedPairs[0] > capturedPairs[1]) {
        winner = 0;
        host.log('棋盘已满，${name(0)} 凭借更多夹吃对数获胜！');
      } else if (capturedPairs[1] > capturedPairs[0]) {
        winner = 1;
        host.log('棋盘已满，${name(1)} 凭借更多夹吃对数获胜！');
      } else {
        winner = -1;
        host.log('棋盘已满，双方和棋！');
      }
      return;
    }

    turn = 1 - seat;
  }

  @override
  Map<String, dynamic> view(int seat) {
    String? resultText;
    if (over) {
      if (winner == -1 || winner == null) {
        resultText = '双方和棋！';
      } else if (winReason == 'five') {
        resultText = '${name(winner!)} 五子连珠获胜！';
      } else if (winReason == 'capture') {
        resultText = '${name(winner!)} 夹吃 ${capturedPairs[winner!]} 对棋子获胜！';
      } else if (winReason == 'resign') {
        resultText = '${name(winner!)} 获胜（对手认输）！';
      } else {
        resultText = '${name(winner!)} 获胜！';
      }
    }

    return {
      'size': size,
      'targetPairs': targetPairs,
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'capturedPairs': List<int>.of(capturedPairs),
      'turn': turn,
      'moveCount': moveCount,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'winningLine': [
        for (final p in winningLine) List<int>.of(p),
      ],
      'lastMove': lastMove,
      'result': resultText,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    final me = seat + 1;
    final opp = 2 - seat;
    final center = size ~/ 2;

    if (moveCount == 0 && board[center][center] == 0) {
      return {'type': 'place', 'r': center, 'c': center};
    }

    final candidates = <(int, int)>[];
    final nearSet = <(int, int)>{};
    var anyStone = false;

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] != 0) {
          anyStone = true;
          for (var dr = -2; dr <= 2; dr++) {
            for (var dc = -2; dc <= 2; dc++) {
              final nr = r + dr, nc = c + dc;
              if (inBounds(nr, nc) && board[nr][nc] == 0) {
                nearSet.add((nr, nc));
              }
            }
          }
        }
      }
    }

    if (!anyStone) {
      return {'type': 'place', 'r': center, 'c': center};
    }

    if (nearSet.isNotEmpty) {
      candidates.addAll(nearSet);
    } else {
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (board[r][c] == 0) candidates.add((r, c));
        }
      }
    }

    // Easy bot occasionally picks a random nearby intersection unless an immediate win exists
    int bestR = candidates.first.$1;
    int bestC = candidates.first.$2;
    double bestScore = double.negativeInfinity;

    for (final (r, c) in candidates) {
      final score = _evaluateMove(r, c, seat, me, opp, center);
      final jitter = botLevel == 0 ? rng.nextDouble() * 450 : rng.nextDouble() * 5;
      if (score + jitter > bestScore) {
        bestScore = score + jitter;
        bestR = r;
        bestC = c;
      }
    }

    return {'type': 'place', 'r': bestR, 'c': bestC};
  }

  double _evaluateMove(int r, int c, int seat, int me, int opp, int center) {
    // 1. Check how many pairs we capture by placing at (r, c)
    var myCapPairs = 0;
    for (final (dr, dc) in _dirs8) {
      if (inBounds(r + 3 * dr, c + 3 * dc) &&
          board[r + dr][c + dc] == opp &&
          board[r + 2 * dr][c + 2 * dc] == opp &&
          board[r + 3 * dr][c + 3 * dc] == me) {
        myCapPairs++;
      }
    }
    if (capturedPairs[seat] + myCapPairs >= targetPairs) {
      return 1000000.0; // Immediate capture win
    }

    // 2. Check if placing at (r, c) forms 5-in-a-row for me
    final maxMyRun = _maxRunIfPlaced(r, c, me);
    if (maxMyRun >= 5) {
      return 1000000.0; // Immediate 5-in-a-row win
    }

    // 3. Check if opponent would win immediately if they played at (r, c)
    var oppCapPairs = 0;
    for (final (dr, dc) in _dirs8) {
      if (inBounds(r + 3 * dr, c + 3 * dc) &&
          board[r + dr][c + dc] == me &&
          board[r + 2 * dr][c + 2 * dc] == me &&
          board[r + 3 * dr][c + 3 * dc] == opp) {
        oppCapPairs++;
      }
    }
    if (capturedPairs[1 - seat] + oppCapPairs >= targetPairs) {
      return 500000.0; // Must block opponent capture win
    }
    final maxOppRun = _maxRunIfPlaced(r, c, opp);
    if (maxOppRun >= 5) {
      return 500000.0; // Must block opponent 5-in-a-row win
    }

    var score = 0.0;
    // Reward capturing pairs
    score += myCapPairs * (3500.0 + capturedPairs[seat] * 1200.0);
    // Reward blocking opponent pair capture
    score += oppCapPairs * (2400.0 + capturedPairs[1 - seat] * 900.0);

    // Line potential for me and opponent
    score += _linePotential(r, c, me) * 1.25;
    score += _linePotential(r, c, opp) * 1.1;

    // Penalize stepping into an exposed pair vulnerability: opp - me - me - empty
    for (final (dr, dc) in _dirs8) {
      if (inBounds(r + 2 * dr, c + 2 * dc) &&
          inBounds(r - dr, c - dc) &&
          board[r + dr][c + dc] == me) {
        final a = board[r - dr][c - dc];
        final b = board[r + 2 * dr][c + 2 * dc];
        if ((a == opp && b == 0) || (a == 0 && b == opp)) {
          score -= 900.0;
        }
      }
    }

    // Slight preference for center
    final distCenter = (r - center).abs() + (c - center).abs();
    score += (size - distCenter) * 4.0;
    return score;
  }

  int _maxRunIfPlaced(int r, int c, int color) {
    var best = 1;
    for (final (dr, dc) in _axes4) {
      var count = 1;
      var nr = r + dr, nc = c + dc;
      while (inBounds(nr, nc) && board[nr][nc] == color) {
        count++;
        nr += dr;
        nc += dc;
      }
      nr = r - dr;
      nc = c - dc;
      while (inBounds(nr, nc) && board[nr][nc] == color) {
        count++;
        nr -= dr;
        nc -= dc;
      }
      if (count > best) best = count;
    }
    return best;
  }

  double _linePotential(int r, int c, int color) {
    var total = 0.0;
    for (final (dr, dc) in _axes4) {
      var count = 1;
      var openEnds = 0;

      var nr = r + dr, nc = c + dc;
      while (inBounds(nr, nc) && board[nr][nc] == color) {
        count++;
        nr += dr;
        nc += dc;
      }
      if (inBounds(nr, nc) && board[nr][nc] == 0) openEnds++;

      nr = r - dr;
      nc = c - dc;
      while (inBounds(nr, nc) && board[nr][nc] == color) {
        count++;
        nr -= dr;
        nc -= dc;
      }
      if (inBounds(nr, nc) && board[nr][nc] == 0) openEnds++;

      if (count >= 4) {
        if (openEnds == 2) {
          total += 18000;
        } else if (openEnds == 1) {
          total += 5500;
        }
      } else if (count == 3) {
        if (openEnds == 2) {
          total += 2200;
        } else if (openEnds == 1) {
          total += 350;
        }
      } else if (count == 2) {
        if (openEnds == 2) {
          total += 260;
        } else if (openEnds == 1) {
          total += 50;
        }
      }
    }
    return total;
  }
}
