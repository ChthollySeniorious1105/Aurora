import '../../src/engine.dart';

const String theCrewRules = '''
# 星际探险队 (The Crew) 规则说明

## 基本配置
- **人数与模式**：支持 3~5 人合作闯关！所有船员共同组成星际探险队，合力完成各个星际任务。
- **牌库构成（40张）**：
  - **4 种彩色花色**：蓝 (`B1..B9`)、绿 (`G1..G9`)、粉 (`P1..P9`)、黄 (`Y1..Y9`)，每种花色各 `1~9` 共 36 张。
  - **王牌花色（火箭 Rocket）**：`R1, R2, R3, R4` 共 4 张，火箭永远作为主牌（Trump），可克制任何彩色花色。
- **指挥官 (Commander)**：每关发完 40 张牌后，手握最高火箭 **`R4`** 的玩家自动成为本关指挥官，负责第一个认领任务并首引第一墩！

## 游戏流程
1. **认领任务阶段 (`draft_tasks`)**：
   - 每关开始翻开 2~5 张彩色任务牌（部分任务带有顺序标记 **`1`**、**`2`** 或 **`last`**）。
   - 从指挥官开始按顺时针顺序，每位玩家轮流认领 1 张任务牌（`take_task`），直到所有任务分配完毕。
2. **无线电通信与吃墩阶段 (`play`)**：
   - **无线电通信 (`communicate`)**：在任意一墩首引出牌前，尚未通信过的船员可以执行每关仅限 1 次的无线电通信——亮出自己手中某彩色花色 **最大 (`highest`)**、**最小 (`lowest`)** 或 **唯一 (`only`)** 的一张牌（火箭牌不可通信，通信后的牌仍留在手牌中正常打出）。
   - **吃墩规则 (`play`)**：必须跟出首引花色（若手中没有首引花色，可打出任意花色或用火箭王牌毙牌）。本墩中有火箭则最大火箭赢墩，否则首引花色最大点数赢墩。
3. **任务检定与通关判定**：
   - 每墩结算时，检查本墩打出的牌中是否包含任务牌：
     - **任务失败**：若某张任务牌被**非认领者**赢走，或违反了顺序标记（`1` 必须第 1 个完成，`2` 必须第 2 个完成，`last` 必须最后一个完成），探险队损失 1 点飞船护盾（Hull）并立即重开本关（护盾归零则任务彻底失败）。
     - **任务成功**：当本关所有任务牌均由对应认领者按合法顺序赢取时，本关立即宣告成功！完成全部设定关卡即获得最终胜利！
''';

const List<String> kCrewColorPrefixes = ['B', 'G', 'P', 'Y'];
const List<String> kCrewSuitNames = ['蓝', '绿', '粉', '黄', '火箭'];

int crewSuitIndex(String card) {
  if (card.isEmpty) return 0;
  switch (card[0].toUpperCase()) {
    case 'B':
    case '0':
      return 0;
    case 'G':
    case '1':
      return 1;
    case 'P':
    case '2':
      return 2;
    case 'Y':
    case '3':
      return 3;
    case 'R':
    case '4':
      return 4;
    default:
      return 0;
  }
}

int crewRank(String card) {
  if (card.length < 2) return 1;
  final sub = card.substring(1).replaceAll('-', '').replaceAll(':', '');
  return int.tryParse(sub) ?? 1;
}

bool isRocketCard(String card) => crewSuitIndex(card) == 4;

int crewCardPower(String card, {required int ledSuit}) {
  final suit = crewSuitIndex(card);
  final rank = crewRank(card);
  if (suit == 4) return 100 + rank;
  if (suit == ledSuit) return 20 + rank;
  return rank;
}

List<String> buildTheCrewDeck() => [
      for (final prefix in kCrewColorPrefixes)
        for (var r = 1; r <= 9; r++) '$prefix$r',
      for (var r = 1; r <= 4; r++) 'R$r',
    ];

List<String> buildCrewColoredPool() => [
      for (final prefix in kCrewColorPrefixes)
        for (var r = 1; r <= 9; r++) '$prefix$r',
    ];

/// Checks whether [card] can be communicated from [hand].
/// Returns `'only'`, `'highest'`, `'lowest'`, or `null` if illegal.
String? checkCrewCommunication(String card, List<String> hand) {
  if (!hand.contains(card)) return null;
  final suit = crewSuitIndex(card);
  if (suit == 4) return null; // Rockets cannot be communicated
  final sameSuit = hand.where((c) => crewSuitIndex(c) == suit).toList();
  if (sameSuit.isEmpty) return null;
  if (sameSuit.length == 1) return 'only';
  final r = crewRank(card);
  var minR = 99, maxR = -1;
  for (final c in sameSuit) {
    final cr = crewRank(c);
    if (cr < minR) minR = cr;
    if (cr > maxR) maxR = cr;
  }
  if (r == maxR) return 'highest';
  if (r == minR) return 'lowest';
  return null;
}

typedef TheCrew = TheCrewGame;

class TheCrewGame extends GameEngine {
  late int maxMissions;
  late String difficulty; // 'normal' | 'hard'

  int mission = 1;
  int hull = 3;
  int maxHull = 3;
  int commander = 0;
  int leader = 0;
  int turn = 0;
  String phase = 'draft_tasks'; // 'draft_tasks', 'play', 'over'

  List<List<String>> hands = [];
  List<Map<String, dynamic>> tasks = [];
  List<bool> communicated = [];
  List<Map<String, dynamic>?> radio = [];

  int tricksPlayed = 0;
  List<int> tricksWon = [];
  List<int> playerTasksDone = [];
  List<Map<String, dynamic>> currentTrick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastMissionSummary;
  Map<String, dynamic>? result;

  bool campaignWon = false;
  bool _over = false;

  TheCrewGame(super.setup) {
    maxMissions = setup.opt<int>('missions', 3);
    difficulty = setup.opt<String>('difficulty', 'normal');
  }

  @override
  void start() {
    mission = 1;
    hull = 3;
    maxHull = 3;
    campaignWon = false;
    _over = false;
    result = null;
    lastMissionSummary = null;
    playerTasksDone = List<int>.filled(players, 0);
    _startMission();
  }

  int _taskCountForMission(int m) {
    if (difficulty == 'hard') {
      return (m + 2).clamp(3, 5); // 3, 4, 5
    }
    return (m + 1).clamp(2, 4); // 2, 3, 4
  }

  void _startMission() {
    final deck = shuffled(buildTheCrewDeck(), rng);
    hands = [for (var s = 0; s < players; s++) <String>[]];
    for (var i = 0; i < deck.length; i++) {
      hands[i % players].add(deck[i]);
    }
    for (var s = 0; s < players; s++) {
      hands[s].sort(_compareCards);
      if (hands[s].contains('R4')) {
        commander = s;
      }
    }

    final count = _taskCountForMission(mission);
    final pool = shuffled(buildCrewColoredPool(), rng);
    // Prefer higher-rank task cards so tricks are easier to control
    pool.sort((a, b) => crewRank(b).compareTo(crewRank(a)));
    final chosen = pool.take(count * 2).toList()..shuffle(rng);
    final taskCards = chosen.take(count).toList();

    tasks = [
      for (var i = 0; i < taskCards.length; i++)
        {
          'card': taskCards[i],
          'token': _tokenForTaskIndex(i, count),
          'owner': null,
          'completed': false,
          'completedOrder': null,
        },
    ];

    communicated = List<bool>.filled(players, false);
    radio = List<Map<String, dynamic>?>.filled(players, null);
    tricksPlayed = 0;
    tricksWon = List<int>.filled(players, 0);
    currentTrick = [];
    lastTrick = null;
    phase = 'draft_tasks';
    leader = commander;
    turn = commander;
  }

  String? _tokenForTaskIndex(int idx, int total) {
    if (difficulty == 'hard') {
      if (idx == 0) return '1';
      if (idx == 1 && total >= 4) return '2';
      if (idx == total - 1 && total >= 3) return 'last';
      return null;
    } else {
      if (mission >= 2 && idx == 0) return '1';
      if (mission >= 3 && idx == total - 1) return 'last';
      return null;
    }
  }

  int _compareCards(String a, String b) {
    final sa = crewSuitIndex(a);
    final sb = crewSuitIndex(b);
    if (sa != sb) return sa.compareTo(sb);
    return crewRank(a).compareTo(crewRank(b));
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('任务已结束');
    final type = asStr(action['type']);

    if (phase == 'draft_tasks') {
      if (seat != turn) throw GameError('还没轮到你认领任务');
      if (type != 'take_task') throw GameError('请先认领一张任务牌');
      final idx = asInt(action['index'], -1);
      if (idx < 0 || idx >= tasks.length) throw GameError('无效的任务编号');
      if (tasks[idx]['owner'] != null) throw GameError('该任务已被其他船员认领');

      tasks[idx]['owner'] = seat;
      host.log('${name(seat)} 认领了任务 ${tasks[idx]['card']}${tasks[idx]['token'] != null ? ' [${tasks[idx]['token']}]' : ''}');

      if (tasks.every((t) => t['owner'] != null)) {
        phase = 'play';
        leader = commander;
        turn = commander;
      } else {
        turn = (turn + 1) % players;
      }
      return;
    }

    if (phase == 'play') {
      if (type == 'communicate') {
        if (currentTrick.isNotEmpty) {
          throw GameError('只能在每墩首引出牌前进行无线电通信');
        }
        if (communicated[seat]) {
          throw GameError('本关你已经使用过无线电通信');
        }
        final card = asStr(action['card']);
        final pos = checkCrewCommunication(card, hands[seat]);
        if (pos == null) {
          throw GameError('只能通信手中某彩色花色最大、最小或唯一的一张牌（火箭牌不可通信）');
        }
        communicated[seat] = true;
        radio[seat] = {
          'card': card,
          'position': pos,
          'active': true,
        };
        host.log('${name(seat)} 无线电通信亮出 $card ($pos)');
        return;
      }

      if (type == 'play') {
        if (seat != turn) throw GameError('还没轮到你出牌');
        final card = asStr(action['card']);
        if (!hands[seat].contains(card)) throw GameError('手中没有这张牌');

        if (currentTrick.isNotEmpty) {
          final ledSuit = crewSuitIndex(asStr(currentTrick.first['card']));
          final hasLedSuit = hands[seat].any((c) => crewSuitIndex(c) == ledSuit);
          if (hasLedSuit && crewSuitIndex(card) != ledSuit) {
            throw GameError('必须跟出首引花色（${kCrewSuitNames[ledSuit]}）');
          }
        }

        hands[seat].remove(card);
        if (radio[seat] != null && radio[seat]!['card'] == card) {
          radio[seat] = {...radio[seat]!, 'active': false};
        }
        currentTrick.add({'seat': seat, 'card': card});

        if (currentTrick.length < players) {
          turn = (turn + 1) % players;
          return;
        }

        _resolveTrick();
        return;
      }

      throw GameError('未知操作');
    }

    throw GameError('当前阶段无法执行此操作');
  }

  void _resolveTrick() {
    final ledSuit = crewSuitIndex(asStr(currentTrick.first['card']));
    var bestIdx = 0;
    var bestPow = -1;
    for (var i = 0; i < currentTrick.length; i++) {
      final c = asStr(currentTrick[i]['card']);
      final pow = crewCardPower(c, ledSuit: ledSuit);
      if (pow > bestPow) {
        bestPow = pow;
        bestIdx = i;
      }
    }

    final winner = asInt(currentTrick[bestIdx]['seat'], 0);
    final trickCards = [for (final e in currentTrick) asStr(e['card'])];
    tricksWon[winner]++;
    tricksPlayed++;

    lastTrick = {
      'leader': leader,
      'winner': winner,
      'cards': List<Map<String, dynamic>>.of(currentTrick),
    };
    currentTrick = [];
    leader = winner;
    turn = winner;

    // Check any Task Cards present in this trick
    final wonTasks = <Map<String, dynamic>>[
      for (final t in tasks)
        if (trickCards.contains(asStr(t['card']))) t,
    ];

    if (wonTasks.isNotEmpty) {
      // 1. Check owner
      for (final t in wonTasks) {
        if (t['owner'] != winner) {
          _handleMissionFailure(
            '任务牌 ${t['card']} 被 ${name(winner)} 误吃（应由 ${name(asInt(t['owner'], 0))} 赢取）',
          );
          return;
        }
      }

      // 2. Sort tasks won in the same trick by token priority ('1' -> '2' -> null -> 'last')
      int tokenSortKey(String? tok) {
        if (tok == '1') return 0;
        if (tok == '2') return 1;
        if (tok == 'last') return 3;
        return 2;
      }

      wonTasks.sort(
        (a, b) => tokenSortKey(a['token'] as String?).compareTo(
          tokenSortKey(b['token'] as String?),
        ),
      );

      var completedSoFar = tasks.where((t) => t['completed'] == true).length;
      for (final t in wonTasks) {
        final nextOrder = completedSoFar + 1;
        final tok = t['token'] as String?;

        if (tok == '1' && nextOrder != 1) {
          _handleMissionFailure('任务 ${t['card']} [1] 必须第一个完成');
          return;
        }
        if (tok == '2' && nextOrder != 2) {
          _handleMissionFailure('任务 ${t['card']} [2] 必须第二个完成');
          return;
        }
        if (tok == 'last' && nextOrder != tasks.length) {
          _handleMissionFailure('任务 ${t['card']} [last] 必须最后一个完成');
          return;
        }

        // Check if another uncompleted task needed this exact order slot
        for (final other in tasks) {
          if (identical(other, t) || other['completed'] == true || wonTasks.contains(other)) {
            continue;
          }
          final otherTok = other['token'] as String?;
          if (otherTok == '1' && nextOrder >= 1) {
            _handleMissionFailure('顺序 [1] 任务 ${other['card']} 尚未完成，不能先完成其他任务');
            return;
          }
          if (otherTok == '2' && nextOrder >= 2) {
            _handleMissionFailure('顺序 [2] 任务 ${other['card']} 尚未完成，不能先完成第 2 个任务');
            return;
          }
        }

        t['completed'] = true;
        t['completedOrder'] = nextOrder;
        completedSoFar = nextOrder;
        playerTasksDone[winner]++;
      }
    }

    // Check if all tasks are completed!
    if (tasks.every((t) => t['completed'] == true)) {
      _handleMissionSuccess();
      return;
    }

    // Check if any player is out of cards (no more full tricks possible) while tasks remain
    if (hands.any((h) => h.isEmpty)) {
      _handleMissionFailure('手牌耗尽，仍有未完成的星际任务');
    }
  }

  void _handleMissionFailure(String reason) {
    hull--;
    lastMissionSummary = {
      'mission': mission,
      'status': 'failed',
      'reason': reason,
      'hullRemaining': hull,
    };
    host.log('第 $mission 关失利：$reason（剩余护盾 $hull）');

    if (hull <= 0) {
      _over = true;
      campaignWon = false;
      phase = 'over';
      result = {
        'campaignWon': false,
        'missionReached': mission,
        'maxMissions': maxMissions,
        'reason': reason,
        'playerTasksDone': List<int>.of(playerTasksDone),
      };
      return;
    }

    // Retry current mission
    _startMission();
  }

  void _handleMissionSuccess() {
    lastMissionSummary = {
      'mission': mission,
      'status': 'success',
      'hullRemaining': hull,
    };
    host.log('第 $mission 关任务圆满完成！');

    if (mission >= maxMissions) {
      _over = true;
      campaignWon = true;
      phase = 'over';
      result = {
        'campaignWon': true,
        'missionReached': mission,
        'maxMissions': maxMissions,
        'hullRemaining': hull,
        'playerTasksDone': List<int>.of(playerTasksDone),
      };
      return;
    }

    mission++;
    _startMission();
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'mission': mission,
      'maxMissions': maxMissions,
      'difficulty': difficulty,
      'hull': hull,
      'maxHull': maxHull,
      'commander': commander,
      'leader': leader,
      'turn': turn,
      'phase': phase,
      'myHand': seat >= 0 && seat < players ? List<String>.of(hands[seat]) : const <String>[],
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'tasks': [for (final t in tasks) Map<String, dynamic>.of(t)],
      'communicated': List<bool>.of(communicated),
      'radio': [
        for (final r in radio) r == null ? null : Map<String, dynamic>.of(r),
      ],
      'tricksPlayed': tricksPlayed,
      'tricksWon': List<int>.of(tricksWon),
      'currentTrick': [
        for (final e in currentTrick) Map<String, dynamic>.of(e),
      ],
      'lastTrick': lastTrick,
      'lastMissionSummary': lastMissionSummary,
      'campaignWon': campaignWon,
      'result': result,
    };
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (campaignWon) {
      return List<int>.filled(players, 1);
    }
    return rankByScore([
      for (var s = 0; s < players; s++) playerTasksDone[s] * 10 + tricksWon[s],
    ]);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'draft_tasks') {
      // Pick the unassigned task that best matches our hand strength in that suit
      var bestIdx = -1;
      var bestScore = -1000;
      for (var i = 0; i < tasks.length; i++) {
        if (tasks[i]['owner'] != null) continue;
        final tCard = asStr(tasks[i]['card']);
        final tSuit = crewSuitIndex(tCard);
        var score = 0;
        if (hands[seat].contains(tCard)) score += 30;
        for (final c in hands[seat]) {
          if (crewSuitIndex(c) == tSuit && crewRank(c) >= 7) score += 15;
          if (isRocketCard(c)) score += 10 * crewRank(c);
        }
        if (score > bestScore) {
          bestScore = score;
          bestIdx = i;
        }
      }
      return {'type': 'take_task', 'index': bestIdx};
    }

    // phase == 'play'
    final hand = hands[seat];
    List<String> legal = hand;
    if (currentTrick.isNotEmpty) {
      final ledSuit = crewSuitIndex(asStr(currentTrick.first['card']));
      final follow = hand.where((c) => crewSuitIndex(c) == ledSuit).toList();
      if (follow.isNotEmpty) legal = follow;
    }

    // Cooperative heuristic:
    // Check if there is an uncompleted task in the current trick or in our hand
    final uncompleted = tasks.where((t) => t['completed'] != true).toList();
    final taskCardOwners = <String, int>{
      for (final t in uncompleted) asStr(t['card']): asInt(t['owner'], 0),
    };

    if (currentTrick.isEmpty) {
      // Leading a trick: if we own an uncompleted task and hold it or a high card of its suit, lead it
      for (final t in uncompleted) {
        if (t['owner'] == seat) {
          final tc = asStr(t['card']);
          if (legal.contains(tc) && crewRank(tc) >= 7) {
            return {'type': 'play', 'card': tc};
          }
        }
      }
      // Otherwise lead a safe non-task card
      final nonTask = legal.where((c) => !taskCardOwners.containsKey(c)).toList();
      if (nonTask.isNotEmpty) {
        return {'type': 'play', 'card': nonTask.first};
      }
      return {'type': 'play', 'card': legal.first};
    }

    // Following in a trick: check if any task card is already in the trick
    final ledSuit = crewSuitIndex(asStr(currentTrick.first['card']));
    int? desiredWinner;
    for (final e in currentTrick) {
      final c = asStr(e['card']);
      if (taskCardOwners.containsKey(c)) {
        desiredWinner = taskCardOwners[c];
        break;
      }
    }

    if (desiredWinner == seat) {
      // We want to win this trick! Play our highest power card
      final sorted = List<String>.of(legal)
        ..sort(
          (a, b) => crewCardPower(b, ledSuit: ledSuit).compareTo(
            crewCardPower(a, ledSuit: ledSuit),
          ),
        );
      return {'type': 'play', 'card': sorted.first};
    } else if (desiredWinner != null && desiredWinner != seat) {
      // Teammate needs to win this trick! Play our lowest power non-task card
      final sorted = List<String>.of(legal)
        ..sort(
          (a, b) => crewCardPower(a, ledSuit: ledSuit).compareTo(
            crewCardPower(b, ledSuit: ledSuit),
          ),
        );
      return {'type': 'play', 'card': sorted.first};
    } else {
      // No task card in trick yet: if we hold a task card belonging to current trick leader/winner, dump it!
      var curBestPow = -1;
      var curWinner = 0;
      for (final e in currentTrick) {
        final pow = crewCardPower(asStr(e['card']), ledSuit: ledSuit);
        if (pow > curBestPow) {
          curBestPow = pow;
          curWinner = asInt(e['seat'], 0);
        }
      }
      for (final c in legal) {
        if (taskCardOwners[c] == curWinner &&
            crewCardPower(c, ledSuit: ledSuit) < curBestPow) {
          return {'type': 'play', 'card': c};
        }
      }
      final safe = legal.where((c) => !taskCardOwners.containsKey(c)).toList();
      return {'type': 'play', 'card': (safe.isNotEmpty ? safe : legal).first};
    }
  }
}
