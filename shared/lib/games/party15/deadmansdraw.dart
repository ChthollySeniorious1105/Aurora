import 'dart:math';

import '../../src/engine.dart';

class DeadMansDrawCard {
  final int suit; // 0..9
  final int val; // 2..7 (or 4..9 for Mermaid suit 6)

  const DeadMansDrawCard(this.suit, this.val);

  Map<String, dynamic> toJson() => {'suit': suit, 'val': val};

  static DeadMansDrawCard fromJson(Map<String, dynamic> m) =>
      DeadMansDrawCard(asInt(m['suit']), asInt(m['val']));
}

const List<String> kDeadMansSuits = [
  '⚓ 船锚',
  '🪝 铁钩',
  '💣 火炮',
  '🗡️ 弯刀',
  '🔮 预言球',
  '🗺️ 藏宝图',
  '🧜‍♀️ 人鱼',
  '🗝️ 钥匙',
  '📦 宝箱',
  '🦑 海怪',
];

class DeadMansDrawGame extends GameEngine {
  DeadMansDrawGame(super.setup);

  List<DeadMansDrawCard> deck = [];
  List<DeadMansDrawCard> discard = [];
  List<DeadMansDrawCard> turnArea = [];

  /// bank[seat][suit] stores banked card values in ascending order (last = highest/top).
  late List<List<List<int>>> bank;

  int turn = 0;
  String phase = 'turn'; // 'turn', 'hook', 'cannon', 'sword', 'map', 'over'
  DeadMansDrawCard? oraclePeek;
  List<DeadMansDrawCard> mapChoices = [];
  int krakenMustDraw = 0;
  String lastEvent = '';
  bool _over = false;

  @override
  bool get isOver => _over;

  List<int> get scores => [
        for (var s = 0; s < players; s++) _seatScore(s),
      ];

  int _seatScore(int s) {
    var total = 0;
    for (var suit = 0; suit < 10; suit++) {
      final pile = bank[s][suit];
      if (pile.isNotEmpty) {
        total += pile.reduce(max);
      }
    }
    return total;
  }

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    final fast = setup.opt<String>('mode', 'standard') == 'fast';
    final all = <DeadMansDrawCard>[];
    for (var suit = 0; suit < 10; suit++) {
      final startVal = suit == 6 ? 4 : 2;
      final count = fast ? 4 : 6; // 40 cards in fast mode, 60 in standard
      for (var i = 0; i < count; i++) {
        all.add(DeadMansDrawCard(suit, startVal + (6 - count) + i));
      }
    }
    all.shuffle(rng);
    // Seed 6 cards into discard pile so Map and Key+Chest work from turn 1
    discard = all.sublist(0, 6);
    deck = all.sublist(6);
    bank = [
      for (var s = 0; s < players; s++) [for (var suit = 0; suit < 10; suit++) <int>[]],
    ];
    turnArea = [];
    turn = 0;
    phase = 'turn';
    oraclePeek = null;
    mapChoices = [];
    krakenMustDraw = 0;
    _over = false;
    lastEvent = '游戏开始！轮到 ${name(turn)} 抽牌探索。';
    host.log(lastEvent);
  }

  void _bankCard(int seat, DeadMansDrawCard c) {
    final pile = bank[seat][c.suit];
    pile.add(c.val);
    pile.sort();
  }

  bool _hasOwnBankCards(int seat) => bank[seat].any((p) => p.isNotEmpty);

  bool _hasOpponentBankCards(int seat, {bool excludeTurnAreaSuits = false}) {
    final turnSuits = {for (final c in turnArea) c.suit};
    for (var s = 0; s < players; s++) {
      if (s == seat) continue;
      for (var suit = 0; suit < 10; suit++) {
        if (bank[s][suit].isNotEmpty) {
          if (!excludeTurnAreaSuits || !turnSuits.contains(suit)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Adds [card] to [turnArea], checks for Bust, or triggers its suit ability.
  void playCardIntoTurnArea(DeadMansDrawCard card, {String source = '抽到'}) {
    final alreadyHadSuit = turnArea.any((c) => c.suit == card.suit);
    turnArea.add(card);
    if (alreadyHadSuit) {
      // BUST!
      final anchorIdx = turnArea.indexWhere((c) => c.suit == 0);
      final saved = <DeadMansDrawCard>[];
      if (anchorIdx > 0) {
        for (var i = 0; i < anchorIdx; i++) {
          saved.add(turnArea[i]);
          _bankCard(turn, turnArea[i]);
        }
        for (var i = anchorIdx; i < turnArea.length; i++) {
          discard.add(turnArea[i]);
        }
      } else {
        discard.addAll(turnArea);
      }
      turnArea.clear();
      oraclePeek = null;
      mapChoices.clear();
      krakenMustDraw = 0;
      if (saved.isNotEmpty) {
        lastEvent =
            '${name(turn)} $source ${kDeadMansSuits[card.suit]}(${card.val}) 爆牌！⚓船锚保护了此前 ${saved.length} 张牌收入宝库！';
      } else {
        lastEvent = '${name(turn)} $source ${kDeadMansSuits[card.suit]}(${card.val}) 爆牌！本回合战利品全部作废。';
      }
      host.log(lastEvent);
      _advanceTurn();
      return;
    }

    // Did not bust: resolve Pirate Ability
    _resolveSuitAbility(card, source: source);
  }

  void _resolveSuitAbility(DeadMansDrawCard card, {String source = '抽到'}) {
    final label = '${kDeadMansSuits[card.suit]}(${card.val})';
    switch (card.suit) {
      case 0: // ⚓ Anchor
        phase = 'turn';
        lastEvent = '${name(turn)} $source $label（爆牌保护已激活）';
        host.log(lastEvent);
      case 1: // 🪝 Hook
        if (_hasOwnBankCards(turn)) {
          phase = 'hook';
          lastEvent = '${name(turn)} $source $label，请从自己宝库选择一门花色打出顶牌！';
        } else {
          phase = 'turn';
          lastEvent = '${name(turn)} $source $label（宝库暂无卡牌可钩取）';
        }
        host.log(lastEvent);
      case 2: // 💣 Cannon
        if (_hasOpponentBankCards(turn)) {
          phase = 'cannon';
          lastEvent = '${name(turn)} $source $label，请选择摧毁一名对手宝库的顶牌！';
        } else {
          phase = 'turn';
          lastEvent = '${name(turn)} $source $label（对手宝库暂无卡牌可轰击）';
        }
        host.log(lastEvent);
      case 3: // 🗡️ Sword
        if (_hasOpponentBankCards(turn, excludeTurnAreaSuits: true)) {
          phase = 'sword';
          lastEvent = '${name(turn)} $source $label，请掠夺一名对手宝库的顶牌进入出牌区！';
        } else {
          phase = 'turn';
          lastEvent = '${name(turn)} $source $label（对手宝库暂无可安全掠夺的花色）';
        }
        host.log(lastEvent);
      case 4: // 🔮 Oracle
        phase = 'turn';
        if (deck.isNotEmpty) {
          oraclePeek = deck.last;
          lastEvent =
              '${name(turn)} $source $label，预言球窥视牌堆顶为 ${kDeadMansSuits[oraclePeek!.suit]}(${oraclePeek!.val})！';
        } else {
          oraclePeek = null;
          lastEvent = '${name(turn)} $source $label（牌堆已空）';
        }
        host.log(lastEvent);
      case 5: // 🗺️ Map
        if (discard.isNotEmpty) {
          discard.shuffle(rng);
          final takeCount = min(3, discard.length);
          mapChoices = discard.sublist(discard.length - takeCount);
          discard.removeRange(discard.length - takeCount, discard.length);
          phase = 'map';
          lastEvent = '${name(turn)} $source $label，从弃牌堆翻出 ${mapChoices.length} 张牌，请选择其中 1 张！';
        } else {
          phase = 'turn';
          lastEvent = '${name(turn)} $source $label（弃牌堆为空）';
        }
        host.log(lastEvent);
      case 6: // 🧜‍♀️ Mermaid
      case 7: // 🗝️ Key
      case 8: // 📦 Chest
        phase = 'turn';
        lastEvent = '${name(turn)} $source $label';
        host.log(lastEvent);
      case 9: // 🦑 Kraken
        phase = 'turn';
        krakenMustDraw = max(krakenMustDraw, 1);
        lastEvent = '${name(turn)} $source $label，海怪袭来！必须至少再抽 1 张牌！';
        host.log(lastEvent);
    }
  }

  void _advanceTurn() {
    if (deck.isEmpty) {
      _finishGame();
      return;
    }
    turn = (turn + 1) % players;
    phase = 'turn';
    oraclePeek = null;
    mapChoices.clear();
    krakenMustDraw = 0;
  }

  void _finishGame() {
    _over = true;
    phase = 'over';
    final sc = scores;
    final best = sc.reduce(max);
    final winners = [
      for (var i = 0; i < players; i++)
        if (sc[i] == best) name(i),
    ];
    lastEvent = '牌堆耗尽，游戏结束！获胜者：${winners.join('、')}（$best 分）';
    host.log(lastEvent);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    switch (phase) {
      case 'turn':
        if (type == 'draw') {
          if (deck.isEmpty) {
            if (turnArea.isNotEmpty) {
              _doBank();
            } else {
              _finishGame();
            }
            return;
          }
          if (krakenMustDraw > 0) {
            krakenMustDraw--;
          }
          oraclePeek = null;
          final card = deck.removeLast();
          playCardIntoTurnArea(card, source: '抽到');
        } else if (type == 'bank') {
          if (turnArea.isEmpty) throw GameError('当前回合区还没有卡牌，请先抽牌');
          if (krakenMustDraw > 0 && deck.isNotEmpty) {
            throw GameError('海怪效果生效中，必须至少再抽 $krakenMustDraw 张牌才能见好就收');
          }
          _doBank();
        } else {
          throw GameError('未知操作：$type');
        }

      case 'hook':
        if (type != 'hook') throw GameError('请先选择铁钩要打出的宝库花色');
        final suit = asInt(action['suit']);
        if (suit < 0 || suit >= 10 || bank[turn][suit].isEmpty) {
          throw GameError('该花色宝库中没有卡牌');
        }
        final val = bank[turn][suit].removeLast();
        phase = 'turn';
        playCardIntoTurnArea(DeadMansDrawCard(suit, val), source: '铁钩钩出');

      case 'cannon':
        if (type != 'cannon') throw GameError('请先选择火炮要轰击的目标与花色');
        final target = asInt(action['target']);
        final suit = asInt(action['suit']);
        if (target < 0 || target >= players || target == turn) {
          throw GameError('必须选择一名对手');
        }
        if (suit < 0 || suit >= 10 || bank[target][suit].isEmpty) {
          throw GameError('目标没有该花色的宝库牌');
        }
        final val = bank[target][suit].removeLast();
        discard.add(DeadMansDrawCard(suit, val));
        phase = 'turn';
        lastEvent = '${name(turn)} 用💣火炮轰掉了 ${name(target)} 的 ${kDeadMansSuits[suit]}($val)！';
        host.log(lastEvent);

      case 'sword':
        if (type != 'sword') throw GameError('请先选择弯刀要掠夺的目标与花色');
        final target = asInt(action['target']);
        final suit = asInt(action['suit']);
        if (target < 0 || target >= players || target == turn) {
          throw GameError('必须选择一名对手');
        }
        if (suit < 0 || suit >= 10 || bank[target][suit].isEmpty) {
          throw GameError('目标没有该花色的宝库牌');
        }
        final val = bank[target][suit].removeLast();
        phase = 'turn';
        playCardIntoTurnArea(DeadMansDrawCard(suit, val), source: '弯刀掠夺 ${name(target)} 的');

      case 'map':
        if (type != 'map') throw GameError('请先从藏宝图翻出的牌中选择一张');
        final idx = asInt(action['index'], 0);
        if (idx == -1) {
          discard.addAll(mapChoices);
          mapChoices.clear();
          phase = 'turn';
          lastEvent = '${name(turn)} 放弃拿取藏宝图卡牌。';
          host.log(lastEvent);
          return;
        }
        if (idx < 0 || idx >= mapChoices.length) {
          throw GameError('无效的卡牌索引');
        }
        final chosen = mapChoices[idx];
        for (var i = 0; i < mapChoices.length; i++) {
          if (i != idx) discard.add(mapChoices[i]);
        }
        mapChoices.clear();
        phase = 'turn';
        playCardIntoTurnArea(chosen, source: '藏宝图选取');

      default:
        throw GameError('未知阶段：$phase');
    }
  }

  void _doBank() {
    final hasKey = turnArea.any((c) => c.suit == 7);
    final hasChest = turnArea.any((c) => c.suit == 8);
    final count = turnArea.length;
    for (final c in turnArea) {
      _bankCard(turn, c);
    }
    turnArea.clear();

    var bonusCount = 0;
    if (hasKey && hasChest && discard.isNotEmpty) {
      discard.shuffle(rng);
      final n = min(count, discard.length);
      for (var i = 0; i < n; i++) {
        final bonus = discard.removeLast();
        _bankCard(turn, bonus);
        bonusCount++;
      }
    }
    if (bonusCount > 0) {
      lastEvent = '${name(turn)} 见好就收存入 $count 张牌，触发🗝️钥匙+📦宝箱额外获得 $bonusCount 张弃牌堆宝藏！';
    } else {
      lastEvent = '${name(turn)} 见好就收，将 $count 张战利品存入宝库！';
    }
    host.log(lastEvent);
    _advanceTurn();
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final turnSuits = {for (final c in turnArea) c.suit};

    switch (phase) {
      case 'hook':
        // Prefer a suit in own bank that isn't already in turnArea
        for (var s = 0; s < 10; s++) {
          if (bank[seat][s].isNotEmpty && !turnSuits.contains(s)) {
            return {'type': 'hook', 'suit': s};
          }
        }
        for (var s = 0; s < 10; s++) {
          if (bank[seat][s].isNotEmpty) {
            return {'type': 'hook', 'suit': s};
          }
        }
        return null;

      case 'cannon':
        int? bestTarget;
        int? bestSuit;
        var bestVal = -1;
        for (var p = 0; p < players; p++) {
          if (p == seat) continue;
          for (var s = 0; s < 10; s++) {
            if (bank[p][s].isNotEmpty && bank[p][s].last > bestVal) {
              bestVal = bank[p][s].last;
              bestTarget = p;
              bestSuit = s;
            }
          }
        }
        if (bestTarget != null && bestSuit != null) {
          return {'type': 'cannon', 'target': bestTarget, 'suit': bestSuit};
        }
        return null;

      case 'sword':
        int? bestTarget;
        int? bestSuit;
        var bestVal = -1;
        for (var p = 0; p < players; p++) {
          if (p == seat) continue;
          for (var s = 0; s < 10; s++) {
            if (bank[p][s].isNotEmpty && !turnSuits.contains(s) && bank[p][s].last > bestVal) {
              bestVal = bank[p][s].last;
              bestTarget = p;
              bestSuit = s;
            }
          }
        }
        if (bestTarget != null && bestSuit != null) {
          return {'type': 'sword', 'target': bestTarget, 'suit': bestSuit};
        }
        // Fallback if any exists
        for (var p = 0; p < players; p++) {
          if (p == seat) continue;
          for (var s = 0; s < 10; s++) {
            if (bank[p][s].isNotEmpty) {
              return {'type': 'sword', 'target': p, 'suit': s};
            }
          }
        }
        return null;

      case 'map':
        for (var i = 0; i < mapChoices.length; i++) {
          if (!turnSuits.contains(mapChoices[i].suit)) {
            return {'type': 'map', 'index': i};
          }
        }
        return {'type': 'map', 'index': -1};

      case 'turn':
        if (turnArea.isEmpty) return {'type': 'draw'};
        if (krakenMustDraw > 0 && deck.isNotEmpty) return {'type': 'draw'};
        if (deck.isEmpty) return {'type': 'bank'};
        if (oraclePeek != null) {
          if (turnSuits.contains(oraclePeek!.suit)) {
            return {'type': 'bank'};
          }
          return {'type': 'draw'};
        }
        final targetCards = botLevel == 0 ? 2 : 3;
        if (turnArea.length >= targetCards) {
          return {'type': 'bank'};
        }
        return {'type': 'draw'};

      default:
        return null;
    }
  }

  @override
  Map<String, dynamic> view(int seat) => {
        'turn': turn,
        'phase': phase,
        'deckCount': deck.length,
        'discardCount': discard.length,
        'turnArea': [for (final c in turnArea) c.toJson()],
        'bank': [
          for (var s = 0; s < players; s++)
            [
              for (var suit = 0; suit < 10; suit++) List<int>.of(bank[s][suit]),
            ],
        ],
        'oraclePeek': oraclePeek?.toJson(),
        'mapChoices': [for (final c in mapChoices) c.toJson()],
        'krakenMustDraw': krakenMustDraw,
        'scores': scores,
        'lastEvent': lastEvent,
        'over': _over,
      };
}
