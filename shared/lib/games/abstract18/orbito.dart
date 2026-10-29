import '../../src/engine.dart';

/// 轨道旋转棋（Orbito）—— FlexiQ 出品的 4×4 双环逆时针公转、移敌布子与动态四连抽象策略名作。
///
/// 核心规则：
/// - 棋盘为 `4×4` 网格（`r in 0..3, c in 0..3`），包含内外两条**逆时针（Counterclockwise）公转轨道**：
///   - **外环轨道（12 格）**：`(0,0)->(1,0)->(2,0)->(3,0)->(3,1)->(3,2)->(3,3)->(2,3)->(1,3)->(0,3)->(0,2)->(0,1)->(0,0)`
///   - **内环轨道（4 格）**：`(1,1)->(2,1)->(2,2)->(1,2)->(1,1)`
/// - **每回合三步流程**：
///   1. **可选推敌（Optional Shove）**：在落子前，你可以选择棋盘上 **1 枚对手的弹珠**，将其正交（上下左右）移动 1 格到相邻空格（也可跳过不推）。
///   2. **必须落子（Place）**：将 1 枚己方颜色的弹珠放置到任意空格 `(r, c)`（包括刚才推走敌方弹珠后腾出的空格）。
///   3. **按下 Orbito 轨道旋转按钮（Auto-Rotate）**：落子后自动触发轨道公转——**棋盘上的所有弹珠同时沿各自所在轨道箭头方向前进 1 格！**
/// - **终局与胜负**：
///   - 每次轨道公转结束后，检查是否有人在横、竖或对角线上形成 **4 枚同色弹珠连线**：
///     - 若仅一方形成四连，该玩家立即获胜！
///     - 若双方在同一时刻均形成四连，则四连线数量更多者获胜（数量相同则平局）！
///   - **第 16 子满盘终局加转**：若第 16 枚弹珠落下并完成常规公转后仍无人四连，则继续触发最多 **4 次额外轨道公转**（每次公转后检查四连），若仍无人获胜则握手言和！
class OrbitoGame extends GameEngine {
  OrbitoGame(super.setup);

  static const int kSize = 4;

  static const List<(int, int)> kOrthoDirs = [
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
  ];

  static const List<List<(int, int)>> kLines4 = [
    // Rows
    [(0, 0), (0, 1), (0, 2), (0, 3)],
    [(1, 0), (1, 1), (1, 2), (1, 3)],
    [(2, 0), (2, 1), (2, 2), (2, 3)],
    [(3, 0), (3, 1), (3, 2), (3, 3)],
    // Columns
    [(0, 0), (1, 0), (2, 0), (3, 0)],
    [(0, 1), (1, 1), (2, 1), (3, 1)],
    [(0, 2), (1, 2), (2, 2), (3, 2)],
    [(0, 3), (1, 3), (2, 3), (3, 3)],
    // Diagonals
    [(0, 0), (1, 1), (2, 2), (3, 3)],
    [(0, 3), (1, 2), (2, 1), (3, 0)],
  ];

  /// Maps every `(r, c)` on the 4x4 board to its next cell along its counterclockwise orbit.
  static const Map<(int, int), (int, int)> kOrbitNext = {
    // Outer orbit (counterclockwise)
    (0, 0): (1, 0),
    (1, 0): (2, 0),
    (2, 0): (3, 0),
    (3, 0): (3, 1),
    (3, 1): (3, 2),
    (3, 2): (3, 3),
    (3, 3): (2, 3),
    (2, 3): (1, 3),
    (1, 3): (0, 3),
    (0, 3): (0, 2),
    (0, 2): (0, 1),
    (0, 1): (0, 0),
    // Inner orbit (counterclockwise)
    (1, 1): (2, 1),
    (2, 1): (2, 2),
    (2, 2): (1, 2),
    (1, 2): (1, 1),
  };

  late String mode;

  /// `board[r][c]`: `-1` = empty, `0` = Seat 0 (White/Cyan), `1` = Seat 1 (Black/Amber).
  late List<List<int>> board;

  int turn = 0;
  bool shovedThisTurn = false;
  Map<String, int>? currentShove;

  bool over = false;
  int? winner;
  String? winReason;
  List<(int, int)> winningCells = [];
  List<int>? _placings;
  int moveCount = 0;
  Map<String, dynamic>? lastMove;

  static bool inBounds(int r, int c) => r >= 0 && r < kSize && c >= 0 && c < kSize;

  static (int, int) nextOrbitCell(int r, int c) => kOrbitNext[(r, c)]!;

  static List<List<int>> cloneBoard(List<List<int>> src) => [
        for (final row in src) List<int>.of(row),
      ];

  /// Returns a new 4x4 board where every marble has shifted 1 step along its counterclockwise orbit.
  static List<List<int>> rotateBoard(List<List<int>> src) {
    final next = List.generate(kSize, (_) => List.filled(kSize, -1));
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        final v = src[r][c];
        if (v >= 0) {
          final (nr, nc) = kOrbitNext[(r, c)]!;
          next[nr][nc] = v;
        }
      }
    }
    return next;
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    board = List.generate(kSize, (_) => List.filled(kSize, -1));
    turn = 0;
    shovedThisTurn = false;
    currentShove = null;
    over = false;
    winner = null;
    winReason = null;
    winningCells = [];
    _placings = null;
    moveCount = 0;
    lastMove = null;
  }

  void clearBoard() {
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        board[r][c] = -1;
      }
    }
  }

  int marbleCount([List<List<int>>? b]) {
    final grid = b ?? board;
    var cnt = 0;
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        if (grid[r][c] >= 0) cnt++;
      }
    }
    return cnt;
  }

  static List<List<(int, int)>> findWinningLines(int seat, List<List<int>> grid) {
    final res = <List<(int, int)>>[];
    for (final line in kLines4) {
      if (line.every((pos) => grid[pos.$1][pos.$2] == seat)) {
        res.add(line);
      }
    }
    return res;
  }

  bool canShove(int seat, int fromR, int fromC, int toR, int toC, [List<List<int>>? b]) {
    final grid = b ?? board;
    if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) return false;
    final opp = 1 - seat;
    if (grid[fromR][fromC] != opp) return false;
    if (grid[toR][toC] != -1) return false;
    final dist = (fromR - toR).abs() + (fromC - toC).abs();
    return dist == 1;
  }

  List<Map<String, int>> legalShoves(int seat, [List<List<int>>? b]) {
    if (shovedThisTurn && b == null) return const [];
    final grid = b ?? board;
    final opp = 1 - seat;
    final res = <Map<String, int>>[];
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        if (grid[r][c] != opp) continue;
        for (final (dr, dc) in kOrthoDirs) {
          final nr = r + dr;
          final nc = c + dc;
          if (inBounds(nr, nc) && grid[nr][nc] == -1) {
            res.add({
              'fromR': r,
              'fromC': c,
              'toR': nr,
              'toC': nc,
            });
          }
        }
      }
    }
    return res;
  }

  List<(int, int)> legalPlacements([List<List<int>>? b]) {
    final grid = b ?? board;
    final res = <(int, int)>[];
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        if (grid[r][c] == -1) res.add((r, c));
      }
    }
    return res;
  }

  void _endGame(int winSeat, String reason, [List<(int, int)> cells = const []]) {
    over = true;
    winner = winSeat;
    winningCells = cells;
    _placings = winSeat == 0
        ? [1, 2]
        : (winSeat == 1 ? [2, 1] : [1, 1]);
    winReason = reason;
    host.log(reason);
  }

  bool _checkAndResolveVictory({int extraRotations = 0}) {
    final lines0 = findWinningLines(0, board);
    final lines1 = findWinningLines(1, board);
    if (lines0.isEmpty && lines1.isEmpty) return false;

    final suffix = extraRotations > 0 ? '（经终局第 $extraRotations 次公转）' : '';
    if (lines0.isNotEmpty && lines1.isEmpty) {
      _endGame(0, '${name(0)} 在轨道公转后达成四子连线$suffix，获得胜利！', lines0.first);
      return true;
    }
    if (lines1.isNotEmpty && lines0.isEmpty) {
      _endGame(1, '${name(1)} 在轨道公转后达成四子连线$suffix，获得胜利！', lines1.first);
      return true;
    }
    // Both players formed 4-in-a-row simultaneously
    if (lines0.length > lines1.length) {
      _endGame(0, '双方同时连成四线，${name(0)} 四连数（${lines0.length} 条）多于对手获胜！', lines0.first);
    } else if (lines1.length > lines0.length) {
      _endGame(1, '双方同时连成四线，${name(1)} 四连数（${lines1.length} 条）多于对手获胜！', lines1.first);
    } else {
      _endGame(-1, '双方在轨道公转后同时达成四子连线$suffix，势均力敌握手言和！', lines0.first);
    }
    return true;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');

    final type = asStr(action['type']);

    if (type == 'shove') {
      if (shovedThisTurn) throw GameError('本回合已经推过对手的弹珠了');
      final fromR = asInt(action['fromR'], -1);
      final fromC = asInt(action['fromC'], -1);
      final toR = asInt(action['toR'], -1);
      final toC = asInt(action['toC'], -1);

      if (!canShove(seat, fromR, fromC, toR, toC)) {
        throw GameError('推子无效：只能将 1 枚对手弹珠正交移动 1 格到相邻空格');
      }

      board[toR][toC] = board[fromR][fromC];
      board[fromR][fromC] = -1;
      shovedThisTurn = true;
      currentShove = {
        'fromR': fromR,
        'fromC': fromC,
        'toR': toR,
        'toC': toC,
      };
      host.log('${name(seat)} 将对手位于 ($fromR, $fromC) 的弹珠推至 ($toR, $toC)');
      return;
    }

    if (type == 'place' || type == 'turn') {
      var shoveInfo = currentShove;

      // Support inline optional shove parameters in a single atomic turn action
      if (!shovedThisTurn &&
          (action.containsKey('shoveFromR') || action.containsKey('shoveFrom'))) {
        int sfR = asInt(action['shoveFromR'], -1);
        int sfC = asInt(action['shoveFromC'], -1);
        int stR = asInt(action['shoveToR'], -1);
        int stC = asInt(action['shoveToC'], -1);
        if (action['shoveFrom'] is List && (action['shoveFrom'] as List).length >= 2) {
          final l = action['shoveFrom'] as List;
          sfR = asInt(l[0], -1);
          sfC = asInt(l[1], -1);
        }
        if (action['shoveTo'] is List && (action['shoveTo'] as List).length >= 2) {
          final l = action['shoveTo'] as List;
          stR = asInt(l[0], -1);
          stC = asInt(l[1], -1);
        }
        if (!canShove(seat, sfR, sfC, stR, stC)) {
          throw GameError('推子无效：只能将 1 枚对手弹珠正交移动 1 格到相邻空格');
        }
        board[stR][stC] = board[sfR][sfC];
        board[sfR][sfC] = -1;
        shoveInfo = {
          'fromR': sfR,
          'fromC': sfC,
          'toR': stR,
          'toC': stC,
        };
      }

      final r = asInt(action['r'], -1);
      final c = asInt(action['c'], -1);
      if (!inBounds(r, c)) throw GameError('落子坐标 ($r, $c) 越界');
      if (board[r][c] != -1) throw GameError('目标格 ($r, $c) 已有弹珠');

      // 2. Place marble at (r, c)
      board[r][c] = seat;

      // 3. Automatic Orbito rotation (every marble shifts 1 step along its orbit)
      board = rotateBoard(board);
      final (rotR, rotC) = nextOrbitCell(r, c);

      shovedThisTurn = false;
      currentShove = null;
      moveCount++;

      lastMove = {
        'type': 'place',
        'seat': seat,
        'placedR': r,
        'placedC': c,
        'rotatedToR': rotR,
        'rotatedC': rotC,
        'shove': shoveInfo,
      };

      if (shoveInfo != null) {
        host.log(
          '${name(seat)} 推开 (${shoveInfo['fromR']}, ${shoveInfo['fromC']})->(${shoveInfo['toR']}, ${shoveInfo['toC']})，'
          '在 ($r, $c) 落子并启动轨道公转 -> ($rotR, $rotC)',
        );
      } else {
        host.log('${name(seat)} 在 ($r, $c) 落子并启动轨道公转 -> ($rotR, $rotC)');
      }

      if (_checkAndResolveVictory()) return;

      // If all 16 cells are now filled, perform up to 4 final extra rotations
      if (marbleCount() >= 16) {
        for (var extra = 1; extra <= 4; extra++) {
          board = rotateBoard(board);
          if (_checkAndResolveVictory(extraRotations: extra)) return;
        }
        _endGame(-1, '16 枚弹珠全部落满且完成终局轨道公转，双方均未达成四连，握手言和！');
        return;
      }

      turn = 1 - seat;
      return;
    }

    throw GameError('未知操作类型：$type');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final opp = 1 - seat;

    // If already shoved this turn, only choose the best placement
    if (shovedThisTurn) {
      final places = legalPlacements();
      if (places.isEmpty) return null;
      var bestVal = -1e9;
      var bestPos = places.first;
      for (final (r, c) in places) {
        final sim = cloneBoard(board);
        sim[r][c] = seat;
        final rot = rotateBoard(sim);
        final val = _evalAfterRotate(seat, opp, rot) + rng.nextDouble() * 0.5;
        if (val > bestVal) {
          bestVal = val;
          bestPos = (r, c);
        }
      }
      return {'type': 'place', 'r': bestPos.$1, 'c': bestPos.$2};
    }

    // Generate candidate (optional shove + place) actions
    final candidates = <Map<String, dynamic>>[];
    for (final (r, c) in legalPlacements()) {
      candidates.add({'type': 'place', 'r': r, 'c': c});
    }

    if (botLevel > 0) {
      for (final sh in legalShoves(seat)) {
        final afterShove = cloneBoard(board);
        final sfR = sh['fromR']!;
        final sfC = sh['fromC']!;
        final stR = sh['toR']!;
        final stC = sh['toC']!;
        afterShove[stR][stC] = afterShove[sfR][sfC];
        afterShove[sfR][sfC] = -1;
        for (final (r, c) in legalPlacements(afterShove)) {
          candidates.add({
            'type': 'place',
            'r': r,
            'c': c,
            'shoveFromR': sfR,
            'shoveFromC': sfC,
            'shoveToR': stR,
            'shoveToC': stC,
          });
        }
      }
    }

    if (botLevel <= 0) {
      return candidates[rng.nextInt(candidates.length)];
    }

    var bestScore = -1e9;
    var bestActions = <Map<String, dynamic>>[];

    for (final act in candidates) {
      final sim = cloneBoard(board);
      if (act.containsKey('shoveFromR')) {
        final sfR = act['shoveFromR'] as int;
        final sfC = act['shoveFromC'] as int;
        final stR = act['shoveToR'] as int;
        final stC = act['shoveToC'] as int;
        sim[stR][stC] = sim[sfR][sfC];
        sim[sfR][sfC] = -1;
      }
      sim[act['r'] as int][act['c'] as int] = seat;
      final rot = rotateBoard(sim);

      final val = _evalAfterRotate(seat, opp, rot) + rng.nextDouble() * 0.5;
      if (val > bestScore) {
        bestScore = val;
        bestActions = [act];
      }
    }

    return bestActions[rng.nextInt(bestActions.length)];
  }

  static double _evalAfterRotate(int seat, int opp, List<List<int>> rot) {
    final myWins = findWinningLines(seat, rot).length;
    final oppWins = findWinningLines(opp, rot).length;
    if (myWins > oppWins) return 100000.0 + myWins * 1000.0;
    if (oppWins > myWins) return -100000.0;

    // Also evaluate how the board looks both now (`rot`) and after one more orbit rotation (`rot2`)
    final rot2 = rotateBoard(rot);
    return _linePotential(seat, opp, rot) * 1.0 +
        _linePotential(seat, opp, rot2) * 1.2;
  }

  static double _linePotential(int seat, int opp, List<List<int>> grid) {
    var score = 0.0;
    for (final line in kLines4) {
      var myCnt = 0;
      var oppCnt = 0;
      for (final (r, c) in line) {
        final v = grid[r][c];
        if (v == seat) {
          myCnt++;
        } else if (v == opp) {
          oppCnt++;
        }
      }
      if (myCnt > 0 && oppCnt == 0) {
        if (myCnt == 3) score += 60.0;
        if (myCnt == 2) score += 12.0;
      } else if (oppCnt > 0 && myCnt == 0) {
        if (oppCnt == 3) score -= 75.0;
        if (oppCnt == 2) score -= 14.0;
      }
    }
    return score;
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
        for (final row in board) List<int>.of(row),
      ],
      'marbleCount': marbleCount(),
      'turn': turn,
      'shovedThisTurn': shovedThisTurn,
      'currentShove': currentShove,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'winningCells': [
        for (final (r, c) in winningCells) [r, c],
      ],
      'moveCount': moveCount,
      'lastMove': lastMove,
      'legalShoves': over ? const [] : legalShoves(turn),
      'legalPlacements': over
          ? const []
          : [
              for (final (r, c) in legalPlacements()) {'r': r, 'c': c},
            ],
    };
  }
}
