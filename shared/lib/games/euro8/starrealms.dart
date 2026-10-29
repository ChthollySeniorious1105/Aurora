import 'dart:math';

import '../../src/engine.dart';

const List<String> srFactionNames = ['贸易联盟', '异虫', '星际帝国', '机械神教', '中立'];

class SrCard {
  final int id;
  final String name;
  final int faction; // 0: 贸易联盟, 1: 异虫, 2: 星际帝国, 3: 机械神教, 4: 中立
  final int cost;
  final bool isBase;
  final bool isOutpost;
  final int defense;

  // Primary ability
  final int trade;
  final int combat;
  final int heal;
  final int draw;
  final int oppDiscard;
  final int scrapPower;

  // Ally ability (triggers when 2+ cards/bases of same faction 0..3 are in play)
  final int allyTrade;
  final int allyCombat;
  final int allyHeal;
  final int allyDraw;
  final int allyOppDiscard;

  // Self-scrap bonus (e.g. Explorer scraps for +2 combat)
  final int selfScrapCombat;

  const SrCard({
    required this.id,
    required this.name,
    required this.faction,
    required this.cost,
    this.isBase = false,
    this.isOutpost = false,
    this.defense = 0,
    this.trade = 0,
    this.combat = 0,
    this.heal = 0,
    this.draw = 0,
    this.oppDiscard = 0,
    this.scrapPower = 0,
    this.allyTrade = 0,
    this.allyCombat = 0,
    this.allyHeal = 0,
    this.allyDraw = 0,
    this.allyOppDiscard = 0,
    this.selfScrapCombat = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'faction': faction,
        'factionName': srFactionNames[faction],
        'cost': cost,
        'isBase': isBase,
        'isOutpost': isOutpost,
        'defense': defense,
        'trade': trade,
        'combat': combat,
        'heal': heal,
        'draw': draw,
        'oppDiscard': oppDiscard,
        'scrapPower': scrapPower,
        'allyTrade': allyTrade,
        'allyCombat': allyCombat,
        'allyHeal': allyHeal,
        'allyDraw': allyDraw,
        'allyOppDiscard': allyOppDiscard,
        'selfScrapCombat': selfScrapCombat,
      };
}

const SrCard srScoutTemplate = SrCard(
  id: 1,
  name: '侦察机 (Scout)',
  faction: 4,
  cost: 0,
  trade: 1,
);

const SrCard srViperTemplate = SrCard(
  id: 2,
  name: '毒蛇战机 (Viper)',
  faction: 4,
  cost: 0,
  combat: 1,
);

const SrCard srExplorerTemplate = SrCard(
  id: 3,
  name: '探索者 (Explorer)',
  faction: 4,
  cost: 2,
  trade: 2,
  selfScrapCombat: 2,
);

/// Trade deck templates across all 4 factions (ships, bases, outposts)
const List<(SrCard, int)> srTradeDeckCatalog = [
  // 0: 贸易联盟 (Trade Federation - Blue)
  (
    SrCard(
      id: 10,
      name: '联邦穿梭机',
      faction: 0,
      cost: 1,
      trade: 2,
      allyHeal: 4,
    ),
    3,
  ),
  (
    SrCard(
      id: 11,
      name: '切割者护卫舰',
      faction: 0,
      cost: 2,
      trade: 2,
      heal: 4,
      allyCombat: 4,
    ),
    3,
  ),
  (
    SrCard(
      id: 12,
      name: '使节运输船',
      faction: 0,
      cost: 3,
      heal: 4,
      combat: 2,
      allyTrade: 2,
    ),
    2,
  ),
  (
    SrCard(
      id: 13,
      name: '贸易前哨站',
      faction: 0,
      cost: 4,
      isBase: true,
      isOutpost: true,
      defense: 4,
      trade: 1,
      heal: 2,
      allyCombat: 2,
    ),
    2,
  ),
  (
    SrCard(
      id: 14,
      name: '旗舰·和平使者',
      faction: 0,
      cost: 6,
      combat: 5,
      heal: 6,
      draw: 1,
      allyHeal: 5,
    ),
    1,
  ),

  // 1: 异虫 (Blob - Green)
  (
    SrCard(
      id: 20,
      name: '异虫战斗机',
      faction: 1,
      cost: 1,
      combat: 3,
      allyDraw: 1,
    ),
    3,
  ),
  (
    SrCard(
      id: 21,
      name: '贸易虫茧',
      faction: 1,
      cost: 2,
      trade: 3,
      allyCombat: 2,
    ),
    3,
  ),
  (
    SrCard(
      id: 22,
      name: '冲角虫舰',
      faction: 1,
      cost: 3,
      combat: 5,
      allyTrade: 2,
    ),
    2,
  ),
  (
    SrCard(
      id: 23,
      name: '异虫母巢基地',
      faction: 1,
      cost: 3,
      isBase: true,
      isOutpost: false,
      defense: 5,
      combat: 2,
      allyDraw: 1,
    ),
    2,
  ),
  (
    SrCard(
      id: 24,
      name: '利维坦母虫',
      faction: 1,
      cost: 7,
      combat: 7,
      draw: 1,
      allyCombat: 4,
    ),
    1,
  ),

  // 2: 星际帝国 (Star Empire - Yellow)
  (
    SrCard(
      id: 30,
      name: '帝国战机',
      faction: 2,
      cost: 1,
      combat: 2,
      oppDiscard: 1,
      allyCombat: 2,
    ),
    3,
  ),
  (
    SrCard(
      id: 31,
      name: '科尔维特护卫舰',
      faction: 2,
      cost: 2,
      combat: 1,
      draw: 1,
      allyCombat: 2,
    ),
    3,
  ),
  (
    SrCard(
      id: 32,
      name: '太空站前哨',
      faction: 2,
      cost: 4,
      isBase: true,
      isOutpost: true,
      defense: 4,
      combat: 2,
      allyTrade: 2,
    ),
    2,
  ),
  (
    SrCard(
      id: 33,
      name: '战列巡洋舰',
      faction: 2,
      cost: 6,
      combat: 5,
      draw: 1,
      allyOppDiscard: 1,
    ),
    2,
  ),
  (
    SrCard(
      id: 34,
      name: '皇家无畏舰',
      faction: 2,
      cost: 7,
      combat: 7,
      draw: 1,
      oppDiscard: 1,
      allyCombat: 4,
    ),
    1,
  ),

  // 3: 机械神教 (Machine Cult - Red)
  (
    SrCard(
      id: 40,
      name: '贸易机器人',
      faction: 3,
      cost: 1,
      trade: 1,
      scrapPower: 1,
      allyCombat: 2,
    ),
    3,
  ),
  (
    SrCard(
      id: 41,
      name: '导弹工程舰',
      faction: 3,
      cost: 2,
      combat: 2,
      scrapPower: 1,
      allyCombat: 2,
    ),
    3,
  ),
  (
    SrCard(
      id: 42,
      name: '巡逻机甲',
      faction: 3,
      cost: 3,
      trade: 2,
      combat: 2,
      allyCombat: 2,
    ),
    2,
  ),
  (
    SrCard(
      id: 43,
      name: '边境要塞前哨',
      faction: 3,
      cost: 4,
      isBase: true,
      isOutpost: true,
      defense: 5,
      combat: 2,
      scrapPower: 1,
      allyCombat: 2,
    ),
    2,
  ),
  (
    SrCard(
      id: 44,
      name: '机械母舰',
      faction: 3,
      cost: 6,
      combat: 6,
      draw: 1,
      scrapPower: 1,
      allyCombat: 3,
    ),
    1,
  ),
];

const String starRealmsRules = '''
# 星域奇航（Star Realms）规则说明

- **游戏概述**：快节奏双人科幻星际牌库构筑对战桌游！两名指挥官从相同的 10 张基础舰队起步，通过中央贸易行购入四大阵营的强力战舰与前哨基地，触发同盟连击，摧毁敌方母舰权威值（Authority）。
- **开局设置**：
  - 双方起始拥有 `50` 点母舰权威值（快速模式 `35` 点）。
  - 每名玩家的个人牌库起始包含 10 张基础卡：`8` 张【侦察机 Scout】（`+1 贸易点`）与 `2` 张【毒蛇战机 Viper】（`+1 战力`）。
  - 中央市场展示 5 张贸易行卡牌（`tradeRow[0..4]`）以及常驻可购买的【探索者 Explorer】（费用 2，`+2 贸易点`，报废可得 `+2 战力`）。
  - 先手玩家第 1 回合抽取 `3` 张手牌，之后每回合双方均抽取 `5` 张手牌。
- **四大星际阵营与同盟连击（Ally Ability）**：
  - **0: 贸易联盟（蓝色）**：擅长恢复母舰权威值与赚取巨额贸易点。
  - **1: 异虫（绿色）**：拥有毁灭性的高额战力与过牌能力。
  - **2: 星际帝国（黄色）**：兼具高机动抽牌与迫使对手弃牌的能力。
  - **3: 机械神教（红色）**：擅长报废（销毁）手牌或弃牌堆中的弱小基础卡，精简提纯牌库。
  - **同盟连击**：当你本回合场上有 2 张或更多属于同一阵营的卡牌（含在场基地）时，自动触发这些卡牌的【同盟连击】额外加成！
- **基地与前哨站（Bases & Outposts）**：
  - 基地打出后留在场上跨回合持续生效，每回合自动提供基础收益。
  - 带盾牌标志的【前哨站（Outpost）】具有嘲讽护盾：只要对手场上有前哨站存在，你必须先消耗战力摧毁其所有前哨站（`attack_base`），才能攻击其非前哨基地或直接攻击敌方母舰权威值（`attack_player`）！
- **胜负条件**：一旦将对手的母舰权威值降至 `<= 0`，立即获胜！
''';

class StarRealms extends GameEngine {
  StarRealms(super.setup);

  late int startAuthority;
  int turn = 0;
  int turnCount = 1;
  bool over = false;

  late List<int> authority;
  late List<List<SrCard>> decks;
  late List<List<SrCard>> hands;
  late List<List<SrCard>> discards;
  late List<List<SrCard>> inPlay; // ships played this turn
  late List<List<SrCard>> bases; // bases/outposts remaining in play across turns

  final List<SrCard> tradeDeck = [];
  final List<SrCard?> tradeRow = List<SrCard?>.filled(5, null);
  final List<SrCard> scrapHeap = [];
  int explorersLeft = 12;

  int tradePool = 0;
  int combatPool = 0;
  int scrapCredits = 0;
  final Set<int> allyTriggeredIds = <int>{};
  int _nextInstanceId = 1;

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
    final winner = 1 - seat;
    _placings = rankWinners(players, [winner]);
    result = {
      'winner': winner,
      'authority': authority,
      'placings': _placings,
      'resigned': seat,
    };
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  SrCard _cloneCard(SrCard template) => SrCard(
        id: _nextInstanceId++,
        name: template.name,
        faction: template.faction,
        cost: template.cost,
        isBase: template.isBase,
        isOutpost: template.isOutpost,
        defense: template.defense,
        trade: template.trade,
        combat: template.combat,
        heal: template.heal,
        draw: template.draw,
        oppDiscard: template.oppDiscard,
        scrapPower: template.scrapPower,
        allyTrade: template.allyTrade,
        allyCombat: template.allyCombat,
        allyHeal: template.allyHeal,
        allyDraw: template.allyDraw,
        allyOppDiscard: template.allyOppDiscard,
        selfScrapCombat: template.selfScrapCombat,
      );

  @override
  void start() {
    startAuthority = setup.opt<int>('authority', 50);
    turn = 0;
    turnCount = 1;
    over = false;
    _nextInstanceId = 1;

    authority = [startAuthority, startAuthority];
    decks = [[], []];
    hands = [[], []];
    discards = [[], []];
    inPlay = [[], []];
    bases = [[], []];
    scrapHeap.clear();
    explorersLeft = 12;

    for (var s = 0; s < 2; s++) {
      for (var i = 0; i < 8; i++) {
        decks[s].add(_cloneCard(srScoutTemplate));
      }
      for (var i = 0; i < 2; i++) {
        decks[s].add(_cloneCard(srViperTemplate));
      }
      decks[s].shuffle(rng);
    }

    tradeDeck.clear();
    for (final (tmpl, count) in srTradeDeckCatalog) {
      for (var i = 0; i < count; i++) {
        tradeDeck.add(_cloneCard(tmpl));
      }
    }
    tradeDeck.shuffle(rng);
    for (var i = 0; i < 5; i++) {
      tradeRow[i] = tradeDeck.isNotEmpty ? tradeDeck.removeLast() : null;
    }

    // Player 0 draws 3 cards on first turn; Player 1 draws 5 cards
    _drawCards(0, 3);
    _drawCards(1, 5);
    _beginTurn(0);

    lastAction = '星域奇航开始！双方起始母舰权威值 $startAuthority，由 ${name(0)} 先手（首回合 3 张手牌）';
    host.log(lastAction);
  }

  void _drawCards(int seat, int count) {
    for (var i = 0; i < count; i++) {
      if (decks[seat].isEmpty) {
        if (discards[seat].isEmpty) return;
        decks[seat].addAll(discards[seat]);
        discards[seat].clear();
        decks[seat].shuffle(rng);
      }
      hands[seat].add(decks[seat].removeLast());
    }
  }

  void _beginTurn(int seat) {
    tradePool = 0;
    combatPool = 0;
    scrapCredits = 0;
    allyTriggeredIds.clear();

    // Activate all bases currently in play for `seat`
    for (final b in bases[seat]) {
      _applyPrimary(seat, b);
    }
    _checkAllyTriggers(seat);

    // Late-game escalation after turn 60 so matches always conclude decisively
    if (turnCount > 60) {
      combatPool += (turnCount - 60);
    }
  }

  void _applyPrimary(int seat, SrCard c) {
    tradePool += c.trade;
    combatPool += c.combat;
    authority[seat] += c.heal;
    scrapCredits += c.scrapPower;
    if (c.draw > 0) _drawCards(seat, c.draw);
    if (c.oppDiscard > 0) _discardFromOpponent(1 - seat, c.oppDiscard);
  }

  void _applyAlly(int seat, SrCard c) {
    tradePool += c.allyTrade;
    combatPool += c.allyCombat;
    authority[seat] += c.allyHeal;
    if (c.allyDraw > 0) _drawCards(seat, c.allyDraw);
    if (c.allyOppDiscard > 0) _discardFromOpponent(1 - seat, c.allyOppDiscard);
  }

  void _discardFromOpponent(int opp, int count) {
    for (var i = 0; i < count; i++) {
      if (hands[opp].isEmpty) return;
      // Discard weakest card (Scout/Viper first)
      hands[opp].sort((a, b) => a.cost.compareTo(b.cost));
      discards[opp].add(hands[opp].removeAt(0));
    }
  }

  void _checkAllyTriggers(int seat) {
    final activeCards = [...bases[seat], ...inPlay[seat]];
    final factionCounts = List<int>.filled(5, 0);
    for (final c in activeCards) {
      if (c.faction >= 0 && c.faction < 4) {
        factionCounts[c.faction]++;
      }
    }
    for (final c in activeCards) {
      if (c.faction >= 0 &&
          c.faction < 4 &&
          factionCounts[c.faction] >= 2 &&
          !allyTriggeredIds.contains(c.id)) {
        allyTriggeredIds.add(c.id);
        _applyAlly(seat, c);
      }
    }
  }

  bool opponentHasOutpost(int opp) => bases[opp].any((b) => b.isOutpost);

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    final opp = 1 - seat;

    if (type == 'play') {
      final idx = asInt(action['index'], -1);
      if (idx < 0 || idx >= hands[seat].length) {
        throw GameError('无效的手牌索引');
      }
      final card = hands[seat].removeAt(idx);
      if (card.isBase) {
        bases[seat].add(card);
      } else {
        inPlay[seat].add(card);
      }
      _applyPrimary(seat, card);
      _checkAllyTriggers(seat);
      lastAction = '${name(seat)} 打出了【${card.name}】';
      return;
    }

    if (type == 'play_all') {
      if (hands[seat].isEmpty) throw GameError('没有可打出的手牌');
      final count = hands[seat].length;
      while (hands[seat].isNotEmpty) {
        final card = hands[seat].removeAt(0);
        if (card.isBase) {
          bases[seat].add(card);
        } else {
          inPlay[seat].add(card);
        }
        _applyPrimary(seat, card);
        _checkAllyTriggers(seat);
      }
      lastAction = '${name(seat)} 打出了全部 $count 张手牌（贸易:$tradePool 战力:$combatPool）';
      host.log(lastAction);
      return;
    }

    if (type == 'buy') {
      final slot = asInt(action['slot'], -1);
      if (slot < 0 || slot >= 5 || tradeRow[slot] == null) {
        throw GameError('该贸易行槽位没有卡牌');
      }
      final card = tradeRow[slot]!;
      if (tradePool < card.cost) {
        throw GameError('贸易点不足（需要 ${card.cost}，当前 $tradePool）');
      }
      tradePool -= card.cost;
      discards[seat].add(card);
      tradeRow[slot] = tradeDeck.isNotEmpty ? tradeDeck.removeLast() : null;
      lastAction = '${name(seat)} 花费 ${card.cost} 贸易点购入了【${card.name}】';
      host.log(lastAction);
      return;
    }

    if (type == 'buy_explorer') {
      if (explorersLeft <= 0) throw GameError('探索者已售罄');
      if (tradePool < 2) throw GameError('贸易点不足（需要 2，当前 $tradePool）');
      tradePool -= 2;
      explorersLeft--;
      discards[seat].add(_cloneCard(srExplorerTemplate));
      lastAction = '${name(seat)} 花费 2 贸易点购入了【探索者】';
      host.log(lastAction);
      return;
    }

    if (type == 'scrap_in_play') {
      final idx = asInt(action['index'], -1);
      if (idx < 0 || idx >= inPlay[seat].length) {
        throw GameError('无效的在场舰船索引');
      }
      final card = inPlay[seat][idx];
      if (card.selfScrapCombat <= 0) {
        throw GameError('该卡牌没有自毁报废技能');
      }
      inPlay[seat].removeAt(idx);
      scrapHeap.add(card);
      combatPool += card.selfScrapCombat;
      lastAction = '${name(seat)} 报废了【${card.name}】，获得 +${card.selfScrapCombat} 战力';
      host.log(lastAction);
      return;
    }

    if (type == 'scrap_card') {
      if (scrapCredits <= 0) throw GameError('当前没有可用的机械神教报废点数');
      final zone = asStr(action['zone'], 'discard');
      final idx = asInt(action['index'], -1);
      final targetList = zone == 'hand' ? hands[seat] : discards[seat];
      if (idx < 0 || idx >= targetList.length) {
        throw GameError('无效的报废目标索引');
      }
      scrapCredits--;
      final removed = targetList.removeAt(idx);
      scrapHeap.add(removed);
      lastAction = '${name(seat)} 报废销毁了${zone == "hand" ? "手牌" : "弃牌堆"}中的【${removed.name}】';
      host.log(lastAction);
      return;
    }

    if (type == 'attack_base') {
      final idx = asInt(action['index'], -1);
      if (idx < 0 || idx >= bases[opp].length) {
        throw GameError('无效的敌方基地索引');
      }
      final targetBase = bases[opp][idx];
      if (!targetBase.isOutpost && opponentHasOutpost(opp)) {
        throw GameError('必须先摧毁敌方的前哨站（Outpost）才能攻击普通基地！');
      }
      if (combatPool < targetBase.defense) {
        throw GameError('战力不足以摧毁【${targetBase.name}】（需要 ${targetBase.defense}，当前 $combatPool）');
      }
      combatPool -= targetBase.defense;
      bases[opp].removeAt(idx);
      discards[opp].add(targetBase);
      lastAction = '${name(seat)} 消耗 ${targetBase.defense} 战力摧毁了 ${name(opp)} 的【${targetBase.name}】！';
      host.log(lastAction);
      return;
    }

    if (type == 'attack_player') {
      if (opponentHasOutpost(opp)) {
        throw GameError('敌方在场有【前哨站（Outpost）】护盾，必须先摧毁所有前哨站才能直接攻击母舰！');
      }
      if (combatPool <= 0) {
        throw GameError('当前没有可用战力');
      }
      final dmg = action['amount'] != null ? min(combatPool, max(1, asInt(action['amount'], combatPool))) : combatPool;
      combatPool -= dmg;
      authority[opp] -= dmg;
      lastAction = '${name(seat)} 对 ${name(opp)} 母舰发动攻击，造成 $dmg 点伤害（剩余权威值 ${authority[opp]}）！';
      host.log(lastAction);

      if (authority[opp] <= 0) {
        _finishGame(seat);
      }
      return;
    }

    if (type == 'end_turn') {
      // Discard remaining hand and ships in play (bases stay in play!)
      discards[seat].addAll(hands[seat]);
      hands[seat].clear();
      discards[seat].addAll(inPlay[seat]);
      inPlay[seat].clear();

      _drawCards(seat, 5);
      turn = opp;
      turnCount++;
      _beginTurn(turn);
      return;
    }

    throw GameError('未知操作: $type');
  }

  void _finishGame(int winner) {
    over = true;
    _placings = rankWinners(players, [winner]);
    result = {
      'winner': winner,
      'authority': authority,
      'placings': _placings,
      'scores': authority,
    };
    host.log('星域奇航结束！${name(winner)} 击毁敌方母舰获胜！');
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'turn': turn,
      'turnCount': turnCount,
      'over': over,
      'authority': authority,
      'tradePool': tradePool,
      'combatPool': combatPool,
      'scrapCredits': scrapCredits,
      'explorersLeft': explorersLeft,
      'tradeDeckCount': tradeDeck.length,
      'tradeRow': [for (final c in tradeRow) c?.toJson()],
      'myHand': seat >= 0 && seat < 2 ? [for (final c in hands[seat]) c.toJson()] : const [],
      'playersData': [
        for (var s = 0; s < 2; s++)
          {
            'authority': authority[s],
            'handCount': hands[s].length,
            'deckCount': decks[s].length,
            'discardCount': discards[s].length,
            'discardTop': discards[s].isNotEmpty ? discards[s].last.toJson() : null,
            // Only the owner sees their own discard pile cards for scrapping
            'discard': s == seat ? [for (final c in discards[s]) c.toJson()] : const [],
            'inPlay': [for (final c in inPlay[s]) c.toJson()],
            'bases': [for (final b in bases[s]) b.toJson()],
            'hasOutpost': opponentHasOutpost(s),
          },
      ],
      'scores': authority,
      'lastAction': lastAction,
      if (result != null) 'result': result,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final opp = 1 - seat;

    // 1. Play all cards from hand first
    if (hands[seat].isNotEmpty) {
      return {'type': 'play_all'};
    }

    // 2. Use scrap credits on Scouts/Vipers in discard pile if available
    if (scrapCredits > 0 && botLevel >= 1) {
      final weakIdx = discards[seat].indexWhere((c) => c.cost == 0);
      if (weakIdx >= 0) {
        return {'type': 'scrap_card', 'zone': 'discard', 'index': weakIdx};
      }
    }

    // 3. If scrapping an Explorer in play gives lethal or destroys an outpost, do it
    final expIdx = inPlay[seat].indexWhere((c) => c.selfScrapCombat > 0);
    if (expIdx >= 0 && (authority[opp] <= combatPool + 2 || bases[opp].isNotEmpty)) {
      return {'type': 'scrap_in_play', 'index': expIdx};
    }

    // 4. Spend tradePool on the highest-cost affordable card in tradeRow
    var bestSlot = -1;
    var bestVal = -1;
    for (var i = 0; i < 5; i++) {
      final c = tradeRow[i];
      if (c != null && c.cost <= tradePool) {
        final v = c.cost * 3 + c.combat * 2 + (c.isOutpost ? 4 : 0);
        if (v > bestVal) {
          bestVal = v;
          bestSlot = i;
        }
      }
    }
    if (bestSlot >= 0) {
      return {'type': 'buy', 'slot': bestSlot};
    }
    if (tradePool >= 2 && explorersLeft > 0 && turnCount <= 12) {
      return {'type': 'buy_explorer'};
    }

    // 5. Spend combatPool: destroy opponent Outposts first, then Bases, then attack opponent Authority
    if (combatPool > 0) {
      final outposts = [
        for (var i = 0; i < bases[opp].length; i++)
          if (bases[opp][i].isOutpost && bases[opp][i].defense <= combatPool) i,
      ];
      if (outposts.isNotEmpty) {
        return {'type': 'attack_base', 'index': outposts.first};
      }
      if (!opponentHasOutpost(opp)) {
        // Check if lethal on player
        if (combatPool >= authority[opp]) {
          return {'type': 'attack_player'};
        }
        // Destroy non-outpost base if affordable and botLevel >= 1
        final normalBases = [
          for (var i = 0; i < bases[opp].length; i++)
            if (bases[opp][i].defense <= combatPool) i,
        ];
        if (normalBases.isNotEmpty && botLevel >= 1) {
          return {'type': 'attack_base', 'index': normalBases.first};
        }
        return {'type': 'attack_player'};
      }
    }

    // 6. End turn
    return {'type': 'end_turn'};
  }
}
