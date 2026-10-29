import '../../src/engine.dart';

const String entropyRules = '''
# 熵增与秩序 Entropy 规则说明

## 游戏概述
《熵增与秩序》（Entropy，又名 Hyle）是由 Eric Solomon 于 1977 年设计的经典**非对称抽象策略棋类**。两名玩家分别扮演对立的宇宙力量——**混沌（Chaos）**与**秩序（Order）**：
- **混沌方（Chaos）**：从暗袋中随机抽取彩色棋子并放置到棋盘任意空格，试图制造无序、打乱对称结构。
- **秩序方（Order）**：每当混沌方放下一枚棋子后，秩序方可以将棋盘上任意一枚已有棋子沿横或纵方向滑移任意格数的连续空格（如同国际象棋的“车”），或选择跳过（Pass），力求在每一行与每一列中构筑尽可能多的**回文串（Palindrome）**得分！

## 游戏流程
1. **棋盘与彩子配置**：
   - **5×5 快速模式**：共 5 种颜色（1~5），每种颜色各 5 枚，总计 25 枚棋子。
   - **7×7 标准模式**：共 7 种颜色（1~7），每种颜色各 7 枚，总计 49 枚棋子。
2. **回合交替**：
   - **混沌阶段（Chaos）**：混沌方查看当前抽出的棋子颜色 `currentTile`，并将其放入棋盘上任意一个空格 `(r, c)`。若放完后棋盘已满（最后一枚棋子落定），本半场立即结算。
   - **秩序阶段（Order）**：秩序方可以选择棋盘上任意一枚棋子，沿同行或同列正交滑移穿过 1 个或多个连续空格停下（不可越过其他棋子），也可以选择“保持不动（Pass）”。

## 回文串计分规则（Palindrome Scoring）
- 棋盘上每一行、每一列中，**任意长度 `L >= 2` 且不含空格的连续子串**，如果正读与反读颜色完全相同（即回文串），秩序方即可获得 **`L` 分**！
- **叠加计分**：同一个长回文串内部包含的短回文串也会分别独立计分！
  - `[1, 1]`：长度 2 的回文 → **2 分**。
  - `[1, 2, 1]`：长度 3 的回文 → **3 分**。
  - `[3, 1, 1, 3]`：包含内层 `[1, 1]`（2 分）与外层 `[3, 1, 1, 3]`（4 分）→ 共 **6 分**。
  - `[2, 2, 2]`：包含两个 `[2, 2]`（2+2 分）与一个 `[2, 2, 2]`（3 分）→ 共 **7 分**。

## 赛制与胜负判定
- **半场换边公平赛（halves = 2）**：
  - 上半场：座位 0 扮演混沌，座位 1 扮演秩序，记录座位 1 的秩序得分。
  - 下半场：双方互换角色，座位 1 扮演混沌，座位 0 扮演秩序，记录座位 0 的秩序得分。
  - 两半场结束后，**扮演秩序方时得分更高者获胜**（同分则和棋）！
- **单局目标决胜（halves = 1）**：
  - 仅进行一局（座位 0 混沌，座位 1 秩序）。若秩序方最终得分达到或超过目标分（5×5 为 30 分，7×7 为 75 分）则秩序方获胜，否则混沌方获胜！
''';

class EntropyGame extends GameEngine {
  late final int size;
  late final int halves;
  late int targetScore;

  int half = 1;
  int chaosSeat = 0;
  int orderSeat = 1;
  String phase = 'chaos'; // 'chaos' | 'order'

  late List<List<int>> board;
  late List<int> bag;
  int currentTile = 0;

  /// Scores achieved by each seat when playing as Order.
  final List<int> halfScores = [0, 0];
  Map<String, dynamic>? firstHalfSummary;
  Map<String, dynamic>? lastAction;

  bool over = false;
  int? winner;
  String? winReason;

  EntropyGame(super.setup) {
    size = setup.opt<int>('size', 5);
    halves = setup.opt<int>('halves', 2);
    targetScore = setup.opt<int>('targetScore', size == 5 ? 30 : 75);
  }

  int get turn => phase == 'chaos' ? chaosSeat : orderSeat;
  int get orderScore => halfScores[orderSeat];

  bool inBounds(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;

  @override
  void start() {
    half = 1;
    halfScores[0] = 0;
    halfScores[1] = 0;
    firstHalfSummary = null;
    lastAction = null;
    over = false;
    winner = null;
    winReason = null;
    _initHalf(1);
    host.log(
      '熵增与秩序开始：${size}×$size 棋盘（${halves == 2 ? "上下半场换边赛" : "单局决胜，秩序目标 $targetScore 分"}）。',
    );
  }

  void _initHalf(int h) {
    half = h;
    chaosSeat = h == 1 ? 0 : 1;
    orderSeat = h == 1 ? 1 : 0;
    board = List.generate(size, (_) => List.filled(size, 0));
    final allTiles = <int>[
      for (var color = 1; color <= size; color++)
        for (var k = 0; k < size; k++) color,
    ];
    bag = shuffled(allTiles, rng);
    currentTile = bag.removeLast();
    phase = 'chaos';
    halfScores[orderSeat] = 0;
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

  /// Calculates palindrome points for a single row or column.
  /// Every contiguous non-empty substring `line[i..j]` of length `L >= 2`
  /// that reads the same forwards and backwards awards `L` points.
  static int scoreLine(List<int> line) {
    var pts = 0;
    final n = line.length;
    for (var i = 0; i < n; i++) {
      if (line[i] <= 0) continue;
      for (var j = i + 1; j < n; j++) {
        if (line[j] <= 0) break;
        var isPal = true;
        for (var l = i, r = j; l < r; l++, r--) {
          if (line[l] != line[r]) {
            isPal = false;
            break;
          }
        }
        if (isPal) {
          pts += (j - i + 1);
        }
      }
    }
    return pts;
  }

  int computeBoardScore([List<List<int>>? b]) {
    final grid = b ?? board;
    final n = grid.length;
    var total = 0;
    for (var r = 0; r < n; r++) {
      total += scoreLine(grid[r]);
    }
    for (var c = 0; c < n; c++) {
      final col = <int>[for (var r = 0; r < n; r++) grid[r][c]];
      total += scoreLine(col);
    }
    return total;
  }

  int scoreBoard([List<List<int>>? b]) => computeBoardScore(b);

  bool _hasEmptyCell() {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] == 0) return true;
      }
    }
    return false;
  }

  bool canSlide(int fromR, int fromC, int toR, int toC, [List<List<int>>? b]) {
    final grid = b ?? board;
    if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) return false;
    if (fromR == toR && fromC == toC) return false;
    if (fromR != toR && fromC != toC) return false;
    if (grid[fromR][fromC] <= 0) return false;

    final dr = (toR - fromR).sign;
    final dc = (toC - fromC).sign;
    var cr = fromR + dr;
    var cc = fromC + dc;
    while (true) {
      if (grid[cr][cc] != 0) return false;
      if (cr == toR && cc == toC) break;
      cr += dr;
      cc += dc;
    }
    return true;
  }

  List<(int, int)> legalSlideTargetsFrom(int fromR, int fromC, [List<List<int>>? b]) {
    final grid = b ?? board;
    if (!inBounds(fromR, fromC) || grid[fromR][fromC] <= 0) return const [];
    final targets = <(int, int)>[];
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    for (final (dr, dc) in dirs) {
      var nr = fromR + dr;
      var nc = fromC + dc;
      while (inBounds(nr, nc) && grid[nr][nc] == 0) {
        targets.add((nr, nc));
        nr += dr;
        nc += dc;
      }
    }
    return targets;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'chaos') {
      if (type != 'place') throw GameError('混沌方当前必须放置棋子');
      var r = asInt(action['r'], -1);
      var c = asInt(action['c'], -1);
      if ((r < 0 || c < 0) && action['pos'] is List && (action['pos'] as List).length >= 2) {
        final pos = action['pos'] as List;
        r = asInt(pos[0], -1);
        c = asInt(pos[1], -1);
      }
      if (!inBounds(r, c)) throw GameError('坐标超出棋盘范围');
      if (board[r][c] != 0) throw GameError('该格已有棋子');

      final placedColor = currentTile > 0 ? currentTile : 1;
      board[r][c] = placedColor;
      lastAction = {
        'type': 'place',
        'seat': seat,
        'r': r,
        'c': c,
        'color': placedColor,
        'half': half,
      };
      halfScores[orderSeat] = computeBoardScore();

      if (!_hasEmptyCell()) {
        _finishHalf();
      } else {
        currentTile = 0;
        phase = 'order';
      }
      return;
    }

    if (phase == 'order') {
      if (type == 'pass') {
        lastAction = {
          'type': 'pass',
          'seat': seat,
          'half': half,
        };
        halfScores[orderSeat] = computeBoardScore();
        _nextChaosTurnOrEndHalf();
        return;
      }

      if (type == 'slide') {
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

        if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) {
          throw GameError('滑移坐标超出棋盘范围');
        }
        if (board[fromR][fromC] <= 0) {
          throw GameError('起始格没有可滑移的棋子');
        }
        if (!canSlide(fromR, fromC, toR, toC)) {
          throw GameError('只能沿同行或同列滑移穿过连续空格');
        }

        final tile = board[fromR][fromC];
        board[fromR][fromC] = 0;
        board[toR][toC] = tile;

        lastAction = {
          'type': 'slide',
          'seat': seat,
          'fromR': fromR,
          'fromC': fromC,
          'toR': toR,
          'toC': toC,
          'color': tile,
          'half': half,
        };
        halfScores[orderSeat] = computeBoardScore();
        _nextChaosTurnOrEndHalf();
        return;
      }

      throw GameError('秩序方请选择滑移棋子或跳过');
    }
  }

  void _nextChaosTurnOrEndHalf() {
    if (bag.isEmpty || !_hasEmptyCell()) {
      _finishHalf();
    } else {
      currentTile = bag.removeLast();
      phase = 'chaos';
    }
  }

  void _finishHalf() {
    final finalHalfScore = computeBoardScore();
    halfScores[orderSeat] = finalHalfScore;
    currentTile = 0;

    if (halves == 1) {
      over = true;
      winReason = 'score';
      if (finalHalfScore >= targetScore) {
        winner = orderSeat;
        host.log('单局结束：秩序方（${name(orderSeat)}）获得 $finalHalfScore 分（目标 $targetScore 分），秩序方获胜！');
      } else {
        winner = chaosSeat;
        host.log('单局结束：秩序方（${name(orderSeat)}）获得 $finalHalfScore 分（未达 $targetScore 分），混沌方（${name(chaosSeat)}）获胜！');
      }
      return;
    }

    if (half == 1) {
      firstHalfSummary = {
        'orderSeat': orderSeat,
        'chaosSeat': chaosSeat,
        'score': finalHalfScore,
        'board': [
          for (final r in board) List<int>.of(r),
        ],
      };
      host.log('上半场结束：${name(orderSeat)} 扮演秩序方获得 $finalHalfScore 分！双方互换角色进入下半场。');
      _initHalf(2);
      return;
    }

    over = true;
    winReason = 'halves';
    final s0 = halfScores[0];
    final s1 = halfScores[1];
    if (s0 > s1) {
      winner = 0;
      host.log('下半场结束：秩序总分 ${name(0)} $s0 : $s1 ${name(1)}，${name(0)} 获胜！');
    } else if (s1 > s0) {
      winner = 1;
      host.log('下半场结束：秩序总分 ${name(0)} $s0 : $s1 ${name(1)}，${name(1)} 获胜！');
    } else {
      winner = -1;
      host.log('下半场结束：双方秩序得分均为 $s0 分，握手言和！');
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final rowScores = <int>[
      for (var r = 0; r < size; r++) scoreLine(board[r]),
    ];
    final colScores = <int>[
      for (var c = 0; c < size; c++)
        scoreLine([for (var r = 0; r < size; r++) board[r][c]]),
    ];

    // Remaining counts per color (including currentTile if not yet placed, or just in bag)
    final remainingByColor = List<int>.filled(size + 1, 0);
    for (final t in bag) {
      if (t >= 1 && t <= size) remainingByColor[t]++;
    }

    String? resultText;
    if (over) {
      if (winner == -1 || winner == null) {
        resultText = '双方平局（${halfScores[0]} : ${halfScores[1]}）！';
      } else if (winReason == 'resign') {
        resultText = '${name(winner!)} 获胜（对手认输）！';
      } else if (halves == 1) {
        resultText =
            '${name(winner!)} 获胜！（秩序得分 ${halfScores[orderSeat]} / 目标 $targetScore）';
      } else {
        resultText =
            '${name(winner!)} 获胜！（秩序得分 ${name(0)} ${halfScores[0]} : ${halfScores[1]} ${name(1)}）';
      }
    }

    return {
      'size': size,
      'halves': halves,
      'targetScore': targetScore,
      'half': half,
      'chaosSeat': chaosSeat,
      'orderSeat': orderSeat,
      'phase': phase,
      'turn': turn,
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'currentTile': currentTile,
      'bagCount': bag.length,
      'remainingByColor': remainingByColor.sublist(1),
      'currentScore': halfScores[orderSeat],
      'halfScores': List<int>.of(halfScores),
      'rowScores': rowScores,
      'colScores': colScores,
      'firstHalfSummary': firstHalfSummary,
      'lastAction': lastAction,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'result': resultText,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    if (phase == 'chaos') {
      final empties = <(int, int)>[];
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (board[r][c] == 0) empties.add((r, c));
        }
      }
      if (empties.isEmpty) return null;
      if (botLevel == 0) {
        final pick = empties[rng.nextInt(empties.length)];
        return {'type': 'place', 'r': pick.$1, 'c': pick.$2};
      }

      final tile = currentTile > 0 ? currentTile : 1;
      var bestR = empties.first.$1;
      var bestC = empties.first.$2;
      var bestCost = double.infinity;

      for (final (r, c) in empties) {
        final rowCopy = List<int>.of(board[r]);
        rowCopy[c] = tile;
        final colCopy = <int>[
          for (var rr = 0; rr < size; rr++) rr == r ? tile : board[rr][c],
        ];
        final immediateRowColPts = scoreLine(rowCopy) + scoreLine(colCopy);

        // Count how many same-color tiles are already in row r or col c
        var sameInLine = 0;
        for (var k = 0; k < size; k++) {
          if (board[r][k] == tile) sameInLine++;
          if (board[k][c] == tile) sameInLine++;
        }

        // Chaos wants to MINIMIZE immediate palindrome points and same-color clustering
        final cost = immediateRowColPts * 20.0 + sameInLine * 6.0 + rng.nextDouble() * 1.5;
        if (cost < bestCost) {
          bestCost = cost;
          bestR = r;
          bestC = c;
        }
      }
      return {'type': 'place', 'r': bestR, 'c': bestC};
    }

    // Order phase: evaluate all legal orthogonal slides vs pass
    final curScore = computeBoardScore();
    var bestGain = 0.0;
    Map<String, dynamic>? bestSlide;

    final simGrid = [for (final r in board) List<int>.of(r)];

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final tile = board[r][c];
        if (tile <= 0) continue;
        final targets = legalSlideTargetsFrom(r, c);
        for (final (tr, tc) in targets) {
          simGrid[r][c] = 0;
          simGrid[tr][tc] = tile;
          final newScore = computeBoardScore(simGrid);
          simGrid[tr][tc] = 0;
          simGrid[r][c] = tile;

          final delta = (newScore - curScore).toDouble();
          final jitter = botLevel == 0 ? (rng.nextDouble() * 4.0 - 2.0) : rng.nextDouble() * 0.2;
          if (delta + jitter > bestGain) {
            bestGain = delta + jitter;
            bestSlide = {
              'type': 'slide',
              'fromR': r,
              'fromC': c,
              'toR': tr,
              'toC': tc,
            };
          }
        }
      }
    }

    if (bestSlide != null && bestGain > 0.1) {
      return bestSlide;
    }
    return {'type': 'pass'};
  }
}
