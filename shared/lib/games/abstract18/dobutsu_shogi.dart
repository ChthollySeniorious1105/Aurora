import '../../src/engine.dart';

/// 森林小将棋棋子
class DobutsuPiece {
  final int owner; // 0 (South, moves toward r=0) or 1 (North, moves toward r=3)
  final String kind; // 'L' (Lion), 'E' (Elephant), 'G' (Giraffe), 'C' (Chick), 'H' (Hen)

  const DobutsuPiece(this.owner, this.kind);

  Map<String, dynamic> toJson() => {
        'owner': owner,
        'kind': kind,
      };
}

/// 森林小将棋（Dōbutsu Shōgi / どうぶつしょうぎ）—— 北尾圆与藤田麻衣子创作的 3×4 森林萌宠将棋名作。
///
/// 核心规则：
/// - 棋盘为 `4 行 × 3 列`（`r in 0..3, c in 0..2`）的森林棋盘。
/// - **初始布置**：
///   - **座位 0（南方森林，向 `r = 0` 前进）**：`(3,0)` 🐘大象（`E`）、`(3,1)` 🦁狮子（`L`）、`(3,2)` 🦒长颈鹿（`G`）、`(2,1)` 🐥小鸡（`C`）。
///   - **座位 1（北方森林，向 `r = 3` 前进）**：`(0,0)` 🦒长颈鹿（`G`）、`(0,1)` 🦁狮子（`L`）、`(0,2)` 🐘大象（`E`）、`(1,1)` 🐥小鸡（`C`）。
/// - **五种动物走法**：
///   - 🦁 **狮子（`L`, Lion）**：向周围全部 **8 个方向**（正交+对角）移动 1 格。
///   - 🐘 **大象（`E`, Elephant）**：向 **4 个对角线斜向**移动 1 格。
///   - 🦒 **长颈鹿（`G`, Giraffe）**：向 **4 个上下左右正交方向**移动 1 格。
///   - 🐥 **小鸡（`C`, Chick）**：只能向**正前方**移动 1 格（座位 0 为 `dr = -1`，座位 1 为 `dr = +1`）。当小鸡通过移动踏入对方底线（座位 0 到达 `r == 0`，座位 1 到达 `r == 3`）时，自动晋升为 **🐔母鸡（`H`, Hen）**！
///   - 🐔 **母鸡（`H`, Hen）**：向 **6 个方向**（上下左右 4 正交 + 左前/右前 2 斜向，除左后/右后外）移动 1 格（同本将棋“金将”）。
/// - **俘获与打入（Capture & Drop）**：
///   - 吃掉对手的棋子后，该棋子归入己方**持驹手牌（`hands[seat]`）**（若吃掉的是母鸡 `H`，则还原为小鸡 `C` 收入手牌）。
///   - 轮到你的回合时，除移动盘面棋子外，也可选择从手牌中取 1 枚棋子**打入（`'drop'`）**到棋盘上的**任意空格 `(r, c)`**（直接打入底线的小鸡不会立即晋升，须日后移动方可晋升）。
/// - **两种获胜方式**：
///   1. **捕获（Catch / キャッチ）**：吃掉对手的 🦁**狮子（`L`）** 立即获胜！
///   2. **达阵（Try / トライ）**：将己方的 🦁**狮子（`L`）** 移入对方底线（座位 0 进入 `r == 0`，座位 1 进入 `r == 3`），且落点**不会在下一回合被对手立即吃掉**，立即达阵获胜！
class DobutsuShogiGame extends GameEngine {
  DobutsuShogiGame(super.setup);

  static const int kRows = 4;
  static const int kCols = 3;

  static const Map<String, String> kPieceNames = {
    'L': '狮子🦁',
    'E': '大象🐘',
    'G': '长颈鹿🦒',
    'C': '小鸡🐥',
    'H': '母鸡🐔',
  };

  late String mode;
  late List<List<DobutsuPiece?>> board;
  late List<List<String>> hands;

  int turn = 0;
  bool over = false;
  int? winner;
  String? winReason;
  List<int>? _placings;
  int moveCount = 0;
  Map<String, dynamic>? lastMove;

  static bool inBounds(int r, int c) =>
      r >= 0 && r < kRows && c >= 0 && c < kCols;

  static int forwardDr(int seat) => seat == 0 ? -1 : 1;

  static int promoRow(int seat) => seat == 0 ? 0 : 3;

  /// Returns valid 1-step `(dr, dc)` offsets for `kind` owned by `seat`.
  static List<(int, int)> pieceDirs(int seat, String kind) {
    final fwd = forwardDr(seat);
    switch (kind) {
      case 'L':
        return const [
          (-1, -1),
          (-1, 0),
          (-1, 1),
          (0, -1),
          (0, 1),
          (1, -1),
          (1, 0),
          (1, 1),
        ];
      case 'E':
        return const [
          (-1, -1),
          (-1, 1),
          (1, -1),
          (1, 1),
        ];
      case 'G':
        return const [
          (-1, 0),
          (1, 0),
          (0, -1),
          (0, 1),
        ];
      case 'C':
        return [(fwd, 0)];
      case 'H':
        return [
          (-1, 0),
          (1, 0),
          (0, -1),
          (0, 1),
          (fwd, -1),
          (fwd, 1),
        ];
      default:
        return const [];
    }
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    board = List.generate(kRows, (_) => List<DobutsuPiece?>.filled(kCols, null));

    // North (Seat 1): (0,0)=G, (0,1)=L, (0,2)=E, (1,1)=C
    board[0][0] = const DobutsuPiece(1, 'G');
    board[0][1] = const DobutsuPiece(1, 'L');
    board[0][2] = const DobutsuPiece(1, 'E');
    board[1][1] = const DobutsuPiece(1, 'C');

    // South (Seat 0): (2,1)=C, (3,0)=E, (3,1)=L, (3,2)=G
    board[2][1] = const DobutsuPiece(0, 'C');
    board[3][0] = const DobutsuPiece(0, 'E');
    board[3][1] = const DobutsuPiece(0, 'L');
    board[3][2] = const DobutsuPiece(0, 'G');

    hands = [<String>[], <String>[]];
    turn = 0;
    over = false;
    winner = null;
    winReason = null;
    _placings = null;
    moveCount = 0;
    lastMove = null;
  }

  void clearBoard() {
    for (var r = 0; r < kRows; r++) {
      for (var c = 0; c < kCols; c++) {
        board[r][c] = null;
      }
    }
  }

  void setPiece(int r, int c, int owner, String kind) {
    board[r][c] = DobutsuPiece(owner, kind);
  }

  static List<List<DobutsuPiece?>> cloneBoard(List<List<DobutsuPiece?>> src) => [
        for (final row in src) List<DobutsuPiece?>.of(row),
      ];

  /// Checks if square `(targetR, targetC)` is currently attacked by any board piece of `attackerSeat`.
  static bool isSquareAttackedBy(
    int targetR,
    int targetC,
    int attackerSeat,
    List<List<DobutsuPiece?>> grid,
  ) {
    for (var r = 0; r < kRows; r++) {
      for (var c = 0; c < kCols; c++) {
        final p = grid[r][c];
        if (p == null || p.owner != attackerSeat) continue;
        for (final (dr, dc) in pieceDirs(attackerSeat, p.kind)) {
          if (r + dr == targetR && c + dc == targetC) {
            return true;
          }
        }
      }
    }
    return false;
  }

  List<Map<String, dynamic>> legalMoves(int seat) {
    final res = <Map<String, dynamic>>[];

    // 1. Board moves
    for (var r = 0; r < kRows; r++) {
      for (var c = 0; c < kCols; c++) {
        final p = board[r][c];
        if (p == null || p.owner != seat) continue;
        for (final (dr, dc) in pieceDirs(seat, p.kind)) {
          final nr = r + dr;
          final nc = c + dc;
          if (!inBounds(nr, nc)) continue;
          final dst = board[nr][nc];
          if (dst != null && dst.owner == seat) continue;
          res.add({
            'type': 'move',
            'fromR': r,
            'fromC': c,
            'toR': nr,
            'toC': nc,
            'kind': p.kind,
            'captured': dst?.kind,
          });
        }
      }
    }

    // 2. Hand drops onto any empty cell
    final uniqueHandKinds = hands[seat].toSet().toList();
    for (final k in uniqueHandKinds) {
      for (var r = 0; r < kRows; r++) {
        for (var c = 0; c < kCols; c++) {
          if (board[r][c] == null) {
            res.add({
              'type': 'drop',
              'kind': k,
              'r': r,
              'c': c,
            });
          }
        }
      }
    }

    return res;
  }

  void _endGame(int winSeat, String reason) {
    over = true;
    winner = winSeat;
    _placings = winSeat == 0
        ? [1, 2]
        : (winSeat == 1 ? [2, 1] : [1, 1]);
    winReason = reason;
    host.log(reason);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');

    final type = asStr(action['type']);
    final opp = 1 - seat;

    if (type == 'move') {
      final fromR = asInt(action['fromR'], -1);
      final fromC = asInt(action['fromC'], -1);
      final toR = asInt(action['toR'], -1);
      final toC = asInt(action['toC'], -1);

      if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) {
        throw GameError('棋盘坐标越界');
      }
      final src = board[fromR][fromC];
      if (src == null || src.owner != seat) {
        throw GameError('起始格 ($fromR, $fromC) 没有你的动物棋子');
      }
      final dst = board[toR][toC];
      if (dst != null && dst.owner == seat) {
        throw GameError('目标格 ($toR, $toC) 已有己方动物棋子');
      }

      final dr = toR - fromR;
      final dc = toC - fromC;
      if (!pieceDirs(seat, src.kind).contains((dr, dc))) {
        throw GameError('${kPieceNames[src.kind]}不能沿该方向移动');
      }

      var newKind = src.kind;
      var promoted = false;
      if (src.kind == 'C' && toR == promoRow(seat)) {
        newKind = 'H';
        promoted = true;
      }

      String? capturedKind;
      if (dst != null) {
        capturedKind = dst.kind;
        if (capturedKind != 'L') {
          final handKind = capturedKind == 'H' ? 'C' : capturedKind;
          hands[seat].add(handKind);
        }
      }

      board[fromR][fromC] = null;
      board[toR][toC] = DobutsuPiece(seat, newKind);
      moveCount++;

      lastMove = {
        'type': 'move',
        'seat': seat,
        'fromR': fromR,
        'fromC': fromC,
        'toR': toR,
        'toC': toC,
        'kind': src.kind,
        'promoted': promoted,
        'captured': capturedKind,
      };

      // 1. Victory by Catch (capturing opponent's Lion)
      if (capturedKind == 'L') {
        _endGame(
          seat,
          '${name(seat)} 的${kPieceNames[src.kind]}在 ($toR, $toC) 成功捕获 ${name(opp)} 的狮子🦁（Catch），赢得胜利！',
        );
        return;
      }

      if (promoted) {
        host.log('${name(seat)} 的小鸡🐥移至底线 ($toR, $toC)，晋升为母鸡🐔！');
      } else if (capturedKind != null) {
        host.log(
          '${name(seat)} 的${kPieceNames[src.kind]}从 ($fromR, $fromC) 移至 ($toR, $toC)，俘获${kPieceNames[capturedKind]}！',
        );
      } else {
        host.log('${name(seat)} 的${kPieceNames[src.kind]}从 ($fromR, $fromC) 移至 ($toR, $toC)');
      }

      // 2. Victory by Try (Lion reaches opponent's back rank onto an unattacked square)
      if (newKind == 'L' && toR == promoRow(seat)) {
        if (!isSquareAttackedBy(toR, toC, opp, board)) {
          _endGame(
            seat,
            '${name(seat)} 的狮子🦁安全踏入敌方底线 ($toR, $toC) 达成「达阵（Try）」，赢得胜利！',
          );
          return;
        }
      }
    } else if (type == 'drop') {
      final kind = asStr(action['kind']);
      final r = asInt(action['r'] ?? action['toR'], -1);
      final c = asInt(action['c'] ?? action['toC'], -1);

      if (!hands[seat].contains(kind)) {
        throw GameError('你的手牌中没有可打入的 ${kPieceNames[kind] ?? kind}');
      }
      if (!inBounds(r, c)) {
        throw GameError('打入坐标 ($r, $c) 越界');
      }
      if (board[r][c] != null) {
        throw GameError('目标格 ($r, $c) 已有棋子，只能打入空格');
      }

      hands[seat].remove(kind);
      board[r][c] = DobutsuPiece(seat, kind);
      moveCount++;

      lastMove = {
        'type': 'drop',
        'seat': seat,
        'kind': kind,
        'r': r,
        'c': c,
      };
      host.log('${name(seat)} 将手牌中的${kPieceNames[kind]}打入 ($r, $c)');
    } else {
      throw GameError('未知操作类型：$type');
    }

    // If opponent's Lion was already on their target back rank and we didn't capture it,
    // check if opponent's Lion now wins by Try
    for (var c = 0; c < kCols; c++) {
      final p = board[promoRow(opp)][c];
      if (p != null && p.owner == opp && p.kind == 'L') {
        _endGame(
          opp,
          '${name(opp)} 的狮子🦁在底线屹立不倒达成「达阵（Try）」，赢得胜利！',
        );
        return;
      }
    }

    turn = opp;
    if (legalMoves(opp).isEmpty) {
      _endGame(seat, '${name(opp)} 已无合法走步，${name(seat)} 获胜！');
      return;
    }

    if (moveCount >= 120) {
      final s0 = _materialScore(0, board, hands[0]);
      final s1 = _materialScore(1, board, hands[1]);
      if (s0 > s1) {
        _endGame(0, '达到回合上限，${name(0)} 子力优势获胜！');
      } else if (s1 > s0) {
        _endGame(1, '达到回合上限，${name(1)} 子力优势获胜！');
      } else {
        _endGame(-1, '达到回合上限，双方势均力敌握手言和！');
      }
    }
  }

  static double _pieceVal(String kind) {
    switch (kind) {
      case 'L':
        return 1000.0;
      case 'H':
        return 14.0;
      case 'G':
        return 10.0;
      case 'E':
        return 9.0;
      case 'C':
        return 5.0;
      default:
        return 1.0;
    }
  }

  static double _materialScore(int seat, List<List<DobutsuPiece?>> grid, List<String> hand) {
    var score = 0.0;
    for (var r = 0; r < kRows; r++) {
      for (var c = 0; c < kCols; c++) {
        final p = grid[r][c];
        if (p != null && p.owner == seat) {
          score += _pieceVal(p.kind);
          if (p.kind == 'L') {
            final distToGoal = (r - promoRow(seat)).abs();
            score += (3 - distToGoal) * 3.0;
          }
        }
      }
    }
    for (final k in hand) {
      score += _pieceVal(k) * 0.9;
    }
    return score;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final moves = legalMoves(seat);
    if (moves.isEmpty) return null;

    final opp = 1 - seat;

    // 1. Immediate win by Catch (capturing opponent's Lion) or unattacked Try!
    for (final m in moves) {
      if (m['type'] == 'move') {
        if (m['captured'] == 'L') return m;
        final kind = m['kind'] as String;
        final toR = m['toR'] as int;
        final toC = m['toC'] as int;
        if (kind == 'L' && toR == promoRow(seat)) {
          final sim = cloneBoard(board);
          sim[m['fromR'] as int][m['fromC'] as int] = null;
          sim[toR][toC] = DobutsuPiece(seat, 'L');
          if (!isSquareAttackedBy(toR, toC, opp, sim)) {
            return m;
          }
        }
      }
    }

    if (botLevel <= 0) {
      return moves[rng.nextInt(moves.length)];
    }

    var bestScore = -1e9;
    var bestMoves = <Map<String, dynamic>>[];

    for (final m in moves) {
      final simB = cloneBoard(board);
      final simH0 = List<String>.of(hands[0]);
      final simH1 = List<String>.of(hands[1]);
      final myHand = seat == 0 ? simH0 : simH1;

      if (m['type'] == 'move') {
        final fr = m['fromR'] as int;
        final fc = m['fromC'] as int;
        final tr = m['toR'] as int;
        final tc = m['toC'] as int;
        final src = simB[fr][fc]!;
        final dst = simB[tr][tc];
        if (dst != null && dst.kind != 'L') {
          myHand.add(dst.kind == 'H' ? 'C' : dst.kind);
        }
        final nk = (src.kind == 'C' && tr == promoRow(seat)) ? 'H' : src.kind;
        simB[fr][fc] = null;
        simB[tr][tc] = DobutsuPiece(seat, nk);
      } else {
        final k = m['kind'] as String;
        final r = m['r'] as int;
        final c = m['c'] as int;
        myHand.remove(k);
        simB[r][c] = DobutsuPiece(seat, k);
      }

      // Locate our Lion and check if it is attacked by opponent
      var myLionAttacked = false;
      for (var r = 0; r < kRows; r++) {
        for (var c = 0; c < kCols; c++) {
          final p = simB[r][c];
          if (p != null && p.owner == seat && p.kind == 'L') {
            if (isSquareAttackedBy(r, c, opp, simB)) {
              myLionAttacked = true;
            }
          }
        }
      }

      var val = _materialScore(seat, simB, seat == 0 ? simH0 : simH1) -
          _materialScore(opp, simB, opp == 0 ? simH0 : simH1) * 1.05;
      if (myLionAttacked) val -= 5000.0;
      val += rng.nextDouble() * 0.5;

      if (val > bestScore) {
        bestScore = val;
        bestMoves = [m];
      }
    }

    return bestMoves[rng.nextInt(bestMoves.length)];
  }

  @override
  bool get canResign => !isOver;

  @override
  void resign(int seat) {
    if (over) throw GameError('对局已结束');
    _endGame(1 - seat, '${name(seat)} 认输，${name(1 - seat)} 获胜！');
  }

  @override
  bool get canDraw => !isOver;

  @override
  void agreeDraw() {
    if (over) throw GameError('对局已结束');
    _endGame(-1, '双方同意和棋！');
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => _placings;

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'mode': mode,
      'board': [
        for (var r = 0; r < kRows; r++)
          [
            for (var c = 0; c < kCols; c++) board[r][c]?.toJson(),
          ],
      ],
      'hands': [
        List<String>.of(hands[0]),
        List<String>.of(hands[1]),
      ],
      'turn': turn,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'moveCount': moveCount,
      'lastMove': lastMove,
      'legalMoves': over ? const [] : legalMoves(turn),
    };
  }
}
