import 'dart:math';

import '../../src/engine.dart';

const List<String> kAgentNames = [
  '红影(0)',
  '蓝狐(1)',
  '绿蛇(2)',
  '黄蜂(3)',
  '紫电(4)',
  '橙鹰(5)',
  '黑鸦(6)',
];

const List<String> kAgentShortNames = [
  '红特工',
  '蓝特工',
  '绿特工',
  '黄特工',
  '紫特工',
  '橙特工',
  '黑特工',
];

const List<String> kBuildingNames = [
  '0号·断壁废墟(-3分)',
  '1号·街角报亭',
  '2号·咖啡馆',
  '3号·古董店',
  '4号·钟表行',
  '5号·美术馆',
  '6号·皇家剧院',
  '7号·机密银行',
  '8号·市政厅',
  '9号·大使馆',
  '10号·情报总部',
];

class HeimlichGame extends GameEngine {
  HeimlichGame(super.setup);

  late int targetScore;
  int turn = 0;
  int turnCount = 0;
  String phase = 'move'; // 'move' | 'move_safe'
  bool over = false;

  /// Current die roll (1..6) for the active player's movement budget.
  int moveBudget = 1;

  /// Position (0..10) of each of the 7 colored agents (0..6).
  late List<int> agentPos;

  /// Public score (0..targetScore+) of each of the 7 colored agents (0..6).
  late List<int> agentScores;

  /// Secret agent ID (0..6) assigned to each player seat (0..players-1).
  late List<int> secretAgent;

  /// Building index (0..10) currently holding the Safe (starts at 7).
  int safeBuilding = 7;

  /// Summary of the most recent scoring event for UI display.
  Map<String, dynamic>? lastScoring;

  static int buildingPoints(int building) => building == 0 ? -3 : building;

  @override
  void start() {
    targetScore = setup.opt<int>('target', 42);
    turn = 0;
    turnCount = 0;
    phase = 'move';
    over = false;
    lastScoring = null;

    agentPos = List.filled(7, 0);
    agentScores = List.filled(7, 0);
    safeBuilding = 7;

    final pool = shuffled([0, 1, 2, 3, 4, 5, 6], rng);
    secretAgent = [for (var s = 0; s < players; s++) pool[s]];

    moveBudget = 1 + rng.nextInt(6);
    host.log('特工暗棋开始！7 名特工潜入小镇，保险箱位于 7 号机密银行，目标分数 $targetScore 分！');
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('当前还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'move') {
      if (type != 'move') {
        throw GameError('请分配移动步数 (move)');
      }
      final steps = asIntList(action['steps']);
      if (steps.length != 7) {
        throw GameError('steps 必须包含 7 名特工的步数列表');
      }
      if (steps.any((x) => x < 0)) {
        throw GameError('移动步数不能为负数');
      }
      final sum = steps.fold<int>(0, (a, b) => a + b);
      if (sum != moveBudget) {
        throw GameError('分配的总步数 ($sum) 必须等于当前骰子点数 ($moveBudget)');
      }

      final movedParts = <String>[];
      var triggeredScoring = false;
      for (var a = 0; a < 7; a++) {
        if (steps[a] > 0) {
          agentPos[a] = (agentPos[a] + steps[a]) % 11;
          movedParts.add('${kAgentShortNames[a]}+${steps[a]}→${agentPos[a]}号');
          if (agentPos[a] == safeBuilding) {
            triggeredScoring = true;
          }
        }
      }

      host.log('${name(seat)} 投出 $moveBudget 点并移动：${movedParts.join("，")}');

      if (triggeredScoring) {
        _triggerScoring(seat);
        if (over) return;

        final optSafe = action.containsKey('safeTo')
            ? asInt(action['safeTo'])
            : (action.containsKey('safeBuilding')
                ? asInt(action['safeBuilding'])
                : -1);
        if (optSafe >= 0 && optSafe <= 10 && optSafe != safeBuilding) {
          _applyMoveSafe(seat, optSafe);
        } else {
          phase = 'move_safe';
        }
        return;
      }

      _advanceTurn();
      return;
    }

    if (phase == 'move_safe') {
      if (type != 'move_safe') {
        throw GameError('请选择保险箱的新位置 (move_safe)');
      }
      final b = action.containsKey('building')
          ? asInt(action['building'])
          : (action.containsKey('to')
              ? asInt(action['to'])
              : asInt(action['pos']));
      if (b < 0 || b > 10) {
        throw GameError('请选择 0..10 号建筑');
      }
      if (b == safeBuilding) {
        throw GameError('必须将保险箱移动到不同的建筑');
      }
      _applyMoveSafe(seat, b);
      return;
    }

    throw GameError('未知阶段: $phase');
  }

  void _triggerScoring(int triggerSeat) {
    final deltas = List<int>.filled(7, 0);
    for (var a = 0; a < 7; a++) {
      final pts = buildingPoints(agentPos[a]);
      final before = agentScores[a];
      agentScores[a] = max(0, before + pts);
      deltas[a] = agentScores[a] - before;
    }

    lastScoring = {
      'bySeat': triggerSeat,
      'safeBuilding': safeBuilding,
      'deltas': deltas,
      'scoresAfter': List<int>.of(agentScores),
    };

    final details = [
      for (var a = 0; a < 7; a++)
        '${kAgentShortNames[a]}(${deltas[a] >= 0 ? "+${deltas[a]}" : "${deltas[a]}"}→${agentScores[a]})',
    ];
    host.log('【情报结算】特工抵达 $safeBuilding 号保险箱！全体特工计分：${details.join(" ")}');

    if (agentScores.any((sc) => sc >= targetScore)) {
      _finishGame('有特工达到目标分数 $targetScore 分！');
    }
  }

  void _applyMoveSafe(int seat, int newBuilding) {
    safeBuilding = newBuilding;
    phase = 'move';
    host.log('${name(seat)} 将【保险箱】转移到了 $safeBuilding 号建筑（${kBuildingNames[safeBuilding]}）');
    _advanceTurn();
  }

  void _advanceTurn() {
    turnCount++;
    if (turnCount >= 160) {
      _finishGame('行动轮数耗尽，进行最终情报结算！');
      return;
    }
    turn = (turn + 1) % players;
    phase = 'move';
    moveBudget = 1 + rng.nextInt(6);
  }

  void _finishGame(String reason) {
    over = true;
    final pScores = playerScores;
    final best = pScores.reduce(max);
    final winners = [
      for (var s = 0; s < players; s++)
        if (pScores[s] == best)
          '${name(s)}(${kAgentShortNames[secretAgent[s]]}:${pScores[s]}分)',
    ];
    host.log('$reason 秘密身份揭晓！最高分赢家：${winners.join("、")}！');
  }

  List<int> get playerScores => [
        for (var s = 0; s < players; s++) agentScores[secretAgent[s]],
      ];

  @override
  Map<String, dynamic> view(int seat) {
    final myAgent = (seat >= 0 && seat < players) ? secretAgent[seat] : null;
    return {
      'turn': turn,
      'turnCount': turnCount,
      'phase': phase,
      'over': over,
      'targetScore': targetScore,
      'moveBudget': moveBudget,
      'safeBuilding': safeBuilding,
      'agentPos': List<int>.of(agentPos),
      'agentScores': List<int>.of(agentScores),
      'myAgent': myAgent,
      'secretAgents': over ? List<int>.of(secretAgent) : null,
      'playerScores': over ? playerScores : null,
      'lastScoring': lastScoring,
      'agentNames': kAgentShortNames,
      'buildingNames': kBuildingNames,
    };
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? rankByScore(playerScores) : null;

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final myAgent = secretAgent[seat];

    if (phase == 'move_safe') {
      // Move the safe to a building near where myAgent can reach, or away from building 0.
      final candidates = [
        for (var b = 1; b <= 10; b++)
          if (b != safeBuilding) b,
      ];
      final target = (agentPos[myAgent] + 3) % 11;
      if (target != 0 && target != safeBuilding) {
        return {'type': 'move_safe', 'building': target};
      }
      return {
        'type': 'move_safe',
        'building': candidates[rng.nextInt(candidates.length)],
      };
    }

    // phase == 'move': distribute `moveBudget` across the 7 agents.
    final steps = List<int>.filled(7, 0);
    var rem = moveBudget;

    if (botLevel == 0 && rng.nextDouble() < 0.35) {
      while (rem > 0) {
        steps[rng.nextInt(7)]++;
        rem--;
      }
      return {'type': 'move', 'steps': steps};
    }

    // Check if any agent can reach `safeBuilding` within `rem` steps.
    int? triggerAgent;
    var triggerCost = 99;
    for (var a = 0; a < 7; a++) {
      final d = (safeBuilding - agentPos[a] + 11) % 11;
      if (d >= 1 && d <= rem) {
        // Check what myAgent's building would be if we trigger scoring now.
        final myFuturePos = ( a == myAgent )
            ? safeBuilding
            : (agentPos[myAgent] + (rem - d)) % 11;
        final myGain = buildingPoints(myFuturePos);
        if (myGain >= 4 && d < triggerCost) {
          triggerCost = d;
          triggerAgent = a;
        }
      }
    }

    if (triggerAgent != null) {
      steps[triggerAgent] += triggerCost;
      rem -= triggerCost;
      if (rem > 0) {
        if (triggerAgent != myAgent &&
            (agentPos[myAgent] + rem) % 11 != 0) {
          steps[myAgent] += rem;
        } else {
          final decoy = (myAgent + 1 + rng.nextInt(6)) % 7;
          steps[decoy] += rem;
        }
      }
      return {'type': 'move', 'steps': steps};
    }

    // Otherwise, move myAgent to a high-value building (avoiding 0) and split with a decoy.
    var giveMy = rem;
    while (giveMy > 0 && (agentPos[myAgent] + giveMy) % 11 == 0) {
      giveMy--;
    }
    if (giveMy > 0 && rng.nextDouble() < 0.75) {
      final actual = max(1, giveMy - (giveMy >= 3 ? 1 : 0));
      if ((agentPos[myAgent] + actual) % 11 != 0) {
        steps[myAgent] += actual;
        rem -= actual;
      }
    }

    // Try to push a high-scoring rival agent into Building 0 (Ruins -3) if reachable!
    for (var a = 0; a < 7 && rem > 0; a++) {
      if (a == myAgent) continue;
      final dToRuins = (11 - agentPos[a]) % 11;
      if (dToRuins >= 1 && dToRuins <= rem && agentScores[a] >= 10) {
        steps[a] += dToRuins;
        rem -= dToRuins;
        break;
      }
    }

    // Assign any remaining steps to decoy agents.
    while (rem > 0) {
      final decoy = (myAgent + 1 + rng.nextInt(6)) % 7;
      steps[decoy]++;
      rem--;
    }

    return {'type': 'move', 'steps': steps};
  }
}
