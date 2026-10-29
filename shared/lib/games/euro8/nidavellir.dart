import 'dart:math';

import '../../src/engine.dart';

const List<String> nidavellirTavernIds = ['laughing', 'dancing', 'shining'];
const List<String> nidavellirTavernNames = ['欢笑酒馆', '跃马酒馆', '闪耀酒馆'];
const List<String> nidavellirClassNames = ['铁匠', '猎人', '战士', '矿工', '探险家'];

class NidavellirCard {
  final int id;
  final int age; // 1 or 2
  final int classId; // 0..4 = Dwarf class
  final String name;
  final List<int> ranks; // usually [val] or [0, 0] for double-badge cards
  final int coinUpgrade; // optional extra coin upgrade when drafted

  const NidavellirCard({
    required this.id,
    required this.age,
    required this.classId,
    required this.name,
    required this.ranks,
    this.coinUpgrade = 0,
  });

  int get badges => ranks.length;
  int get rankSum => ranks.fold<int>(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        'id': id,
        'age': age,
        'classId': classId,
        'className': nidavellirClassNames[classId],
        'name': name,
        'ranks': ranks,
        'badges': badges,
        'rankSum': rankSum,
        'coinUpgrade': coinUpgrade,
      };
}

class NidavellirHero {
  final int id;
  final String name;
  final String desc;
  final int classId; // 0..4 for class badge, -1 for pure neutral VP
  final List<int> ranks;
  final int bonusVp;
  final int coinUpgrade;

  const NidavellirHero({
    required this.id,
    required this.name,
    required this.desc,
    required this.classId,
    required this.ranks,
    this.bonusVp = 0,
    this.coinUpgrade = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'desc': desc,
        'classId': classId,
        'className': classId >= 0 ? nidavellirClassNames[classId] : '中立英雄',
        'ranks': ranks,
        'bonusVp': bonusVp,
        'coinUpgrade': coinUpgrade,
      };
}

const List<NidavellirHero> nidavellirCatalogHeroes = [
  NidavellirHero(
    id: 101,
    name: '洛克杜尔 (Lokdur)',
    desc: '铁匠英雄：提供 2 枚铁匠徽章',
    classId: 0,
    ranks: [0, 0],
  ),
  NidavellirHero(
    id: 102,
    name: '塔拉 (Tarah)',
    desc: '猎人英雄：提供 2 枚猎人徽章',
    classId: 1,
    ranks: [0, 0],
  ),
  NidavellirHero(
    id: 103,
    name: '克랄 (Kraal)',
    desc: '战士英雄：提供 1 枚 11 点战士徽章',
    classId: 2,
    ranks: [11],
  ),
  NidavellirHero(
    id: 104,
    name: '佐拉尔 (Zoral)',
    desc: '矿工英雄：提供 2 枚(2+3)矿工徽章',
    classId: 3,
    ranks: [2, 3],
  ),
  NidavellirHero(
    id: 105,
    name: '埃古尔 (Aegur)',
    desc: '探险家英雄：提供 1 枚 12 点探险家徽章',
    classId: 4,
    ranks: [12],
  ),
  NidavellirHero(
    id: 106,
    name: '伊登 (Idunn)',
    desc: '猎人与金币英雄：提供 1 枚猎人徽章及额外 +7 荣誉分',
    classId: 1,
    ranks: [0],
    bonusVp: 7,
  ),
  NidavellirHero(
    id: 107,
    name: '斯露德 (Thrud)',
    desc: '皇家统帅：直接提供 13 点中立荣誉分并升级最高金币+2',
    classId: -1,
    ranks: [],
    bonusVp: 13,
    coinUpgrade: 2,
  ),
  NidavellirHero(
    id: 108,
    name: '达格尔 (Dagda)',
    desc: '传奇铁匠：提供 1 枚铁匠徽章及额外 +8 荣誉分',
    classId: 0,
    ranks: [0],
    bonusVp: 8,
  ),
];

const String nidavellirRules = '''
# 尼达维利亚（Nidavellir）规则说明

- **游戏概述**：荣获多项国际大奖的硬币盲拍与“硬币锻造（Coin-building）”矮人军团招募桌游！巨龙法夫纳苏醒，2至5名国王特使前往尼达维利亚的三大酒馆招募矮人勇士与传奇英雄。
- **硬币与皇家钱袋**：
  - 每名玩家开局拥有 5 枚硬币：`[0, 2, 3, 4, 5]`，以及 1 枚用于打破平局的水晶宝石（排名 `1..人数`）。
  - 每轮分为两个阶段：**① 出价阶段（`'bid'`）** 与 **② 招募阶段（`'draft'`）**。
- **阶段流程**：
  1. **同时出价（`'bid'`）**：所有玩家同时从自己的 5 枚硬币中选出 3 枚，分别放置到三座酒馆（`欢笑酒馆`、`跃马酒馆`、`闪耀酒馆`），其余 2 枚硬币留在【皇家钱袋】中。
  2. **酒馆结算与硬币锻造（`'draft'`）**：
     - 依次结算第 1、2、3 座酒馆。在每座酒馆中，按玩家出价硬币面值从高到低依次挑选 1 张矮人卡加入自己的军团。
     - **水晶平局与交换**：若出价硬币面值相同，持有更高编号水晶宝石的玩家优先挑选；平局结算后，平局玩家之间互换水晶宝石！
     - **0 号硬币锻造（硬币升级）**：凡是在当前酒馆打出 `0` 号硬币的玩家，不仅照常参与挑选卡牌，还会触发【硬币锻造】——查看留在皇家钱袋中的 2 枚硬币，将其中面值较大的那枚硬币永久升级，增加量等于面值较小硬币的数值（最高可锻造至 25 面值）！
     - **招募英雄**：每当你在全部 5 个矮人兵种中集齐完整的一横排徽章（即所有 5 个兵种的徽章数均达到 1、2、3...），可立即从王庭招募 1 位强大的【传奇英雄】！
- **五大兵种与终局计分**：
  - **0: 铁匠（紫色）**：按徽章数量递增计分，1/2/3/4/5/6... 枚分别得 `3 / 7 / 12 / 18 / 25 / 33...` 分（公式：`k*(k+5)/2`）。
  - **1: 猎人（绿色）**：得分为猎人徽章数量的平方（`数量²`）。
  - **2: 战士（红色）**：得分为所有战士卡牌点数之和；拥有最多战士徽章的玩家额外获得等同于自己最高面值硬币的【英勇奖励】！
  - **3: 矿工（橙色）**：得分为 `矿工徽章总数 × 所有矿工卡牌点数之和`。
  - **4: 探险家（蓝色）**：得分为所有探险家卡牌点数之和。
  - **总分**：五大兵种得分 + 中立英雄奖励分 + 自己 5 枚硬币面值总和，最高分者获胜！
''';

class Nidavellir extends GameEngine {
  Nidavellir(super.setup);

  late int maxRounds;
  int round = 1;
  String phase = 'bid'; // 'bid', 'draft', 'recruit_hero'
  int currentTavern = 0; // 0..2
  int draftIdx = 0;
  List<int> draftOrder = [];
  int pendingHeroSeat = -1;
  bool over = false;

  late List<List<int>> coins; // coins[seat] of length 5
  late List<List<int>?> currentBids; // currentBids[seat] of length 3
  late List<List<int>> pouches; // pouches[seat] of length 2
  late List<int> gems; // unique crystal rank 1..players
  late List<List<NidavellirCard>> armies;
  late List<List<NidavellirHero>> heroes;

  final List<NidavellirCard> age1Deck = [];
  final List<NidavellirCard> age2Deck = [];
  late List<List<NidavellirCard>> taverns;
  final List<NidavellirHero> availableHeroes = [];

  String lastAction = '';
  Map<String, dynamic>? result;
  List<int>? _placings;

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => _placings;

  @override
  bool get canResign => !over;

  @override
  void resign(int seat) {
    if (over || seat < 0 || seat >= players) throw GameError('无法认输');
    over = true;
    final breakdown = computeScoreBreakdown();
    final scores = [
      for (var s = 0; s < players; s++) s == seat ? -999 : (breakdown[s]['total'] as int),
    ];
    _placings = rankByScore(scores);
    result = {
      'scores': [for (var s = 0; s < players; s++) breakdown[s]['total']],
      'breakdown': breakdown,
      'placings': _placings,
      'resigned': seat,
    };
  }

  @override
  List<int> get waitingFor {
    if (over) return const [];
    if (phase == 'bid') {
      return [
        for (var s = 0; s < players; s++)
          if (currentBids[s] == null) s,
      ];
    }
    if (phase == 'recruit_hero') {
      return [pendingHeroSeat];
    }
    if (phase == 'draft' && draftIdx < draftOrder.length) {
      return [draftOrder[draftIdx]];
    }
    return const [];
  }

  @override
  void start() {
    maxRounds = setup.opt<int>('rounds', 6);
    round = 1;
    phase = 'bid';
    currentTavern = 0;
    draftIdx = 0;
    pendingHeroSeat = -1;
    over = false;

    coins = List.generate(players, (_) => [0, 2, 3, 4, 5]);
    currentBids = List<List<int>?>.filled(players, null);
    pouches = List.generate(players, (_) => <int>[]);
    gems = [for (var s = 0; s < players; s++) players - s];
    armies = List.generate(players, (_) => <NidavellirCard>[]);
    heroes = List.generate(players, (_) => <NidavellirHero>[]);
    taverns = List.generate(3, (_) => <NidavellirCard>[]);

    availableHeroes
      ..clear()
      ..addAll(nidavellirCatalogHeroes);

    _buildDecks();
    _dealTaverns();
    lastAction = '尼达维利亚第 1 轮开始！请各特使向三座酒馆秘密分配硬币';
    host.log(lastAction);
  }

  void _buildDecks() {
    age1Deck.clear();
    age2Deck.clear();
    var id = 1;
    // Age 1 cards (36 cards across 5 classes)
    for (var i = 0; i < 8; i++) {
      age1Deck.add(NidavellirCard(id: id++, age: 1, classId: 0, name: '见习铁匠', ranks: const [0]));
      age1Deck.add(NidavellirCard(id: id++, age: 1, classId: 1, name: '丛林猎手', ranks: const [0]));
    }
    const w1 = [3, 4, 4, 5, 5, 6, 6, 7];
    for (final r in w1) {
      age1Deck.add(NidavellirCard(id: id++, age: 1, classId: 2, name: '红须战士($r)', ranks: [r]));
    }
    const m1 = [0, 1, 1, 1, 2, 2, 2];
    for (final r in m1) {
      age1Deck.add(NidavellirCard(id: id++, age: 1, classId: 3, name: '深渊矿工($r)', ranks: [r]));
    }
    const e1 = [5, 6, 7, 8, 9, 10, 5];
    for (var i = 0; i < e1.length; i++) {
      final r = e1[i];
      age1Deck.add(NidavellirCard(
        id: id++,
        age: 1,
        classId: 4,
        name: '皇家探险家($r)',
        ranks: [r],
        coinUpgrade: i == 6 ? 2 : 0,
      ));
    }
    age1Deck.shuffle(rng);

    // Age 2 cards (36 cards across 5 classes, including double-badge cards)
    for (var i = 0; i < 7; i++) {
      age2Deck.add(NidavellirCard(
        id: id++,
        age: 2,
        classId: 0,
        name: i < 2 ? '宗师铁匠(双徽章)' : '符文铁匠',
        ranks: i < 2 ? const [0, 0] : const [0],
      ));
      age2Deck.add(NidavellirCard(
        id: id++,
        age: 2,
        classId: 1,
        name: i < 2 ? '传奇猎王(双徽章)' : '巨兽猎人',
        ranks: i < 2 ? const [0, 0] : const [0],
      ));
    }
    const w2 = [7, 8, 8, 9, 9, 10, 10, 11];
    for (final r in w2) {
      age2Deck.add(NidavellirCard(id: id++, age: 2, classId: 2, name: '狂暴战神($r)', ranks: [r]));
    }
    const m2 = [1, 2, 2, 3, 3, 4, 4];
    for (final r in m2) {
      age2Deck.add(NidavellirCard(id: id++, age: 2, classId: 3, name: '秘银矿工($r)', ranks: [r]));
    }
    const e2 = [8, 9, 10, 11, 12, 6, 7];
    for (var i = 0; i < e2.length; i++) {
      final r = e2[i];
      age2Deck.add(NidavellirCard(
        id: id++,
        age: 2,
        classId: 4,
        name: '远古探险家($r)',
        ranks: [r],
        coinUpgrade: i >= 5 ? 3 : 0,
      ));
    }
    age2Deck.shuffle(rng);
  }

  NidavellirCard _drawCard(int age) {
    final deck = age == 1 ? age1Deck : age2Deck;
    if (deck.isEmpty) {
      final fallback = age == 1 ? age2Deck : age1Deck;
      if (fallback.isNotEmpty) return fallback.removeLast();
      final c = rng.nextInt(5);
      return NidavellirCard(
        id: 500 + rng.nextInt(400),
        age: age,
        classId: c,
        name: nidavellirClassNames[c],
        ranks: [c >= 2 ? 6 : 0],
      );
    }
    return deck.removeLast();
  }

  void _dealTaverns() {
    final age = round <= (maxRounds ~/ 2) ? 1 : 2;
    for (var t = 0; t < 3; t++) {
      taverns[t].clear();
      for (var i = 0; i < players; i++) {
        taverns[t].add(_drawCard(age));
      }
    }
  }

  /// Counts total badges in each of the 5 classes for [seat].
  List<int> classBadgeCounts(int seat) {
    final counts = List<int>.filled(5, 0);
    for (final c in armies[seat]) {
      counts[c.classId] += c.badges;
    }
    for (final h in heroes[seat]) {
      if (h.classId >= 0 && h.classId < 5) {
        counts[h.classId] += h.ranks.length;
      }
    }
    return counts;
  }

  /// Number of completed 5-class lines for [seat].
  int completedSetLines(int seat) => classBadgeCounts(seat).reduce(min);

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'bid') {
      if (type != 'bid') throw GameError('当前为出价阶段，请提交三座酒馆的硬币');
      if (currentBids[seat] != null) throw GameError('你本轮已经完成出价');
      final bidList = asIntList(action['coins']);
      if (bidList.length != 3) {
        throw GameError('必须为三座酒馆各分配 1 枚硬币（共 3 枚）');
      }
      // Verify `bidList` is a valid subset of `coins[seat]`
      final rem = List<int>.of(coins[seat]);
      for (final c in bidList) {
        final idx = rem.indexOf(c);
        if (idx < 0) {
          throw GameError('你没有面值为 $c 的可用硬币');
        }
        rem.removeAt(idx);
      }
      currentBids[seat] = bidList;
      pouches[seat] = rem..sort();

      if (currentBids.every((b) => b != null)) {
        // All players have bid -> start resolving Tavern 0
        phase = 'draft';
        currentTavern = 0;
        _prepareTavernOrder(0);
      } else {
        lastAction = '${name(seat)} 已部署酒馆硬币';
      }
      return;
    }

    if (phase == 'draft') {
      if (draftIdx >= draftOrder.length || seat != draftOrder[draftIdx]) {
        throw GameError('还没轮到你招募矮人');
      }
      if (type != 'draft') throw GameError('请从当前酒馆选择 1 张矮人卡');
      final idx = asInt(action['index'], -1);
      final cards = taverns[currentTavern];
      if (idx < 0 || idx >= cards.length) {
        throw GameError('无效的卡牌索引');
      }
      final picked = cards.removeAt(idx);
      armies[seat].add(picked);

      var upgradeMsg = '';
      if (picked.coinUpgrade > 0) {
        final upgraded = _upgradeHighestCoin(seat, picked.coinUpgrade);
        upgradeMsg = '（卡牌特效升级金币至$upgraded）';
      }

      // Check 0-coin Royal Treasure forging at this tavern
      final bidVal = currentBids[seat]![currentTavern];
      if (bidVal == 0) {
        final forged = _forgePouchCoin(seat);
        if (forged != null) {
          upgradeMsg += '（0币锻造将钱袋金币升级为$forged！）';
        }
      }

      lastAction =
          '${name(seat)} 在【${nidavellirTavernNames[currentTavern]}】招募了【${picked.name}】$upgradeMsg';
      host.log(lastAction);

      // Check if player completed a full set of all 5 Dwarf classes to recruit a Hero
      if (completedSetLines(seat) > heroes[seat].length && availableHeroes.isNotEmpty) {
        phase = 'recruit_hero';
        pendingHeroSeat = seat;
        return;
      }

      _advanceDraft();
      return;
    }

    if (phase == 'recruit_hero') {
      if (seat != pendingHeroSeat) throw GameError('还没轮到你招募英雄');
      if (type != 'recruit_hero') throw GameError('请选择要招募的传奇英雄');
      final heroId = asInt(action['heroId'], -1);
      final hIdx = availableHeroes.indexWhere((h) => h.id == heroId);
      if (hIdx < 0) throw GameError('该英雄不可招募');
      final hero = availableHeroes.removeAt(hIdx);
      heroes[seat].add(hero);
      if (hero.coinUpgrade > 0) {
        _upgradeHighestCoin(seat, hero.coinUpgrade);
      }
      lastAction = '${name(seat)} 集齐五兵种阵容，招募了传奇英雄【${hero.name}】！';
      host.log(lastAction);

      pendingHeroSeat = -1;
      phase = 'draft';
      _advanceDraft();
      return;
    }

    throw GameError('未知操作');
  }

  /// Resolves draft order for [tavernIdx] (`0..2`) and swaps Gem crystals among tied bidders!
  void _prepareTavernOrder(int tavernIdx) {
    final seats = [for (var s = 0; s < players; s++) s];
    seats.sort((a, b) {
      final ca = currentBids[a]![tavernIdx];
      final cb = currentBids[b]![tavernIdx];
      if (ca != cb) return cb.compareTo(ca);
      return gems[b].compareTo(gems[a]);
    });

    // Swap gems within any tied bid group
    var i = 0;
    while (i < seats.length) {
      var j = i + 1;
      final bidVal = currentBids[seats[i]]![tavernIdx];
      while (j < seats.length && currentBids[seats[j]]![tavernIdx] == bidVal) {
        j++;
      }
      if (j - i > 1) {
        // Group seats[i..j-1] tied on bidVal -> reverse their gem values
        final groupGems = [for (var k = i; k < j; k++) gems[seats[k]]];
        for (var k = 0; k < groupGems.length; k++) {
          gems[seats[i + k]] = groupGems[groupGems.length - 1 - k];
        }
      }
      i = j;
    }

    draftOrder = seats;
    draftIdx = 0;
    lastAction = '第 $round 轮：【${nidavellirTavernNames[tavernIdx]}】亮出硬币，由 ${name(draftOrder.first)} 先选';
    host.log(lastAction);
  }

  /// Forges the higher of the 2 pouch coins by adding the smaller pouch coin's value.
  int? _forgePouchCoin(int seat) {
    final p = pouches[seat];
    if (p.length < 2) return null;
    p.sort();
    final small = p[0];
    final high = p[1];
    if (small <= 0) return null;
    final newVal = min(25, high + small);
    // Update in both pouch and player's master coin list
    final cIdx = coins[seat].lastIndexOf(high);
    if (cIdx >= 0) {
      coins[seat][cIdx] = newVal;
      coins[seat].sort();
    }
    p[1] = newVal;
    return newVal;
  }

  int _upgradeHighestCoin(int seat, int delta) {
    coins[seat].sort();
    final oldVal = coins[seat].last;
    final newVal = min(25, oldVal + delta);
    coins[seat][coins[seat].length - 1] = newVal;
    return newVal;
  }

  void _advanceDraft() {
    draftIdx++;
    if (draftIdx < draftOrder.length && taverns[currentTavern].isNotEmpty) {
      return;
    }
    if (currentTavern < 2) {
      currentTavern++;
      _prepareTavernOrder(currentTavern);
      return;
    }
    // End of round
    if (round >= maxRounds) {
      _finishGame();
      return;
    }
    round++;
    phase = 'bid';
    currentTavern = 0;
    draftIdx = 0;
    for (var s = 0; s < players; s++) {
      currentBids[s] = null;
      pouches[s] = [];
    }
    _dealTaverns();
    lastAction = '第 $round 轮开始！请向三座酒馆分配硬币';
    host.log(lastAction);
  }

  void _finishGame() {
    over = true;
    final breakdown = computeScoreBreakdown();
    final scores = [for (var s = 0; s < players; s++) breakdown[s]['total'] as int];
    final tieBreak = [
      for (var s = 0; s < players; s++) scores[s] * 100 + gems[s],
    ];
    _placings = rankByScore(tieBreak);
    result = {
      'scores': scores,
      'breakdown': breakdown,
      'placings': _placings,
    };
    host.log('尼达维利亚结束！最终得分：${[for (var s = 0; s < players; s++) "${name(s)} ${scores[s]}分"].join("，")}');
  }

  // ==================== Class Scoring Functions ====================

  /// Blacksmith (0): 3, 7, 12, 18, 25, 33... = k * (k + 5) ~/ 2
  static int scoreBlacksmith(int badges) => badges <= 0 ? 0 : (badges * (badges + 5)) ~/ 2;

  /// Hunter (1): badges^2
  static int scoreHunter(int badges) => badges * badges;

  /// Compute full score breakdown for all seats.
  List<Map<String, dynamic>> computeScoreBreakdown() {
    final badgeMatrix = [for (var s = 0; s < players; s++) classBadgeCounts(s)];
    final maxWarriorBadges = [for (var s = 0; s < players; s++) badgeMatrix[s][2]].reduce(max);

    final out = <Map<String, dynamic>>[];
    for (var s = 0; s < players; s++) {
      final bCounts = badgeMatrix[s];
      final blacksmithPts = scoreBlacksmith(bCounts[0]);
      final hunterPts = scoreHunter(bCounts[1]);

      // Warrior (2): sum of ranks + bravery bonus (highest coin value if tied/sole leader in Warrior badges)
      var warriorRankSum = armies[s]
          .where((c) => c.classId == 2)
          .fold<int>(0, (sum, c) => sum + c.rankSum);
      warriorRankSum += heroes[s]
          .where((h) => h.classId == 2)
          .fold<int>(0, (sum, h) => sum + h.ranks.fold<int>(0, (a, b) => a + b));
      final hasBravery = maxWarriorBadges > 0 && bCounts[2] == maxWarriorBadges;
      final highestCoin = coins[s].reduce(max);
      final warriorPts = warriorRankSum + (hasBravery ? highestCoin : 0);

      // Miner (3): badge count * sum of ranks
      var minerRankSum = armies[s]
          .where((c) => c.classId == 3)
          .fold<int>(0, (sum, c) => sum + c.rankSum);
      minerRankSum += heroes[s]
          .where((h) => h.classId == 3)
          .fold<int>(0, (sum, h) => sum + h.ranks.fold<int>(0, (a, b) => a + b));
      final minerPts = bCounts[3] * minerRankSum;

      // Explorer (4): sum of ranks
      var explorerPts = armies[s]
          .where((c) => c.classId == 4)
          .fold<int>(0, (sum, c) => sum + c.rankSum);
      explorerPts += heroes[s]
          .where((h) => h.classId == 4)
          .fold<int>(0, (sum, h) => sum + h.ranks.fold<int>(0, (a, b) => a + b));

      final heroBonusPts = heroes[s].fold<int>(0, (sum, h) => sum + h.bonusVp);
      final coinSum = coins[s].fold<int>(0, (a, b) => a + b);
      final classScores = [blacksmithPts, hunterPts, warriorPts, minerPts, explorerPts];
      final total = blacksmithPts + hunterPts + warriorPts + minerPts + explorerPts + heroBonusPts + coinSum;

      out.add({
        'badges': bCounts,
        'classScores': classScores,
        'hasBravery': hasBravery,
        'heroBonus': heroBonusPts,
        'coinSum': coinSum,
        'total': total,
      });
    }
    return out;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final breakdown = computeScoreBreakdown();
    return {
      'round': round,
      'maxRounds': maxRounds,
      'phase': phase,
      'currentTavern': currentTavern,
      'draftOrder': draftOrder,
      'draftIdx': draftIdx,
      'pendingHeroSeat': pendingHeroSeat,
      'turn': waitingFor.isNotEmpty ? waitingFor.first : -1,
      'over': over,
      'taverns': [
        for (var t = 0; t < 3; t++)
          {
            'id': nidavellirTavernIds[t],
            'name': nidavellirTavernNames[t],
            'cards': [for (final c in taverns[t]) c.toJson()],
          },
      ],
      'availableHeroes': [for (final h in availableHeroes) h.toJson()],
      'playersData': [
        for (var s = 0; s < players; s++)
          {
            'coins': coins[s],
            'gem': gems[s],
            'hasBid': currentBids[s] != null,
            // Hide other players' bids during simultaneous 'bid' phase!
            'bids': phase == 'bid'
                ? (s == seat ? currentBids[s] : null)
                : currentBids[s],
            'pouch': phase == 'bid'
                ? (s == seat ? pouches[s] : const <int>[])
                : pouches[s],
            'army': [for (final c in armies[s]) c.toJson()],
            'heroes': [for (final h in heroes[s]) h.toJson()],
            'badges': breakdown[s]['badges'],
            'classScores': breakdown[s]['classScores'],
            'score': breakdown[s]['total'],
          },
      ],
      'scores': [for (var s = 0; s < players; s++) breakdown[s]['total']],
      'breakdown': breakdown,
      'lastAction': lastAction,
      if (result != null) 'result': result,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over) return null;

    if (phase == 'bid') {
      if (currentBids[seat] != null) return null;
      final myCoins = List<int>.of(coins[seat]);
      if (botLevel == 0) {
        myCoins.shuffle(rng);
        return {'type': 'bid', 'coins': myCoins.sublist(0, 3)};
      }
      // Smart bot: always include the 0 coin on one tavern so the two highest coins in pouch forge!
      myCoins.sort();
      if (myCoins.contains(0)) {
        // Put 0 on one tavern, and two mid coins on the other two taverns so the highest coins stay in pouch (or put highest on best tavern)
        final zeroIdx = myCoins.indexOf(0);
        final pool = List<int>.of(myCoins)..removeAt(zeroIdx);
        // Keep the top 2 coins in pouch in early rounds to forge big coins!
        if (round <= maxRounds - 2 && pool.length >= 4) {
          final bids = [0, pool[0], pool[1]]..shuffle(rng);
          return {'type': 'bid', 'coins': bids};
        } else {
          final bids = [0, pool[pool.length - 1], pool[pool.length - 2]]..shuffle(rng);
          return {'type': 'bid', 'coins': bids};
        }
      }
      myCoins.shuffle(rng);
      return {'type': 'bid', 'coins': myCoins.sublist(0, 3)};
    }

    if (phase == 'draft') {
      if (draftIdx >= draftOrder.length || seat != draftOrder[draftIdx]) return null;
      final cards = taverns[currentTavern];
      if (cards.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'draft', 'index': rng.nextInt(cards.length)};
      }
      // Pick card that maximizes immediate army score or completes a 5-class set line
      final curBadges = classBadgeCounts(seat);
      final minBadge = curBadges.reduce(min);
      var bestIdx = 0;
      var bestGain = -999;
      for (var i = 0; i < cards.length; i++) {
        final c = cards[i];
        var gain = c.rankSum + c.badges * 5 + c.coinUpgrade * 2;
        if (curBadges[c.classId] == minBadge) {
          gain += 12; // Helps complete a full 5-class line for a Hero!
        } else if (curBadges[c.classId] >= 3 && (c.classId == 0 || c.classId == 1 || c.classId == 3)) {
          gain += curBadges[c.classId] * 4; // Quadratic scaling classes
        }
        if (gain > bestGain) {
          bestGain = gain;
          bestIdx = i;
        }
      }
      return {'type': 'draft', 'index': bestIdx};
    }

    if (phase == 'recruit_hero') {
      if (seat != pendingHeroSeat || availableHeroes.isEmpty) return null;
      return {'type': 'recruit_hero', 'heroId': availableHeroes.first.id};
    }

    return null;
  }
}
