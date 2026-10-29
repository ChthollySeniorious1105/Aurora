import 'dart:math';

import '../../src/engine.dart';

const List<String> kAlhambraCurrencies = [
  '蓝弗罗林',
  '绿迪拉姆',
  '橙第纳尔',
  '黄杜卡特',
];

const List<String> kAlhambraBuildings = [
  '亭阁',
  '后宫',
  '拱廊',
  '寝宫',
  '花园',
  '塔楼',
];

/// Scoring table per building type (0..5) for rounds 1, 2, 3:
/// Round 1: [1st]
/// Round 2: [1st, 2nd]
/// Round 3: [1st, 2nd, 3rd]
const List<List<List<int>>> kAlhambraMajorityPoints = [
  // Round 1
  [
    [1],
    [2],
    [3],
    [4],
    [5],
    [6],
  ],
  // Round 2
  [
    [8, 1],
    [9, 2],
    [10, 3],
    [11, 4],
    [12, 5],
    [13, 6],
  ],
  // Round 3
  [
    [16, 8, 1],
    [17, 9, 2],
    [18, 10, 3],
    [19, 11, 4],
    [20, 12, 5],
    [21, 13, 6],
  ],
];

class AlhambraMoney {
  final int currency; // 0..3
  final int value; // 1..9

  const AlhambraMoney(this.currency, this.value);

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'value': value,
      };
}

class AlhambraTile {
  final int id;
  final int type; // 0..5
  final int cost; // 2..12
  final int walls; // bitmask: 1=N, 2=E, 4=S, 8=W

  const AlhambraTile({
    required this.id,
    required this.type,
    required this.cost,
    required this.walls,
  });

  int get wallCount =>
      ((walls & 1) != 0 ? 1 : 0) +
      ((walls & 2) != 0 ? 1 : 0) +
      ((walls & 4) != 0 ? 1 : 0) +
      ((walls & 8) != 0 ? 1 : 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': kAlhambraBuildings[type],
        'cost': cost,
        'walls': walls,
        'wallCount': wallCount,
      };
}

/// Complete catalog of 54 Alhambra building tiles.
final List<AlhambraTile> kAlhambraTileCatalog = _buildTileCatalog();

List<AlhambraTile> _buildTileCatalog() {
  final specs = <(int, int, int)>[
    // Type 0: 亭阁 (Pavilion, 7 tiles, cost 2..8)
    (0, 2, 1 | 2 | 8),
    (0, 3, 1 | 4),
    (0, 4, 2 | 4),
    (0, 5, 1 | 8),
    (0, 6, 2),
    (0, 7, 4),
    (0, 8, 1),
    // Type 1: 后宫 (Seraglio, 7 tiles, cost 3..9)
    (1, 3, 1 | 2 | 4),
    (1, 4, 2 | 8),
    (1, 5, 1 | 4),
    (1, 6, 4 | 8),
    (1, 7, 8),
    (1, 8, 2),
    (1, 9, 1),
    // Type 2: 拱廊 (Arcades, 9 tiles, cost 4..10)
    (2, 4, 1 | 4 | 8),
    (2, 5, 2 | 4 | 8),
    (2, 6, 1 | 2),
    (2, 6, 4 | 8),
    (2, 7, 1 | 8),
    (2, 8, 2 | 4),
    (2, 8, 1),
    (2, 9, 4),
    (2, 10, 8),
    // Type 3: 寝宫 (Chambers, 9 tiles, cost 5..11)
    (3, 5, 1 | 2 | 8),
    (3, 6, 1 | 2 | 4),
    (3, 7, 2 | 8),
    (3, 7, 1 | 4),
    (3, 8, 1 | 2),
    (3, 9, 4 | 8),
    (3, 9, 2),
    (3, 10, 1),
    (3, 11, 4),
    // Type 4: 花园 (Garden, 11 tiles, cost 6..12)
    (4, 6, 1 | 4 | 8),
    (4, 7, 2 | 4 | 8),
    (4, 7, 1 | 2),
    (4, 8, 2 | 4),
    (4, 8, 1 | 8),
    (4, 9, 4 | 8),
    (4, 9, 1 | 4),
    (4, 10, 2 | 8),
    (4, 10, 1),
    (4, 11, 2),
    (4, 12, 4),
    // Type 5: 塔楼 (Tower, 11 tiles, cost 7..12)
    (5, 7, 1 | 2 | 8),
    (5, 7, 1 | 2 | 4),
    (5, 8, 1 | 4 | 8),
    (5, 8, 2 | 4),
    (5, 9, 1 | 2),
    (5, 9, 4 | 8),
    (5, 10, 1 | 8),
    (5, 10, 2),
    (5, 11, 4),
    (5, 11, 8),
    (5, 12, 1),
  ];
  return [
    for (var i = 0; i < specs.length; i++)
      AlhambraTile(
        id: i,
        type: specs[i].$1,
        cost: specs[i].$2,
        walls: specs[i].$3,
      ),
  ];
}

const String alhambraRules = '''
# 阿尔罕布拉宫（Alhambra）规则说明

## 游戏简介
《阿尔罕布拉宫》是荣获德国年度游戏奖（Spiel des Jahres）的经典宫殿建造桌游。玩家需要收集 4 种不同颜色的货币，在建筑市场用对应货币购买 6 类宫殿建筑板块，争夺每类建筑的数量多数并扩建外城墙。

## 货币与建筑
- **4 种货币**：蓝弗罗林、绿迪拉姆、橙第纳尔、黄杜卡特（面值 1～9）。
- **6 类建筑**：亭阁（1～6分基数）、后宫、拱廊、寝宫、花园、塔楼（价值与分值依次递增）。每块建筑带有 1～3 段外城墙。
- **建筑市场**：4 个槽位分别对应 4 种货币颜色，购买第 `c` 槽位的建筑必须使用第 `c` 种货币支付。

## 回合行动（二选一）
1. **拿取货币**：从中央货币市场的 4 张明牌中：
   - 拿取 **任意 1 张** 货币卡（无论面值大小）；或者
   - 拿取 **2 张或更多张** 货币卡，但这些货币卡的 **面值总和不能超过 5**。
2. **购买建筑**：选择一个有建筑板块的市场槽位，打出手中对应颜色的货币卡（面值总和 ≥ 建筑价格）将其收入自己的阿尔罕布拉宫：
   - 找零不退；
   - **精准支付奖励（Exact Change）**：若所付货币的面值总和 **恰好等于** 建筑价格，你立即获得 **1 次额外行动**（可继续精准购买或拿取货币）！
   - 回合结束时补充货币市场与建筑市场。

## 计分轮与终局
- 游戏过程中会触发 **2 轮或 3 轮计分**：
  - **第一轮计分**：每种建筑数量第 1 名获得分数（1～6分），加上各自的城墙总长度分。
  - **第二轮计分**：每种建筑第 1 名（8～13分）、第 2 名（1～6分）得分，加上城墙总长度分。
  - **第三轮（终局）计分**：当建筑袋无法补满市场时游戏结束，结算第 1/2/3 名多数得分（16～21分 / 8～13分 / 1～6分）与城墙总长度分（平局平分名次分数向下取整）。
- 最终总分最高的玩家获胜。

## 房间选项
- **计分轮数**：三轮标准计分（`standard`）或两轮快速计分（`quick`）。
''';

class AlhambraGame extends GameEngine {
  AlhambraGame(super.setup);

  final List<AlhambraMoney> moneyDeck = [];
  final List<AlhambraMoney> moneyDiscard = [];
  final List<AlhambraMoney> moneyMarket = [];

  final List<AlhambraTile> tileDeck = [];
  final List<AlhambraTile?> tileMarket = [null, null, null, null];

  late List<List<AlhambraMoney>> hand;
  late List<List<int>> buildings; // buildings[seat][type]
  late List<List<AlhambraTile>> palace;
  late List<int> walls; // outer wall length per seat
  late List<int> scores;

  int turn = 0;
  int round = 1;
  bool bonusAction = false;
  int scoringRoundsDone = 0;
  late List<int> scoringThresholds; // moneyDraws count when mid-game scorings trigger
  int moneyDrawnCount = 0;
  String lastLog = '游戏开始';
  Map<String, dynamic>? lastScoringReport;

  bool _over = false;

  bool get isQuick => setup.opt<String>('rounds', 'standard') == 'quick';
  int get totalScoringRounds => isQuick ? 2 : 3;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    moneyDeck.clear();
    moneyDiscard.clear();
    moneyMarket.clear();
    for (var c = 0; c < 4; c++) {
      for (var v = 1; v <= 9; v++) {
        for (var copy = 0; copy < 3; copy++) {
          moneyDeck.add(AlhambraMoney(c, v));
        }
      }
    }
    moneyDeck.shuffle(rng);

    tileDeck
      ..clear()
      ..addAll(kAlhambraTileCatalog)
      ..shuffle(rng);
    if (isQuick && tileDeck.length > 36) {
      tileDeck.removeRange(36, tileDeck.length);
    }

    hand = List.generate(players, (_) => <AlhambraMoney>[]);
    buildings = List.generate(players, (_) => List<int>.filled(6, 0));
    palace = List.generate(players, (_) => <AlhambraTile>[]);
    walls = List<int>.filled(players, 0);
    scores = List<int>.filled(players, 0);

    // Deal starting money to each player until sum >= 20
    for (var s = 0; s < players; s++) {
      var sum = 0;
      while (sum < 20 && moneyDeck.isNotEmpty) {
        final card = moneyDeck.removeLast();
        hand[s].add(card);
        sum += card.value;
      }
    }

    // Fill initial 4 moneyMarket cards
    for (var i = 0; i < 4 && moneyDeck.isNotEmpty; i++) {
      moneyMarket.add(moneyDeck.removeLast());
    }

    // Fill initial 4 tileMarket slots
    for (var i = 0; i < 4; i++) {
      tileMarket[i] = tileDeck.isNotEmpty ? tileDeck.removeLast() : null;
    }

    moneyDrawnCount = 0;
    final rem = moneyDeck.length;
    if (isQuick) {
      scoringThresholds = [max(10, rem ~/ 2)];
    } else {
      scoringThresholds = [max(8, rem ~/ 3), max(16, (rem * 2) ~/ 3)];
    }

    turn = 0;
    round = 1;
    bonusAction = false;
    scoringRoundsDone = 0;
    _over = false;
    lastScoringReport = null;
    lastLog = '游戏开始，轮到 ${name(turn)} 行动';
    host.log(lastLog);
  }

  AlhambraMoney? _drawMoney() {
    if (moneyDeck.isEmpty && moneyDiscard.isNotEmpty) {
      moneyDeck.addAll(moneyDiscard..shuffle(rng));
      moneyDiscard.clear();
    }
    if (moneyDeck.isEmpty) return null;
    moneyDrawnCount++;
    return moneyDeck.removeLast();
  }

  void _refillMoneyMarket() {
    while (moneyMarket.length < 4) {
      final card = _drawMoney();
      if (card == null) break;
      moneyMarket.add(card);
    }
    // Check if any mid-game scoring threshold was crossed
    while (scoringRoundsDone < scoringThresholds.length &&
        moneyDrawnCount >= scoringThresholds[scoringRoundsDone]) {
      scoreRound(scoringRoundsDone);
      scoringRoundsDone++;
    }
  }

  /// Refills empty tileMarket slots at the end of a turn.
  /// Returns false if tileDeck ran out and couldn't fill all 4 slots (game end!).
  bool _refillTileMarket() {
    for (var c = 0; c < 4; c++) {
      if (tileMarket[c] == null) {
        if (tileDeck.isEmpty) {
          return false;
        }
        tileMarket[c] = tileDeck.removeLast();
      }
    }
    return true;
  }

  /// Executes scoring round [tier] (0 = 1st scoring, 1 = 2nd scoring, 2 = 3rd scoring).
  void scoreRound(int tier) {
    final table = kAlhambraMajorityPoints[tier.clamp(0, 2)];
    final gained = List<int>.filled(players, 0);

    for (var t = 0; t < 6; t++) {
      final rewards = table[t];
      // Group eligible players (count > 0) by their building count descending
      final counts = <int, List<int>>{};
      for (var s = 0; s < players; s++) {
        final cnt = buildings[s][t];
        if (cnt > 0) {
          counts.putIfAbsent(cnt, () => <int>[]).add(s);
        }
      }
      final sortedCounts = counts.keys.toList()..sort((a, b) => b.compareTo(a));
      var rankIdx = 0;
      for (final cnt in sortedCounts) {
        if (rankIdx >= rewards.length) break;
        final tiedSeats = counts[cnt]!;
        var pool = 0;
        for (var k = 0; k < tiedSeats.length && (rankIdx + k) < rewards.length; k++) {
          pool += rewards[rankIdx + k];
        }
        final ptsEach = pool ~/ tiedSeats.length;
        for (final s in tiedSeats) {
          gained[s] += ptsEach;
        }
        rankIdx += tiedSeats.length;
      }
    }

    // Add outer palace wall length points
    for (var s = 0; s < players; s++) {
      gained[s] += walls[s];
      scores[s] += gained[s];
    }

    lastScoringReport = {
      'tier': tier + 1,
      'gained': gained,
      'scores': List<int>.of(scores),
    };
    host.log('第 ${tier + 1} 轮计分完成：${[
      for (var s = 0; s < players; s++) '${name(s)} +${gained[s]}（总${scores[s]}）',
    ].join('，')}');
  }

  void _endGameWithFinalScoring() {
    if (_over) return;
    // Perform any remaining mid-game scorings if skipped, or directly final scoring
    final finalTier = isQuick ? 2 : 2;
    scoreRound(finalTier);
    scoringRoundsDone = totalScoringRounds;
    _over = true;
    final maxScore = scores.reduce(max);
    final winners = [
      for (var s = 0; s < players; s++)
        if (scores[s] == maxScore) name(s),
    ];
    lastLog = '游戏结束！${winners.join('、')} 以 $maxScore 分获胜！';
    host.log(lastLog);
  }

  void _finishTurn() {
    bonusAction = false;
    _refillMoneyMarket();
    final filledAll = _refillTileMarket();
    if (!filledAll || (moneyMarket.isEmpty && tileMarket.every((t) => t == null))) {
      _endGameWithFinalScoring();
      return;
    }
    turn = (turn + 1) % players;
    if (turn == 0) round++;
    if (round > 60) {
      _endGameWithFinalScoring();
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'take_money':
        _handleTakeMoney(seat, action);
        break;
      case 'buy_tile':
        _handleBuyTile(seat, action);
        break;
      default:
        throw GameError('未知操作：$type');
    }
  }

  void _handleTakeMoney(int seat, Map<String, dynamic> action) {
    final indices = asIntList(action['indices']);
    if (indices.isEmpty) throw GameError('请至少选择 1 张货币卡');
    final unique = indices.toSet();
    if (unique.length != indices.length) throw GameError('不能重复选择同一张货币卡');
    for (final idx in indices) {
      if (idx < 0 || idx >= moneyMarket.length) {
        throw GameError('货币市场索引无效：$idx');
      }
    }

    final chosen = [for (final idx in indices) moneyMarket[idx]];
    final sum = chosen.fold<int>(0, (s, c) => s + c.value);
    if (chosen.length >= 2 && sum > 5) {
      throw GameError('拿取多张货币时，面值总和不能超过 5（当前为 $sum）');
    }

    final sortedDesc = List<int>.of(indices)..sort((a, b) => b.compareTo(a));
    for (final idx in sortedDesc) {
      moneyMarket.removeAt(idx);
    }
    hand[seat].addAll(chosen);

    final desc = chosen.map((c) => '${kAlhambraCurrencies[c.currency]}${c.value}').join('、');
    lastLog = '${name(seat)} 拿取了货币：$desc';
    host.log(lastLog);

    _finishTurn();
  }

  void _handleBuyTile(int seat, Map<String, dynamic> action) {
    final slot = asInt(action['slot']);
    if (slot < 0 || slot >= 4) throw GameError('建筑市场槽位无效');
    final tile = tileMarket[slot];
    if (tile == null) throw GameError('该槽位没有可购买的建筑');

    final cardIndices = asIntList(action['cards']);
    if (cardIndices.isEmpty) throw GameError('请选择用于支付的货币卡');
    final unique = cardIndices.toSet();
    if (unique.length != cardIndices.length) throw GameError('不能重复使用同一张手牌');

    var sum = 0;
    for (final idx in cardIndices) {
      if (idx < 0 || idx >= hand[seat].length) {
        throw GameError('手牌索引无效：$idx');
      }
      final card = hand[seat][idx];
      if (card.currency != slot) {
        throw GameError('购买该槽位建筑必须使用 ${kAlhambraCurrencies[slot]}');
      }
      sum += card.value;
    }

    if (sum < tile.cost) {
      throw GameError('支付金额不足（需要 ${tile.cost}，当前支付 $sum）');
    }

    final sortedDesc = List<int>.of(cardIndices)..sort((a, b) => b.compareTo(a));
    final mutableHand = List<AlhambraMoney>.of(hand[seat]);
    for (final idx in sortedDesc) {
      moneyDiscard.add(mutableHand.removeAt(idx));
    }
    hand[seat] = mutableHand;

    tileMarket[slot] = null;
    buildings[seat][tile.type] += 1;
    palace[seat].add(tile);
    walls[seat] += tile.wallCount;

    final exact = sum == tile.cost;
    if (exact) {
      bonusAction = true;
      _refillMoneyMarket();
      lastLog = '${name(seat)} 以精准金额 $sum 购买了 ${kAlhambraBuildings[tile.type]}（+${tile.wallCount}城墙），获得额外行动！';
      host.log(lastLog);
      // If neither money nor affordable tiles remain for bonus action, finish turn
      if (moneyMarket.isEmpty && !_hasAnyAffordableTile(seat)) {
        _finishTurn();
      }
    } else {
      lastLog = '${name(seat)} 支付 $sum 购买了 ${kAlhambraBuildings[tile.type]}（价格 ${tile.cost}，+${tile.wallCount}城墙）';
      host.log(lastLog);
      _finishTurn();
    }
  }

  bool _hasAnyAffordableTile(int seat) {
    for (var c = 0; c < 4; c++) {
      final t = tileMarket[c];
      if (t == null) continue;
      final sum = hand[seat].where((m) => m.currency == c).fold<int>(0, (s, m) => s + m.value);
      if (sum >= t.cost) return true;
    }
    return false;
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'turn': turn,
      'round': round,
      'bonusAction': bonusAction,
      'scoringRoundsDone': scoringRoundsDone,
      'totalScoringRounds': totalScoringRounds,
      'tileDeckCount': tileDeck.length,
      'moneyDeckCount': moneyDeck.length,
      'moneyMarket': [for (final m in moneyMarket) m.toJson()],
      'tileMarket': [for (final t in tileMarket) t?.toJson()],
      'lastLog': lastLog,
      if (lastScoringReport != null) 'lastScoring': lastScoringReport,
      'hand': seat >= 0 && seat < players ? [for (final m in hand[seat]) m.toJson()] : const [],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'score': scores[s],
            'handCount': hand[s].length,
            'buildings': List<int>.of(buildings[s]),
            'walls': walls[s],
            'palaceCount': palace[s].length,
          },
      ],
      if (_over)
        'result': {
          'scores': List<int>.of(scores),
          'placings': placings,
        },
    };
  }

  /// Finds a subset of hand indices of [currency] that sums to [cost],
  /// preferring exact match (`sum == cost`), or minimal overpayment.
  List<int>? findBestPayment(int seat, int currency, int cost) {
    final matching = <int>[
      for (var i = 0; i < hand[seat].length; i++)
        if (hand[seat][i].currency == currency) i,
    ];
    if (matching.isEmpty) return null;
    final total = matching.fold<int>(0, (s, i) => s + hand[seat][i].value);
    if (total < cost) return null;

    // Limit subset search to at most first 12 matching cards (sorted ascending)
    matching.sort((a, b) => hand[seat][a].value.compareTo(hand[seat][b].value));
    final pool = matching.length > 12 ? matching.sublist(matching.length - 12) : matching;
    final n = pool.length;

    List<int>? bestSubset;
    var bestSum = 999999;

    for (var mask = 1; mask < (1 << n); mask++) {
      var sum = 0;
      for (var b = 0; b < n; b++) {
        if ((mask & (1 << b)) != 0) {
          sum += hand[seat][pool[b]].value;
        }
      }
      if (sum >= cost && sum < bestSum) {
        bestSum = sum;
        bestSubset = [
          for (var b = 0; b < n; b++)
            if ((mask & (1 << b)) != 0) pool[b],
        ];
        if (bestSum == cost) break; // Exact change found!
      }
    }
    return bestSubset ?? matching;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    // 1. Check for exact-change tile purchase first!
    for (var c = 0; c < 4; c++) {
      final tile = tileMarket[c];
      if (tile == null) continue;
      final pay = findBestPayment(seat, c, tile.cost);
      if (pay != null) {
        final sum = pay.fold<int>(0, (s, i) => s + hand[seat][i].value);
        if (sum == tile.cost) {
          return {'type': 'buy_tile', 'slot': c, 'cards': pay};
        }
      }
    }

    // 2. Check for any affordable tile purchase (prefer higher type / lower overpayment)
    int? bestSlot;
    List<int>? bestPay;
    var bestScore = -999;
    for (var c = 0; c < 4; c++) {
      final tile = tileMarket[c];
      if (tile == null) continue;
      final pay = findBestPayment(seat, c, tile.cost);
      if (pay != null) {
        final sum = pay.fold<int>(0, (s, i) => s + hand[seat][i].value);
        final overpay = sum - tile.cost;
        final val = tile.type * 4 + tile.wallCount * 2 - overpay;
        if (val > bestScore) {
          bestScore = val;
          bestSlot = c;
          bestPay = pay;
        }
      }
    }
    if (bestSlot != null && bestPay != null) {
      return {'type': 'buy_tile', 'slot': bestSlot, 'cards': bestPay};
    }

    // 3. Otherwise take money from moneyMarket
    if (moneyMarket.isNotEmpty) {
      // Find best multi-card combo summing to <= 5, or best single card
      List<int> bestMulti = [0];
      var bestMultiSum = moneyMarket[0].value;
      for (var i = 1; i < moneyMarket.length; i++) {
        if (moneyMarket[i].value > bestMultiSum) {
          bestMultiSum = moneyMarket[i].value;
          bestMulti = [i];
        }
      }
      final m = moneyMarket.length;
      for (var mask = 1; mask < (1 << m); mask++) {
        final idxs = <int>[
          for (var b = 0; b < m; b++)
            if ((mask & (1 << b)) != 0) b,
        ];
        if (idxs.length >= 2) {
          final sum = idxs.fold<int>(0, (s, i) => s + moneyMarket[i].value);
          if (sum <= 5 && (sum > bestMultiSum || (sum == bestMultiSum && idxs.length > bestMulti.length))) {
            bestMultiSum = sum;
            bestMulti = idxs;
          }
        }
      }
      return {'type': 'take_money', 'indices': bestMulti};
    }

    return null;
  }
}
