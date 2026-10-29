import 'dart:math';

import '../../src/engine.dart';

const List<String> saboteurTools = ['pickaxe', 'lantern', 'cart'];

const Map<String, String> saboteurToolNames = {
  'pickaxe': '十字镐',
  'lantern': '矿灯',
  'cart': '矿车',
};

const List<(int, int)> saboteurGoalPositions = [
  (0, 8),
  (2, 8),
  (4, 8),
];

String saboteurOppositeDir(String d) {
  switch (d) {
    case 'N':
      return 'S';
    case 'S':
      return 'N';
    case 'E':
      return 'W';
    case 'W':
      return 'E';
    default:
      return '';
  }
}

(int, int) saboteurStep(int r, int c, String d) {
  switch (d) {
    case 'N':
      return (r - 1, c);
    case 'S':
      return (r + 1, c);
    case 'E':
      return (r, c + 1);
    case 'W':
      return (r, c - 1);
    default:
      return (r, c);
  }
}

const saboteurRules = '''
# 概述
《矮人矿坑》（Saboteur）是一款风靡全球的隐藏身份派对桌游，支持 3~8 人游玩。玩家秘密分为两大阵营：
- 【淘金矮人（Gold-Diggers）】：齐心协力从起点梯子（2, 0）挖掘一条连续畅通的矿道通往右侧 3 张终点卡中的【金矿】！
- 【破坏者（Saboteurs）】：暗中搞破坏（3~4 人局 1 名，5~6 人局 2 名，7~8 人局 3 名），通过放置死胡同、弄坏工具、引发塌方阻止淘金矮人在牌堆耗尽前挖到金矿！

# 矿坑棋盘（9×5 网格）
- 起点卡位于左侧中央 `(r: 2, c: 0)`，四面（N/E/S/W）全部互通。
- 3 张终点卡位于右侧 `(r: 0, c: 8)`、`(r: 2, c: 8)`、`(r: 4, c: 8)`，其中 1 张是【金矿】，2 张是【石头】，开局背面朝上洗混。

# 卡牌类型与回合行动
轮到你时，必须从以下三项中选择一项执行，随后从牌堆摸 1 张牌（若牌堆非空）：
1. 放置通道卡（place_path）：
   - 只有当你面前【没有任何损坏的工具】时才能放置通道卡。
   - 必须放置在与已有卡牌正交相邻的空格，四边接口必须与所有相邻已翻开卡牌完全匹配（通路对通路、墙壁对墙壁），且必须能从起点 `(2, 0)` 沿着连续畅通的通道到达该格！
   - 死胡同卡（deadEnd）可以合法接入矿道，但中心被岩石堵死，矿道无法穿过它继续延伸。
2. 打出行动卡（action）：
   - 破坏工具（break）：弄坏另一名玩家的【十字镐（pickaxe）】、【矿灯（lantern）】或【矿车（cart）】。只要有任意工具处于损坏状态，该玩家就不能放置通道卡！
   - 修复工具（repair）：修复任意一名玩家（包括自己）对应类型的已损坏工具。
   - 落石塌方（rockfall）：移除棋盘上任意 1 张非起点、非终点的通道卡！
   - 藏宝图（map）：秘密查看右侧 3 张终点卡中的任意 1 张（仅自己可见）！
3. 弃牌摸牌（discard）：暗置弃掉手中任意 1 张牌并摸 1 张新牌。

# 单局结算与胜负
- 当一条从起点 `(2, 0)` 出发的连续畅通通道连入某张终点卡时，翻开该终点卡：若是【金矿】，本局【淘金矮人获胜】并分得金块！
- 若牌堆摸空且所有玩家手牌全部打完仍未连通知金矿，则本局【破坏者获胜】并分得金块！
- 支持标准 3 局制或快速 1 局制，全部局数结束后累计金块最多者获胜！
''';

/// Returns all `(r, c)` cells on the grid that have a passable (`deadEnd != true`)
/// card reachable via a continuous open path from Start `(2, 0)`.
Set<(int, int)> saboteurReachablePassableCells(
  Map<(int, int), Map<String, dynamic>> grid,
) {
  final start = grid[(2, 0)];
  if (start == null || start['deadEnd'] == true) return const {};
  final visited = <(int, int)>{(2, 0)};
  final queue = <(int, int)>[(2, 0)];
  while (queue.isNotEmpty) {
    final (r, c) = queue.removeAt(0);
    final card = grid[(r, c)];
    if (card == null || card['deadEnd'] == true) continue;
    final edges = (card['edges'] as List).cast<String>().toSet();
    for (final d in edges) {
      final (nr, nc) = saboteurStep(r, c, d);
      if (visited.contains((nr, nc))) continue;
      final neighbor = grid[(nr, nc)];
      if (neighbor == null) continue;
      final nEdges = (neighbor['edges'] as List).cast<String>().toSet();
      if (nEdges.contains(saboteurOppositeDir(d))) {
        visited.add((nr, nc));
        if (neighbor['deadEnd'] != true) {
          queue.add((nr, nc));
        }
      }
    }
  }
  return visited;
}

/// Checks if [card] can be legally placed at `(r, c)` on [grid].
bool saboteurCanPlacePath(
  Map<(int, int), Map<String, dynamic>> grid,
  int r,
  int c,
  Map<String, dynamic> card,
) {
  if (r < 0 || r >= 5 || c < 0 || c >= 9) return false;
  if (r == 2 && c == 0) return false;
  if (c == 8 && (r == 0 || r == 2 || r == 4)) return false;
  if (grid.containsKey((r, c))) return false;
  if (card['kind'] != 'path') return false;

  final myEdges = (card['edges'] as List).cast<String>().toSet();
  if (myEdges.isEmpty) return false;

  final passableReachable = saboteurReachablePassableCells(grid);
  var connectedToStart = false;

  for (final d in const ['N', 'E', 'S', 'W']) {
    final (nr, nc) = saboteurStep(r, c, d);
    final neighbor = grid[(nr, nc)];
    if (neighbor == null) continue;
    final nEdges = (neighbor['edges'] as List).cast<String>().toSet();
    final myOpen = myEdges.contains(d);
    final neighborOpen = nEdges.contains(saboteurOppositeDir(d));
    if (myOpen != neighborOpen) {
      return false; // Edge mismatch with an existing card
    }
    if (myOpen && neighborOpen && passableReachable.contains((nr, nc))) {
      connectedToStart = true;
    }
  }

  return connectedToStart;
}

List<Map<String, dynamic>> buildSaboteurDeck() {
  var nextId = 1;
  final deck = <Map<String, dynamic>>[];

  void addPath(List<String> edges, {bool deadEnd = false, int count = 1}) {
    for (var i = 0; i < count; i++) {
      deck.add({
        'id': nextId++,
        'kind': 'path',
        'edges': List<String>.of(edges),
        'deadEnd': deadEnd,
      });
    }
  }

  // Passable tunnel cards (generous East-West connectivity for 9x5 grid)
  addPath(['N', 'E', 'S', 'W'], count: 7);
  addPath(['N', 'E', 'S'], count: 5);
  addPath(['N', 'E', 'W'], count: 6);
  addPath(['E', 'S', 'W'], count: 6);
  addPath(['N', 'S', 'W'], count: 3);
  addPath(['E', 'W'], count: 6);
  addPath(['N', 'S'], count: 3);
  addPath(['N', 'E'], count: 2);
  addPath(['S', 'E'], count: 2);
  addPath(['N', 'W'], count: 2);
  addPath(['S', 'W'], count: 2);

  // Dead-end blocker cards
  addPath(['N', 'E', 'S', 'W'], deadEnd: true, count: 1);
  addPath(['E', 'W'], deadEnd: true, count: 2);
  addPath(['N', 'E', 'W'], deadEnd: true, count: 1);
  addPath(['E', 'S', 'W'], deadEnd: true, count: 1);
  addPath(['N', 'S'], deadEnd: true, count: 1);
  addPath(['W'], deadEnd: true, count: 1);

  // Action: break
  for (final tool in saboteurTools) {
    for (var i = 0; i < 3; i++) {
      deck.add({
        'id': nextId++,
        'kind': 'action',
        'action': 'break',
        'tool': tool,
      });
    }
  }

  // Action: repair (single & dual tool)
  for (final tool in saboteurTools) {
    for (var i = 0; i < 2; i++) {
      deck.add({
        'id': nextId++,
        'kind': 'action',
        'action': 'repair',
        'tools': [tool],
      });
    }
  }
  deck.add({'id': nextId++, 'kind': 'action', 'action': 'repair', 'tools': ['pickaxe', 'lantern']});
  deck.add({'id': nextId++, 'kind': 'action', 'action': 'repair', 'tools': ['pickaxe', 'cart']});
  deck.add({'id': nextId++, 'kind': 'action', 'action': 'repair', 'tools': ['lantern', 'cart']});

  // Action: rockfall
  for (var i = 0; i < 3; i++) {
    deck.add({'id': nextId++, 'kind': 'action', 'action': 'rockfall'});
  }

  // Action: map
  for (var i = 0; i < 5; i++) {
    deck.add({'id': nextId++, 'kind': 'action', 'action': 'map'});
  }

  return deck;
}

class SaboteurGame extends GameEngine {
  SaboteurGame(super.setup);

  late int totalRounds = setup.opt<int>('rounds', 3);
  int round = 1;
  String phase = 'play'; // 'play' | 'roundEnd' | 'gameOver'
  bool over = false;
  int turn = 0;

  late List<String> roles = List.filled(players, 'digger'); // 'digger' | 'saboteur'
  late List<int> gold = List.filled(players, 0);
  late List<List<Map<String, dynamic>>> hands = [for (var s = 0; s < players; s++) []];
  late List<Set<String>> brokenTools = [for (var s = 0; s < players; s++) <String>{}];
  late List<Map<int, String>> peekedGoals = [for (var s = 0; s < players; s++) <int, String>{}];

  List<Map<String, dynamic>> deck = [];
  Map<(int, int), Map<String, dynamic>> grid = {};
  List<String> goalTypes = ['gold', 'stone', 'stone']; // indices 0, 1, 2 for r = 0, 2, 4 at c = 8
  List<bool> revealedGoals = [false, false, false];

  Set<int> ackedNextRound = {};
  Map<String, dynamic>? lastAction;
  Map<String, dynamic>? roundSummary;
  final List<String> logs = [];

  void _say(String text) {
    logs.add(text);
    if (logs.length > 40) logs.removeAt(0);
    host.log(text);
  }

  int get saboteurCount => players <= 4 ? 1 : (players <= 6 ? 2 : 3);
  int get initialHandSize => players <= 5 ? 6 : (players <= 7 ? 5 : 4);

  @override
  void start() {
    round = 1;
    turn = rng.nextInt(players);
    _startRound();
  }

  void _startRound() {
    phase = 'play';
    ackedNextRound.clear();
    roundSummary = null;

    // Assign hidden roles: exact saboteur count per player bracket
    final rolePool = <String>[
      for (var i = 0; i < saboteurCount; i++) 'saboteur',
      for (var i = 0; i < players - saboteurCount; i++) 'digger',
    ]..shuffle(rng);
    roles = rolePool;

    // Shuffle 3 goal cards (1 gold, 2 stone)
    goalTypes = shuffled(['gold', 'stone', 'stone'], rng);
    revealedGoals = [false, false, false];

    // Initialize grid with Start ladder card at (2, 0)
    grid = {
      (2, 0): {
        'id': 0,
        'kind': 'start',
        'edges': ['N', 'E', 'S', 'W'],
        'deadEnd': false,
      },
    };

    brokenTools = [for (var s = 0; s < players; s++) <String>{}];
    peekedGoals = [for (var s = 0; s < players; s++) <int, String>{}];

    deck = shuffled(buildSaboteurDeck(), rng);
    hands = [for (var s = 0; s < players; s++) <Map<String, dynamic>>[]];
    final handCount = initialHandSize;
    for (var s = 0; s < players; s++) {
      for (var i = 0; i < handCount && deck.isNotEmpty; i++) {
        hands[s].add(deck.removeLast());
      }
    }

    _say('矮人矿坑 第 $round/$totalRounds 局开始！（${players - saboteurCount} 名淘金矮人 vs $saboteurCount 名破坏者），${name(turn)} 先手。');
  }

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor {
    if (over) return const [];
    if (phase == 'roundEnd') {
      return [for (var s = 0; s < players; s++) if (!ackedNextRound.contains(s)) s];
    }
    return [turn];
  }

  @override
  List<int>? get placings => over ? rankByScore(gold) : null;

  void _drawOne(int seat) {
    if (deck.isNotEmpty) {
      hands[seat].add(deck.removeLast());
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'roundEnd') {
      if (type != 'next_round') throw GameError('请点击继续进入下一局');
      ackedNextRound.add(seat);
      if (ackedNextRound.length >= players) {
        round++;
        turn = (turn + 1) % players;
        _startRound();
      }
      return;
    }

    if (seat != turn) throw GameError('还没轮到你操作');
    final idx = asInt(action['index'], -1);
    if (idx < 0 || idx >= hands[seat].length) {
      throw GameError('请选择一张有效的手牌');
    }
    final card = hands[seat][idx];

    if (type == 'discard') {
      hands[seat].removeAt(idx);
      _drawOne(seat);
      lastAction = {'type': 'discard', 'seat': seat};
      _say('${name(seat)} 弃掉了 1 张手牌');
      _afterTurnAction(seat);
      return;
    }

    if (type == 'place_path') {
      if (card['kind'] != 'path') {
        throw GameError('所选手牌不是通道卡');
      }
      if (brokenTools[seat].isNotEmpty) {
        final brokenNames = brokenTools[seat].map((t) => saboteurToolNames[t] ?? t).join('、');
        throw GameError('你的工具（$brokenNames）已损坏，修复前不能放置通道卡');
      }
      final r = asInt(action['r'], -1);
      final c = asInt(action['c'], -1);
      if (!saboteurCanPlacePath(grid, r, c, card)) {
        throw GameError('该位置无法合法放置此通道卡（需与起点连通且四边接口匹配）');
      }

      hands[seat].removeAt(idx);
      grid[(r, c)] = Map<String, dynamic>.of(card);
      _drawOne(seat);
      lastAction = {
        'type': 'place_path',
        'seat': seat,
        'r': r,
        'c': c,
        'card': card,
      };
      _say('${name(seat)} 在 ($r, $c) 放置了${card['deadEnd'] == true ? "死胡同" : "矿道"}卡');
      if (_checkGoalsAndWin(seat)) return;
      _afterTurnAction(seat);
      return;
    }

    if (type == 'action') {
      if (card['kind'] != 'action') {
        throw GameError('所选手牌不是行动卡');
      }
      final actKind = asStr(card['action']);

      if (actKind == 'break') {
        final target = asInt(action['target'], -1);
        if (target < 0 || target >= players || target == seat) {
          throw GameError('请选择另一名玩家作为破坏目标');
        }
        final tool = asStr(card['tool']);
        if (brokenTools[target].contains(tool)) {
          throw GameError('${name(target)} 的${saboteurToolNames[tool] ?? tool}已经损坏了');
        }
        hands[seat].removeAt(idx);
        brokenTools[target].add(tool);
        _drawOne(seat);
        lastAction = {
          'type': 'break',
          'seat': seat,
          'target': target,
          'tool': tool,
        };
        _say('${name(seat)} 弄坏了 ${name(target)} 的【${saboteurToolNames[tool] ?? tool}】！');
        _afterTurnAction(seat);
        return;
      }

      if (actKind == 'repair') {
        final target = asInt(action['target'], -1);
        if (target < 0 || target >= players) {
          throw GameError('请选择要修复工具的玩家');
        }
        final allowedTools = (card['tools'] as List).cast<String>();
        var tool = asStr(action['tool']);
        if (tool.isEmpty) {
          final matching = allowedTools.where((t) => brokenTools[target].contains(t)).toList();
          if (matching.isNotEmpty) tool = matching.first;
        }
        if (!allowedTools.contains(tool) || !brokenTools[target].contains(tool)) {
          throw GameError('目标玩家没有可被此卡修复的对应损坏工具');
        }
        hands[seat].removeAt(idx);
        brokenTools[target].remove(tool);
        _drawOne(seat);
        lastAction = {
          'type': 'repair',
          'seat': seat,
          'target': target,
          'tool': tool,
        };
        _say('${name(seat)} 修复了 ${name(target)} 的【${saboteurToolNames[tool] ?? tool}】');
        _afterTurnAction(seat);
        return;
      }

      if (actKind == 'rockfall') {
        final r = asInt(action['r'], -1);
        final c = asInt(action['c'], -1);
        final existing = grid[(r, c)];
        if (existing == null || existing['kind'] != 'path') {
          throw GameError('只能移除棋盘上已放置的非起点、非终点通道卡');
        }
        hands[seat].removeAt(idx);
        grid.remove((r, c));
        _drawOne(seat);
        lastAction = {
          'type': 'rockfall',
          'seat': seat,
          'r': r,
          'c': c,
        };
        _say('${name(seat)} 发动【落石塌方】，移除了 ($r, $c) 的通道卡！');
        if (_checkGoalsAndWin(seat)) return;
        _afterTurnAction(seat);
        return;
      }

      if (actKind == 'map') {
        final goalIdx = asInt(action['goalIndex'], -1);
        if (goalIdx < 0 || goalIdx >= 3) {
          throw GameError('请选择要查看的终点卡（0、1 或 2）');
        }
        hands[seat].removeAt(idx);
        peekedGoals[seat][goalIdx] = goalTypes[goalIdx];
        _drawOne(seat);
        lastAction = {
          'type': 'map',
          'seat': seat,
          'goalIndex': goalIdx,
        };
        _say('${name(seat)} 使用【藏宝图】秘密查看了第 ${goalIdx + 1} 张终点卡');
        _afterTurnAction(seat);
        return;
      }
    }

    throw GameError('未知操作类型');
  }

  bool _checkGoalsAndWin(int activeSeat) {
    final passable = saboteurReachablePassableCells(grid);
    for (final (r, c) in passable) {
      final card = grid[(r, c)]!;
      final edges = (card['edges'] as List).cast<String>();
      for (final d in edges) {
        final (nr, nc) = saboteurStep(r, c, d);
        if (nc == 8 && (nr == 0 || nr == 2 || nr == 4)) {
          final gIdx = nr ~/ 2;
          if (!revealedGoals[gIdx]) {
            revealedGoals[gIdx] = true;
            grid[(nr, nc)] = {
              'id': 900 + gIdx,
              'kind': 'goal',
              'goalType': goalTypes[gIdx],
              'edges': ['N', 'E', 'S', 'W'],
              'deadEnd': false,
            };
            _say('${name(activeSeat)} 挖通了终点 ($nr, 8)，翻开是【${goalTypes[gIdx] == 'gold' ? '金矿' : '石头'}】！');
          }
          if (goalTypes[gIdx] == 'gold') {
            _finishRound(diggerWin: true, finderSeat: activeSeat);
            return true;
          }
        }
      }
    }
    return false;
  }

  void _afterTurnAction(int activeSeat) {
    if (deck.isEmpty && hands.every((h) => h.isEmpty)) {
      _finishRound(diggerWin: false, finderSeat: -1);
      return;
    }
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (hands[next].isNotEmpty) {
        turn = next;
        return;
      }
    }
    _finishRound(diggerWin: false, finderSeat: -1);
  }

  void _finishRound({required bool diggerWin, required int finderSeat}) {
    final gained = List.filled(players, 0);
    if (diggerWin) {
      for (var s = 0; s < players; s++) {
        if (roles[s] == 'digger') {
          final bonus = s == finderSeat ? 4 : 3;
          gold[s] += bonus;
          gained[s] = bonus;
        }
      }
      _say('第 $round 局结束：淘金矮人成功挖到金矿获胜！');
    } else {
      final sabReward = saboteurCount == 1 ? 4 : 3;
      for (var s = 0; s < players; s++) {
        if (roles[s] == 'saboteur') {
          gold[s] += sabReward;
          gained[s] = sabReward;
        }
      }
      _say('第 $round 局结束：牌堆与手牌耗尽，破坏者阵营获胜！');
    }

    roundSummary = {
      'round': round,
      'winnerTeam': diggerWin ? 'digger' : 'saboteur',
      'finderSeat': finderSeat,
      'roles': List.of(roles),
      'gainedGold': gained,
      'goalTypes': List.of(goalTypes),
    };

    if (round >= totalRounds) {
      over = true;
      phase = 'gameOver';
      final best = gold.reduce(max);
      final winners = [for (var s = 0; s < players; s++) if (gold[s] == best) name(s)].join('、');
      _say('全场比赛结束！$winners 以 $best 块金子夺冠！');
    } else {
      phase = 'roundEnd';
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final revealAll = over || phase == 'roundEnd';
    final visibleGoals = <Map<String, dynamic>>[];
    for (var gIdx = 0; gIdx < 3; gIdx++) {
      final (gr, gc) = saboteurGoalPositions[gIdx];
      final canSee = revealAll ||
          revealedGoals[gIdx] ||
          (seat >= 0 && seat < players && peekedGoals[seat].containsKey(gIdx));
      visibleGoals.add({
        'goalIndex': gIdx,
        'r': gr,
        'c': gc,
        'revealed': revealedGoals[gIdx],
        'knownType': canSee ? goalTypes[gIdx] : null,
      });
    }

    return {
      'players': players,
      'turn': turn,
      'round': round,
      'totalRounds': totalRounds,
      'phase': phase,
      'deckCount': deck.length,
      'myRole': seat >= 0 && seat < players ? roles[seat] : null,
      'roles': revealAll ? List.of(roles) : null,
      'gold': List.of(gold),
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'hand': seat >= 0 && seat < players ? List.of(hands[seat]) : const <Map<String, dynamic>>[],
      'brokenTools': [
        for (var s = 0; s < players; s++) (brokenTools[s].toList()..sort())
      ],
      'grid': {
        for (final e in grid.entries) '${e.key.$1},${e.key.$2}': e.value,
      },
      'gridCells': [
        for (final e in grid.entries)
          {
            'r': e.key.$1,
            'c': e.key.$2,
            ...e.value,
          }
      ],
      'reachableCells': [
        for (final (r, c) in saboteurReachablePassableCells(grid)) '$r,$c'
      ],
      'goals': visibleGoals,
      'lastAction': lastAction,
      'roundSummary': roundSummary,
      'ackedNextRound': ackedNextRound.toList()..sort(),
      'over': over,
      'log': logs.length > 12 ? logs.sublist(logs.length - 12) : List.of(logs),
    };
  }

  // ------------------------------------------------------------------ Bot
  /// All valid `(r, c)` cells where [card] can be placed right now.
  List<(int, int)> validPlacementsForCard(Map<String, dynamic> card) {
    if (card['kind'] != 'path') return const [];
    final out = <(int, int)>[];
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 9; c++) {
        if (saboteurCanPlacePath(grid, r, c, card)) {
          out.add((r, c));
        }
      }
    }
    return out;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over) return null;
    if (phase == 'roundEnd') {
      if (!ackedNextRound.contains(seat)) return {'type': 'next_round'};
      return null;
    }
    if (seat != turn || hands[seat].isEmpty) return null;

    final hand = hands[seat];
    final myRole = roles[seat];
    final myKnownGoals = <int, String>{
      for (var i = 0; i < 3; i++)
        if (revealedGoals[i]) i: goalTypes[i],
      ...peekedGoals[seat],
    };

    // Target goal row preference for diggers (based ONLY on what seat knows!)
    int targetGoalRow = 2;
    for (final e in myKnownGoals.entries) {
      if (e.value == 'gold') {
        targetGoalRow = e.key * 2;
        break;
      }
    }
    if (!myKnownGoals.values.contains('gold')) {
      for (var gIdx = 0; gIdx < 3; gIdx++) {
        if (!myKnownGoals.containsKey(gIdx)) {
          targetGoalRow = gIdx * 2;
          break;
        }
      }
    }

    // 1. If our own tool is broken and we have a repair card for it, repair ourselves!
    if (brokenTools[seat].isNotEmpty) {
      for (var i = 0; i < hand.length; i++) {
        final c = hand[i];
        if (c['kind'] == 'action' && c['action'] == 'repair') {
          final tools = (c['tools'] as List).cast<String>();
          for (final t in tools) {
            if (brokenTools[seat].contains(t)) {
              return {'type': 'action', 'index': i, 'target': seat, 'tool': t};
            }
          }
        }
      }
    }

    if (myRole == 'digger') {
      // Use map card if we don't know where the gold is yet
      if (!myKnownGoals.values.contains('gold')) {
        for (var i = 0; i < hand.length; i++) {
          final c = hand[i];
          if (c['kind'] == 'action' && c['action'] == 'map') {
            for (var gIdx = 0; gIdx < 3; gIdx++) {
              if (!myKnownGoals.containsKey(gIdx)) {
                return {'type': 'action', 'index': i, 'goalIndex': gIdx};
              }
            }
          }
        }
      }

      // Remove dead-end blockers with rockfall
      for (var i = 0; i < hand.length; i++) {
        final c = hand[i];
        if (c['kind'] == 'action' && c['action'] == 'rockfall') {
          for (final e in grid.entries) {
            if (e.value['kind'] == 'path' && e.value['deadEnd'] == true) {
              return {'type': 'action', 'index': i, 'r': e.key.$1, 'c': e.key.$2};
            }
          }
        }
      }

      // Place a passable path card advancing toward (targetGoalRow, 8)
      if (brokenTools[seat].isEmpty) {
        var bestScore = -1e9;
        Map<String, dynamic>? bestMove;
        for (var i = 0; i < hand.length; i++) {
          final c = hand[i];
          if (c['kind'] != 'path' || c['deadEnd'] == true) continue;
          final edges = (c['edges'] as List).cast<String>();
          final spots = validPlacementsForCard(c);
          for (final (r, col) in spots) {
            var score = col * 12.0 - (r - targetGoalRow).abs() * 3.0;
            if (edges.contains('E')) score += 6.0;
            if (col == 7 && edges.contains('E') && (r == 0 || r == 2 || r == 4)) {
              final gIdx = r ~/ 2;
              if (myKnownGoals[gIdx] != 'stone') score += 50.0;
            }
            if (score > bestScore) {
              bestScore = score;
              bestMove = {'type': 'place_path', 'index': i, 'r': r, 'c': col};
            }
          }
        }
        if (bestMove != null && bestScore >= 5.0) {
          return bestMove;
        }
      }
    } else {
      // Saboteur bot strategy
      // 1. Break another player's tool
      for (var i = 0; i < hand.length; i++) {
        final c = hand[i];
        if (c['kind'] == 'action' && c['action'] == 'break') {
          final tool = asStr(c['tool']);
          for (var other = 0; other < players; other++) {
            if (other != seat && !brokenTools[other].contains(tool)) {
              return {'type': 'action', 'index': i, 'target': other};
            }
          }
        }
      }

      // 2. Rockfall a passable tunnel card close to the goals
      for (var i = 0; i < hand.length; i++) {
        final c = hand[i];
        if (c['kind'] == 'action' && c['action'] == 'rockfall') {
          (int, int)? bestCell;
          var bestCol = 1;
          for (final e in grid.entries) {
            if (e.value['kind'] == 'path' && e.value['deadEnd'] != true && e.key.$2 > bestCol) {
              bestCol = e.key.$2;
              bestCell = e.key;
            }
          }
          if (bestCell != null) {
            return {'type': 'action', 'index': i, 'r': bestCell.$1, 'c': bestCell.$2};
          }
        }
      }

      // 3. Place a dead-end blocker card at the furthest valid spot
      if (brokenTools[seat].isEmpty) {
        for (var i = 0; i < hand.length; i++) {
          final c = hand[i];
          if (c['kind'] == 'path' && c['deadEnd'] == true) {
            final spots = validPlacementsForCard(c);
            if (spots.isNotEmpty) {
              spots.sort((a, b) => b.$2.compareTo(a.$2));
              final chosen = spots.first;
              return {'type': 'place_path', 'index': i, 'r': chosen.$1, 'c': chosen.$2};
            }
          }
        }
      }
    }

    // Fallback: discard a dead-end card (for digger) or passable path card (for saboteur), or index 0
    for (var i = 0; i < hand.length; i++) {
      final c = hand[i];
      if (myRole == 'digger' && c['kind'] == 'path' && c['deadEnd'] == true) {
        return {'type': 'discard', 'index': i};
      }
      if (myRole == 'saboteur' && c['kind'] == 'path' && c['deadEnd'] != true) {
        return {'type': 'discard', 'index': i};
      }
    }
    return {'type': 'discard', 'index': 0};
  }
}
