import 'dart:math';

import '../../src/engine.dart';

/// Summit heights for columns 2..12 in Can't Stop.
const Map<int, int> canStopHeights = {
  2: 3,
  3: 5,
  4: 7,
  5: 9,
  6: 11,
  7: 13,
  8: 11,
  9: 9,
  10: 7,
  11: 5,
  12: 3,
};

const canStopRules = '''
# 概述
《欲罢不能》（Can't Stop）是由传奇设计师 Sid Sackson 创作的经典押注运气（Push-your-luck）骰子登山桌游，支持 2~4 人游玩。棋盘共有编号为 2~12 的 11 条登山道，每条登山道的长度根据概率分布不同（2 和 12 仅 3 格，7 有 13 格）。

# 登山与标记
- 每位玩家拥有自己颜色的永久营地标记（Camps），以及全场的 3 个临时白色登山者标记（Runners）。
- 回合开始时，系统为你投掷 4 颗六面骰，你需要将 4 颗骰子分成两组（每组 2 颗），产生两个点数之和（sumA, sumB）。

# 规则与流程
- 选择组合（choose_pair）：从合法的骰子配对中选择一组，将白色登山者沿对应列向上推进 1 格（若两组点数相同且合法，则同一列推进 2 格）。
- 只有尚未被任何玩家登顶占领的列才能推进；且你单回合最多只能在 3 条不同的列上放置白色登山者。如果某组配对中只有 1 个点数合法，则只推进该点数对应的列。
- 抉择阶段（decide）：推进后你可以选择：
  - 继续掷骰（roll）：继续投掷 4 颗骰子冲击更高峰！但如果掷出的 4 颗骰子没有任何合法配对可以推进任何一列，你将发生【坠崖（Bust）】——本回合所有临时白色登山者进度全部清零，直接轮到下一位玩家！
  - 扎营保存（stop）：见好就收，将当前所有白色登山者的位置保存为你的永久营地！若某一列已到达山顶最高格，你将永久【登顶占领】该列（其他玩家不能再走该列）。

# 胜负条件
- 率先登顶占领指定数量列（标准 3 列 / 快速 2 列）的玩家立即获胜！
''';

/// Compute all legal column advancement choices `[c1, c2]` or `[c1]` for 4 dice.
List<List<int>> canStopLegalChoices(
  List<int> dice,
  Map<int, int> runners,
  Map<int, int> claimed,
) {
  if (dice.length != 4) return const [];
  final active = runners.keys.toSet();
  bool canUse(int col, Set<int> cur) =>
      col >= 2 && col <= 12 && !claimed.containsKey(col) && (cur.contains(col) || cur.length < 3);

  final pairings = <(int, int)>[
    (dice[0] + dice[1], dice[2] + dice[3]),
    (dice[0] + dice[2], dice[1] + dice[3]),
    (dice[0] + dice[3], dice[1] + dice[2]),
  ];

  final seen = <String>{};
  final out = <List<int>>[];

  void addChoice(List<int> cols) {
    final sorted = List.of(cols)..sort();
    final key = sorted.join(',');
    if (seen.add(key)) out.add(sorted);
  }

  for (final (s1, s2) in pairings) {
    final ok1 = canUse(s1, active);
    final after1 = ok1 ? <int>{...active, s1} : active;
    final ok1After2 = canUse(s2, active) && canUse(s1, <int>{...active, s2});
    final ok2After1 = ok1 && canUse(s2, after1);

    if (ok2After1 || ok1After2) {
      addChoice([s1, s2]);
    } else {
      if (ok1) addChoice([s1]);
      if (canUse(s2, active)) addChoice([s2]);
    }
  }
  return out;
}

class CanStopGame extends GameEngine {
  CanStopGame(super.setup);

  late int targetCols = setup.opt<int>('targetCols', 3);
  late List<Map<int, int>> camps = [
    for (var s = 0; s < players; s++) {for (var c = 2; c <= 12; c++) c: 0}
  ];
  Map<int, int> claimed = {}; // col -> seat
  Map<int, int> runners = {}; // col -> temporary step (1..height)
  List<int> dice = [1, 1, 1, 1];
  List<List<int>> legalChoices = [];
  int turn = 0;
  String phase = 'choose_pair'; // 'choose_pair' | 'decide' | 'gameOver'
  bool over = false;
  int winner = -1;
  int rollStreak = 0;
  Map<String, dynamic>? lastEvent;
  final List<String> logs = [];

  void _say(String text) {
    logs.add(text);
    if (logs.length > 40) logs.removeAt(0);
    host.log(text);
  }

  int claimedCount(int seat) => claimed.values.where((s) => s == seat).length;

  /// Total progress score for ranking players.
  double playerProgressScore(int seat) {
    var score = claimedCount(seat) * 1000.0;
    for (var c = 2; c <= 12; c++) {
      if (claimed.containsKey(c)) continue;
      final h = canStopHeights[c]!;
      final pos = camps[seat][c] ?? 0;
      score += (pos / h) * 10.0;
    }
    return score;
  }

  @override
  void start() {
    turn = rng.nextInt(players);
    _say('欲罢不能开始！目标率先占领 $targetCols 列，${name(turn)} 先手。');
    _rollForTurn(initialTurnRoll: true);
  }

  List<int> _randomDice() => [for (var i = 0; i < 4; i++) 1 + rng.nextInt(6)];

  void _rollForTurn({bool initialTurnRoll = false}) {
    var attempts = 0;
    while (attempts < players * 4) {
      attempts++;
      var d = _randomDice();
      var choices = canStopLegalChoices(d, runners, claimed);
      if (initialTurnRoll && runners.isEmpty && choices.isEmpty) {
        // Try to find a roll with at least one open column so the starting roll doesn't spin if columns are open
        for (var c = 2; c <= 12; c++) {
          if (!claimed.containsKey(c)) {
            final d1 = (c ~/ 2).clamp(1, 6);
            final d2 = (c - d1).clamp(1, 6);
            d = [d1, d2, 1 + rng.nextInt(6), 1 + rng.nextInt(6)];
            choices = canStopLegalChoices(d, runners, claimed);
            break;
          }
        }
      }
      dice = d;
      legalChoices = choices;
      if (choices.isNotEmpty) {
        phase = 'choose_pair';
        return;
      }
      // Bust!
      final lost = {for (final e in runners.entries) '${e.key}': e.value};
      lastEvent = {
        'type': 'bust',
        'seat': turn,
        'dice': List.of(dice),
        'lostRunners': lost,
      };
      _say('${name(turn)} 掷出 ${dice.join("-")}，无路可走，坠崖失去了本回合进度！');
      runners.clear();
      rollStreak = 0;
      turn = (turn + 1) % players;
      initialTurnRoll = true;
    }
    // Fallback if all 11 columns are somehow claimed in a custom test
    over = true;
    phase = 'gameOver';
  }

  /// Apply a specific 4-dice roll (useful for deterministic unit tests and normal rolls).
  void applyDiceRoll(List<int> newDice) {
    dice = List.of(newDice);
    legalChoices = canStopLegalChoices(dice, runners, claimed);
    if (legalChoices.isNotEmpty) {
      phase = 'choose_pair';
      return;
    }
    final lost = {for (final e in runners.entries) '${e.key}': e.value};
    lastEvent = {
      'type': 'bust',
      'seat': turn,
      'dice': List.of(dice),
      'lostRunners': lost,
    };
    _say('${name(turn)} 掷出 ${dice.join("-")}，无路可走，坠崖失去了本回合进度！');
    runners.clear();
    rollStreak = 0;
    turn = (turn + 1) % players;
    _rollForTurn(initialTurnRoll: true);
  }

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings =>
      over ? rankByScore([for (var s = 0; s < players; s++) playerProgressScore(s)]) : null;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');
    final type = asStr(action['type']);

    if (phase == 'choose_pair') {
      if (type != 'choose_pair') throw GameError('请先选择一组骰子点数推进');
      final rawCols = asIntList(action['cols']);
      if (rawCols.isEmpty || rawCols.length > 2) {
        throw GameError('每次必须选择 1 或 2 个有效列');
      }
      final sorted = List.of(rawCols)..sort();
      final match = legalChoices.any((c) {
        if (c.length != sorted.length) return false;
        for (var i = 0; i < c.length; i++) {
          if (c[i] != sorted[i]) return false;
        }
        return true;
      });
      if (!match) {
        throw GameError('所选列组合不在当前骰子的合法配对中');
      }

      for (final col in sorted) {
        final h = canStopHeights[col]!;
        final cur = runners[col] ?? camps[seat][col] ?? 0;
        runners[col] = min(h, cur + 1);
      }
      rollStreak++;
      lastEvent = {
        'type': 'advance',
        'seat': seat,
        'dice': List.of(dice),
        'cols': sorted,
        'runners': {for (final e in runners.entries) '${e.key}': e.value},
      };
      _say('${name(seat)} 掷出 ${dice.join("-")}，推进了第 ${sorted.join("、")} 列');
      phase = 'decide';
      return;
    }

    if (phase == 'decide') {
      if (type == 'roll') {
        applyDiceRoll(_randomDice());
        return;
      }
      if (type == 'stop') {
        final newlyClaimed = <int>[];
        for (final entry in runners.entries) {
          final col = entry.key;
          final pos = entry.value;
          camps[seat][col] = pos;
          if (pos >= canStopHeights[col]! && !claimed.containsKey(col)) {
            claimed[col] = seat;
            newlyClaimed.add(col);
          }
        }
        final savedCols = runners.keys.toList()..sort();
        runners.clear();
        rollStreak = 0;
        lastEvent = {
          'type': 'stop',
          'seat': seat,
          'savedCols': savedCols,
          'claimedCols': newlyClaimed,
        };
        if (newlyClaimed.isNotEmpty) {
          _say('${name(seat)} 扎营并成功登顶第 ${newlyClaimed.join("、")} 列！');
        } else {
          _say('${name(seat)} 选择扎营，保存了第 ${savedCols.join("、")} 列的进度');
        }

        if (claimedCount(seat) >= targetCols) {
          over = true;
          winner = seat;
          phase = 'gameOver';
          _say('游戏结束！${name(seat)} 率先占领 ${claimedCount(seat)} 列获胜！');
          return;
        }

        turn = (turn + 1) % players;
        _rollForTurn(initialTurnRoll: true);
        return;
      }
      throw GameError('请选择继续掷骰（roll）或扎营保存（stop）');
    }

    throw GameError('未知阶段操作');
  }

  @override
  Map<String, dynamic> view(int seat) {
    final pairingDetails = <Map<String, dynamic>>[];
    if (dice.length == 4) {
      final rawPairs = [
        [dice[0], dice[1], dice[2], dice[3]],
        [dice[0], dice[2], dice[1], dice[3]],
        [dice[0], dice[3], dice[1], dice[2]],
      ];
      for (final p in rawPairs) {
        pairingDetails.add({
          'd1': [p[0], p[1]],
          'd2': [p[2], p[3]],
          'sums': [p[0] + p[1], p[2] + p[3]],
        });
      }
    }
    return {
      'players': players,
      'turn': turn,
      'phase': phase,
      'targetCols': targetCols,
      'dice': dice,
      'pairings': pairingDetails,
      'legalChoices': legalChoices,
      'runners': {for (final e in runners.entries) '${e.key}': e.value},
      'camps': [
        for (var s = 0; s < players; s++)
          {for (var c = 2; c <= 12; c++) '$c': camps[s][c] ?? 0}
      ],
      'claimed': {for (final e in claimed.entries) '${e.key}': e.value},
      'claimedCounts': [for (var s = 0; s < players; s++) claimedCount(s)],
      'heights': {for (final e in canStopHeights.entries) '${e.key}': e.value},
      'rollStreak': rollStreak,
      'lastEvent': lastEvent,
      'over': over,
      'winner': winner,
      'log': logs.length > 12 ? logs.sublist(logs.length - 12) : List.of(logs),
    };
  }

  // ------------------------------------------------------------------ Bot
  double _colWeight(int seat, int col) {
    final h = canStopHeights[col]!;
    final cur = runners[col] ?? camps[seat][col] ?? 0;
    final rem = h - cur;
    // Prefer middle columns (6,7,8) and columns where we are close to summit
    final probWeight = 7.0 - (col - 7).abs();
    final progressBonus = (h - rem) / h * 8.0;
    final summitBonus = rem <= 1 ? 20.0 : (rem == 2 ? 8.0 : 0.0);
    final existingRunnerBonus = runners.containsKey(col) ? 4.0 : 0.0;
    return probWeight + progressBonus + summitBonus + existingRunnerBonus;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    if (phase == 'choose_pair') {
      if (legalChoices.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'choose_pair', 'cols': legalChoices[rng.nextInt(legalChoices.length)]};
      }
      List<int> best = legalChoices.first;
      var bestScore = -1e9;
      for (final choice in legalChoices) {
        var score = 0.0;
        for (final c in choice) {
          score += _colWeight(seat, c);
        }
        if (choice.length == 2 && choice[0] == choice[1]) {
          score += 5.0; // Double advance on one runner is very strong
        }
        if (score > bestScore) {
          bestScore = score;
          best = choice;
        }
      }
      return {'type': 'choose_pair', 'cols': best};
    }

    if (phase == 'decide') {
      // Check how many columns are at summit right now
      var atSummit = 0;
      var gainedSteps = 0;
      for (final e in runners.entries) {
        final col = e.key;
        final pos = e.value;
        final saved = camps[seat][col] ?? 0;
        gainedSteps += (pos - saved);
        if (pos >= canStopHeights[col]!) atSummit++;
      }

      // If stopping wins the game immediately, always stop!
      if (claimedCount(seat) + atSummit >= targetCols) {
        return {'type': 'stop'};
      }
      // If we reached at least one summit, stop to lock it in!
      if (atSummit > 0) {
        return {'type': 'stop'};
      }
      // If we still have fewer than 3 runners placed, we can rarely bust, so roll!
      if (runners.length < 3) {
        if (botLevel == 0 && gainedSteps >= 4 && rng.nextDouble() < 0.4) {
          return {'type': 'stop'};
        }
        return {'type': 'roll'};
      }

      // All 3 runners are placed: compute survival quality of our 3 columns
      // Rule of 28 heuristic: stop when gained progress is solid
      var riskCost = 0.0;
      for (final c in runners.keys) {
        final h = canStopHeights[c]!;
        final gained = (runners[c]! - (camps[seat][c] ?? 0));
        // Outer columns are much harder to hit and more valuable per step
        final stepVal = (15 - h) / 2.0;
        riskCost += gained * stepVal;
      }
      final threshold = botLevel >= 2 ? 12.0 : (botLevel == 1 ? 10.0 : 8.0);
      if (riskCost >= threshold || gainedSteps >= 5) {
        return {'type': 'stop'};
      }
      return {'type': 'roll'};
    }

    return null;
  }
}
