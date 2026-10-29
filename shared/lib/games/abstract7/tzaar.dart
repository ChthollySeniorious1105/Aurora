import 'dart:math';

import '../../src/engine.dart';

/// Radius-4 hexagonal board for TZAAR: 60 cells (61 cells minus the center pit `(0, 0)`).
const int tzaarRadius = 4;

final List<(int, int)> tzaarCoords = () {
  final list = <(int, int)>[];
  for (var r = -tzaarRadius; r <= tzaarRadius; r++) {
    final qMin = max(-tzaarRadius, -tzaarRadius - r);
    final qMax = min(tzaarRadius, tzaarRadius - r);
    for (var q = qMin; q <= qMax; q++) {
      if (q == 0 && r == 0) continue; // Center pit (0,0) is empty abyss!
      list.add((q, r));
    }
  }
  return List<(int, int)>.unmodifiable(list);
}();

final Map<(int, int), int> _tzaarCoordToIndex = {
  for (var i = 0; i < tzaarCoords.length; i++) tzaarCoords[i]: i,
};

/// Returns index `0..59`, or `-1` if off-board OR if `(q, r) == (0, 0)` (center pit).
int tzaarIndex(int q, int r) => _tzaarCoordToIndex[(q, r)] ?? -1;

const List<(int, int)> tzaarDirs = [
  (1, 0),
  (-1, 0),
  (0, 1),
  (0, -1),
  (1, -1),
  (-1, 1),
];

const List<String> tzaarTypeNames = ['沙皇(王冠)', '贵族(骑士)', '卫兵(庶民)'];
const List<String> tzaarTypeShort = ['皇', '骑', '兵'];

String tzaarCellLabel(int idx) {
  if (idx < 0 || idx >= tzaarCoords.length) return '?';
  final (q, r) = tzaarCoords[idx];
  final rowChar = String.fromCharCode(65 + (r + tzaarRadius));
  final colNum = q + tzaarRadius + 1;
  return '$rowChar$colNum';
}

/// 沙皇棋（TZAAR）— Kris Burm 星盘计划三兵种存亡与叠高猎杀名作
class Tzaar extends GameEngine {
  static const int tzaarPerPlayer = 6;
  static const int tzarraPerPlayer = 9;
  static const int tottPerPlayer = 15;

  String setupMode = 'standard';

  /// 60-cell arrays (`0..59`):
  /// `owner[i]`: `-1` empty, `0` White (Seat 0), `1` Black (Seat 1).
  /// `pieceType[i]`: `-1` empty, `0` Tzaar (王冠), `1` Tzarra (骑士), `2` Tott (卫兵).
  /// `height[i]`: `0` empty, `>= 1` stack height.
  late List<int> owner;
  late List<int> pieceType;
  late List<int> height;

  /// True on the very first turn of the game (Turn 0, Player 0 only gets 1 mandatory capture).
  bool isOpeningTurn = true;

  /// Current active player (`0` or `1`).
  int turn = 0;

  /// `1` = Mandatory Capture (Action 1); `2` = Choice: Capture / Strengthen / Pass (Action 2).
  int step = 1;

  int plies = 0;
  bool _over = false;
  int winner = -1; // 0, 1, or 2 (draw)
  List<int>? _placings;
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;

  Tzaar(super.setup);

  @override
  void start() {
    final rawSetup = setup.options['setup'] ?? setup.options['setupMode'] ?? 'standard';
    setupMode = rawSetup == 'random' ? 'random' : 'standard';

    final n = tzaarCoords.length; // 60
    owner = List.filled(n, -1);
    pieceType = List.filled(n, -1);
    height = List.filled(n, 0);

    if (setupMode == 'random') {
      final pool = <(int, int)>[
        for (var s = 0; s < 2; s++) ...[
          for (var i = 0; i < tzaarPerPlayer; i++) (s, 0),
          for (var i = 0; i < tzarraPerPlayer; i++) (s, 1),
          for (var i = 0; i < tottPerPlayer; i++) (s, 2),
        ],
      ];
      pool.shuffle(rng);
      for (var i = 0; i < n; i++) {
        owner[i] = pool[i].$1;
        pieceType[i] = pool[i].$2;
        height[i] = 1;
      }
    } else {
      _initStandardLayout();
    }

    isOpeningTurn = true;
    turn = 0;
    step = 1;
    plies = 0;
    _over = false;
    winner = -1;
    _placings = null;
    lastAction = null;
    result = '';
    note = '开局阶段：先手白方（${name(0)}）首回合仅执行 1 次强制吃子，随后每回合执行 2 步行动！';
  }

  void _initStandardLayout() {
    // Group the 60 cells into the 6 official ring/corner bands, sorted by angle around (0,0),
    // and alternate White (0) and Black (1) within each band so each player gets
    // exactly 6 Tzaars (0), 9 Tzarras (1), and 15 Totts (2).
    final bands = List.generate(6, (_) => <int>[]);
    final types = [0, 0, 1, 1, 2, 2];

    for (var i = 0; i < tzaarCoords.length; i++) {
      final (q, r) = tzaarCoords[i];
      final ring = max(q.abs(), max(r.abs(), (q + r).abs()));
      final isCorner = q == 0 || r == 0 || (q + r) == 0;
      if (ring == 1) {
        bands[0].add(i); // 6 cells -> Tzaar (0)
      } else if (ring == 2 && !isCorner) {
        bands[1].add(i); // 6 cells -> Tzaar (0)
      } else if (ring == 2 && isCorner) {
        bands[2].add(i); // 6 cells -> Tzarra (1)
      } else if (ring == 3 && !isCorner) {
        bands[3].add(i); // 12 cells -> Tzarra (1)
      } else if (ring == 3 && isCorner) {
        bands[4].add(i); // 6 cells -> Tott (2)
      } else {
        bands[5].add(i); // 24 cells -> Tott (2)
      }
    }

    for (var b = 0; b < bands.length; b++) {
      final list = bands[b];
      list.sort((a, c) {
        final (qa, ra) = tzaarCoords[a];
        final (qc, rc) = tzaarCoords[c];
        final angA = atan2(ra * 0.8660254, qa + ra * 0.5);
        final angC = atan2(rc * 0.8660254, qc + rc * 0.5);
        return angA.compareTo(angC);
      });
      final t = types[b];
      for (var k = 0; k < list.length; k++) {
        final idx = list[k];
        owner[idx] = (k + (b.isOdd ? 1 : 0)) % 2;
        pieceType[idx] = t;
        height[idx] = 1;
      }
    }
  }

  /// Counts how many stacks on the board are controlled by [seat] with top piece of [type] (`0..2`).
  int countType(int seat, int type) {
    var cnt = 0;
    for (var i = 0; i < tzaarCoords.length; i++) {
      if (height[i] > 0 && owner[i] == seat && pieceType[i] == type) {
        cnt++;
      }
    }
    return cnt;
  }

  List<int> typeCounts(int seat) => [
        countType(seat, 0),
        countType(seat, 1),
        countType(seat, 2),
      ];

  bool hasAllThreeTypes(int seat) =>
      countType(seat, 0) > 0 && countType(seat, 1) > 0 && countType(seat, 2) > 0;

  /// Finds the first occupied cell in each of the 6 hex directions from [from]
  /// (stopping at the board edge or the center pit `(0,0)`).
  List<int> visibleOccupiedTargets(int from) {
    if (from < 0 || from >= tzaarCoords.length || height[from] <= 0) return const [];
    final (q0, r0) = tzaarCoords[from];
    final out = <int>[];
    for (final (dq, dr) in tzaarDirs) {
      var cq = q0 + dq, cr = r0 + dr;
      while (true) {
        final idx = tzaarIndex(cq, cr);
        if (idx == -1) break; // Off-board or center pit (0,0)
        if (height[idx] > 0) {
          out.add(idx);
          break;
        }
        cq += dq;
        cr += dr;
      }
    }
    return out;
  }

  /// Returns legal destinations for stack at [from] controlled by [seat] on [forStep] (`1` or `2`).
  /// - If `forStep == 1` (or `isOpeningTurn`): only opponent stacks with `height[from] >= height[to]`.
  /// - If `forStep == 2` (and `!isOpeningTurn`): opponent stacks with `height[from] >= height[to]`
  ///   OR own stacks (provided covering the target doesn't eliminate [seat]'s last stack of that type).
  List<int> legalTargets(int from, {int? forStep}) {
    final st = forStep ?? step;
    if (from < 0 || from >= tzaarCoords.length || height[from] <= 0) return const [];
    final s = owner[from];
    if (s != 0 && s != 1) return const [];

    final allowStrengthen = st == 2 && !isOpeningTurn;
    final out = <int>[];
    for (final to in visibleOccupiedTargets(from)) {
      if (owner[to] == 1 - s) {
        if (height[from] >= height[to]) {
          out.add(to);
        }
      } else if (allowStrengthen && owner[to] == s) {
        final targetType = pieceType[to];
        final fromType = pieceType[from];
        if (fromType == targetType || countType(s, targetType) > 1) {
          out.add(to);
        }
      }
    }
    return out;
  }

  bool hasAnyCapture(int seat) {
    for (var i = 0; i < tzaarCoords.length; i++) {
      if (height[i] > 0 && owner[i] == seat) {
        if (legalTargets(i, forStep: 1).isNotEmpty) return true;
      }
    }
    return false;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');

    final t = asStr(action['type']);
    final sideName = seat == 0 ? '白方' : '黑方';

    if (t == 'pass') {
      if (step != 2 || isOpeningTurn) {
        throw GameError('第 1 步必须执行强制吃子，只有第 2 步才可以选择跳过');
      }
      plies++;
      lastAction = {
        'type': 'pass',
        'seat': seat,
      };
      final nextSeat = 1 - seat;
      if (!hasAnyCapture(nextSeat)) {
        _finish(
          seat,
          '${name(seat)}（$sideName）跳过第 2 步；${name(nextSeat)} 已无任何可吃的敌方棋子，${name(seat)} 获胜！',
        );
        return;
      }
      turn = nextSeat;
      step = 1;
      note = '${name(seat)}（$sideName）放弃第 2 步行动，轮到 ${name(nextSeat)} 执行第 1 步强制吃子';
      return;
    }

    if (t != 'move') throw GameError('无效的操作类型');
    final from = asInt(action['from'], -1);
    final to = asInt(action['to'], -1);
    if (from < 0 || from >= tzaarCoords.length || to < 0 || to >= tzaarCoords.length) {
      throw GameError('请选择有效的起点与终点');
    }
    if (height[from] <= 0 || owner[from] != seat) {
      throw GameError('起点必须是你自己的棋子或棋垛');
    }

    final visible = visibleOccupiedTargets(from);
    if (!visible.contains(to)) {
      throw GameError('终点必须是沿六角直线方向上的第一枚有子棋格（且不可穿越中央深渊）');
    }

    final isCapture = owner[to] == 1 - seat;
    if (isCapture) {
      if (height[from] < height[to]) {
        throw GameError('吃子失败：己方棋垛高度（${height[from]}）不能低于目标敌方棋垛高度（${height[to]}）');
      }
    } else {
      if (step != 2 || isOpeningTurn) {
        throw GameError('第 1 步必须吃掉一枚敌方棋垛，第 2 步才可以叠高加固己方棋垛');
      }
      final targetType = pieceType[to];
      if (pieceType[from] != targetType && countType(seat, targetType) <= 1) {
        throw GameError('不能覆盖自己场上仅存的最后一枚${tzaarTypeNames[targetType]}');
      }
    }

    final capturedType = isCapture ? pieceType[to] : -1;
    final prevTargetHeight = height[to];
    _executeMove(seat, from, to);
    plies++;

    final moveKind = isCapture ? 'capture' : 'strengthen';
    lastAction = {
      'type': 'move',
      'kind': moveKind,
      'seat': seat,
      'step': step,
      'from': from,
      'to': to,
      'newHeight': height[to],
      'topType': pieceType[to],
    };

    final opp = 1 - seat;
    if (isCapture) {
      for (var tp = 0; tp < 3; tp++) {
        if (countType(opp, tp) == 0) {
          _finish(
            seat,
            '${name(seat)}（$sideName）在 ${tzaarCellLabel(to)} 击杀敌方最后一枚${tzaarTypeNames[tp]}，立即获胜！',
          );
          return;
        }
      }
    }

    if (!hasAllThreeTypes(seat)) {
      _finish(
        opp,
        '${name(seat)}（$sideName）失去了全部三兵种之一，${name(opp)} 获胜！',
      );
      return;
    }

    final actionDesc = isCapture
        ? '在 ${tzaarCellLabel(from)}→${tzaarCellLabel(to)} 吃掉敌方 $prevTargetHeight 层${tzaarTypeShort[capturedType]}垛'
        : '在 ${tzaarCellLabel(from)}→${tzaarCellLabel(to)} 叠高己方棋垛至 ${height[to]} 层';

    if (isOpeningTurn) {
      isOpeningTurn = false;
      if (!hasAnyCapture(opp)) {
        _finish(
          seat,
          '${name(seat)}（$sideName）$actionDesc；${name(opp)} 无合法吃子，${name(seat)} 获胜！',
        );
        return;
      }
      turn = opp;
      step = 1;
      note = '先手首回合：${name(seat)}（$sideName）$actionDesc；轮到 ${name(opp)} 执行第 1 步强制吃子';
      return;
    }

    if (step == 1) {
      step = 2;
      note = '${name(seat)}（$sideName）第 1 步$actionDesc；请执行第 2 步（可继续吃子、叠高己方棋垛，或点击跳过）';
    } else {
      if (!hasAnyCapture(opp)) {
        _finish(
          seat,
          '${name(seat)}（$sideName）第 2 步$actionDesc；${name(opp)} 已无合法吃子，${name(seat)} 获胜！',
        );
        return;
      }
      turn = opp;
      step = 1;
      note = '${name(seat)}（$sideName）第 2 步$actionDesc；轮到 ${name(opp)} 执行第 1 步强制吃子';
    }
  }

  void _executeMove(int seat, int from, int to) {
    final isCapture = owner[to] != seat;
    owner[to] = seat;
    pieceType[to] = pieceType[from];
    height[to] = isCapture ? height[from] : (height[to] + height[from]);

    owner[from] = -1;
    pieceType[from] = -1;
    height[from] = 0;
  }

  void _finish(int w, String msg) {
    _over = true;
    winner = w;
    result = msg;
    note = msg;
    if (w == 2) {
      _placings = [1, 1];
    } else {
      _placings = rankWinners(players, [w]);
    }
    host.log(msg);
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players) throw GameError('无法认输');
    final w = 1 - seat;
    _finish(w, '${name(seat)} 认输，${name(w)} 获胜！');
  }

  @override
  bool get canDraw => true;

  @override
  void agreeDraw() {
    if (_over) throw GameError('对局已结束');
    _finish(2, '双方议和');
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'setupMode': setupMode,
      'owner': List<int>.of(owner),
      'pieceType': List<int>.of(pieceType),
      'height': List<int>.of(height),
      'isOpeningTurn': isOpeningTurn,
      'turn': turn,
      'step': step,
      'plies': plies,
      'typeCounts': [typeCounts(0), typeCounts(1)],
      'over': _over,
      'winner': winner,
      'result': result,
      'note': note,
      'last': lastAction,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    final moves = <(int, int)>[];
    for (var i = 0; i < tzaarCoords.length; i++) {
      if (height[i] <= 0 || owner[i] != seat) continue;
      for (final t in legalTargets(i, forStep: step)) {
        moves.add((i, t));
      }
    }

    if (moves.isEmpty) {
      if (step == 2 && !isOpeningTurn) {
        return {'type': 'pass'};
      }
      return null;
    }

    if (botLevel == 0 && rng.nextDouble() < 0.4) {
      if (step == 2 && !isOpeningTurn && rng.nextDouble() < 0.25) {
        return {'type': 'pass'};
      }
      final pick = moves[rng.nextInt(moves.length)];
      return {'type': 'move', 'from': pick.$1, 'to': pick.$2};
    }

    final opp = 1 - seat;
    final oppCountsBefore = typeCounts(opp);
    final myCountsBefore = typeCounts(seat);

    var bestScore = -1e12;
    (int, int)? bestMove;

    for (final (f, t) in moves) {
      final isCap = owner[t] == opp;
      final tType = pieceType[t];
      final fType = pieceType[f];
      final tH = height[t];
      final fH = height[f];

      if (isCap && oppCountsBefore[tType] <= 1) {
        // Immediate winning capture!
        return {'type': 'move', 'from': f, 'to': t};
      }

      var sc = rng.nextDouble() * 1.5;
      if (isCap) {
        // High priority on capturing rare opponent piece types (especially Tzaars or scarce types)
        final scarcityBonus = oppCountsBefore[tType] == 2
            ? 45.0
            : (oppCountsBefore[tType] == 3 ? 22.0 : 8.0);
        sc += scarcityBonus + tH * 10.0 + (2 - tType) * 4.0;
      } else {
        // Strengthening own stack on step 2:
        // Reward creating taller stacks of scarce types (like Tzaar) up to height 3-4
        final newH = fH + tH;
        if (newH <= 4) {
          sc += newH * 6.5;
          if (myCountsBefore[fType] <= 2) sc += 14.0; // protect scarce top type by making it taller!
        } else {
          sc -= 5.0; // avoid over-stacking into a single immobile mega-tower
        }
        // Penalize reducing own count of a scarce type
        if (fType != tType && myCountsBefore[tType] <= 2) {
          sc -= 25.0;
        }
      }

      if (sc > bestScore) {
        bestScore = sc;
        bestMove = (f, t);
      }
    }

    if (step == 2 && !isOpeningTurn && (bestMove == null || bestScore < 4.0)) {
      return {'type': 'pass'};
    }

    return {'type': 'move', 'from': bestMove!.$1, 'to': bestMove.$2};
  }
}
