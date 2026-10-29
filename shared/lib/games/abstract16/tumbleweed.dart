import '../../src/engine.dart';

/// 风滚草视线棋（Tumbleweed）—— Michaela 2020 BGG Golden Geek 最佳抽象棋得主。
///
/// 核心规则：
/// - 六角网格棋盘：快速模式半径 `3`（37 格），标准模式半径 `4`（61 格）。
/// - 初始布置：中心 `(0, 0)` 放置高度为 `2` 的中立棋堆（`owner = -1`）；
///   `(-1, 0)` 放置玩家 0（红方，`owner = 0`）高度为 `1` 的棋堆；
///   `(1, 0)` 放置玩家 1（白方，`owner = 1`）高度为 `1` 的棋堆。
/// - 视线定居法则（`settle`）：
///   - 对棋盘任意格 `(q, r)`，沿着 6 个正六角方向发射视线（每条射线遇到第一个非空格即停止，无论该格为己方、敌方或中立）。
///   - 统计 6 条射线上看到的己方棋堆总数 `losCount(seat, q, r)`。
///   - 玩家 `seat` 可以在 `(q, r)` 定居当且仅当：`losCount(seat, q, r) >= 1` 且 `losCount(seat, q, r) > height(q, r)`。
///   - 定居后，目标格 `(q, r)` 原有的棋堆（若有）被移除，替换为归属 `seat`、高度等于 `losCount(seat, q, r)` 的新棋堆。
/// - 终局与领地计分：
///   - 当双方连续跳过（`pass`），或某一方占领的格子数严格超过棋盘总格数的一半时，对局立即结束。
///   - 每位玩家得分 = 己方占领的格数 + 仅被己方棋堆视线看到的空格数（`losCount(seat) > 0 && losCount(1 - seat) == 0`）。
class TumbleweedGame extends GameEngine {
  TumbleweedGame(super.setup);

  static const List<(int, int)> kHexDirs = [
    (1, 0),
    (-1, 0),
    (0, 1),
    (0, -1),
    (1, -1),
    (-1, 1),
  ];

  late String mode;
  late int radius;
  late List<(int, int)> allHexes;

  /// Keyed by `'q,r'`. Height 0 means empty; when height > 0, owner is -1 (Neutral), 0 (P0), or 1 (P1).
  final Map<(int, int), int> _height = {};
  final Map<(int, int), int> _owner = {};

  int turn = 0;
  bool over = false;
  int? winner;
  String? winReason;
  List<int>? _placings;
  int consecutivePasses = 0;
  int moveCount = 0;
  Map<String, dynamic>? lastMove;

  int get totalHexes => allHexes.length;

  bool isValidHex(int q, int r) =>
      q.abs() <= radius && r.abs() <= radius && (q + r).abs() <= radius;

  int getHeight(int q, int r) => _height[(q, r)] ?? 0;

  /// Returns `-2` when empty, `-1` for neutral, `0` for P0, `1` for P1.
  int getOwner(int q, int r) => getHeight(q, r) > 0 ? (_owner[(q, r)] ?? -2) : -2;

  void setStack(int q, int r, int owner, int height) {
    if (!isValidHex(q, r)) return;
    if (height <= 0) {
      _height.remove((q, r));
      _owner.remove((q, r));
    } else {
      _height[(q, r)] = height;
      _owner[(q, r)] = owner;
    }
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    radius = mode == 'quick' ? 3 : 4;
    allHexes = [
      for (var r = -radius; r <= radius; r++)
        for (var q = -radius; q <= radius; q++)
          if ((q + r).abs() <= radius) (q, r),
    ];
    _height.clear();
    _owner.clear();

    // Standard Tumbleweed initial setup:
    // (0, 0) -> Neutral stack of height 2
    // (-1, 0) -> Player 0 stack of height 1
    // (1, 0) -> Player 1 stack of height 1
    setStack(0, 0, -1, 2);
    setStack(-1, 0, 0, 1);
    setStack(1, 0, 1, 1);

    turn = 0;
    over = false;
    winner = null;
    winReason = null;
    _placings = null;
    consecutivePasses = 0;
    moveCount = 0;
    lastMove = null;
  }

  /// Number of friendly stacks (`owner == seat`) visible from `(q, r)` along the 6 hex directions.
  /// Each ray stops at the first non-empty hex (`height > 0`) it encounters.
  int losCount(int seat, int q, int r) {
    if (!isValidHex(q, r)) return 0;
    var count = 0;
    for (final (dq, dr) in kHexDirs) {
      var step = 1;
      while (true) {
        final nq = q + dq * step;
        final nr = r + dr * step;
        if (!isValidHex(nq, nr)) break;
        final h = getHeight(nq, nr);
        if (h > 0) {
          if (getOwner(nq, nr) == seat) {
            count++;
          }
          break;
        }
        step++;
      }
    }
    return count;
  }

  bool canSettle(int seat, int q, int r) {
    if (!isValidHex(q, r)) return false;
    final los = losCount(seat, q, r);
    return los >= 1 && los > getHeight(q, r);
  }

  int occupiedCount(int seat) {
    var c = 0;
    for (final (q, r) in allHexes) {
      if (getHeight(q, r) > 0 && getOwner(q, r) == seat) c++;
    }
    return c;
  }

  int controlledEmptyCount(int seat) {
    var c = 0;
    final opp = 1 - seat;
    for (final (q, r) in allHexes) {
      if (getHeight(q, r) == 0) {
        if (losCount(seat, q, r) > 0 && losCount(opp, q, r) == 0) {
          c++;
        }
      }
    }
    return c;
  }

  List<int> get scores => [
        occupiedCount(0) + controlledEmptyCount(0),
        occupiedCount(1) + controlledEmptyCount(1),
      ];

  List<(int, int)> legalSettlements(int seat) => [
        for (final (q, r) in allHexes)
          if (canSettle(seat, q, r)) (q, r),
      ];

  void _finishByScore({String? prefix}) {
    over = true;
    final sc = scores;
    final occ0 = occupiedCount(0);
    final occ1 = occupiedCount(1);
    final emp0 = controlledEmptyCount(0);
    final emp1 = controlledEmptyCount(1);
    final summary =
        '${name(0)} ${sc[0]}分（占领$occ0+领地$emp0） vs ${name(1)} ${sc[1]}分（占领$occ1+领地$emp1）';
    if (sc[0] > sc[1]) {
      winner = 0;
      _placings = [1, 2];
      winReason = '${prefix != null ? '$prefix，' : ''}$summary，${name(0)} 获胜！';
    } else if (sc[1] > sc[0]) {
      winner = 1;
      _placings = [2, 1];
      winReason = '${prefix != null ? '$prefix，' : ''}$summary，${name(1)} 获胜！';
    } else {
      winner = -1;
      _placings = [1, 1];
      winReason = '${prefix != null ? '$prefix，' : ''}$summary，双方平局！';
    }
    host.log(winReason!);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');

    final type = asStr(action['type']);
    if (type == 'pass') {
      consecutivePasses++;
      moveCount++;
      lastMove = {'type': 'pass', 'seat': seat};
      host.log('${name(seat)} 选择跳过（Pass）');
      if (consecutivePasses >= 2) {
        _finishByScore(prefix: '双方连续跳过');
        return;
      }
      turn = 1 - turn;
      return;
    }

    if (type == 'settle') {
      final q = asInt(action['q'], 999);
      final r = asInt(action['r'], 999);
      if (!isValidHex(q, r)) throw GameError('目标六角格坐标越界');

      final los = losCount(seat, q, r);
      final oldH = getHeight(q, r);
      final oldOwner = getOwner(q, r);
      if (los < 1 || los <= oldH) {
        throw GameError('视线内可见己方棋堆数（$los）必须大于目标格当前高度（$oldH）且至少为 1');
      }

      setStack(q, r, seat, los);
      consecutivePasses = 0;
      moveCount++;
      lastMove = {
        'type': 'settle',
        'seat': seat,
        'q': q,
        'r': r,
        'height': los,
        'oldHeight': oldH,
        'oldOwner': oldOwner,
      };

      final actionVerb = oldH == 0
          ? '在 ($q, $r) 定居建立 $los 层棋堆'
          : (oldOwner == -1
              ? '吞并中心中立棋堆 ($q, $r) 建立 $los 层棋堆'
              : (oldOwner == seat
                  ? '在 ($q, $r) 加固棋堆至 $los 层'
                  : '在 ($q, $r) 以 $los 层视线压制取代敌方 $oldH 层棋堆'));
      host.log('${name(seat)} $actionVerb');

      final majority = totalHexes ~/ 2 + 1;
      if (occupiedCount(seat) >= majority) {
        _finishByScore(prefix: '${name(seat)} 已占领超过半数棋盘格（${occupiedCount(seat)}/$totalHexes）');
        return;
      }

      turn = 1 - turn;
      return;
    }

    throw GameError('未知操作类型：$type');
  }

  static int _hexDist(int q1, int r1, int q2, int r2) =>
      ((q1 - q2).abs() + (r1 - r2).abs() + ((q1 + r1) - (q2 + r2)).abs()) ~/ 2;

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    final opp = 1 - seat;
    final allLegal = legalSettlements(seat);

    // Filter out pointless self-overwrites on safe friendly stacks so games end cleanly
    final productive = <(int, int)>[];
    for (final (q, r) in allLegal) {
      final curOwner = getOwner(q, r);
      final curH = getHeight(q, r);
      if (curOwner != seat) {
        productive.add((q, r));
      } else {
        // Reinforcing own stack is only useful if opponent currently threatens it
        // and our new height prevents immediate recapture or reaches 6
        final oppLos = losCount(opp, q, r);
        final myLos = losCount(seat, q, r);
        if (oppLos > curH && myLos >= oppLos && moveCount < totalHexes * 2) {
          productive.add((q, r));
        }
      }
    }

    if (productive.isEmpty) {
      return {'type': 'pass'};
    }

    if (botLevel <= 0) {
      final pick = productive[rng.nextInt(productive.length)];
      return {'type': 'settle', 'q': pick.$1, 'r': pick.$2};
    }

    var bestScore = -1e9;
    var bestMoves = <(int, int)>[];

    for (final (q, r) in productive) {
      final myLos = losCount(seat, q, r);
      final oldH = getHeight(q, r);
      final oldOwner = getOwner(q, r);
      final oppLos = losCount(opp, q, r);

      var value = 0.0;
      if (oldOwner == opp) {
        value += 36.0 + oldH * 8.0;
      } else if (oldOwner == -1) {
        value += 28.0;
      } else if (oldOwner == -2) {
        value += 16.0;
        if (oppLos > 0) value += 6.0; // Contesting or stealing territory
      } else {
        value += 4.0;
      }

      value += myLos * 5.0;
      value += (radius - _hexDist(q, r, 0, 0)) * 2.0;

      // Vulnerability penalty if opponent can immediately recapture with higher LOS
      if (oppLos > myLos) {
        value -= 14.0;
      }

      if (botLevel >= 2) {
        // Simulate board score delta
        setStack(q, r, seat, myLos);
        final sc = scores;
        final diff = (sc[seat] - sc[opp]).toDouble();
        if (oldH == 0) {
          setStack(q, r, -2, 0);
        } else {
          setStack(q, r, oldOwner, oldH);
        }
        value += diff * 4.5;
      }

      if (value > bestScore + 1e-6) {
        bestScore = value;
        bestMoves = [(q, r)];
      } else if ((value - bestScore).abs() <= 1e-6) {
        bestMoves.add((q, r));
      }
    }

    final chosen = bestMoves[rng.nextInt(bestMoves.length)];
    return {'type': 'settle', 'q': chosen.$1, 'r': chosen.$2};
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
    final cells = <Map<String, dynamic>>[];
    for (final (q, r) in allHexes) {
      final h = getHeight(q, r);
      final o = getOwner(q, r);
      final los0 = losCount(0, q, r);
      final los1 = losCount(1, q, r);
      int territory = -1;
      if (h == 0) {
        if (los0 > 0 && los1 == 0) {
          territory = 0;
        } else if (los1 > 0 && los0 == 0) {
          territory = 1;
        }
      }
      cells.add({
        'q': q,
        'r': r,
        'owner': o,
        'height': h,
        'los0': los0,
        'los1': los1,
        'territory': territory,
      });
    }

    return {
      'mode': mode,
      'radius': radius,
      'totalHexes': totalHexes,
      'cells': cells,
      'turn': turn,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'scores': scores,
      'occupied': [occupiedCount(0), occupiedCount(1)],
      'controlledEmpty': [controlledEmptyCount(0), controlledEmptyCount(1)],
      'consecutivePasses': consecutivePasses,
      'moveCount': moveCount,
      'lastMove': lastMove,
    };
  }
}
