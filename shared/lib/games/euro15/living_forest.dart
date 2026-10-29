import '../../src/engine.dart';

const List<String> forestElementNames = [
  '太阳',
  '水滴',
  '树苗',
  '旋风',
  '圣莲',
];

const List<String> forestElementEmojis = [
  '☀',
  '💧',
  '🌱',
  '🌀',
  '🌸',
];

class GuardianAnimalCard {
  final int id;
  final int tier; // 0: 初始, 1: 一阶, 2: 二阶, 3: 三阶
  final String name;
  final String emoji;
  final int cost; // ☀ Sun cost to recruit
  final List<int> elements; // [sun, water, sprout, wind, lotus]
  final bool isSolitary; // 🐾 Solitary symbol

  const GuardianAnimalCard({
    required this.id,
    required this.tier,
    required this.name,
    required this.emoji,
    required this.cost,
    required this.elements,
    this.isSolitary = false,
  });

  String get elemSummary {
    final parts = <String>[];
    for (var i = 0; i < 5; i++) {
      if (elements[i] > 0) {
        parts.add('${forestElementEmojis[i]}${elements[i]}');
      }
    }
    return parts.join(' ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tier': tier,
        'name': name,
        'emoji': emoji,
        'cost': cost,
        'elements': elements,
        'isSolitary': isSolitary,
        'elemSummary': elemSummary,
      };
}

class ForestTreeTile {
  final int id;
  final String name;
  final String emoji;
  final int cost; // 🌱 Sprout cost to plant
  final int bonusElem; // 0..4 element index
  final int bonusAmount;

  const ForestTreeTile({
    required this.id,
    required this.name,
    required this.emoji,
    required this.cost,
    required this.bonusElem,
    required this.bonusAmount,
  });

  String get bonusLabel =>
      '+$bonusAmount${forestElementEmojis[bonusElem]}${forestElementNames[bonusElem]}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'cost': cost,
        'bonusElem': bonusElem,
        'bonusAmount': bonusAmount,
        'bonusLabel': bonusLabel,
      };
}

class LivingForestGame extends GameEngine {
  static const int treeRows = 3;
  static const int treeCols = 5;
  static const int stoneCircleSize = 12;
  static const int maxRounds = 12;

  late final int winTarget;
  late List<List<GuardianAnimalCard>> drawPile;
  late List<List<GuardianAnimalCard>> helpLine;
  late List<List<GuardianAnimalCard>> discardPile;
  late List<List<List<ForestTreeTile?>>> forestGrid;

  late List<int> trees; // 🌲 Victory Counter 1: Protective Trees
  late List<int> fires; // 🔥 Victory Counter 2: Extinguished Onibi Fires
  late List<int> lotus; // 🌸 Victory Counter 3: Sacred Lotus Flowers
  late List<int> bonusLotus; // Permanent lotus tokens from Stone Circle
  late List<int> fragments; // 💎 Magic Fragments to banish Solitary cards
  late List<int> circlePos; // Position 0..11 on Stone Circle
  late List<int> score;

  final List<GuardianAnimalCard> animalDeck = [];
  final List<GuardianAnimalCard> animalMarket = [];
  final List<ForestTreeTile> treeMarket = [];
  final List<int> fireCircle = []; // Fire values (2..4 Water cost each)

  int round = 1;
  int turn = 0;
  int turnsDoneInRound = 0;
  String phase = 'draw'; // 'draw' | 'action'
  int actionsLeft = 0;
  final Set<String> usedActions = {};
  bool over = false;
  String lastAction = '生机森林守护战开启';

  LivingForestGame(super.setup) : winTarget = setup.opt<int>('winTarget', 12);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  List<GuardianAnimalCard> _buildStarterDeck(int seat) {
    final base = <GuardianAnimalCard>[
      const GuardianAnimalCard(
        id: 101,
        tier: 0,
        name: '灵狐',
        emoji: '🦊',
        cost: 0,
        elements: [2, 0, 0, 0, 0],
        isSolitary: false,
      ),
      const GuardianAnimalCard(
        id: 102,
        tier: 0,
        name: '山猫',
        emoji: '🐱',
        cost: 0,
        elements: [1, 1, 0, 0, 0],
        isSolitary: true,
      ),
      const GuardianAnimalCard(
        id: 103,
        tier: 0,
        name: '水獭',
        emoji: '🦦',
        cost: 0,
        elements: [0, 2, 0, 0, 0],
        isSolitary: false,
      ),
      const GuardianAnimalCard(
        id: 104,
        tier: 0,
        name: '刺猬',
        emoji: '🦔',
        cost: 0,
        elements: [0, 0, 2, 0, 0],
        isSolitary: false,
      ),
      const GuardianAnimalCard(
        id: 105,
        tier: 0,
        name: '野猪',
        emoji: '🐗',
        cost: 0,
        elements: [1, 0, 1, 0, 0],
        isSolitary: true,
      ),
      const GuardianAnimalCard(
        id: 106,
        tier: 0,
        name: '蜂鸟',
        emoji: '🐦',
        cost: 0,
        elements: [0, 0, 0, 1, 1],
        isSolitary: false,
      ),
      const GuardianAnimalCard(
        id: 107,
        tier: 0,
        name: '夜枭',
        emoji: '🦉',
        cost: 0,
        elements: [1, 0, 0, 1, 0],
        isSolitary: true,
      ),
    ];
    return shuffled(base, rng);
  }

  List<GuardianAnimalCard> _buildMarketDeck() {
    const templates = [
      (1, '白鹿', '🦌', 3, [2, 0, 1, 0, 0], false),
      (1, '青蛙', '🐸', 3, [0, 2, 0, 1, 0], false),
      (1, '松鼠', '🐿️', 3, [1, 0, 2, 0, 0], false),
      (1, '花豹', '🐆', 4, [2, 1, 0, 1, 0], true),
      (1, '彩蝶', '🦋', 4, [0, 0, 1, 1, 1], false),
      (2, '棕熊', '🐻', 5, [3, 0, 2, 0, 0], true),
      (2, '巨鲸', '🐋', 5, [0, 3, 0, 1, 0], false),
      (2, '神龟', '🐢', 5, [0, 1, 3, 0, 0], false),
      (2, '苍鹰', '🦅', 6, [1, 0, 0, 2, 1], false),
      (2, '狼王', '🐺', 6, [2, 2, 0, 0, 1], true),
      (3, '麒麟', '🦄', 7, [2, 0, 2, 0, 2], false),
      (3, '青龙', '🐉', 8, [0, 3, 0, 1, 2], false),
      (3, '朱雀', '🦚', 8, [3, 0, 1, 0, 2], false),
    ];
    final list = <GuardianAnimalCard>[];
    var id = 201;
    for (var copy = 0; copy < 2; copy++) {
      for (final (tier, nm, em, cost, elems, sol) in templates) {
        list.add(GuardianAnimalCard(
          id: id++,
          tier: tier,
          name: nm,
          emoji: em,
          cost: cost,
          elements: elems,
          isSolitary: sol,
        ));
      }
    }
    return shuffled(list, rng);
  }

  List<ForestTreeTile> _buildTreeMarket() {
    const templates = [
      ('晨曦古树', '🌳', 3, 0, 2),
      ('清泉柳树', '🌲', 3, 1, 2),
      ('繁茂榕树', '🌴', 4, 2, 2),
      ('疾风桦树', '🎋', 4, 3, 2),
      ('圣莲神木', '🌸', 5, 4, 1),
      ('烈日梧桐', '🍁', 6, 0, 3),
      ('甘霖杉木', '🎄', 6, 1, 3),
      ('双莲灵木', '🌺', 7, 4, 2),
    ];
    final list = <ForestTreeTile>[];
    var id = 301;
    for (var copy = 0; copy < 3; copy++) {
      for (final (nm, em, cost, elem, amt) in templates) {
        list.add(ForestTreeTile(
          id: id++,
          name: nm,
          emoji: em,
          cost: cost,
          bonusElem: elem,
          bonusAmount: amt,
        ));
      }
    }
    return list;
  }

  @override
  void start() {
    drawPile = List.generate(players, _buildStarterDeck);
    helpLine = List.generate(players, (_) => <GuardianAnimalCard>[]);
    discardPile = List.generate(players, (_) => <GuardianAnimalCard>[]);
    forestGrid = List.generate(
      players,
      (_) => List.generate(treeRows, (_) => List.filled(treeCols, null)),
    );
    // Place starting Sacred Tree at center (1, 2) for each player
    for (var s = 0; s < players; s++) {
      forestGrid[s][1][2] = const ForestTreeTile(
        id: 300,
        name: '初始圣树',
        emoji: '🌲',
        cost: 0,
        bonusElem: 0,
        bonusAmount: 1,
      );
    }

    trees = List.filled(players, 1);
    fires = List.filled(players, 0);
    bonusLotus = List.filled(players, 0);
    lotus = List.filled(players, 0);
    fragments = List.filled(players, 1);
    circlePos = [for (var s = 0; s < players; s++) (s * 3) % stoneCircleSize];
    score = List.filled(players, 1);

    animalDeck
      ..clear()
      ..addAll(_buildMarketDeck());
    animalMarket.clear();
    while (animalMarket.length < 6 && animalDeck.isNotEmpty) {
      animalMarket.add(animalDeck.removeLast());
    }

    treeMarket
      ..clear()
      ..addAll(_buildTreeMarket());

    fireCircle
      ..clear()
      ..addAll([2, 2, 3]);

    round = 1;
    turn = 0;
    turnsDoneInRound = 0;
    phase = 'draw';
    actionsLeft = 0;
    usedActions.clear();
    over = false;
    _refreshCounters();
    lastAction = '第 1 轮开始，请召唤守护兽或见好就收执行森林行动';
  }

  int solitaryCount(int seat) =>
      helpLine[seat].where((c) => c.isSolitary).length;

  /// Calculates total amount of element [elemIdx] (0..4) for [seat].
  int elementTotal(int seat, int elemIdx) {
    var sum = 0;
    for (final c in helpLine[seat]) {
      sum += c.elements[elemIdx];
    }
    for (var r = 0; r < treeRows; r++) {
      for (var c = 0; c < treeCols; c++) {
        final t = forestGrid[seat][r][c];
        if (t != null && t.bonusElem == elemIdx) {
          sum += t.bonusAmount;
        }
      }
    }
    if (elemIdx == 4) {
      sum += bonusLotus[seat];
    }
    return sum;
  }

  List<int> allElements(int seat) => [
        for (var i = 0; i < 5; i++) elementTotal(seat, i),
      ];

  void _refreshCounters() {
    for (var s = 0; s < players; s++) {
      lotus[s] = elementTotal(s, 4);
      score[s] = trees[s] + fires[s] + lotus[s];
    }
  }

  List<(int, int)> legalTreeCells(int seat) {
    final res = <(int, int)>[];
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    for (var r = 0; r < treeRows; r++) {
      for (var c = 0; c < treeCols; c++) {
        if (forestGrid[seat][r][c] != null) continue;
        var adj = false;
        for (final (dr, dc) in dirs) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr >= 0 &&
              nr < treeRows &&
              nc >= 0 &&
              nc < treeCols &&
              forestGrid[seat][nr][nc] != null) {
            adj = true;
            break;
          }
        }
        if (adj) res.add((r, c));
      }
    }
    return res;
  }

  GuardianAnimalCard? _drawOneCard(int seat) {
    if (drawPile[seat].isEmpty && discardPile[seat].isNotEmpty) {
      drawPile[seat].addAll(shuffled(discardPile[seat], rng));
      discardPile[seat].clear();
    }
    if (drawPile[seat].isEmpty) return null;
    final card = drawPile[seat].removeLast();
    helpLine[seat].add(card);
    return card;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);

    if (phase == 'draw') {
      switch (type) {
        case 'draw':
          final card = _drawOneCard(seat);
          if (card == null) {
            phase = 'action';
            actionsLeft = solitaryCount(seat) >= 3 ? 1 : 2;
            usedActions.clear();
            _refreshCounters();
            lastAction = '${name(seat)} 牌库已抽空，进入行动阶段（$actionsLeft 次行动）';
            host.log(lastAction);
            return;
          }
          final sol = solitaryCount(seat);
          _refreshCounters();
          if (sol >= 3) {
            phase = 'action';
            actionsLeft = 1;
            usedActions.clear();
            lastAction =
                '${name(seat)} 抽到 ${card.emoji}${card.name}，独行标志达到 $sol🐾！强制停止抽牌，仅获 1 次行动';
          } else {
            lastAction =
                '${name(seat)} 召唤了 ${card.emoji}${card.name}（当前独行 $sol/3🐾）';
          }
          host.log(lastAction);

        case 'fragment':
          if (fragments[seat] <= 0) {
            throw GameError('没有魔法碎片(💎)可用');
          }
          if (helpLine[seat].isEmpty) {
            throw GameError('当前召唤队列没有守护兽可驱散');
          }
          var rmIdx = asInt(action['index'], -1);
          if (rmIdx < 0 || rmIdx >= helpLine[seat].length) {
            rmIdx = helpLine[seat].lastIndexWhere((c) => c.isSolitary);
            if (rmIdx < 0) rmIdx = helpLine[seat].length - 1;
          }
          fragments[seat]--;
          final removed = helpLine[seat].removeAt(rmIdx);
          discardPile[seat].add(removed);
          _refreshCounters();
          lastAction =
              '${name(seat)} 消耗 1 枚💎魔法碎片送回 ${removed.emoji}${removed.name}（独行降至 ${solitaryCount(seat)}🐾）';
          host.log(lastAction);

        case 'stop_draw':
          final sol = solitaryCount(seat);
          phase = 'action';
          actionsLeft = sol >= 3 ? 1 : 2;
          usedActions.clear();
          _refreshCounters();
          lastAction =
              '${name(seat)} 停止召唤（独行 $sol🐾），获得 $actionsLeft 次不同森林行动！';
          host.log(lastAction);

        default:
          throw GameError('当前处于召唤抽牌阶段，请抽牌(draw)或停止(stop_draw)');
      }
      return;
    }

    // phase == 'action'
    if (type == 'pass') {
      lastAction = '${name(seat)} 结束森林行动';
      host.log(lastAction);
      _finishPlayerTurn();
      return;
    }

    if (usedActions.contains(type)) {
      throw GameError('同一回合的两次行动必须不同（已执行过 $type）');
    }

    switch (type) {
      case 'recruit':
        final slot = asInt(action['slot'], 0);
        if (slot < 0 || slot >= animalMarket.length) {
          throw GameError('无效的守护兽编号');
        }
        final card = animalMarket[slot];
        final sun = elementTotal(seat, 0);
        if (sun < card.cost) {
          throw GameError('太阳元素不足（需要 ${card.cost}☀，当前 $sun☀）');
        }
        animalMarket.removeAt(slot);
        // Recruited animal is placed on TOP of the player's drawPile!
        drawPile[seat].add(card);
        if (animalDeck.isNotEmpty) {
          animalMarket.add(animalDeck.removeLast());
        }
        if (fireCircle.length < 7) {
          fireCircle.add((card.tier + 1).clamp(2, 4));
        }
        usedActions.add('recruit');
        actionsLeft--;
        _refreshCounters();
        lastAction =
            '${name(seat)} 消耗 ${card.cost}☀ 招募了 ${card.emoji}${card.name} 置入牌库顶';
        host.log(lastAction);

      case 'extinguish':
        if (fireCircle.isEmpty) {
          throw GameError('当前中央没有鬼火可扑灭');
        }
        final slot = asInt(action['slot'], 0);
        if (slot < 0 || slot >= fireCircle.length) {
          throw GameError('无效的鬼火编号');
        }
        var water = elementTotal(seat, 1);
        final cost = fireCircle[slot];
        if (water < cost) {
          throw GameError('水滴元素不足（需要 $cost💧，当前 $water💧）');
        }
        water -= cost;
        fireCircle.removeAt(slot);
        var count = 1;
        // Also extinguish additional fires if player has enough remaining water
        if (asBool(action['all']) || action['slot'] == null) {
          fireCircle.sort();
          while (fireCircle.isNotEmpty && water >= fireCircle.first) {
            water -= fireCircle.removeAt(0);
            count++;
          }
        }
        fires[seat] += count;
        usedActions.add('extinguish');
        actionsLeft--;
        _refreshCounters();
        lastAction =
            '${name(seat)} 扑灭了 $count 团🔥鬼火（累计 ${fires[seat]}/$winTarget🔥）';
        host.log(lastAction);

      case 'plant':
        final slot = asInt(action['slot'], 0);
        if (slot < 0 || slot >= treeMarket.length) {
          throw GameError('无效的护林树苗编号');
        }
        final tree = treeMarket[slot];
        final sprout = elementTotal(seat, 2);
        if (sprout < tree.cost) {
          throw GameError('树苗元素不足（需要 ${tree.cost}🌱，当前 $sprout🌱）');
        }
        final legalCells = legalTreeCells(seat);
        if (legalCells.isEmpty) {
          throw GameError('森林网格已满');
        }
        var r = asInt(action['r'], -1);
        var c = asInt(action['c'], -1);
        if (r < 0 || c < 0) {
          (r, c) = legalCells.first;
        } else if (!legalCells.contains((r, c))) {
          throw GameError('必须在已有守护树正交相邻的空位种树');
        }
        treeMarket.removeAt(slot);
        forestGrid[seat][r][c] = tree;
        trees[seat]++;
        usedActions.add('plant');
        actionsLeft--;
        _refreshCounters();
        lastAction =
            '${name(seat)} 在 ($r,$c) 种下 ${tree.emoji}${tree.name}（累计 ${trees[seat]}/$winTarget🌲）';
        host.log(lastAction);

      case 'move':
        final wind = elementTotal(seat, 3);
        if (wind <= 0) {
          throw GameError('旋风元素不足（至少需要 1🌀）');
        }
        final steps = asInt(action['steps'], wind).clamp(1, wind);
        final oldPos = circlePos[seat];
        final stoleNotes = <String>[];
        final stealPref = asStr(action['stealType'], 'fire');

        for (var s = 1; s <= steps; s++) {
          final pos = (oldPos + s) % stoneCircleSize;
          for (var other = 0; other < players; other++) {
            if (other == seat) continue;
            if (circlePos[other] == pos) {
              // Leaped over or landed on [other] -> steal 1 Fire, Tree, or Fragment!
              if (stealPref == 'tree' && trees[other] > 1) {
                trees[other]--;
                trees[seat]++;
                stoleNotes.add('夺取${name(other)} 1🌲');
              } else if (stealPref == 'fragment' && fragments[other] > 0) {
                fragments[other]--;
                fragments[seat]++;
                stoleNotes.add('夺取${name(other)} 1💎');
              } else if (fires[other] > 0) {
                fires[other]--;
                fires[seat]++;
                stoleNotes.add('夺取${name(other)} 1🔥');
              } else if (trees[other] > 1) {
                trees[other]--;
                trees[seat]++;
                stoleNotes.add('夺取${name(other)} 1🌲');
              } else if (fragments[other] > 0) {
                fragments[other]--;
                fragments[seat]++;
                stoleNotes.add('夺取${name(other)} 1💎');
              }
            }
          }
        }

        final newPos = (oldPos + steps) % stoneCircleSize;
        circlePos[seat] = newPos;
        // Landing Stone Circle bonus
        final spaceKind = newPos % 4;
        String bonusStr;
        switch (spaceKind) {
          case 0:
            fragments[seat]++;
            bonusStr = '获+1💎魔法碎片';
          case 1:
            bonusLotus[seat]++;
            bonusStr = '获+1🌸永恒圣莲';
          case 2:
            fires[seat]++;
            bonusStr = '获+1🔥圣火印记';
          default:
            trees[seat]++;
            bonusStr = '获+1🌲古树祝福';
        }
        usedActions.add('move');
        actionsLeft--;
        _refreshCounters();
        final stealStr = stoleNotes.isNotEmpty ? '，${stoleNotes.join('、')}' : '';
        lastAction =
            '${name(seat)} 在巨石阵前进 $steps 步至 #$newPos（$bonusStr$stealStr）';
        host.log(lastAction);

      default:
        throw GameError('未知操作: $type');
    }

    if (actionsLeft <= 0) {
      _finishPlayerTurn();
    }
  }

  void _finishPlayerTurn() {
    turnsDoneInRound++;
    if (turnsDoneInRound < players) {
      turn = (turn + 1) % players;
      phase = 'draw';
      actionsLeft = 0;
      usedActions.clear();
      return;
    }

    // End of round! Check victory conditions first (before discarding helpLine so Lotus counts!)
    _refreshCounters();
    final anyReached = [for (var s = 0; s < players; s++) s].any(
      (s) =>
          trees[s] >= winTarget ||
          fires[s] >= winTarget ||
          lotus[s] >= winTarget,
    );

    if (anyReached || round >= maxRounds) {
      over = true;
      _refreshCounters();
      lastAction = '生机森林神圣试炼结束！圣物总和最高者获胜';
      host.log(lastAction);
      return;
    }

    // Cleanup helpLine -> discardPile and prepare next round
    for (var s = 0; s < players; s++) {
      discardPile[s].addAll(helpLine[s]);
      helpLine[s].clear();
    }
    while (fireCircle.length < 2) {
      fireCircle.add(2);
    }
    round++;
    turnsDoneInRound = 0;
    turn = (round - 1) % players;
    phase = 'draw';
    actionsLeft = 0;
    usedActions.clear();
    _refreshCounters();
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    if (phase == 'draw') {
      final sol = solitaryCount(seat);
      if (sol == 2 && fragments[seat] > 0 && helpLine[seat].length < 4) {
        return {'type': 'fragment'};
      }
      if (helpLine[seat].length < 3 && sol < 2) {
        if (drawPile[seat].isNotEmpty || discardPile[seat].isNotEmpty) {
          return {'type': 'draw'};
        }
      }
      return {'type': 'stop_draw'};
    }

    // phase == 'action'
    final elems = allElements(seat);
    // 1. Try extinguishing fires if possible
    if (!usedActions.contains('extinguish') && fireCircle.isNotEmpty) {
      for (var i = 0; i < fireCircle.length; i++) {
        if (elems[1] >= fireCircle[i]) {
          return {'type': 'extinguish', 'slot': i, 'all': true};
        }
      }
    }
    // 2. Try planting a protective tree
    if (!usedActions.contains('plant') &&
        treeMarket.isNotEmpty &&
        legalTreeCells(seat).isNotEmpty) {
      for (var i = treeMarket.length - 1; i >= 0; i--) {
        if (elems[2] >= treeMarket[i].cost) {
          final cell = legalTreeCells(seat).first;
          return {
            'type': 'plant',
            'slot': i,
            'r': cell.$1,
            'c': cell.$2,
          };
        }
      }
    }
    // 3. Try recruiting a guardian animal
    if (!usedActions.contains('recruit') && animalMarket.isNotEmpty) {
      for (var i = animalMarket.length - 1; i >= 0; i--) {
        if (elems[0] >= animalMarket[i].cost) {
          return {'type': 'recruit', 'slot': i};
        }
      }
    }
    // 4. Try moving on the Stone Circle
    if (!usedActions.contains('move') && elems[3] > 0) {
      return {'type': 'move', 'steps': elems[3], 'stealType': 'fire'};
    }

    return {'type': 'pass'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'treeRows': treeRows,
      'treeCols': treeCols,
      'winTarget': winTarget,
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'phase': phase,
      'actionsLeft': actionsLeft,
      'usedActions': usedActions.toList(),
      'over': over,
      'lastAction': lastAction,
      'animalMarket': [for (final a in animalMarket) a.toJson()],
      'treeMarket': [for (final t in treeMarket.take(6)) t.toJson()],
      'fireCircle': List<int>.of(fireCircle),
      'players': [
        for (var s = 0; s < players; s++)
          {
            'trees': trees[s],
            'fires': fires[s],
            'lotus': lotus[s],
            'fragments': fragments[s],
            'circlePos': circlePos[s],
            'score': score[s],
            'solitary': solitaryCount(s),
            'elements': allElements(s),
            'drawCount': drawPile[s].length,
            'discardCount': discardPile[s].length,
            'helpLine': [for (final c in helpLine[s]) c.toJson()],
            'legalTreeCells': [
              for (final (r, c) in legalTreeCells(s)) [r, c],
            ],
            'forestGrid': [
              for (var r = 0; r < treeRows; r++)
                [
                  for (var c = 0; c < treeCols; c++)
                    forestGrid[s][r][c]?.toJson(),
                ],
            ],
          },
      ],
    };
  }
}
