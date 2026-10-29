import '../../src/engine.dart';

/// Official Kamisado 8×8 Latin-square color layout (0..7):
/// 0=Orange(橙), 1=Blue(蓝), 2=Purple(紫), 3=Pink(粉),
/// 4=Yellow(黄), 5=Red(红), 6=Green(绿), 7=Brown(棕).
const List<List<int>> kamisadoGrid = [
  [0, 1, 2, 3, 4, 5, 6, 7],
  [5, 0, 3, 6, 1, 4, 7, 2],
  [6, 3, 0, 5, 2, 7, 4, 1],
  [3, 2, 1, 0, 7, 6, 5, 4],
  [4, 5, 6, 7, 0, 1, 2, 3],
  [1, 4, 7, 2, 5, 0, 3, 6],
  [2, 7, 4, 1, 6, 3, 0, 5],
  [7, 6, 5, 4, 3, 2, 1, 0],
];

const List<int> kamisadoCellColors = [
  0, 1, 2, 3, 4, 5, 6, 7,
  5, 0, 3, 6, 1, 4, 7, 2,
  6, 3, 0, 5, 2, 7, 4, 1,
  3, 2, 1, 0, 7, 6, 5, 4,
  4, 5, 6, 7, 0, 1, 2, 3,
  1, 4, 7, 2, 5, 0, 3, 6,
  2, 7, 4, 1, 6, 3, 0, 5,
  7, 6, 5, 4, 3, 2, 1, 0,
];

const List<String> kamisadoColorNames = ['橙', '蓝', '紫', '粉', '黄', '红', '绿', '棕'];

String kamisadoCoord(int cell) {
  if (cell < 0 || cell >= 64) return '?';
  final r = cell ~/ 8, c = cell % 8;
  return '${String.fromCharCode(65 + c)}${8 - r}';
}

class KamisadoMove {
  final int color;
  final int from;
  final int to;
  const KamisadoMove(this.color, this.from, this.to);

  Map<String, dynamic> toAction() => {
        'type': 'move',
        'from': from,
        'to': to,
        'color': color,
      };
}

class Kamisado extends GameEngine {
  /// `towers[seat][color]` holds the board cell index `0..63` of that Dragon Tower.
  final List<List<int>> towers = [
    List.filled(8, 0),
    List.filled(8, 0),
  ];

  final List<int> scores = [0, 0];
  final List<(int, int)> passChain = [];

  int round = 1;
  int turn = 0; // 0 = Gold/Black (bottom, moves up to row 0), 1 = White (top, moves down to row 7)
  int requiredColor = -1; // -1 = any tower (first move of round), 0..7 = forced tower color
  int lastMover = -1;
  int plies = 0;
  bool _over = false;
  int winner = -1; // 0, 1, or 2 for draw
  List<int>? _placings;
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;

  Kamisado(super.setup);

  int get targetScore => setup.opt<int>('targetScore', 1) == 3 ? 3 : 1;

  int _parseCell(Object? v) {
    if (v is List && v.length >= 2) {
      final r = asInt(v[0], -1), c = asInt(v[1], -1);
      if (r < 0 || r >= 8 || c < 0 || c >= 8) return -1;
      return r * 8 + c;
    }
    final idx = asInt(v, -1);
    return (idx >= 0 && idx < 64) ? idx : -1;
  }

  void _setupRoundBoard(int firstSeat) {
    // Seat 0 starts on Row 7 (cols 0..7 have colors 7..0)
    for (var c = 0; c < 8; c++) {
      final color = kamisadoGrid[7][c];
      towers[0][color] = 7 * 8 + c;
    }
    // Seat 1 starts on Row 0 (cols 0..7 have colors 0..7)
    for (var c = 0; c < 8; c++) {
      final color = kamisadoGrid[0][c];
      towers[1][color] = 0 * 8 + c;
    }
    turn = firstSeat;
    requiredColor = -1;
    lastMover = -1;
    passChain.clear();
  }

  @override
  void start() {
    scores[0] = 0;
    scores[1] = 0;
    round = 1;
    plies = 0;
    _over = false;
    winner = -1;
    _placings = null;
    lastAction = null;
    result = '';
    _setupRoundBoard(0);
    note = '先手方可任选 1 座己方龙塔向前或斜前方移动，落点格颜色将指定对手下一步必须移动的龙塔颜色！';
  }

  /// Returns `(seat, color)` at [cell], or null if empty.
  (int, int)? towerAt(int cell) {
    for (var s = 0; s < 2; s++) {
      for (var c = 0; c < 8; c++) {
        if (towers[s][c] == cell) return (s, c);
      }
    }
    return null;
  }

  bool isOccupied(int cell) => towerAt(cell) != null;

  /// Returns all legal destination cells for `seat`'s tower of [color].
  List<int> legalTargetsForTower(int seat, int color) {
    final out = <int>[];
    if (color < 0 || color >= 8) return out;
    final from = towers[seat][color];
    final r0 = from ~/ 8, c0 = from % 8;
    final dr = seat == 0 ? -1 : 1; // Seat 0 moves up (-1), Seat 1 moves down (+1)
    for (final dc in const [-1, 0, 1]) {
      var r = r0 + dr, c = c0 + dc;
      while (r >= 0 && r < 8 && c >= 0 && c < 8) {
        final idx = r * 8 + c;
        if (isOccupied(idx)) break;
        out.add(idx);
        r += dr;
        c += dc;
      }
    }
    return out;
  }

  /// Generates all legal moves for [seat] given current [requiredColor].
  List<KamisadoMove> legalMoves(int seat) {
    final out = <KamisadoMove>[];
    if (requiredColor == -1) {
      for (var c = 0; c < 8; c++) {
        final from = towers[seat][c];
        for (final to in legalTargetsForTower(seat, c)) {
          out.add(KamisadoMove(c, from, to));
        }
      }
    } else {
      final from = towers[seat][requiredColor];
      for (final to in legalTargetsForTower(seat, requiredColor)) {
        out.add(KamisadoMove(requiredColor, from, to));
      }
    }
    return out;
  }

  bool canPass(int seat) => seat == turn && requiredColor >= 0 && legalMoves(seat).isEmpty;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');
    final type = asStr(action['type'], 'move');

    if (type == 'pass') {
      if (requiredColor < 0 || legalMoves(seat).isNotEmpty) {
        throw GameError('当前龙塔有合法移动步，不能跳过');
      }
      final blockedColor = requiredColor;
      final sq = towers[seat][blockedColor];
      final nextColor = kamisadoCellColors[sq];
      final nextSeat = 1 - seat;

      passChain.add((seat, blockedColor));
      plies++;

      lastAction = {
        'type': 'pass',
        'seat': seat,
        'color': blockedColor,
        'cell': sq,
        'nextColor': nextColor,
      };

      // Check if pass chain created a cycle where nobody can move
      if (passChain.contains((nextSeat, nextColor))) {
        final culprit = lastMover >= 0 ? lastMover : seat;
        final roundWinner = 1 - culprit;
        _scoreRoundWin(
          roundWinner,
          '双方龙塔陷入死锁循环，造成循环的 ${name(culprit)} 判负，${name(roundWinner)} 赢得本局！',
        );
        return;
      }

      turn = nextSeat;
      requiredColor = nextColor;
      note = '${name(seat)} 的【${kamisadoColorNames[blockedColor]}塔】被完全阻挡无法移动，停留在【${kamisadoColorNames[nextColor]}格】（${kamisadoCoord(sq)}），轮到 ${name(nextSeat)} 移动【${kamisadoColorNames[nextColor]}塔】';
      return;
    }

    if (type != 'move') throw GameError('未知操作');

    final to = _parseCell(action['to']);
    if (to < 0) throw GameError('请选择移动目标格');

    int towerColor = asInt(action['color'], -1);
    final fromParam = _parseCell(action['from']);
    if (fromParam >= 0) {
      final occ = towerAt(fromParam);
      if (occ == null || occ.$1 != seat) {
        throw GameError('起点必须是你自己的龙塔');
      }
      towerColor = occ.$2;
    } else if (towerColor < 0 && requiredColor >= 0) {
      towerColor = requiredColor;
    }

    if (towerColor < 0 || towerColor >= 8) {
      throw GameError('请选择要移动的龙塔');
    }
    if (requiredColor >= 0 && towerColor != requiredColor) {
      throw GameError('本回合必须移动受颜色锁指定的【${kamisadoColorNames[requiredColor]}塔】');
    }

    final from = towers[seat][towerColor];
    final targets = legalTargetsForTower(seat, towerColor);
    if (!targets.contains(to)) {
      throw GameError('非法移动：龙塔只能向正前方或左/右斜前方直线移动且不能越过其他龙塔');
    }

    towers[seat][towerColor] = to;
    plies++;
    lastMover = seat;
    passChain.clear();

    final landedColor = kamisadoCellColors[to];
    lastAction = {
      'type': 'move',
      'seat': seat,
      'color': towerColor,
      'from': from,
      'to': to,
      'landedColor': landedColor,
    };

    final goalRow = seat == 0 ? 0 : 7;
    if (to ~/ 8 == goalRow) {
      _scoreRoundWin(
        seat,
        '${name(seat)} 的【${kamisadoColorNames[towerColor]}塔】成功抵达对方底线（${kamisadoCoord(to)}）！',
      );
      return;
    }

    final nextSeat = 1 - seat;
    turn = nextSeat;
    requiredColor = landedColor;
    final blockedHint = legalMoves(nextSeat).isEmpty ? '（该塔已被阻挡，需点击跳过）' : '';
    note = '${name(seat)} 移动【${kamisadoColorNames[towerColor]}塔】${kamisadoCoord(from)}→${kamisadoCoord(to)}（落入${kamisadoColorNames[landedColor]}格），指定 ${name(nextSeat)} 移动【${kamisadoColorNames[landedColor]}塔】$blockedHint';
  }

  void _scoreRoundWin(int roundWinner, String reason) {
    scores[roundWinner]++;
    if (scores[roundWinner] >= targetScore) {
      final scoreStr = targetScore > 1 ? '（总比分 ${scores[0]}:${scores[1]}）' : '';
      _finish(roundWinner, '$reason$scoreStr');
      return;
    }
    // Start next round in multi-point match
    final prevRound = round;
    round++;
    final nextStarter = 1 - roundWinner;
    _setupRoundBoard(nextStarter);
    final msg = '第 $prevRound 局：$reason 当前比分 ${scores[0]}:${scores[1]}，开始第 $round 局（${name(nextStarter)} 先手）！';
    note = msg;
    host.log(msg);
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
    final moves = _over ? const <KamisadoMove>[] : legalMoves(turn);
    return {
      'towers': [
        List<int>.of(towers[0]),
        List<int>.of(towers[1]),
      ],
      'scores': List<int>.of(scores),
      'targetScore': targetScore,
      'round': round,
      'turn': turn,
      'requiredColor': requiredColor,
      'canPass': !_over && canPass(turn),
      'legalMoves': [
        for (final m in moves) [m.color, m.from, m.to]
      ],
      'plies': plies,
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
    final moves = legalMoves(seat);
    if (moves.isEmpty) {
      return {'type': 'pass'};
    }

    final opp = 1 - seat;
    final goalRow = seat == 0 ? 0 : 7;
    final oppGoalRow = opp == 0 ? 0 : 7;

    // 1. Check for immediate home-rank winning move
    for (final mv in moves) {
      if (mv.to ~/ 8 == goalRow) {
        return mv.toAction();
      }
    }

    if (botLevel == 0 && rng.nextDouble() < 0.45) {
      return moves[rng.nextInt(moves.length)].toAction();
    }

    var bestScore = -1e12;
    var bestMove = moves.first;

    for (final mv in moves) {
      final prevPos = towers[seat][mv.color];
      towers[seat][mv.color] = mv.to;

      final landedColor = kamisadoCellColors[mv.to];
      final r = mv.to ~/ 8;
      final progress = seat == 0 ? (7 - r) : r; // 1..7

      var score = progress * 35.0 + rng.nextDouble() * 6.0;

      // Check what opponent can do with their tower of `landedColor`
      final oppTargets = legalTargetsForTower(opp, landedColor);
      var oppCanWin = false;
      var oppCanReachMyWinColor = false;

      // Which colors allow `seat` to win on the following turn?
      final myWinningColors = <int>{};
      for (var c = 0; c < 8; c++) {
        for (final t in legalTargetsForTower(seat, c)) {
          if (t ~/ 8 == goalRow) {
            myWinningColors.add(c);
            break;
          }
        }
      }

      if (oppTargets.isEmpty) {
        // Opponent tower is blocked! Check what square color it stands on
        final oppBlockedSq = towers[opp][landedColor];
        final bounceColor = kamisadoCellColors[oppBlockedSq];
        if (bounceColor == landedColor && legalTargetsForTower(seat, bounceColor).isEmpty) {
          // Deadlock cycle caused by us -> avoid at all costs!
          score -= 900000.0;
        } else if (myWinningColors.contains(bounceColor)) {
          score += 5000.0;
        } else {
          score += 180.0;
        }
      } else {
        var oppBestProgress = 0;
        var allOppGiveMeWin = myWinningColors.isNotEmpty;
        for (final ot in oppTargets) {
          final or = ot ~/ 8;
          if (or == oppGoalRow) {
            oppCanWin = true;
            break;
          }
          final op = opp == 0 ? (7 - or) : or;
          if (op > oppBestProgress) oppBestProgress = op;
          final oc = kamisadoCellColors[ot];
          if (!myWinningColors.contains(oc)) {
            allOppGiveMeWin = false;
          } else {
            oppCanReachMyWinColor = true;
          }
        }
        if (oppCanWin) {
          score -= 500000.0;
        } else {
          if (allOppGiveMeWin) {
            score += 8000.0; // Zugzwang: every opponent reply gives us a winning tower!
          } else if (oppCanReachMyWinColor) {
            score += 40.0;
          }
          score -= oppBestProgress * 18.0 + oppTargets.length * 4.0;
        }
      }

      towers[seat][mv.color] = prevPos;

      if (score > bestScore) {
        bestScore = score;
        bestMove = mv;
      }
    }

    return bestMove.toAction();
  }
}
