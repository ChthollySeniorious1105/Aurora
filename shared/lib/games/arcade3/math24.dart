import 'dart:math';

import '../../src/engine.dart';
import 'a3_util.dart';

/// Exact rational number `n / d` with `d > 0` and `gcd(|n|, d) == 1`.
class Frac {
  final int n;
  final int d;
  const Frac._(this.n, this.d);

  factory Frac(int n, [int d = 1]) {
    if (d == 0) throw ArgumentError('Zero denominator');
    if (n == 0) return const Frac._(0, 1);
    final sign = d < 0 ? -1 : 1;
    final nn = n * sign;
    final dd = d * sign;
    final g = _gcd(nn.abs(), dd);
    return Frac._(nn ~/ g, dd ~/ g);
  }

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = a % b;
      a = b;
      b = t;
    }
    return a == 0 ? 1 : a;
  }

  bool get is24 => n == 24 && d == 1;
  bool get isZero => n == 0;

  Frac? apply(String op, Frac other) {
    switch (op) {
      case '+':
        return Frac(n * other.d + other.n * d, d * other.d);
      case '-':
        return Frac(n * other.d - other.n * d, d * other.d);
      case '*':
      case '×':
        return Frac(n * other.n, d * other.d);
      case '/':
      case '÷':
        if (other.n == 0) return null;
        return Frac(n * other.d, d * other.n);
      default:
        return null;
    }
  }

  @override
  String toString() => d == 1 ? '$n' : '$n/$d';

  @override
  bool operator ==(Object other) => other is Frac && n == other.n && d == other.d;

  @override
  int get hashCode => Object.hash(n, d);
}

class Math24Item {
  final Frac val;
  final String expr;
  const Math24Item(this.val, this.expr);

  factory Math24Item.fromInt(int v) => Math24Item(Frac(v), '$v');

  Map<String, dynamic> toJson() => {
        'n': val.n,
        'd': val.d,
        'txt': val.toString(),
        'expr': expr,
      };
}

/// Solver and generator for 24-point puzzles.
class Math24Solver {
  static const ops = ['+', '-', '*', '/'];
  static const opSymbols = {'+': '+', '-': '-', '*': '×', '/': '÷'};

  /// Combine [items] at indices [a] and [b] using [op].
  /// Places the new item at `min(a, b)` and removes `max(a, b)`.
  static List<Math24Item>? combine(List<Math24Item> items, int a, int b, String op) {
    if (a < 0 || b < 0 || a >= items.length || b >= items.length || a == b) return null;
    final normOp = op == '×' ? '*' : (op == '÷' ? '/' : op);
    if (!ops.contains(normOp)) return null;
    final ia = items[a], ib = items[b];
    final res = ia.val.apply(normOp, ib.val);
    if (res == null) return null;
    final sym = opSymbols[normOp]!;
    final exprA = ia.expr.contains(' ') ? '(${ia.expr})' : ia.expr;
    final exprB = ib.expr.contains(' ') ? '(${ib.expr})' : ib.expr;
    final combined = Math24Item(res, '$exprA $sym $exprB');
    final lo = min(a, b), hi = max(a, b);
    final next = <Math24Item>[];
    for (var i = 0; i < items.length; i++) {
      if (i == lo) {
        next.add(combined);
      } else if (i != hi) {
        next.add(items[i]);
      }
    }
    return next;
  }

  /// Finds a sequence of `{'type': 'op', 'a': a, 'b': b, 'op': op}` actions
  /// and the final expression that reaches 24 from [items], or null if impossible.
  static (List<Map<String, dynamic>>, String)? solveItems(List<Math24Item> items) {
    if (items.isEmpty) return null;
    if (items.length == 1) {
      return items[0].val.is24 ? (<Map<String, dynamic>>[], '${items[0].expr} = 24') : null;
    }
    for (var a = 0; a < items.length; a++) {
      for (var b = 0; b < items.length; b++) {
        if (a == b) continue;
        for (final op in ops) {
          // Commutative pruning for + and *
          if ((op == '+' || op == '*') && a > b) continue;
          final next = combine(items, a, b, op);
          if (next == null) continue;
          final sub = solveItems(next);
          if (sub != null) {
            return ([{'type': 'op', 'a': a, 'b': b, 'op': op}, ...sub.$1], sub.$2);
          }
        }
      }
    }
    return null;
  }

  static (List<Map<String, dynamic>>, String)? solveInts(List<int> nums) =>
      solveItems([for (final v in nums) Math24Item.fromInt(v)]);

  static bool canMake24(List<int> nums) => solveInts(nums) != null;

  /// Generates 4 numbers in `1..maxNum` guaranteed solvable to 24.
  static (List<int>, String) deal(Random rng, int maxNum) {
    for (var tries = 0; tries < 500; tries++) {
      final nums = [for (var i = 0; i < 4; i++) 1 + rng.nextInt(maxNum)];
      final sol = solveInts(nums);
      if (sol != null) return (nums, sol.$2);
    }
    // Guaranteed fallback
    const fallback = [3, 3, 8, 8];
    return (List.of(fallback), solveInts(fallback)!.$2);
  }
}

/// 算术24点 (1-8 人).
class Math24Game extends GameEngine {
  Math24Game(super.setup);

  static const roundMaxSec = 60;
  static const revealTicks = 2;

  late int totalRounds;
  late int maxNum;
  int round = 0;
  int roundSec = 0;
  int revealLeft = 0;
  int moves = 0;
  int roundSolvers = 0;
  List<int> currentNums = const [];
  String currentSolution = '';
  late List<Math24Player> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a3Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 900, 2 => 350, _ => 600 };

  @override
  void resign(int seat) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能认输');
    final p = ps[seat];
    if (p.resignNo > 0) throw GameError('你已认输');
    p.resignNo = ++_resigns;
    p.status = 'resigned';
    host.log('${name(seat)} 认输');
    final still = [for (var s = 0; s < players; s++) if (ps[s].resignNo == 0) s];
    if (still.isEmpty || (players > 1 && still.length <= 1)) {
      _finish(still.isEmpty ? '所有人都已认输' : '其他人都已认输');
    } else {
      _checkRoundComplete();
    }
  }

  @override
  void start() {
    totalRounds = setup.opt<int>('rounds', 5) == 10 ? 10 : 5;
    maxNum = setup.opt<int>('maxNum', 13) == 10 ? 10 : 13;
    ps = [for (var s = 0; s < players; s++) Math24Player()];
    host.log('算术24点开始（共 $totalRounds 题，数字 1~$maxNum）！用加减乘除将 4 个数合成为 24，越快完成得分越高！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    revealLeft = 0;
    roundSolvers = 0;
    final (nums, sol) = Math24Solver.deal(rng, maxNum);
    currentNums = nums;
    currentSolution = sol;
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(nums);
    }
  }

  void _clock() {
    if (over) return;
    if (revealLeft > 0) {
      revealLeft--;
      if (revealLeft <= 0) {
        if (round >= totalRounds) {
          _finish('全部 $totalRounds 题已完成');
          return;
        }
        _startRound(round + 1);
      }
      if (!over) host.schedule(1000, _clock);
      return;
    }
    roundSec++;
    if (roundSec >= roundMaxSec) {
      _endRound('本题时间到');
    }
    if (!over) host.schedule(1000, _clock);
  }

  bool _activeInRound(int s) => ps[s].resignNo == 0 && ps[s].status == 'play';

  @override
  List<int> get waitingFor {
    if (over || revealLeft > 0) return const [];
    return a3Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  static String normOp(String raw) => switch (raw) {
        '×' || 'x' || 'X' || '*' => '*',
        '÷' || '/' => '/',
        '+' => '+',
        '-' => '-',
        _ => '',
      };

  @override
  void handle(int seat, Map<String, dynamic> a) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能操作');
    final type = asStr(a['type']);
    if (type == 'idle') return;
    final p = ps[seat];
    if (p.resignNo > 0) throw GameError('你已认输');

    if (type == 'next') {
      if (revealLeft > 0) {
        revealLeft = 0;
        if (round >= totalRounds) {
          _finish('全部 $totalRounds 题已完成');
        } else {
          _startRound(round + 1);
        }
      }
      return;
    }

    if (revealLeft > 0) throw GameError('正在展示本题结果，请稍候');
    if (p.status != 'play') throw GameError('你已完成本题');

    switch (type) {
      case 'op':
        final idxA = asInt(a['a']);
        final idxB = asInt(a['b']);
        final op = normOp(asStr(a['op']));
        if (op.isEmpty) throw GameError('运算符无效');
        if (idxA < 0 || idxB < 0 || idxA >= p.items.length || idxB >= p.items.length || idxA == idxB) {
          throw GameError('请选择两个不同的数字');
        }
        final ia = p.items[idxA], ib = p.items[idxB];
        if (op == '/' && ib.val.isZero) throw GameError('除数不能为 0');
        final next = Math24Solver.combine(p.items, idxA, idxB, op);
        if (next == null) throw GameError('计算无效');
        p.pushHistory();
        final sym = Math24Solver.opSymbols[op]!;
        final resItem = next[min(idxA, idxB)];
        p.steps.add('${ia.val} $sym ${ib.val} = ${resItem.val}');
        p.items = next;
        moves++;
        if (p.items.length == 1 && p.items[0].val.is24) {
          _markSolved(seat, p.items[0].expr);
        }

      case 'solve':
        final rawSteps = a['steps'];
        if (rawSteps is! List || rawSteps.length != 3) {
          throw GameError('需要提交完整的 3 步运算');
        }
        var cur = [for (final v in currentNums) Math24Item.fromInt(v)];
        final logs = <String>[];
        for (final st in rawSteps) {
          if (st is! Map) throw GameError('步骤格式错误');
          final idxA = asInt(st['a']);
          final idxB = asInt(st['b']);
          final op = normOp(asStr(st['op']));
          if (op.isEmpty) throw GameError('运算符无效');
          if (idxA < 0 || idxB < 0 || idxA >= cur.length || idxB >= cur.length || idxA == idxB) {
            throw GameError('步骤索引无效');
          }
          if (op == '/' && cur[idxB].val.isZero) throw GameError('除数不能为 0');
          final ia = cur[idxA], ib = cur[idxB];
          final next = Math24Solver.combine(cur, idxA, idxB, op);
          if (next == null) throw GameError('计算无效');
          final sym = Math24Solver.opSymbols[op]!;
          final resItem = next[min(idxA, idxB)];
          logs.add('${ia.val} $sym ${ib.val} = ${resItem.val}');
          cur = next;
        }
        if (cur.length != 1 || !cur[0].val.is24) {
          throw GameError('计算结果不等于 24');
        }
        p.pushHistory();
        p.items = cur;
        p.steps
          ..clear()
          ..addAll(logs);
        moves++;
        _markSolved(seat, cur[0].expr);

      case 'undo':
        if (p.history.isEmpty) throw GameError('没有可撤销的步骤');
        p.popHistory();
        moves++;

      case 'reset':
        p.resetWorkspace(currentNums);
        moves++;

      case 'skip':
      case 'pass':
        p.status = 'skip';
        p.lastRoundPts = 0;
        moves++;
        host.log('${name(seat)} 跳过了第 $round 题');
        _checkRoundComplete();

      default:
        throw GameError('未知操作');
    }
  }

  void _markSolved(int seat, String expr) {
    final p = ps[seat];
    roundSolvers++;
    final pts = roundSolvers == 1 ? 10 : (roundSolvers == 2 ? 8 : 6);
    p.status = 'solved';
    p.solveRank = roundSolvers;
    p.lastRoundPts = pts;
    p.score += pts;
    p.solvedCount++;
    p.totalSolveSec += roundSec;
    p.lastExpr = '$expr = 24';
    host.log('${name(seat)} 第 $roundSolvers 个算出 24（$expr = 24），+$pts 分！');
    _checkRoundComplete();
  }

  void _checkRoundComplete() {
    if (over || revealLeft > 0) return;
    if ([for (var s = 0; s < players; s++) if (_activeInRound(s)) s].isEmpty) {
      _endRound('全员完成第 $round 题');
    }
  }

  void _endRound(String reason) {
    lastRoundSummary = {
      'round': round,
      'nums': currentNums,
      'sol': currentSolution,
      'reason': reason,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            's': s,
            'status': ps[s].status,
            'pts': ps[s].lastRoundPts,
            'rank': ps[s].solveRank,
            'expr': ps[s].lastExpr,
          },
      ],
    };
    if (round >= totalRounds) {
      _finish('全部 $totalRounds 题已完成');
    } else {
      revealLeft = revealTicks;
    }
  }

  void _finish(String why) {
    if (over) return;
    over = true;
    revealLeft = 0;
    ranking = a3Ranking(players, (a, b) {
      final pa = ps[a], pb = ps[b];
      if (pa.resignNo != pb.resignNo) {
        return pa.resignNo == 0 ? -1 : (pb.resignNo == 0 ? 1 : pb.resignNo - pa.resignNo);
      }
      if (pa.score != pb.score) return pb.score - pa.score;
      if (pa.solvedCount != pb.solvedCount) return pb.solvedCount - pa.solvedCount;
      return pa.totalSolveSec - pb.totalSolveSec;
    }, (s) => {
          'score': ps[s].score,
          'solved': ps[s].solvedCount,
          'sec': ps[s].totalSolveSec,
        });
    host.log('游戏结束（$why）！冠军：${a3Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || revealLeft > 0 || seat < 0 || seat >= players) return null;
    if (!_activeInRound(seat)) return null;
    final p = ps[seat];
    // Easy bots occasionally pass when starting a round
    if (botLevel <= 0 && p.items.length == 4 && rng.nextInt(6) == 0) {
      return {'type': 'skip'};
    }
    final sol = Math24Solver.solveItems(p.items);
    if (sol == null || sol.$1.isEmpty) {
      return p.history.isNotEmpty ? {'type': 'reset'} : {'type': 'skip'};
    }
    return sol.$1.first;
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : null;
    return {
      'phase': over ? 'over' : (revealLeft > 0 ? 'reveal' : 'play'),
      'round': round,
      'totalRounds': totalRounds,
      'maxNum': maxNum,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'nums': currentNums,
      'sol': (over || revealLeft > 0) ? currentSolution : null,
      'items': me != null
          ? [for (final it in me.items) it.toJson()]
          : [for (final v in currentNums) Math24Item.fromInt(v).toJson()],
      'steps': me?.steps ?? const <String>[],
      'canUndo': me != null && me.history.isNotEmpty && me.status == 'play' && revealLeft == 0 && !over,
      'canReset': me != null && me.items.length < 4 && me.status == 'play' && revealLeft == 0 && !over,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            'score': ps[s].score,
            'solved': ps[s].solvedCount,
            'status': ps[s].status,
            'rank': ps[s].solveRank,
            'pts': ps[s].lastRoundPts,
            'leftCards': ps[s].items.length,
            'expr': (over || revealLeft > 0 || s == seat) ? ps[s].lastExpr : null,
          },
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class Math24Player {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'skip' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  String? lastExpr;
  List<Math24Item> items = [];
  List<String> steps = [];
  final List<(List<Math24Item>, List<String>)> history = [];

  void resetForRound(List<int> nums) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    lastExpr = null;
    resetWorkspace(nums);
  }

  void resetWorkspace(List<int> nums) {
    items = [for (final v in nums) Math24Item.fromInt(v)];
    steps = [];
    history.clear();
  }

  void pushHistory() {
    history.add((List.of(items), List.of(steps)));
  }

  void popHistory() {
    if (history.isEmpty) return;
    final (prevItems, prevSteps) = history.removeLast();
    items = prevItems;
    steps = prevSteps;
  }
}
