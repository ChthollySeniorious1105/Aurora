import 'dart:math';

import '../../src/engine.dart';

class DeepSeaGame extends GameEngine {
  DeepSeaGame(super.setup);

  late final int maxRounds = setup.opt<int>('rounds', 3);

  int round = 1;
  int oxygen = 25;
  int turn = 0;
  String phase = 'dir'; // 'dir' | 'tile' | 'over'
  List<int> dice = [1, 1];
  int lastSteps = 0;
  String lastEvent = '';

  List<Map<String, dynamic>> path = [];
  late List<int> pos;
  late List<bool> turningBack;
  late List<bool> returned;
  late List<List<Map<String, int>>> carried;
  late List<List<Map<String, int>>> banked;
  bool over = false;

  List<int> get scores => [
        for (var s = 0; s < players; s++)
          banked[s].fold<int>(0, (sum, t) => sum + (t['points'] ?? 0)),
      ];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  void start() {
    path = [];
    for (var level = 1; level <= 4; level++) {
      final base = (level - 1) * 4;
      final ptsList = shuffled(
        [
          base,
          base,
          base + 1,
          base + 1,
          base + 2,
          base + 2,
          base + 3,
          base + 3,
        ],
        rng,
      );
      for (final pts in ptsList) {
        path.add({'level': level, 'points': pts, 'blank': false});
      }
    }
    pos = List<int>.filled(players, -1);
    turningBack = List<bool>.filled(players, false);
    returned = List<bool>.filled(players, false);
    carried = [for (var s = 0; s < players; s++) <Map<String, int>>[]];
    banked = [for (var s = 0; s < players; s++) <Map<String, int>>[]];
    round = 1;
    oxygen = 25;
    turn = 0;
    over = false;
    lastEvent = '第 1 潜开始，共享氧气 25';
    _beginTurn();
  }

  bool _isOccupied(int idx, {required int exceptSeat}) {
    if (idx < 0) return false;
    for (var s = 0; s < players; s++) {
      if (s != exceptSeat && !returned[s] && pos[s] == idx) return true;
    }
    return false;
  }

  void _beginTurn() {
    final hold = carried[turn].length;
    if (hold > 0) {
      oxygen = max(0, oxygen - hold);
      host.log('${name(turn)} 携带 $hold 个遗迹，消耗 $hold 点氧气（剩余 $oxygen）');
    }
    if (turningBack[turn]) {
      _rollAndMove();
    } else {
      phase = 'dir';
    }
  }

  void _rollAndMove() {
    final d1 = rng.nextInt(3) + 1;
    final d2 = rng.nextInt(3) + 1;
    dice = [d1, d2];
    final steps = max(0, d1 + d2 - carried[turn].length);
    lastSteps = steps;

    var cur = pos[turn];
    if (!turningBack[turn]) {
      for (var i = 0; i < steps; i++) {
        int? nextIdx;
        for (var cand = cur + 1; cand < path.length; cand++) {
          if (!_isOccupied(cand, exceptSeat: turn)) {
            nextIdx = cand;
            break;
          }
        }
        if (nextIdx != null) {
          cur = nextIdx;
        } else {
          break;
        }
      }
      pos[turn] = cur;
      lastEvent =
          '${name(turn)} 掷出 $d1+$d2，下潜 $steps 步至位置 ${cur + 1}';
      host.log(lastEvent);
    } else {
      for (var i = 0; i < steps; i++) {
        var nextIdx = -1;
        for (var cand = cur - 1; cand >= 0; cand--) {
          if (!_isOccupied(cand, exceptSeat: turn)) {
            nextIdx = cand;
            break;
          }
        }
        cur = nextIdx;
        if (cur <= -1) {
          cur = -1;
          break;
        }
      }
      pos[turn] = cur;
      if (cur == -1) {
        returned[turn] = true;
        final count = carried[turn].length;
        final gained =
            carried[turn].fold<int>(0, (s, t) => s + (t['points'] ?? 0));
        banked[turn].addAll(carried[turn]);
        carried[turn].clear();
        lastEvent =
            '${name(turn)} 掷出 $d1+$d2，成功返回潜艇！入库 $count 个宝藏（+$gained分）';
        host.log(lastEvent);
        _finishTurn();
        return;
      } else {
        lastEvent =
            '${name(turn)} 掷出 $d1+$d2，返航 $steps 步至位置 ${cur + 1}';
        host.log(lastEvent);
      }
    }

    if (pos[turn] >= 0 && pos[turn] < path.length) {
      phase = 'tile';
    } else {
      _finishTurn();
    }
  }

  void _finishTurn() {
    if (oxygen <= 0 || returned.every((r) => r) || path.isEmpty) {
      _endRound();
      return;
    }
    for (var i = 1; i <= players; i++) {
      final cand = (turn + i) % players;
      if (!returned[cand]) {
        turn = cand;
        _beginTurn();
        return;
      }
    }
    _endRound();
  }

  void _endRound() {
    // Divers still outside drop carried treasures at the end of path
    final stranded = <int>[
      for (var s = 0; s < players; s++)
        if (!returned[s] && pos[s] >= 0) s,
    ]..sort((a, b) => pos[a].compareTo(pos[b]));

    var deepestSeat = (turn + 1) % players;
    if (stranded.isNotEmpty) {
      deepestSeat = stranded.last;
    }

    for (final s in stranded) {
      if (carried[s].isNotEmpty) {
        for (final t in carried[s]) {
          path.add({
            'level': t['level'] ?? 1,
            'points': t['points'] ?? 0,
            'blank': false,
          });
        }
        host.log('${name(s)} 未能返回潜艇，遗落 ${carried[s].length} 个遗迹于海底尽头');
        carried[s].clear();
      }
    }

    // Remove all Blank markers from path
    path.removeWhere((t) => t['blank'] == true);

    if (round >= maxRounds || path.isEmpty) {
      over = true;
      phase = 'over';
      lastEvent = '深海探险全部结束！';
      host.log('游戏结束！最终得分：${[
        for (var s = 0; s < players; s++) '${name(s)}:${scores[s]}分'
      ].join('，')}');
      return;
    }

    round++;
    oxygen = 25;
    for (var s = 0; s < players; s++) {
      pos[s] = -1;
      turningBack[s] = false;
      returned[s] = false;
      carried[s].clear();
    }
    turn = deepestSeat;
    lastEvent = '第 $round 潜开始，氧气恢复至 25，海床缩减为 ${path.length} 格';
    host.log(lastEvent);
    _beginTurn();
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn || returned[seat]) throw GameError('当前不是你的回合');

    final type = asStr(action['type']);
    if (phase == 'dir') {
      final dir = type == 'dir' ? asStr(action['dir']) : type;
      if (dir != 'down' && dir != 'back') {
        throw GameError('请选择继续下潜或掉头返航');
      }
      if (dir == 'back') {
        turningBack[seat] = true;
        host.log('${name(seat)} 宣布掉头返航！');
      }
      _rollAndMove();
    } else if (phase == 'tile') {
      final act = type == 'tile' ? asStr(action['act']) : type;
      final p = pos[seat];
      if (p < 0 || p >= path.length) {
        throw GameError('当前不在有效海底格上');
      }
      final cell = path[p];
      final isBlank = cell['blank'] == true;
      if (act == 'stay') {
        _finishTurn();
      } else if (act == 'pickup') {
        if (isBlank) throw GameError('当前位置是空位，没有遗迹可拾取');
        carried[seat].add({
          'level': asInt(cell['level'], 1),
          'points': asInt(cell['points'], 0),
        });
        path[p] = {'level': 0, 'points': 0, 'blank': true};
        lastEvent = '${name(seat)} 拾取了等级 ${cell['level']} 的遗迹圆片';
        host.log(lastEvent);
        _finishTurn();
      } else if (act == 'drop') {
        if (!isBlank) throw GameError('只有站在空位上才能放回携带的遗迹');
        if (carried[seat].isEmpty) throw GameError('当前没有携带任何遗迹圆片');
        var idx = asInt(action['idx'], 0);
        if (idx < 0 || idx >= carried[seat].length) idx = 0;
        final dropped = carried[seat].removeAt(idx);
        path[p] = {
          'level': dropped['level'] ?? 1,
          'points': dropped['points'] ?? 0,
          'blank': false,
        };
        lastEvent = '${name(seat)} 放回了 1 个等级 ${dropped['level']} 的遗迹圆片';
        host.log(lastEvent);
        _finishTurn();
      } else {
        throw GameError('未知海底操作');
      }
    } else {
      throw GameError('未知阶段');
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    if (phase == 'dir') {
      final p = pos[seat];
      final held = carried[seat].length;
      if (p < 0) {
        return {'type': 'dir', 'dir': 'down'};
      }
      final atEnd = p >= path.length - 1;
      final targetHold = botLevel == 0 ? 1 : 2;
      if (atEnd ||
          held >= targetHold ||
          (held >= 1 && oxygen <= p + 6)) {
        return {'type': 'dir', 'dir': 'back'};
      }
      return {'type': 'dir', 'dir': 'down'};
    } else if (phase == 'tile') {
      final p = pos[seat];
      if (p < 0 || p >= path.length) return {'type': 'tile', 'act': 'stay'};
      final cell = path[p];
      final isBlank = cell['blank'] == true;
      final held = carried[seat].length;
      if (!isBlank) {
        final lvl = asInt(cell['level'], 1);
        if (!turningBack[seat]) {
          if (held == 0 || (held == 1 && (lvl >= 2 || oxygen > 12))) {
            return {'type': 'tile', 'act': 'pickup'};
          }
        } else {
          if (held == 0 || (held == 1 && oxygen >= (p + 1) * 2)) {
            return {'type': 'tile', 'act': 'pickup'};
          }
        }
      } else if (turningBack[seat] && held >= 3 && oxygen < p * 2) {
        return {'type': 'tile', 'act': 'drop', 'idx': 0};
      }
      return {'type': 'tile', 'act': 'stay'};
    }
    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'oxygen': oxygen,
      'turn': turn,
      'phase': phase,
      'dice': List<int>.of(dice),
      'lastSteps': lastSteps,
      'lastEvent': lastEvent,
      'path': [
        for (var i = 0; i < path.length; i++)
          {
            'index': i,
            'level': path[i]['level'],
            'blank': path[i]['blank'] == true,
          },
      ],
      'pos': List<int>.of(pos),
      'turningBack': List<bool>.of(turningBack),
      'returned': List<bool>.of(returned),
      'carriedCount': [for (var s = 0; s < players; s++) carried[s].length],
      'carried': [
        for (var s = 0; s < players; s++)
          [
            for (final t in carried[s])
              {'level': t['level'] ?? 1},
          ],
      ],
      'banked': [
        for (var s = 0; s < players; s++)
          [
            for (final t in banked[s])
              {'level': t['level'] ?? 1, 'points': t['points'] ?? 0},
          ],
      ],
      'scores': scores,
      'over': over,
      'result': over ? {'scores': scores, 'placings': placings} : null,
    };
  }
}
