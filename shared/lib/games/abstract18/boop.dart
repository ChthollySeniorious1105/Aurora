import '../../src/engine.dart';

/// 棋盘上的猫咪棋子
class BoopPiece {
  final int owner; // 0 or 1
  final String kind; // 'kitten' (小猫) or 'cat' (大猫)

  const BoopPiece(this.owner, this.kind);

  bool get isCat => kind == 'cat';
  bool get isKitten => kind == 'kitten';

  Map<String, dynamic> toJson() => {
        'owner': owner,
        'kind': kind,
      };
}

/// 推猫上床（boop.）—— Scott Brady 设计的 6×6 绗缝床垫双阶猫咪推挤与三连毕业抽象策略名作。
///
/// 核心规则：
/// - 棋盘为 `6×6` 绗缝床垫网格（`r in 0..5, c in 0..5`）。
/// - 每位玩家总计拥有 **8 只猫咪棋子**：标准模式初始储备池为 **8 只小猫（`'kitten'`）** 与 **0 只大猫（`'cat'`）**。
/// - **放置与八向推挤（Boop!）**：
///   - 轮到你的回合时，从储备池中选择 1 只小猫或 1 只大猫，放置到任意空格 `(r, c)`（`{'type': 'place', 'r': r, 'c': c, 'kind': 'kitten'|'cat'}`）。
///   - **推挤结算**：落子格周围 8 个相邻方向 `(r + dr, c + dc)` 上的所有棋子（无论敌我），都会被沿径向往外推开 1 格至 `(r + 2*dr, c + 2*dc)`，但须遵循以下 3 项铁律：
///     1. **双子连线阻挡（Line of 2+ Blocks）**：若相邻棋子后方紧邻格 `(r + 2*dr, c + 2*dc)` 在床垫内且已有另一枚棋子，则两枚棋子稳如泰山，均不会被推动！
///     2. **体型重量压制（Weight Hierarchy）**：新放下的**小猫**只能推开**小猫**，无法推动**大猫**；而新放下的**大猫**既能推开小猫，也能推开大猫！
///     3. **跌落床沿回池（Off the Bed）**：被推出 `6×6` 床垫边界的棋子不会阵亡，而是直接回到其所属玩家的储备池（保持原有小猫/大猫形态）！
/// - **三连毕业升级（Graduation）与获胜条件**：
///   - 推挤结算完毕后，检查当前行动玩家是否在床垫上连成**正交或斜向 3 子连线**（或床上已有全部 8 枚己方棋子）：
///     - **大猫三连获胜 / 八大猫满床获胜**：若当前行动玩家有 3 只**大猫**连成一线，或床上全部 8 枚己方棋子均为**大猫**，则立即获胜！
///     - **小猫毕业升级**：若 3 子连线中含有至少 1 只小猫，则这 3 枚棋子全部从床垫移除，并全部毕业升级为**大猫**放入该玩家的储备池！若无三连但床上已有全部 8 枚己方棋子（含小猫），则毕业场上 1 只小猫升级为储备池中的大猫！
class BoopGame extends GameEngine {
  BoopGame(super.setup);

  static const int kSize = 6;

  static const List<(int, int)> kDirs8 = [
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1),
  ];

  static const List<(int, int)> kLineAxes = [
    (0, 1),
    (1, 0),
    (1, 1),
    (1, -1),
  ];

  late String mode;
  late List<List<BoopPiece?>> board;
  List<int> kittens = [8, 8];
  List<int> cats = [0, 0];

  int turn = 0;
  bool over = false;
  int? winner;
  String? winReason;
  List<int>? _placings;
  int moveCount = 0;
  Map<String, dynamic>? lastMove;

  static bool inBounds(int r, int c) => r >= 0 && r < kSize && c >= 0 && c < kSize;

  static List<List<BoopPiece?>> cloneBoard(List<List<BoopPiece?>> src) => [
        for (final row in src) List<BoopPiece?>.of(row),
      ];

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    board = List.generate(kSize, (_) => List<BoopPiece?>.filled(kSize, null));
    if (mode == 'quick') {
      kittens = [6, 6];
      cats = [2, 2];
    } else {
      kittens = [8, 8];
      cats = [0, 0];
    }
    turn = 0;
    over = false;
    winner = null;
    winReason = null;
    _placings = null;
    moveCount = 0;
    lastMove = null;
  }

  void clearBoard() {
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        board[r][c] = null;
      }
    }
  }

  void setPiece(int r, int c, int owner, String kind) {
    board[r][c] = BoopPiece(owner, kind);
  }

  int boardPieceCount(int seat, [List<List<BoopPiece?>>? b]) {
    final grid = b ?? board;
    var cnt = 0;
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        if (grid[r][c]?.owner == seat) cnt++;
      }
    }
    return cnt;
  }

  int boardCatCount(int seat, [List<List<BoopPiece?>>? b]) {
    final grid = b ?? board;
    var cnt = 0;
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        final p = grid[r][c];
        if (p != null && p.owner == seat && p.isCat) cnt++;
      }
    }
    return cnt;
  }

  /// Finds all 3-in-a-row lines belonging to `seat` on `grid`.
  static List<List<(int, int)>> findThreeInARows(int seat, List<List<BoopPiece?>> grid) {
    final lines = <List<(int, int)>>[];
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        if (grid[r][c]?.owner != seat) continue;
        for (final (dr, dc) in kLineAxes) {
          final r2 = r + dr * 2;
          final c2 = c + dc * 2;
          if (!inBounds(r2, c2)) continue;
          final r1 = r + dr;
          final c1 = c + dc;
          if (grid[r1][c1]?.owner == seat && grid[r2][c2]?.owner == seat) {
            lines.add([(r, c), (r1, c1), (r2, c2)]);
          }
        }
      }
    }
    return lines;
  }

  /// Simulates placing `(seat, kind)` at `(r, c)` on a copy of the state.
  /// Returns `(nextBoard, nextKittens, nextCats, pushedList, graduatedCells, won, winType)`
  /// or `null` if illegal.
  ({
    List<List<BoopPiece?>> nextBoard,
    List<int> nextKittens,
    List<int> nextCats,
    List<Map<String, dynamic>> pushed,
    List<(int, int)> graduated,
    bool won,
    String? winType,
  })? simulatePlace(int seat, int r, int c, String kind) {
    if (!inBounds(r, c)) return null;
    if (board[r][c] != null) return null;
    if (kind != 'kitten' && kind != 'cat') return null;
    if (kind == 'kitten' && kittens[seat] <= 0) return null;
    if (kind == 'cat' && cats[seat] <= 0) return null;

    final nextB = cloneBoard(board);
    final nextK = List<int>.of(kittens);
    final nextC = List<int>.of(cats);

    if (kind == 'kitten') {
      nextK[seat]--;
    } else {
      nextC[seat]--;
    }
    nextB[r][c] = BoopPiece(seat, kind);

    final pushed = <Map<String, dynamic>>[];

    // Resolve radial pushes in all 8 directions
    for (final (dr, dc) in kDirs8) {
      final ar = r + dr;
      final ac = c + dc;
      if (!inBounds(ar, ac)) continue;
      final adj = board[ar][ac];
      if (adj == null) continue;

      // Weight hierarchy: Kitten cannot push a Cat
      if (kind == 'kitten' && adj.isCat) continue;

      final br = r + 2 * dr;
      final bc = c + 2 * dc;
      // Line of 2+ blocks: if cell behind is on-board and occupied, neither moves
      if (inBounds(br, bc) && board[br][bc] != null) continue;

      nextB[ar][ac] = null;
      if (inBounds(br, bc)) {
        nextB[br][bc] = adj;
        pushed.add({
          'fromR': ar,
          'fromC': ac,
          'toR': br,
          'toC': bc,
          'owner': adj.owner,
          'kind': adj.kind,
          'offBed': false,
        });
      } else {
        // Pushed off the 6x6 bed -> returns to owner's reserve pool
        if (adj.isKitten) {
          nextK[adj.owner]++;
        } else {
          nextC[adj.owner]++;
        }
        pushed.add({
          'fromR': ar,
          'fromC': ac,
          'toR': br,
          'toC': bc,
          'owner': adj.owner,
          'kind': adj.kind,
          'offBed': true,
        });
      }
    }

    // Check 3-in-a-rows and 8-on-bed graduation/victory for active player `seat`
    final lines = findThreeInARows(seat, nextB);
    for (final line in lines) {
      final allCats = line.every((pos) => nextB[pos.$1][pos.$2]!.isCat);
      if (allCats) {
        return (
          nextBoard: nextB,
          nextKittens: nextK,
          nextCats: nextC,
          pushed: pushed,
          graduated: line,
          won: true,
          winType: 'three_cats',
        );
      }
    }

    final onBedCount = boardPieceCount(seat, nextB);
    final onBedCats = boardCatCount(seat, nextB);
    if (onBedCount >= 8 && onBedCats >= 8) {
      return (
        nextBoard: nextB,
        nextKittens: nextK,
        nextCats: nextC,
        pushed: pushed,
        graduated: const [],
        won: true,
        winType: 'eight_cats',
      );
    }

    final graduated = <(int, int)>[];
    if (lines.isNotEmpty) {
      // Pick the 3-in-a-row with the most kittens to maximize upgrade value
      lines.sort((a, b) {
        final ka = a.where((pos) => nextB[pos.$1][pos.$2]!.isKitten).length;
        final kb = b.where((pos) => nextB[pos.$1][pos.$2]!.isKitten).length;
        return kb.compareTo(ka);
      });
      final chosen = lines.first;
      for (final (gr, gc) in chosen) {
        nextB[gr][gc] = null;
        nextC[seat]++; // Both graduated kittens and returning cats go to `cats` pool
        graduated.add((gr, gc));
      }
    } else if (onBedCount >= 8) {
      // All 8 pieces are on the bed (with at least 1 kitten): graduate 1 kitten into a cat
      (int, int)? pickKitten;
      var maxEdgeScore = -1;
      for (var rr = 0; rr < kSize; rr++) {
        for (var cc = 0; cc < kSize; cc++) {
          final p = nextB[rr][cc];
          if (p != null && p.owner == seat && p.isKitten) {
            final edgeScore = (rr * 2 - 5).abs() + (cc * 2 - 5).abs();
            if (edgeScore > maxEdgeScore) {
              maxEdgeScore = edgeScore;
              pickKitten = (rr, cc);
            }
          }
        }
      }
      if (pickKitten != null) {
        nextB[pickKitten.$1][pickKitten.$2] = null;
        nextC[seat]++;
        graduated.add(pickKitten);
      }
    }

    return (
      nextBoard: nextB,
      nextKittens: nextK,
      nextCats: nextC,
      pushed: pushed,
      graduated: graduated,
      won: false,
      winType: null,
    );
  }

  List<Map<String, dynamic>> legalMoves(int seat) {
    final res = <Map<String, dynamic>>[];
    final kinds = <String>[
      if (kittens[seat] > 0) 'kitten',
      if (cats[seat] > 0) 'cat',
    ];
    for (final k in kinds) {
      for (var r = 0; r < kSize; r++) {
        for (var c = 0; c < kSize; c++) {
          if (board[r][c] == null) {
            res.add({'type': 'place', 'r': r, 'c': c, 'kind': k});
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
    if (type != 'place') throw GameError('未知操作类型：$type');

    final r = asInt(action['r'], -1);
    final c = asInt(action['c'], -1);
    final defaultKind = cats[seat] > 0 && kittens[seat] == 0 ? 'cat' : 'kitten';
    final kind = asStr(action['kind'], defaultKind);

    if (!inBounds(r, c)) throw GameError('床垫坐标 ($r, $c) 越界');
    if (board[r][c] != null) throw GameError('目标格 ($r, $c) 已有猫咪');
    if (kind != 'kitten' && kind != 'cat') throw GameError('无效的猫咪类型：$kind');
    if (kind == 'kitten' && kittens[seat] <= 0) throw GameError('储备池中没有可用小猫');
    if (kind == 'cat' && cats[seat] <= 0) throw GameError('储备池中没有可用大猫');

    final sim = simulatePlace(seat, r, c, kind)!;
    board = sim.nextBoard;
    kittens = sim.nextKittens;
    cats = sim.nextCats;
    moveCount++;

    final pieceLabel = kind == 'cat' ? '大猫🐈' : '小猫🐱';
    lastMove = {
      'type': 'place',
      'seat': seat,
      'r': r,
      'c': c,
      'kind': kind,
      'pushed': sim.pushed,
      'graduated': [
        for (final (gr, gc) in sim.graduated) [gr, gc],
      ],
    };

    if (sim.won) {
      if (sim.winType == 'three_cats') {
        _endGame(seat, '${name(seat)} 在 ($r, $c) 落下$pieceLabel，达成三只大猫连线，赢得胜利！');
      } else {
        _endGame(seat, '${name(seat)} 在床上集齐全部 8 只大猫，赢得胜利！');
      }
      return;
    }

    if (sim.graduated.isNotEmpty) {
      host.log(
        '${name(seat)} 在 ($r, $c) 放置$pieceLabel（推开 ${sim.pushed.length} 子），达成三连毕业升级为大猫🐈！',
      );
    } else if (sim.pushed.isNotEmpty) {
      host.log('${name(seat)} 在 ($r, $c) 放置$pieceLabel，Boop 推开了 ${sim.pushed.length} 只猫咪！');
    } else {
      host.log('${name(seat)} 在 ($r, $c) 放置$pieceLabel');
    }

    final opp = 1 - seat;
    turn = opp;

    if (legalMoves(opp).isEmpty) {
      _endGame(seat, '${name(opp)} 已无合法落子位置，${name(seat)} 获胜！');
      return;
    }

    if (moveCount >= 140) {
      final totalCats0 = cats[0] + boardCatCount(0);
      final totalCats1 = cats[1] + boardCatCount(1);
      final score0 = totalCats0 * 10 + boardPieceCount(0);
      final score1 = totalCats1 * 10 + boardPieceCount(1);
      if (score0 > score1) {
        _endGame(0, '达到回合上限，${name(0)}（大猫 $totalCats0 只）领先获胜！');
      } else if (score1 > score0) {
        _endGame(1, '达到回合上限，${name(1)}（大猫 $totalCats1 只）领先获胜！');
      } else {
        _endGame(-1, '达到回合上限，双方势均力敌握手言和！');
      }
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final moves = legalMoves(seat);
    if (moves.isEmpty) return null;

    // Always take an immediate winning move
    for (final m in moves) {
      final sim = simulatePlace(seat, m['r'] as int, m['c'] as int, m['kind'] as String)!;
      if (sim.won) return m;
    }

    if (botLevel <= 0) {
      return moves[rng.nextInt(moves.length)];
    }

    final opp = 1 - seat;
    final myTotalCatsBefore = cats[seat] + boardCatCount(seat);
    var bestScore = -1e9;
    var bestMoves = <Map<String, dynamic>>[];

    for (final m in moves) {
      final r = m['r'] as int;
      final c = m['c'] as int;
      final kind = m['kind'] as String;
      final sim = simulatePlace(seat, r, c, kind)!;

      var val = 0.0;
      final myTotalCatsAfter = sim.nextCats[seat] + boardCatCount(seat, sim.nextBoard);
      final catsUpgraded = myTotalCatsAfter - myTotalCatsBefore;
      if (catsUpgraded > 0) {
        val += catsUpgraded * 90.0;
      } else if (sim.graduated.isNotEmpty) {
        val += 30.0;
      }

      if (kind == 'cat') val += 8.0;

      // Evaluate pushes: pushing opponent off bed or breaking opponent formations is great
      for (final p in sim.pushed) {
        final pOwner = p['owner'] as int;
        final offBed = p['offBed'] == true;
        if (pOwner == opp) {
          val += offBed ? 18.0 : 6.0;
        } else {
          val -= offBed ? 10.0 : 2.0;
        }
      }

      // Evaluate board alignment & center control on sim.nextBoard
      for (var rr = 0; rr < kSize; rr++) {
        for (var cc = 0; cc < kSize; cc++) {
          final p = sim.nextBoard[rr][cc];
          if (p == null) continue;
          final centerBonus = (2.5 - (rr - 2.5).abs()) + (2.5 - (cc - 2.5).abs());
          if (p.owner == seat) {
            val += centerBonus * (p.isCat ? 2.5 : 1.2);
          } else {
            val -= centerBonus * (p.isCat ? 2.5 : 1.0);
          }
        }
      }

      // Count 2-in-a-row pairs on sim.nextBoard
      val += _alignmentScore(seat, sim.nextBoard) * 1.2;
      val -= _alignmentScore(opp, sim.nextBoard) * 1.4;

      val += rng.nextDouble() * 0.5;
      if (val > bestScore) {
        bestScore = val;
        bestMoves = [m];
      }
    }

    return bestMoves[rng.nextInt(bestMoves.length)];
  }

  static double _alignmentScore(int seat, List<List<BoopPiece?>> grid) {
    var score = 0.0;
    for (var r = 0; r < kSize; r++) {
      for (var c = 0; c < kSize; c++) {
        for (final (dr, dc) in kLineAxes) {
          final r2 = r + dr * 2;
          final c2 = c + dc * 2;
          if (!inBounds(r2, c2)) continue;
          var myCnt = 0;
          var catCnt = 0;
          var blocked = false;
          for (var k = 0; k < 3; k++) {
            final p = grid[r + dr * k][c + dc * k];
            if (p != null) {
              if (p.owner == seat) {
                myCnt++;
                if (p.isCat) catCnt++;
              } else {
                blocked = true;
              }
            }
          }
          if (!blocked && myCnt == 2) {
            score += catCnt == 2 ? 28.0 : 12.0;
          }
        }
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
        for (var r = 0; r < kSize; r++)
          [
            for (var c = 0; c < kSize; c++) board[r][c]?.toJson(),
          ],
      ],
      'kittens': List<int>.of(kittens),
      'cats': List<int>.of(cats),
      'boardCounts': [boardPieceCount(0), boardPieceCount(1)],
      'boardCats': [boardCatCount(0), boardCatCount(1)],
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
