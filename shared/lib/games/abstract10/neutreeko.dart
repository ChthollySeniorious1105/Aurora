import '../../src/engine.dart';

const String neutreekoRules = '''
# 滑冰三连棋 Neutreeko 规则说明

## 游戏概述
滑冰三连棋（Neutreeko）是由挪威数学家兼博弈设计师 Jan Kristian Haugland 于 2001 年设计的精巧抽象策略棋类。
游戏在 **5×5 棋盘**上进行，黑白双方各拥有 **3 枚棋子**。与传统三子棋不同，棋子一旦开始移动就如同在冰面上滑行，必须沿着所选方向**一滑到底**！

## 初始布局
- **黑方（座位 0，先手）**：3 枚黑子初始位于 `(0, 1)`、`(0, 3)` 与 `(3, 2)`。
- **白方（座位 1，后手）**：3 枚白子初始位于 `(4, 1)`、`(4, 3)` 与 `(1, 2)`。
- 双方的初始棋子呈交错对称分布，开局即处于相互牵制与借力挡停的态势。

## 核心规则：冰面滑行（Ice-Slide）
- 每回合玩家必须选择己方的 **1 枚棋子**，向横、竖、正斜、反斜 **8 个方向之一**滑行。
- **一滑到底原则**：棋子不能在中途空位任意停下，**必须沿着所选直线方向一直滑行**，直到下一格是**棋盘边界外**或**被任意棋子（无论敌我）占据**时，才会在阻挡物前的最后一个空位停下。
- 棋子每次移动至少需要滑行 1 格；若某个方向紧邻的下一格已有棋子或已是棋盘边缘，则不能向该方向移动。
- 游戏过程中**不吃子**，棋盘上始终保持黑白各 3 枚棋子，玩家需要巧妙利用敌我棋子作为“挡板（Stopper）”来停留在理想位置。

## 获胜条件
- 任意一方率先使己方的 **3 枚棋子在横、竖或对角线方向上形成紧邻的连续三子连珠（3-in-a-row）**，即刻获胜！
- 注意：三枚棋子必须**紧密相邻**（中间不能有空格）才算获胜。
''';

class NeutreekoSlide {
  final int fromR;
  final int fromC;
  final int toR;
  final int toC;
  final int dr;
  final int dc;

  const NeutreekoSlide({
    required this.fromR,
    required this.fromC,
    required this.toR,
    required this.toC,
    required this.dr,
    required this.dc,
  });

  Map<String, dynamic> toAction() => {
        'type': 'slide',
        'from': [fromR, fromC],
        'to': [toR, toC],
        'fromR': fromR,
        'fromC': fromC,
        'toR': toR,
        'toC': toC,
      };
}

class NeutreekoGame extends GameEngine {
  static const int size = 5;

  /// 0 = empty, 1 = Black (Player 0), 2 = White (Player 1)
  late List<List<int>> board;

  int turn = 0;
  int moveCount = 0;
  bool over = false;
  int? winner;
  String? winReason;
  List<List<int>> winningLine = [];
  Map<String, dynamic>? lastMove;
  final List<String> stateHistory = [];

  NeutreekoGame(super.setup);

  static const List<(int, int)> dirs8 = [
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1),
  ];

  @override
  void start() {
    board = List.generate(size, (_) => List.filled(size, 0));
    // Player 0 (1 Black): (0, 1), (0, 3), (3, 2)
    board[0][1] = 1;
    board[0][3] = 1;
    board[3][2] = 1;
    // Player 1 (2 White): (4, 1), (4, 3), (1, 2)
    board[4][1] = 2;
    board[4][3] = 2;
    board[1][2] = 2;

    turn = 0;
    moveCount = 0;
    over = false;
    winner = null;
    winReason = null;
    winningLine = [];
    lastMove = null;
    stateHistory
      ..clear()
      ..add(_encodeBoard(board, turn));

    host.log('滑冰三连棋 Neutreeko 开始：5×5 棋盘，8 方向一滑到底，率先连成紧邻三子者获胜！');
  }

  static bool inBounds(int r, int c) =>
      r >= 0 && r < size && c >= 0 && c < size;

  static String _encodeBoard(List<List<int>> b, int t) {
    final sb = StringBuffer()..write(t)..write(':');
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        sb.write(b[r][c]);
      }
    }
    return sb.toString();
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

  (int, int)? _parseCell(Object? raw) {
    if (raw is List && raw.length >= 2) {
      return (asInt(raw[0], -1), asInt(raw[1], -1));
    }
    if (raw is int || raw is num) {
      final idx = asInt(raw, -1);
      if (idx >= 0 && idx < size * size) {
        return (idx ~/ size, idx % size);
      }
    }
    return null;
  }

  /// Checks if [color] (1 or 2) has formed a contiguous 3-in-a-row on [b].
  /// Returns the 3 coordinates [[r0,c0], [r1,c1], [r2,c2]] if so, or null.
  static List<List<int>>? checkThreeInARow(List<List<int>> b, int color) {
    final pts = <List<int>>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (b[r][c] == color) {
          pts.add([r, c]);
        }
      }
    }
    if (pts.length != 3) return null;
    final dr1 = pts[1][0] - pts[0][0];
    final dc1 = pts[1][1] - pts[0][1];
    final dr2 = pts[2][0] - pts[1][0];
    final dc2 = pts[2][1] - pts[1][1];
    if (dr1 == dr2 && dc1 == dc2 && dr1.abs() <= 1 && dc1.abs() <= 1) {
      return pts;
    }
    return null;
  }

  /// Computes the destination cell when sliding from (r, c) in direction (dr, dc) on [b].
  static (int, int) slideEndpoint(
    List<List<int>> b,
    int r,
    int c,
    int dr,
    int dc,
  ) {
    var curR = r;
    var curC = c;
    while (inBounds(curR + dr, curC + dc) && b[curR + dr][curC + dc] == 0) {
      curR += dr;
      curC += dc;
    }
    return (curR, curC);
  }

  static List<NeutreekoSlide> generateMovesOn(List<List<int>> b, int seat) {
    final me = seat + 1;
    final moves = <NeutreekoSlide>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (b[r][c] != me) continue;
        for (final (dr, dc) in dirs8) {
          final (endR, endC) = slideEndpoint(b, r, c, dr, dc);
          if (endR != r || endC != c) {
            moves.add(
              NeutreekoSlide(
                fromR: r,
                fromC: c,
                toR: endR,
                toC: endC,
                dr: dr,
                dc: dc,
              ),
            );
          }
        }
      }
    }
    return moves;
  }

  List<NeutreekoSlide> generateLegalMoves(int seat) =>
      generateMovesOn(board, seat);

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    if (type != 'slide' && type != 'move') {
      throw GameError('无效操作类型');
    }

    final fromCell = _parseCell(action['from']) ??
        (action.containsKey('fromR')
            ? (asInt(action['fromR'], -1), asInt(action['fromC'], -1))
            : null);
    final toCell = _parseCell(action['to']) ??
        (action.containsKey('toR')
            ? (asInt(action['toR'], -1), asInt(action['toC'], -1))
            : null);

    if (fromCell == null || toCell == null) {
      throw GameError('缺少滑行起止坐标');
    }

    final (fromR, fromC) = fromCell;
    final (toR, toC) = toCell;
    if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) {
      throw GameError('坐标超出棋盘范围');
    }

    final me = seat + 1;
    if (board[fromR][fromC] != me) {
      throw GameError('起始格没有你的棋子');
    }

    final diffR = toR - fromR;
    final diffC = toC - fromC;
    if (diffR == 0 && diffC == 0) {
      throw GameError('棋子必须至少滑行 1 格');
    }
    if (diffR != 0 && diffC != 0 && diffR.abs() != diffC.abs()) {
      throw GameError('必须沿横、竖或对角线直线滑行');
    }

    final dr = diffR.sign;
    final dc = diffC.sign;
    final (endR, endC) = slideEndpoint(board, fromR, fromC, dr, dc);
    if (endR == fromR && endC == fromC) {
      throw GameError('该方向已被阻挡，无法滑行');
    }
    if (toR != endR || toC != endC) {
      throw GameError('滑冰规则要求棋子必须一滑到底，应停在 (${endR + 1}, ${endC + 1})');
    }

    board[fromR][fromC] = 0;
    board[endR][endC] = me;
    moveCount++;

    lastMove = {
      'seat': seat,
      'fromR': fromR,
      'fromC': fromC,
      'toR': endR,
      'toC': endC,
    };

    final winPts = checkThreeInARow(board, me);
    if (winPts != null) {
      over = true;
      winner = seat;
      winReason = 'three';
      winningLine = winPts;
      host.log('${name(seat)} 达成紧邻三子连珠，获胜！');
      return;
    }

    final nextSeat = 1 - seat;
    if (generateMovesOn(board, nextSeat).isEmpty) {
      over = true;
      winner = seat;
      winReason = 'no_moves';
      host.log('${name(nextSeat)} 无子可动，${name(seat)} 获胜！');
      return;
    }

    turn = nextSeat;
    final stateKey = _encodeBoard(board, turn);
    stateHistory.add(stateKey);

    if (moveCount >= 180) {
      over = true;
      winner = -1;
      winReason = 'limit';
      host.log('达到最大回合数限制，双方和棋！');
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    String? resultText;
    if (over) {
      if (winner == -1 || winner == null) {
        resultText = '双方和棋！';
      } else if (winReason == 'three') {
        resultText =
            '${name(winner!)}（${winner == 0 ? "黑方" : "白方"}）达成三子连珠获胜！';
      } else if (winReason == 'resign') {
        resultText = '${name(winner!)} 获胜（对手认输）！';
      } else {
        resultText = '${name(winner!)} 获胜！';
      }
    }

    final legalMoves = <Map<String, dynamic>>[];
    if (!over) {
      for (final m in generateLegalMoves(turn)) {
        legalMoves.add({
          'fromR': m.fromR,
          'fromC': m.fromC,
          'toR': m.toR,
          'toC': m.toC,
        });
      }
    }

    return {
      'size': size,
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'turn': turn,
      'moveCount': moveCount,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'winningLine': [
        for (final p in winningLine) List<int>.of(p),
      ],
      'legalMoves': legalMoves,
      'lastMove': lastMove,
      'result': resultText,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final moves = generateLegalMoves(seat);
    if (moves.isEmpty) return null;

    final me = seat + 1;
    final opp = 2 - seat;

    // 1. Check for immediate 1-move win
    for (final m in moves) {
      final b2 = _cloneAndApply(board, m, me);
      if (checkThreeInARow(b2, me) != null) {
        return m.toAction();
      }
    }

    // 2. Minimax / tactical lookahead
    NeutreekoSlide bestMove = moves.first;
    double bestScore = double.negativeInfinity;

    for (final m in moves) {
      final b2 = _cloneAndApply(board, m, me);
      final nextStateKey = _encodeBoard(b2, 1 - seat);

      var score = 0.0;

      // Penalize repeating already visited board states so games progress
      var repeatCount = 0;
      for (final s in stateHistory) {
        if (s == nextStateKey) repeatCount++;
      }
      if (repeatCount > 0) {
        score -= repeatCount * 3500.0;
      }

      // Check opponent replies
      final oppMoves = generateMovesOn(b2, 1 - seat);
      var oppCanWinImmediately = false;
      var worstAfterOpp = double.infinity;

      for (final om in oppMoves) {
        final b3 = _cloneAndApply(b2, om, opp);
        if (checkThreeInARow(b3, opp) != null) {
          oppCanWinImmediately = true;
          break;
        }
        if (botLevel >= 1) {
          // Check if we have a winning reply on b3
          final myReplies = generateMovesOn(b3, seat);
          var myBestOnB3 = _evalBoard(b3, seat);
          for (final mr in myReplies) {
            final b4 = _cloneAndApply(b3, mr, me);
            if (checkThreeInARow(b4, me) != null) {
              myBestOnB3 = 50000.0;
              break;
            }
            final e4 = _evalBoard(b4, seat);
            if (e4 > myBestOnB3) myBestOnB3 = e4;
          }
          if (myBestOnB3 < worstAfterOpp) {
            worstAfterOpp = myBestOnB3;
          }
        }
      }

      if (oppCanWinImmediately) {
        score -= 500000.0;
      } else if (botLevel >= 1 && worstAfterOpp.isFinite) {
        score += worstAfterOpp;
      } else {
        score += _evalBoard(b2, seat);
      }

      // Count how many immediate winning moves we threaten on b2 if it were our turn
      var myThreats = 0;
      for (final tm in generateMovesOn(b2, seat)) {
        final bt = _cloneAndApply(b2, tm, me);
        if (checkThreeInARow(bt, me) != null) {
          myThreats++;
        }
      }
      score += myThreats * 600.0;

      final jitter =
          botLevel == 0 ? rng.nextDouble() * 450.0 : rng.nextDouble() * 25.0;
      if (score + jitter > bestScore) {
        bestScore = score + jitter;
        bestMove = m;
      }
    }

    return bestMove.toAction();
  }

  static List<List<int>> _cloneAndApply(
    List<List<int>> b,
    NeutreekoSlide m,
    int color,
  ) {
    final copy = [for (final row in b) List<int>.of(row)];
    copy[m.fromR][m.fromC] = 0;
    copy[m.toR][m.toC] = color;
    return copy;
  }

  static double _evalBoard(List<List<int>> b, int seat) {
    final me = seat + 1;
    final opp = 2 - seat;
    return _evalColor(b, me) - _evalColor(b, opp) * 0.95;
  }

  static double _evalColor(List<List<int>> b, int color) {
    final pts = <(int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (b[r][c] == color) pts.add((r, c));
      }
    }
    if (pts.length != 3) return 0.0;

    var score = 0.0;
    // Reward adjacent pairs and collinear near-triples
    for (var i = 0; i < 3; i++) {
      final (r, c) = pts[i];
      // Slight preference for central area
      score += (4 - ((r - 2).abs() + (c - 2).abs())) * 18.0;
      for (var j = i + 1; j < 3; j++) {
        final (r2, c2) = pts[j];
        final dr = (r - r2).abs();
        final dc = (c - c2).abs();
        if (dr <= 1 && dc <= 1) {
          score += 240.0;
        } else if ((dr == 0 && dc == 2) ||
            (dc == 0 && dr == 2) ||
            (dr == 2 && dc == 2)) {
          final midR = (r + r2) ~/ 2;
          final midC = (c + c2) ~/ 2;
          if (b[midR][midC] == 0) {
            score += 130.0;
          }
        }
      }
    }
    return score;
  }
}
