import '../../src/engine.dart';

/// 章鱼骰子吞并棋（Cephalopod）—— Mark Steere 经典无和局正交邻格骰点求和吞并抽象棋。
///
/// 核心规则：
/// - 棋盘为 `5×5`（标准模式，25 格）或 `3×3`（快速模式，9 格）正交网格。
/// - 每个格子 `(r, c)` 为空，或放置一枚归属玩家 `0/1`、点数为 `1..6` 的六面骰子。
/// - 回合行动（`{'type': 'place', 'r': r, 'c': c, 'capture': [[nr, nc], ...]}`）：
///   - 轮到你的回合时，任选棋盘上一个空格 `(r, c)`，检查其上下左右最多 4 个正交相邻格中已有的骰子集合 `N(r, c)`：
///   - **情形 A（强制吞并落子，点数 `2..6`）**：
///     - 若 `N(r, c)` 中存在**至少一个包含 `>= 2` 枚相邻骰子（不论敌我颜色）且点数之和 `sum(S) <= 6` 的子集 `S`**，则在该格落子时**必须**选择其中一个合法子集 `S`（2、3 或 4 枚正交相邻骰子），将 `S` 中的骰子全部移出棋盘，并在 `(r, c)` 放置一枚点数等于 `sum(S)` 的己方骰子！
///   - **情形 B（普通落子，点数 `1`）**：
///     - 仅当 `N(r, c)` 中**不存在任何点数之和 `<= 6` 的 `>= 2` 枚骰子子集**时，在 `(r, c)` 放置一枚点数为 `1` 的己方骰子（`capture: []`）！
/// - 胜负条件：
///   - 由于 `6` 点骰子与任何骰子之和均 `>= 7 > 6`，因此 `6` 点骰子永远无法被吞并。
///   - 当全部格子填满（25 格或 9 格），或任一玩家在场上拥有超过半数格子的 `6` 点不灭骰子（标准模式 `>= 13` 枚、快速模式 `>= 5` 枚）时，对局结束，场上己方颜色骰子总数更多的一方获胜（奇数总格数彻底消除平局）！
class CephalopodGame extends GameEngine {
  CephalopodGame(super.setup);

  static const List<(int, int)> kOrthoDirs = [
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
  ];

  late String mode;
  late int boardSize;
  late List<List<int>> owner; // -1 empty, 0 P0, 1 P1
  late List<List<int>> pips; // 0 empty, 1..6 occupied

  int turn = 0;
  bool over = false;
  int? winner;
  String? winReason;
  List<int>? _placings;
  int moveCount = 0;
  Map<String, dynamic>? lastMove;

  int get totalCells => boardSize * boardSize;

  int get majorityThreshold => totalCells ~/ 2 + 1;

  bool inBounds(int r, int c) => r >= 0 && r < boardSize && c >= 0 && c < boardSize;

  Map<String, int>? cellAt(int r, int c) {
    if (!inBounds(r, c) || pips[r][c] <= 0) return null;
    return {'owner': owner[r][c], 'pips': pips[r][c]};
  }

  void setDie(int r, int c, int? cellOwner, int cellPips) {
    if (!inBounds(r, c)) return;
    if (cellOwner == null || cellOwner < 0 || cellPips <= 0) {
      owner[r][c] = -1;
      pips[r][c] = 0;
    } else {
      owner[r][c] = cellOwner;
      pips[r][c] = cellPips;
    }
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    boardSize = mode == 'quick' ? 3 : 5;
    owner = List.generate(boardSize, (_) => List<int>.filled(boardSize, -1));
    pips = List.generate(boardSize, (_) => List<int>.filled(boardSize, 0));

    turn = 0;
    over = false;
    winner = null;
    winReason = null;
    _placings = null;
    moveCount = 0;
    lastMove = null;
  }

  List<(int, int)> occupiedNeighbors(int r, int c) {
    final res = <(int, int)>[];
    for (final (dr, dc) in kOrthoDirs) {
      final nr = r + dr;
      final nc = c + dc;
      if (inBounds(nr, nc) && pips[nr][nc] > 0) {
        res.add((nr, nc));
      }
    }
    return res;
  }

  /// Returns all subsets `S` of orthogonally adjacent occupied cells around `(r, c)`
  /// such that `S.length >= 2` and the sum of pips in `S` is `<= 6`.
  List<List<(int, int)>> validCaptureSubsets(int r, int c) {
    final nbrs = occupiedNeighbors(r, c);
    final n = nbrs.length;
    if (n < 2) return const [];

    final subsets = <List<(int, int)>>[];
    final totalMasks = 1 << n;
    for (var mask = 1; mask < totalMasks; mask++) {
      // Count bits
      var bitCount = 0;
      var sumPips = 0;
      for (var i = 0; i < n; i++) {
        if ((mask & (1 << i)) != 0) {
          bitCount++;
          final (nr, nc) = nbrs[i];
          sumPips += pips[nr][nc];
        }
      }
      if (bitCount >= 2 && sumPips <= 6) {
        subsets.add([
          for (var i = 0; i < n; i++)
            if ((mask & (1 << i)) != 0) nbrs[i],
        ]);
      }
    }
    return subsets;
  }

  int diceCount(int seat) {
    var count = 0;
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (pips[r][c] > 0 && owner[r][c] == seat) count++;
      }
    }
    return count;
  }

  int sixPipCount(int seat) {
    var count = 0;
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (pips[r][c] == 6 && owner[r][c] == seat) count++;
      }
    }
    return count;
  }

  int get totalOccupied => diceCount(0) + diceCount(1);

  static List<(int, int)> _parseCaptureCoords(Object? raw) {
    if (raw is! List) return const [];
    final out = <(int, int)>[];
    for (final item in raw) {
      if (item is List && item.length >= 2) {
        out.add((asInt(item[0], -1), asInt(item[1], -1)));
      } else if (item is Map) {
        out.add((asInt(item['r'], -1), asInt(item['c'], -1)));
      }
    }
    return out;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');

    final type = asStr(action['type']);
    if (type != 'place') throw GameError('未知操作类型：$type');

    final r = asInt(action['r'], -1);
    final c = asInt(action['c'], -1);
    if (!inBounds(r, c)) throw GameError('目标位置越界');
    if (pips[r][c] > 0) throw GameError('目标格已有骰子');

    final capCoords = _parseCaptureCoords(action['capture']);
    final possibleCaptures = validCaptureSubsets(r, c);

    int placedPips;
    final capturedDetails = <Map<String, int>>[];

    if (possibleCaptures.isNotEmpty) {
      if (capCoords.length < 2) {
        throw GameError('该位置存在点数之和不超过 6 的相邻骰子组合，必须选择至少 2 枚正交相邻骰子进行吞并');
      }
      final seen = <(int, int)>{};
      var sumPips = 0;
      for (final (nr, nc) in capCoords) {
        if (!inBounds(nr, nc)) throw GameError('吞并坐标越界');
        if ((nr - r).abs() + (nc - c).abs() != 1) {
          throw GameError('只能吞并目标格上下左右正交相邻的骰子');
        }
        if (pips[nr][nc] <= 0) {
          throw GameError('被指定吞并的相邻格 ($nr, $nc) 上没有骰子');
        }
        if (!seen.add((nr, nc))) {
          throw GameError('不能重复指定同一个相邻骰子');
        }
        sumPips += pips[nr][nc];
      }
      if (sumPips > 6) {
        throw GameError('被吞并骰子的点数之和（$sumPips）不能超过 6');
      }

      for (final (nr, nc) in capCoords) {
        capturedDetails.add({
          'r': nr,
          'c': nc,
          'owner': owner[nr][nc],
          'pips': pips[nr][nc],
        });
        owner[nr][nc] = -1;
        pips[nr][nc] = 0;
      }
      placedPips = sumPips;
      owner[r][c] = seat;
      pips[r][c] = placedPips;
      host.log('${name(seat)} 在 (${r + 1}, ${c + 1}) 吞并 ${capCoords.length} 枚相邻骰子，合成为 $placedPips 点骰子！');
    } else {
      if (capCoords.isNotEmpty) {
        throw GameError('该位置没有可吞并的相邻骰子组合，不能指定捕获目标');
      }
      placedPips = 1;
      owner[r][c] = seat;
      pips[r][c] = 1;
      host.log('${name(seat)} 在 (${r + 1}, ${c + 1}) 放置 1 点骰子');
    }

    moveCount++;
    lastMove = {
      'seat': seat,
      'r': r,
      'c': c,
      'pips': placedPips,
      'captured': capturedDetails,
    };

    // Check win conditions:
    // 1. A player reaches >= majorityThreshold (13 on 5x5, 5 on 3x3) uncapturable 6-pip dice
    // 2. All cells on the board are filled
    final c0 = diceCount(0);
    final c1 = diceCount(1);
    final s0 = sixPipCount(0);
    final s1 = sixPipCount(1);

    if (s0 >= majorityThreshold || s1 >= majorityThreshold) {
      over = true;
      final winSeat = s0 >= majorityThreshold ? 0 : 1;
      winner = winSeat;
      _placings = winSeat == 0 ? [1, 2] : [2, 1];
      winReason =
          '${name(winSeat)} 已铸就 ${ winSeat == 0 ? s0 : s1 } 枚不可吞并的 6 点骰子（超过半数棋盘格 $majorityThreshold/$totalCells），${name(winSeat)} 锁定胜局！';
      host.log(winReason!);
      return;
    }

    if (c0 + c1 >= totalCells) {
      over = true;
      final winSeat = c0 > c1 ? 0 : 1;
      winner = winSeat;
      _placings = winSeat == 0 ? [1, 2] : [2, 1];
      winReason = '棋盘全部填满！${name(0)} $c0 枚骰子 vs ${name(1)} $c1 枚骰子，${name(winSeat)} 获胜！';
      host.log(winReason!);
      return;
    }

    turn = 1 - turn;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    final candidates = <Map<String, dynamic>>[];
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (pips[r][c] > 0) continue;
        final subs = validCaptureSubsets(r, c);
        if (subs.isEmpty) {
          candidates.add({
            'type': 'place',
            'r': r,
            'c': c,
            'capture': <List<int>>[],
            '_subsets': const <(int, int)>[],
            '_pips': 1,
          });
        } else {
          for (final sub in subs) {
            var sumP = 0;
            for (final (nr, nc) in sub) {
              sumP += pips[nr][nc];
            }
            candidates.add({
              'type': 'place',
              'r': r,
              'c': c,
              'capture': [
                for (final (nr, nc) in sub) [nr, nc],
              ],
              '_subsets': sub,
              '_pips': sumP,
            });
          }
        }
      }
    }

    if (candidates.isEmpty) return null;

    if (botLevel <= 0) {
      final pick = candidates[rng.nextInt(candidates.length)];
      return {
        'type': 'place',
        'r': pick['r'],
        'c': pick['c'],
        'capture': pick['capture'],
      };
    }

    final opp = 1 - seat;
    var bestScore = -1e9;
    var bestList = <Map<String, dynamic>>[];

    for (final cand in candidates) {
      final r = cand['r'] as int;
      final c = cand['c'] as int;
      final sub = cand['_subsets'] as List<(int, int)>;
      final newPips = cand['_pips'] as int;

      var val = 0.0;
      if (sub.isNotEmpty) {
        var enemyRemoved = 0;
        var friendlyRemoved = 0;
        for (final (nr, nc) in sub) {
          if (owner[nr][nc] == opp) {
            enemyRemoved++;
          } else {
            friendlyRemoved++;
          }
        }
        // Creating a 6-pip die is permanently uncapturable!
        if (newPips == 6) {
          val += 45.0;
        } else {
          val += newPips * 3.5;
        }
        val += enemyRemoved * 16.0 - friendlyRemoved * 9.0;
      } else {
        // Non-capture placement of a 1-pip die
        val += 8.0;
      }

      if (botLevel >= 2) {
        // Check if opponent can immediately capture our newly placed die on the next turn
        if (newPips < 6) {
          // Temporarily apply
          final saved = <(int, int, int, int)>[];
          for (final (nr, nc) in sub) {
            saved.add((nr, nc, owner[nr][nc], pips[nr][nc]));
            owner[nr][nc] = -1;
            pips[nr][nc] = 0;
          }
          owner[r][c] = seat;
          pips[r][c] = newPips;

          var canBeCapturedInto6 = false;
          var canBeCaptured = false;
          for (final (dr, dc) in kOrthoDirs) {
            final er = r + dr;
            final ec = c + dc;
            if (!inBounds(er, ec) || pips[er][ec] > 0) continue;
            final oppSubs = validCaptureSubsets(er, ec);
            for (final os in oppSubs) {
              if (os.contains((r, c))) {
                canBeCaptured = true;
                var s = 0;
                for (final (xr, xc) in os) {
                  s += pips[xr][xc];
                }
                if (s == 6) canBeCapturedInto6 = true;
              }
            }
          }

          // Undo temporary state
          owner[r][c] = -1;
          pips[r][c] = 0;
          for (final (nr, nc, o, p) in saved) {
            owner[nr][nc] = o;
            pips[nr][nc] = p;
          }

          if (canBeCapturedInto6) {
            val -= 24.0;
          } else if (canBeCaptured) {
            val -= 10.0;
          }
        }
      }

      if (val > bestScore + 1e-6) {
        bestScore = val;
        bestList = [cand];
      } else if ((val - bestScore).abs() <= 1e-6) {
        bestList.add(cand);
      }
    }

    final chosen = bestList[rng.nextInt(bestList.length)];
    return {
      'type': 'place',
      'r': chosen['r'],
      'c': chosen['c'],
      'capture': chosen['capture'],
    };
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (over) throw GameError('对局已结束');
    over = true;
    winner = 1 - seat;
    _placings = [for (var i = 0; i < players; i++) i == winner ? 1 : 2];
    winReason = '${name(seat)} 认输，${name(winner!)} 获胜！';
    host.log(winReason!);
  }

  @override
  bool get canDraw => true;

  @override
  void agreeDraw() {
    if (over) throw GameError('对局已结束');
    over = true;
    winner = -1;
    _placings = [1, 1];
    winReason = '双方同意和棋！';
    host.log(winReason!);
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => _placings;

  @override
  Map<String, dynamic> view(int seat) {
    final boardView = <List<Map<String, int>?>>[
      for (var r = 0; r < boardSize; r++)
        [
          for (var c = 0; c < boardSize; c++) cellAt(r, c),
        ],
    ];

    return {
      'mode': mode,
      'boardSize': boardSize,
      'totalCells': totalCells,
      'majorityThreshold': majorityThreshold,
      'board': boardView,
      'owners': [for (final row in owner) List<int>.of(row)],
      'pips': [for (final row in pips) List<int>.of(row)],
      'diceCounts': [diceCount(0), diceCount(1)],
      'sixCounts': [sixPipCount(0), sixPipCount(1)],
      'turn': turn,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'moveCount': moveCount,
      'lastMove': lastMove,
    };
  }
}
