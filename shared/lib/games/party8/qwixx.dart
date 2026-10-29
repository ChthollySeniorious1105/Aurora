import '../../src/engine.dart';

class QwixxGame extends GameEngine {
  QwixxGame(super.setup);

  static const List<String> rowNames = ['红', '黄', '绿', '蓝'];

  late final int lockTarget = setup.opt<int>('lockTarget', 2);

  int turn = 0;
  int round = 1;
  String step = 'white'; // 'white' | 'color'
  int w1 = 1;
  int w2 = 1;
  List<int> colorDice = [1, 1, 1, 1];
  List<bool> locked = [false, false, false, false];
  final Set<int> pendingLocks = <int>{};

  late List<List<List<int>>> sheets;
  late List<List<bool>> lockBonus;
  late List<int> penalties;
  late List<bool> whiteDone;
  late List<String> lastActions;
  bool turnCrossedInWhite = false;
  bool over = false;

  static bool isAsc(int r) => r == 0 || r == 1;
  static int rightmost(int r) => isAsc(r) ? 12 : 2;
  static int triScore(int k) => k * (k + 1) ~/ 2;

  int get lockedCount => locked.where((b) => b).length;

  int rowCrossCount(int seat, int r) =>
      sheets[seat][r].length + (lockBonus[seat][r] ? 1 : 0);

  int rowScore(int seat, int r) => triScore(rowCrossCount(seat, r));

  int totalScore(int seat) {
    var s = 0;
    for (var r = 0; r < 4; r++) {
      s += rowScore(seat, r);
    }
    return s - penalties[seat] * 5;
  }

  List<int> get scores => [for (var s = 0; s < players; s++) totalScore(s)];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor {
    if (over) return const [];
    if (step == 'white') {
      return [
        for (var s = 0; s < players; s++)
          if (!whiteDone[s]) s,
      ];
    }
    return [turn];
  }

  @override
  void start() {
    sheets = [
      for (var s = 0; s < players; s++) [for (var r = 0; r < 4; r++) <int>[]],
    ];
    lockBonus = [
      for (var s = 0; s < players; s++) List<bool>.filled(4, false),
    ];
    penalties = List<int>.filled(players, 0);
    whiteDone = List<bool>.filled(players, false);
    lastActions = List<String>.filled(players, '');
    turn = 0;
    round = 1;
    over = false;
    _rollForTurn();
  }

  void _rollForTurn() {
    w1 = rng.nextInt(6) + 1;
    w2 = rng.nextInt(6) + 1;
    for (var r = 0; r < 4; r++) {
      colorDice[r] = locked[r] ? 0 : (rng.nextInt(6) + 1);
    }
    whiteDone = List<bool>.filled(players, false);
    turnCrossedInWhite = false;
    pendingLocks.clear();
    step = 'white';
    host.log('${name(turn)} 掷出白骰 $w1+$w2=${w1 + w2}');
  }

  bool canCross(int seat, int r, int num) {
    if (r < 0 || r >= 4 || locked[r] || num < 2 || num > 12) return false;
    final row = sheets[seat][r];
    if (row.isNotEmpty) {
      if (isAsc(r) && num <= row.last) return false;
      if (!isAsc(r) && num >= row.last) return false;
    }
    if (num == rightmost(r) && row.length < 5) return false;
    return true;
  }

  void _cross(int seat, int r, int num, {required bool immediateLock}) {
    sheets[seat][r].add(num);
    if (num == rightmost(r)) {
      lockBonus[seat][r] = true;
      if (immediateLock) {
        locked[r] = true;
        colorDice[r] = 0;
      } else {
        pendingLocks.add(r);
      }
      host.log('${name(seat)} 划掉了${rowNames[r]}行终点 $num 并锁定该行！');
    } else {
      host.log('${name(seat)} 在${rowNames[r]}行划掉了 $num');
    }
  }

  List<Map<String, int>> legalColorMovesFor(int seat) {
    final out = <Map<String, int>>[];
    for (var r = 0; r < 4; r++) {
      if (locked[r] || colorDice[r] <= 0) continue;
      final candidates = <int>{w1 + colorDice[r], w2 + colorDice[r]}.toList()
        ..sort();
      for (final val in candidates) {
        if (canCross(seat, r, val)) {
          out.add({'row': r, 'num': val});
        }
      }
    }
    return out;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    final type = asStr(action['type']);
    if (step == 'white') {
      if (seat < 0 || seat >= players || whiteDone[seat]) {
        throw GameError('当前无需操作白骰阶段');
      }
      if (type != 'white') throw GameError('当前为白骰阶段');
      final r = asInt(action['row'], -1);
      if (r == -1) {
        whiteDone[seat] = true;
        lastActions[seat] = '白骰跳过';
      } else {
        final sum = w1 + w2;
        if (!canCross(seat, r, sum)) {
          throw GameError('无法在${r >= 0 && r < 4 ? rowNames[r] : ""}行划掉 $sum');
        }
        _cross(seat, r, sum, immediateLock: false);
        whiteDone[seat] = true;
        if (seat == turn) turnCrossedInWhite = true;
        lastActions[seat] = '白骰:${rowNames[r]}$sum';
      }
      if (whiteDone.every((done) => done)) {
        for (final lr in pendingLocks) {
          locked[lr] = true;
          colorDice[lr] = 0;
        }
        pendingLocks.clear();
        step = 'color';
      }
    } else if (step == 'color') {
      if (seat != turn) throw GameError('当前轮到掷骰玩家选择彩骰组合');
      if (type != 'color') throw GameError('当前为彩骰阶段');
      final r = asInt(action['row'], -1);
      if (r == -1) {
        if (!turnCrossedInWhite) {
          penalties[turn]++;
          lastActions[turn] = '两次跳过(罚分-5)';
          host.log('${name(turn)} 本回合未划任何数字，记 1 次罚分（共 ${penalties[turn]}/4）');
        } else {
          lastActions[turn] = '${lastActions[turn]} / 彩骰跳过';
        }
      } else {
        if (r < 0 || r >= 4 || locked[r] || colorDice[r] <= 0) {
          throw GameError('该颜色行已锁定或无效');
        }
        final validNums = <int>{w1 + colorDice[r], w2 + colorDice[r]};
        var val = asInt(action['num'], -1);
        if (val == -1 && validNums.length == 1) {
          val = validNums.first;
        }
        if (!validNums.contains(val)) {
          throw GameError('点数 $val 不是有效的白骰+彩骰组合');
        }
        if (!canCross(turn, r, val)) {
          throw GameError('无法在${rowNames[r]}行划掉 $val');
        }
        _cross(turn, r, val, immediateLock: true);
        lastActions[turn] = '${lastActions[turn]} / 彩骰:${rowNames[r]}$val';
      }
      _finishTurn();
    } else {
      throw GameError('未知阶段');
    }
  }

  void _finishTurn() {
    if (lockedCount >= lockTarget || penalties.any((p) => p >= 4)) {
      over = true;
      host.log('游戏结束！最终得分：${[
        for (var s = 0; s < players; s++) '${name(s)}:${totalScore(s)}分'
      ].join('，')}');
      return;
    }
    turn = (turn + 1) % players;
    if (turn == 0) round++;
    _rollForTurn();
  }

  int _gap(int seat, int r, int num) {
    if (num == rightmost(r)) return -10; // Always prioritize locking a row!
    final row = sheets[seat][r];
    if (isAsc(r)) {
      final last = row.isEmpty ? 1 : row.last;
      return num - last - 1;
    } else {
      final last = row.isEmpty ? 13 : row.last;
      return last - num - 1;
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over) return null;
    if (step == 'white') {
      if (whiteDone[seat]) return null;
      final sum = w1 + w2;
      int bestRow = -1;
      int bestGap = 999;
      for (var r = 0; r < 4; r++) {
        if (!canCross(seat, r, sum)) continue;
        final g = _gap(seat, r, sum);
        if (g < bestGap) {
          bestGap = g;
          bestRow = r;
        }
      }
      final maxAllowedGap = botLevel == 0
          ? 2
          : (seat == turn && legalColorMovesFor(seat).isEmpty ? 2 : 1);
      if (bestRow != -1 && bestGap <= maxAllowedGap) {
        return {'type': 'white', 'row': bestRow};
      }
      return {'type': 'white', 'row': -1};
    } else if (step == 'color') {
      if (seat != turn) return null;
      final moves = legalColorMovesFor(seat);
      if (moves.isEmpty) return {'type': 'color', 'row': -1};
      Map<String, int>? bestMove;
      int bestGap = 999;
      for (final m in moves) {
        final g = _gap(seat, m['row']!, m['num']!);
        if (g < bestGap) {
          bestGap = g;
          bestMove = m;
        }
      }
      final threshold = !turnCrossedInWhite
          ? (penalties[seat] >= 2 ? 5 : 3)
          : (botLevel == 0 ? 2 : 1);
      if (bestMove != null && bestGap <= threshold) {
        return {
          'type': 'color',
          'row': bestMove['row'],
          'num': bestMove['num'],
        };
      }
      return {'type': 'color', 'row': -1};
    }
    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final sValid = seat >= 0 && seat < players;
    final sum = w1 + w2;
    return {
      'turn': turn,
      'round': round,
      'step': step,
      'phase': step,
      'w1': w1,
      'w2': w2,
      'whiteSum': sum,
      'colorDice': List<int>.of(colorDice),
      'locked': List<bool>.of(locked),
      'lockedCount': lockedCount,
      'lockTarget': lockTarget,
      'sheets': [
        for (var s = 0; s < players; s++)
          [for (var r = 0; r < 4; r++) List<int>.of(sheets[s][r])],
      ],
      'lockBonus': [
        for (var s = 0; s < players; s++) List<bool>.of(lockBonus[s]),
      ],
      'penalties': List<int>.of(penalties),
      'scores': scores,
      'rowScores': [
        for (var s = 0; s < players; s++)
          [for (var r = 0; r < 4; r++) rowScore(s, r)],
      ],
      'whiteDone': List<bool>.of(whiteDone),
      'turnCrossedInWhite': turnCrossedInWhite,
      'lastActions': List<String>.of(lastActions),
      'legalWhiteRows': sValid
          ? [
              for (var r = 0; r < 4; r++)
                if (canCross(seat, r, sum)) r,
            ]
          : const <int>[],
      'legalColorMoves':
          sValid ? legalColorMovesFor(seat) : const <Map<String, int>>[],
      'over': over,
      'result': over ? {'scores': scores, 'placings': placings} : null,
    };
  }
}
