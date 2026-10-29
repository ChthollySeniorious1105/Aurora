import 'dart:math';

import '../../src/engine.dart';

class DominionCardDef {
  final String id;
  final String name;
  final String type; // 'treasure', 'victory', 'curse', 'action', 'action_attack', 'action_reaction'
  final int cost;
  final int coins;
  final int vp;
  final int plusCards;
  final int plusActions;
  final int plusBuys;
  final String desc;

  const DominionCardDef({
    required this.id,
    required this.name,
    required this.type,
    required this.cost,
    this.coins = 0,
    this.vp = 0,
    this.plusCards = 0,
    this.plusActions = 0,
    this.plusBuys = 0,
    required this.desc,
  });

  bool get isTreasure => type == 'treasure';
  bool get isVictory => type == 'victory';
  bool get isCurse => type == 'curse';
  bool get isAction => type.startsWith('action');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'cost': cost,
        'coins': coins,
        'vp': vp,
        'plusCards': plusCards,
        'plusActions': plusActions,
        'plusBuys': plusBuys,
        'desc': desc,
      };
}

const Map<String, DominionCardDef> kDominionCards = {
  // Basic Treasures
  'copper': DominionCardDef(
    id: 'copper',
    name: '铜币',
    type: 'treasure',
    cost: 0,
    coins: 1,
    desc: '+1 金币',
  ),
  'silver': DominionCardDef(
    id: 'silver',
    name: '银币',
    type: 'treasure',
    cost: 3,
    coins: 2,
    desc: '+2 金币',
  ),
  'gold': DominionCardDef(
    id: 'gold',
    name: '金币',
    type: 'treasure',
    cost: 6,
    coins: 3,
    desc: '+3 金币',
  ),
  // Victory & Curse
  'estate': DominionCardDef(
    id: 'estate',
    name: '庄园',
    type: 'victory',
    cost: 2,
    vp: 1,
    desc: '1 胜点',
  ),
  'duchy': DominionCardDef(
    id: 'duchy',
    name: '公国',
    type: 'victory',
    cost: 5,
    vp: 3,
    desc: '3 胜点',
  ),
  'province': DominionCardDef(
    id: 'province',
    name: '行省',
    type: 'victory',
    cost: 8,
    vp: 6,
    desc: '6 胜点',
  ),
  'curse': DominionCardDef(
    id: 'curse',
    name: '诅咒',
    type: 'curse',
    cost: 0,
    vp: -1,
    desc: '-1 胜点',
  ),
  // Kingdom Action Cards
  'chapel': DominionCardDef(
    id: 'chapel',
    name: '礼拜堂',
    type: 'action',
    cost: 2,
    desc: '移除手牌中至多 4 张牌',
  ),
  'moat': DominionCardDef(
    id: 'moat',
    name: '护城河',
    type: 'action_reaction',
    cost: 2,
    plusCards: 2,
    desc: '+2 牌；在手牌中自动防御女巫诅咒',
  ),
  'village': DominionCardDef(
    id: 'village',
    name: '村庄',
    type: 'action',
    cost: 3,
    plusCards: 1,
    plusActions: 2,
    desc: '+1 牌，+2 行动',
  ),
  'woodcutter': DominionCardDef(
    id: 'woodcutter',
    name: '伐木工',
    type: 'action',
    cost: 3,
    plusBuys: 1,
    coins: 2,
    desc: '+1 购买，+2 金币',
  ),
  'workshop': DominionCardDef(
    id: 'workshop',
    name: '工坊',
    type: 'action',
    cost: 3,
    desc: '免费获得 1 张费用不超过 4 的牌',
  ),
  'smithy': DominionCardDef(
    id: 'smithy',
    name: '铁匠铺',
    type: 'action',
    cost: 4,
    plusCards: 3,
    desc: '+3 牌',
  ),
  'moneylender': DominionCardDef(
    id: 'moneylender',
    name: '放债人',
    type: 'action',
    cost: 4,
    desc: '移除手牌 1 张铜币，+3 金币',
  ),
  'remodel': DominionCardDef(
    id: 'remodel',
    name: '放债人',
    type: 'action',
    cost: 4,
    desc: '移除手牌 1 张铜币，+3 金币',
  ),
  'market': DominionCardDef(
    id: 'market',
    name: '集市',
    type: 'action',
    cost: 5,
    plusCards: 1,
    plusActions: 1,
    plusBuys: 1,
    coins: 1,
    desc: '+1 牌，+1 行动，+1 购买，+1 金币',
  ),
  'laboratory': DominionCardDef(
    id: 'laboratory',
    name: '实验室',
    type: 'action',
    cost: 5,
    plusCards: 2,
    plusActions: 1,
    desc: '+2 牌，+1 行动',
  ),
  'festival': DominionCardDef(
    id: 'festival',
    name: '庆典',
    type: 'action',
    cost: 5,
    plusActions: 2,
    plusBuys: 1,
    coins: 2,
    desc: '+2 行动，+1 购买，+2 金币',
  ),
  'witch': DominionCardDef(
    id: 'witch',
    name: '女巫',
    type: 'action_attack',
    cost: 5,
    plusCards: 2,
    desc: '+2 牌；其他无护城河玩家各获 1 张诅咒',
  ),
};

const List<String> kBasicSupplyOrder = [
  'copper',
  'silver',
  'gold',
  'estate',
  'duchy',
  'province',
  'curse',
];

const List<String> kKingdomSupplyOrder = [
  'chapel',
  'moat',
  'village',
  'woodcutter',
  'workshop',
  'smithy',
  'moneylender',
  'market',
  'laboratory',
  'festival',
  'witch',
];

const String dominionRules = '''
# 皇舆争霸（Dominion）规则说明

## 游戏简介
《皇舆争霸》是经典的牌库构筑（Deck-Building）桌游。每位玩家从 7 张铜币与 3 张庄园的初始牌库起步，通过打出行动牌、钱币牌并在市场购买新牌不断强化自己的牌库，在终局时拥有最高胜点的玩家获胜。

## 供应区牌堆
- **基础钱币牌**：铜币（0费，+1金）、银币（3费，+2金）、金币（6费，+3金）。
- **分数与诅咒牌**：庄园（2费，1分）、公国（5费，3分）、行省（8费，6分）、诅咒（0费，-1分）。
- **王国行动牌（每堆 10 张）**：
  - **礼拜堂（2费）**：从手牌中移除（销毁）至多 4 张牌，精简牌库。
  - **护城河（2费）**：+2 牌；当其他玩家打出女巫时，若你手牌中有护城河则自动免受诅咒攻击。
  - **村庄（3费）**：+1 牌，+2 行动。
  - **伐木工（3费）**：+1 购买，+2 金币。
  - **工坊（3费）**：免费获得 1 张费用不超过 4 金币的牌放入弃牌堆。
  - **铁匠铺（4费）**：+3 牌。
  - **放债人（4费）**：移除手牌中的 1 张铜币，本回合获得 +3 金币。
  - **集市（5费）**：+1 牌，+1 行动，+1 购买，+1 金币。
  - **实验室（5费）**：+2 牌，+1 行动。
  - **庆典（5费）**：+2 行动，+1 购买，+2 金币。
  - **女巫（5费）**：+2 牌；其他每位手牌中没有护城河的玩家各获得 1 张诅咒。

## 回合流程
- 每回合开始时拥有 **1 次行动**、**1 次购买**、**0 金币**。
- **行动阶段**：可消耗行动次数打出行动牌并结算效果。
- **出钱与购买阶段**：打出钱币牌累积金币，消耗购买次数与金币从供应区购买卡牌（新获得的牌进入个人弃牌堆）。
- **清理阶段**：结束回合时将所有手牌与本回合打出的牌移入弃牌堆，并抽取 5 张新牌（牌库抽空时自动将弃牌堆洗混成新牌库）。

## 结束与胜负
- 回合结束时，若 **行省牌堆被买空** 或 **任意 3 个供应牌堆为空**，游戏立即结束。
- 统计每位玩家牌库、手牌和弃牌堆中所有牌的总胜点（庄园1分、公国3分、行省6分、诅咒-1分），总分最高者获胜。

## 房间选项
- **行省数量**：标准模式（2人8张 / 3-4人12张）或快速模式（5张行省）。
''';

class DominionGame extends GameEngine {
  DominionGame(super.setup);

  final Map<String, int> supply = {};
  late List<List<String>> deck;
  late List<List<String>> hand;
  late List<List<String>> discard;
  final List<String> played = [];
  final List<String> trash = [];

  int turn = 0;
  int round = 1;
  int actions = 1;
  int buys = 1;
  int coins = 0;
  String phase = 'turn'; // 'turn', 'chapel', 'workshop'
  String lastLog = '游戏开始';

  bool _over = false;
  List<int>? _finalScores;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over && _finalScores != null ? rankByScore(_finalScores!) : null;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    final provOpt = setup.options['provinces'];
    final isQuick = provOpt == 5 || provOpt == 'quick';
    final victoryCount = players == 2 ? 8 : 12;
    final provinceCount = isQuick ? 5 : victoryCount;

    supply.clear();
    supply['copper'] = 60 - 7 * players;
    supply['silver'] = 40;
    supply['gold'] = 30;
    supply['estate'] = victoryCount;
    supply['duchy'] = victoryCount;
    supply['province'] = provinceCount;
    supply['curse'] = (players - 1) * 10;

    for (final k in kKingdomSupplyOrder) {
      supply[k] = 10;
    }

    deck = List.generate(players, (_) => <String>[]);
    hand = List.generate(players, (_) => <String>[]);
    discard = List.generate(players, (_) => <String>[]);
    played.clear();
    trash.clear();

    for (var s = 0; s < players; s++) {
      final startCards = <String>[
        for (var i = 0; i < 7; i++) 'copper',
        for (var i = 0; i < 3; i++) 'estate',
      ]..shuffle(rng);
      deck[s].addAll(startCards);
      drawCards(s, 5);
    }

    turn = 0;
    round = 1;
    actions = 1;
    buys = 1;
    coins = 0;
    phase = 'turn';
    _over = false;
    _finalScores = null;
    lastLog = '游戏开始，轮到 ${name(turn)} 行动';
    host.log(lastLog);
  }

  void drawCards(int seat, int count) {
    for (var i = 0; i < count; i++) {
      if (deck[seat].isEmpty && discard[seat].isNotEmpty) {
        deck[seat].addAll(discard[seat]..shuffle(rng));
        discard[seat].clear();
      }
      if (deck[seat].isEmpty) break;
      hand[seat].add(deck[seat].removeLast());
    }
  }

  int scoreOf(int seat) {
    var total = 0;
    for (final c in [...deck[seat], ...hand[seat], ...discard[seat], if (seat == turn && !_over) ...played]) {
      total += kDominionCards[c]?.vp ?? 0;
    }
    return total;
  }

  int totalCardsOf(int seat) =>
      deck[seat].length + hand[seat].length + discard[seat].length + (seat == turn && !_over ? played.length : 0);

  int emptyPileCount() {
    var empty = 0;
    for (final entry in supply.entries) {
      if (entry.value <= 0) empty++;
    }
    return empty;
  }

  bool get hasWorkshopTarget =>
      supply.entries.any((e) => e.value > 0 && (kDominionCards[e.key]?.cost ?? 99) <= 4);

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'chapel_trash':
        _handleChapelTrash(seat, action);
        break;
      case 'workshop_gain':
        _handleWorkshopGain(seat, action);
        break;
      case 'play':
        _handlePlay(seat, action);
        break;
      case 'play_treasures':
        _handlePlayTreasures(seat);
        break;
      case 'buy':
        _handleBuy(seat, action);
        break;
      case 'end_turn':
        _handleEndTurn(seat);
        break;
      default:
        throw GameError('未知操作：$type');
    }
  }

  void _handleChapelTrash(int seat, Map<String, dynamic> action) {
    if (phase != 'chapel') throw GameError('当前不在礼拜堂移除阶段');
    final raw = action['cards'];
    final cards = raw is List ? [for (final e in raw) asStr(e)] : <String>[];
    if (cards.length > 4) throw GameError('礼拜堂至多只能移除 4 张手牌');

    // Verify all cards exist in hand with sufficient multiplicity
    final tempHand = List<String>.of(hand[seat]);
    for (final c in cards) {
      final idx = tempHand.indexOf(c);
      if (idx < 0) throw GameError('手牌中没有足够的 ${kDominionCards[c]?.name ?? c}');
      tempHand.removeAt(idx);
    }

    hand[seat] = tempHand;
    trash.addAll(cards);
    phase = 'turn';
    lastLog = cards.isEmpty
        ? '${name(seat)} 使用礼拜堂未移除卡牌'
        : '${name(seat)} 使用礼拜堂移除了 ${cards.map((c) => kDominionCards[c]?.name ?? c).join('、')}';
    host.log(lastLog);
  }

  void _handleWorkshopGain(int seat, Map<String, dynamic> action) {
    if (phase != 'workshop') throw GameError('当前不在工坊获取阶段');
    final card = asStr(action['card']);
    final def = kDominionCards[card];
    if (def == null) throw GameError('未知卡牌：$card');
    if ((supply[card] ?? 0) <= 0) throw GameError('${def.name} 已无剩余库存');
    if (def.cost > 4) throw GameError('工坊只能获得费用不超过 4 的卡牌');

    supply[card] = supply[card]! - 1;
    discard[seat].add(card);
    phase = 'turn';
    lastLog = '${name(seat)} 通过工坊获得了 ${def.name}';
    host.log(lastLog);
  }

  void _handlePlay(int seat, Map<String, dynamic> action) {
    if (phase != 'turn') throw GameError('请先完成当前卡牌的结算');
    final rawCard = asStr(action['card']);
    var card = rawCard;
    var idx = hand[seat].indexOf(card);
    if (idx < 0 && rawCard == 'remodel') {
      idx = hand[seat].indexOf('moneylender');
      if (idx >= 0) card = 'moneylender';
    } else if (idx < 0 && rawCard == 'moneylender') {
      idx = hand[seat].indexOf('remodel');
      if (idx >= 0) card = 'remodel';
    }
    if (idx < 0) throw GameError('手牌中没有该卡牌');

    final def = kDominionCards[card];
    if (def == null) throw GameError('未知卡牌：$card');

    if (def.isTreasure) {
      hand[seat].removeAt(idx);
      played.add(card);
      coins += def.coins;
      lastLog = '${name(seat)} 打出了 ${def.name}（+${def.coins}金）';
      return;
    }

    if (!def.isAction) throw GameError('${def.name} 不能直接打出');
    if (actions <= 0) throw GameError('没有剩余行动次数');

    hand[seat].removeAt(idx);
    played.add(card);
    actions -= 1;

    if (def.plusCards > 0) drawCards(seat, def.plusCards);
    actions += def.plusActions;
    buys += def.plusBuys;
    coins += def.coins;

    if (card == 'chapel') {
      if (hand[seat].isNotEmpty) {
        phase = 'chapel';
        lastLog = '${name(seat)} 打出了 礼拜堂，请选择要移除的手牌';
      } else {
        lastLog = '${name(seat)} 打出了 礼拜堂（无手牌可移除）';
      }
      host.log(lastLog);
      return;
    }

    if (card == 'workshop') {
      if (hasWorkshopTarget) {
        phase = 'workshop';
        lastLog = '${name(seat)} 打出了 工坊，请选择 1 张不超过 4 费的牌';
      } else {
        lastLog = '${name(seat)} 打出了 工坊（无可用目标）';
      }
      host.log(lastLog);
      return;
    }

    if (card == 'moneylender' || card == 'remodel') {
      final copIdx = hand[seat].indexOf('copper');
      if (copIdx >= 0) {
        hand[seat].removeAt(copIdx);
        trash.add('copper');
        coins += 3;
        lastLog = '${name(seat)} 打出了 放债人，移除 1 张铜币并 +3 金币';
      } else {
        lastLog = '${name(seat)} 打出了 放债人（手牌无铜币）';
      }
      host.log(lastLog);
      return;
    }

    if (card == 'witch') {
      final cursedNames = <String>[];
      final blockedNames = <String>[];
      for (var i = 1; i < players; i++) {
        final target = (seat + i) % players;
        if (hand[target].contains('moat')) {
          blockedNames.add(name(target));
        } else if ((supply['curse'] ?? 0) > 0) {
          supply['curse'] = supply['curse']! - 1;
          discard[target].add('curse');
          cursedNames.add(name(target));
        }
      }
      final parts = <String>['${name(seat)} 打出了 女巫（+2牌）'];
      if (cursedNames.isNotEmpty) parts.add('${cursedNames.join('、')} 获得诅咒');
      if (blockedNames.isNotEmpty) parts.add('${blockedNames.join('、')} 用护城河防御');
      lastLog = parts.join('；');
      host.log(lastLog);
      return;
    }

    lastLog = '${name(seat)} 打出了 ${def.name}';
    host.log(lastLog);
  }

  void _handlePlayTreasures(int seat) {
    if (phase != 'turn') throw GameError('请先完成当前卡牌的结算');
    var addedCoins = 0;
    var count = 0;
    final remaining = <String>[];
    for (final c in hand[seat]) {
      final def = kDominionCards[c];
      if (def != null && def.isTreasure) {
        played.add(c);
        coins += def.coins;
        addedCoins += def.coins;
        count++;
      } else {
        remaining.add(c);
      }
    }
    if (count == 0) throw GameError('手牌中没有钱币牌');
    hand[seat] = remaining;
    lastLog = '${name(seat)} 打出了 $count 张钱币牌（+$addedCoins金，共 $coins金）';
  }

  void _handleBuy(int seat, Map<String, dynamic> action) {
    if (phase != 'turn') throw GameError('请先完成当前卡牌的结算');
    if (buys <= 0) throw GameError('没有剩余购买次数');
    final card = asStr(action['card']);
    final def = kDominionCards[card];
    if (def == null || !supply.containsKey(card)) throw GameError('未知供应区卡牌：$card');
    if ((supply[card] ?? 0) <= 0) throw GameError('${def.name} 已售罄');
    if (coins < def.cost) throw GameError('金币不足（需要 ${def.cost} 金币，当前 $coins 金币）');

    buys -= 1;
    coins -= def.cost;
    supply[card] = supply[card]! - 1;
    discard[seat].add(card);
    lastLog = '${name(seat)} 购买了 ${def.name}';
    host.log(lastLog);
  }

  void _handleEndTurn(int seat) {
    if (phase != 'turn') throw GameError('请先完成当前卡牌的结算');

    discard[seat].addAll(hand[seat]);
    hand[seat].clear();
    discard[seat].addAll(played);
    played.clear();

    drawCards(seat, 5);

    if ((supply['province'] ?? 0) <= 0 || emptyPileCount() >= 3) {
      _over = true;
      _finalScores = [for (var s = 0; s < players; s++) scoreOf(s)];
      final maxScore = _finalScores!.reduce(max);
      final winners = [
        for (var s = 0; s < players; s++)
          if (_finalScores![s] == maxScore) name(s),
      ];
      lastLog = '游戏结束！${winners.join('、')} 以 $maxScore 分获胜！';
      host.log(lastLog);
      return;
    }

    turn = (turn + 1) % players;
    if (turn == 0) round++;
    actions = 1;
    buys = 1;
    coins = 0;
    phase = 'turn';
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'turn': turn,
      'round': round,
      'phase': phase,
      'actions': actions,
      'buys': buys,
      'coins': coins,
      'supply': Map<String, int>.of(supply),
      'played': List<String>.of(played),
      'trashCount': trash.length,
      'emptyPiles': emptyPileCount(),
      'lastLog': lastLog,
      'hand': seat >= 0 && seat < players ? List<String>.of(hand[seat]) : const <String>[],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'handCount': hand[s].length,
            'deckCount': deck[s].length,
            'discardCount': discard[s].length,
            'totalCards': totalCardsOf(s),
            'score': scoreOf(s),
          },
      ],
      if (_over && _finalScores != null)
        'result': {
          'scores': _finalScores,
          'placings': placings,
        },
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'chapel') {
      final toTrash = <String>[];
      for (final c in hand[seat]) {
        if (toTrash.length >= 4) break;
        if (c == 'curse') {
          toTrash.add(c);
        } else if (c == 'estate' && (supply['province'] ?? 0) > 4) {
          toTrash.add(c);
        }
      }
      return {'type': 'chapel_trash', 'cards': toTrash};
    }

    if (phase == 'workshop') {
      for (final target in const ['smithy', 'silver', 'moneylender', 'village', 'woodcutter', 'moat', 'estate', 'copper']) {
        if ((supply[target] ?? 0) > 0 && (kDominionCards[target]?.cost ?? 99) <= 4) {
          return {'type': 'workshop_gain', 'card': target};
        }
      }
      final any = supply.entries.firstWhere((e) => e.value > 0 && (kDominionCards[e.key]?.cost ?? 99) <= 4);
      return {'type': 'workshop_gain', 'card': any.key};
    }

    // phase == 'turn'
    if (actions > 0) {
      // First play non-terminal action cards (+1 or +2 actions)
      for (final c in const ['laboratory', 'market', 'village', 'festival']) {
        if (hand[seat].contains(c)) {
          return {'type': 'play', 'card': c};
        }
      }
      // Next play terminal action cards
      if (hand[seat].contains('witch')) return {'type': 'play', 'card': 'witch'};
      if (hand[seat].contains('smithy')) return {'type': 'play', 'card': 'smithy'};
      if (hand[seat].contains('moneylender') && hand[seat].contains('copper')) {
        return {'type': 'play', 'card': 'moneylender'};
      }
      if (hand[seat].contains('woodcutter')) return {'type': 'play', 'card': 'woodcutter'};
      if (hand[seat].contains('moat')) return {'type': 'play', 'card': 'moat'};
      if (hand[seat].contains('workshop') && hasWorkshopTarget) {
        return {'type': 'play', 'card': 'workshop'};
      }
      if (hand[seat].contains('chapel') && hand[seat].contains('curse')) {
        return {'type': 'play', 'card': 'chapel'};
      }
    }

    // Play treasures if any in hand
    if (hand[seat].any((c) => kDominionCards[c]?.isTreasure ?? false)) {
      return {'type': 'play_treasures'};
    }

    // Buy phase
    if (buys > 0) {
      final provLeft = supply['province'] ?? 0;
      String? pick(List<String> candidates) {
        for (final c in candidates) {
          final def = kDominionCards[c];
          if (def != null && (supply[c] ?? 0) > 0 && coins >= def.cost) {
            return c;
          }
        }
        return null;
      }

      if (coins >= 8 && provLeft > 0) {
        return {'type': 'buy', 'card': 'province'};
      }
      if (coins >= 6 && (supply['gold'] ?? 0) > 0) {
        return {'type': 'buy', 'card': 'gold'};
      }
      if (coins >= 5) {
        if (provLeft <= 4 && (supply['duchy'] ?? 0) > 0) {
          return {'type': 'buy', 'card': 'duchy'};
        }
        final c5 = pick(botLevel == 0
            ? const ['duchy', 'market', 'laboratory', 'silver']
            : const ['laboratory', 'witch', 'market', 'festival', 'duchy', 'silver']);
        if (c5 != null) return {'type': 'buy', 'card': c5};
      }
      if (coins >= 4) {
        final c4 = pick(rng.nextBool() ? const ['silver', 'smithy'] : const ['smithy', 'silver']);
        if (c4 != null) return {'type': 'buy', 'card': c4};
      }
      if (coins >= 3) {
        final c3 = pick(const ['silver', 'village', 'woodcutter']);
        if (c3 != null) return {'type': 'buy', 'card': c3};
      }
      if (coins >= 2 && provLeft <= 2 && (supply['estate'] ?? 0) > 0) {
        return {'type': 'buy', 'card': 'estate'};
      }
    }

    return {'type': 'end_turn'};
  }
}
