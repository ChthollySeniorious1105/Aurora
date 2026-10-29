import 'dart:math';

import '../../src/engine.dart';

/// 皇家港 (Port Royal) — 2-5人推运探索、雇佣船员与远征成套收集桌游
class PortRoyalGame extends GameEngine {
  PortRoyalGame(super.setup);

  static const List<String> shipColors = ['yellow', 'blue', 'red', 'green', 'black'];
  static const Map<String, String> shipColorNames = {
    'yellow': '黄帆商船',
    'blue': '蓝帆商船',
    'red': '红帆战舰',
    'green': '绿帆快船',
    'black': '黑帆海盗船',
  };

  late int targetVp;
  final List<Map<String, dynamic>> deck = [];
  final List<Map<String, dynamic>> discard = [];
  final List<Map<String, dynamic>> harbor = [];
  final List<Map<String, dynamic>> openExpeditions = [];

  late List<int> coins;
  late List<List<Map<String, dynamic>>> crew;
  late List<List<Map<String, dynamic>>> expeditions;
  late List<int> vp;

  int turn = 0;
  int round = 1;
  String phase = 'discover'; // 'discover' | 'trade' | 'end'
  String subPhase = 'flip'; // 'flip' | 'active_trade' | 'other_trade'
  int tradeSeat = 0;
  int allowance = 0;
  String lastEvent = '';
  Map<String, dynamic>? lastBust;
  bool _over = false;

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'discover') return [turn];
    if (phase == 'trade') {
      if (subPhase == 'active_trade') return [turn];
      if (subPhase == 'other_trade') return [tradeSeat];
    }
    return const [];
  }

  @override
  List<int>? get placings {
    if (!_over) return null;
    final scores = [
      for (var s = 0; s < players; s++) vp[s] * 100 + coins[s],
    ];
    return rankByScore(scores);
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over) return;
    _over = true;
    vp[seat] = -99;
    lastEvent = '${name(seat)} 认输';
    host.log(lastEvent);
  }

  @override
  void start() {
    targetVp = setup.opt<int>('targetVp', 12);
    coins = List<int>.filled(players, 3);
    crew = [for (var i = 0; i < players; i++) <Map<String, dynamic>>[]];
    expeditions = [for (var i = 0; i < players; i++) <Map<String, dynamic>>[]];
    vp = List<int>.filled(players, 0);

    _buildDeck();
    turn = 0;
    round = 1;
    phase = 'discover';
    subPhase = 'flip';
    lastEvent = '游戏开始！轮到 ${name(turn)} 探索港口';
    host.log('皇家港开局！目标分数 $targetVp 分，每位船长初始 3 枚金币。');
  }

  void _buildDeck() {
    deck.clear();
    discard.clear();
    harbor.clear();
    openExpeditions.clear();

    var idCounter = 1;
    String nextId(String prefix) => '${prefix}_${idCounter++}';

    // 1. 远征卡 (Expeditions): 2 start open on table, 4 in deck
    final allExps = <Map<String, dynamic>>[
      {
        'id': nextId('exp'),
        'type': 'exp',
        'name': '新大陆垦殖团',
        'reqs': ['settler', 'settler'],
        'vp': 4,
        'coins': 2,
      },
      {
        'id': nextId('exp'),
        'type': 'exp',
        'name': '大教堂传教团',
        'reqs': ['priest', 'priest'],
        'vp': 4,
        'coins': 2,
      },
      {
        'id': nextId('exp'),
        'type': 'exp',
        'name': '远洋护航舰队',
        'reqs': ['captain', 'captain'],
        'vp': 4,
        'coins': 2,
      },
      {
        'id': nextId('exp'),
        'type': 'exp',
        'name': '圣殿开拓使命',
        'reqs': ['settler', 'priest'],
        'vp': 4,
        'coins': 2,
      },
      {
        'id': nextId('exp'),
        'type': 'exp',
        'name': '皇家巡航特使',
        'reqs': ['priest', 'captain'],
        'vp': 4,
        'coins': 2,
      },
      {
        'id': nextId('exp'),
        'type': 'exp',
        'name': '黄金群岛远征',
        'reqs': ['settler', 'priest', 'captain'],
        'vp': 6,
        'coins': 3,
      },
    ]..shuffle(rng);

    openExpeditions.add(allExps[0]);
    openExpeditions.add(allExps[1]);
    for (var i = 2; i < allExps.length; i++) {
      deck.add(allExps[i]);
    }

    // 2. 商船卡 (50 ships: 10 per color)
    final shipTemplates = <String, List<(int, int)>>{
      'yellow': [(1, 1), (1, 1), (2, 1), (2, 2), (2, 2), (3, 2), (3, 3), (3, 3), (4, 3), (4, 4)],
      'blue': [(1, 1), (1, 2), (2, 2), (2, 2), (2, 3), (3, 3), (3, 3), (3, 4), (4, 4), (4, 5)],
      'red': [(1, 1), (2, 2), (2, 3), (2, 3), (3, 3), (3, 4), (3, 4), (4, 5), (4, 5), (4, 99)],
      'green': [(1, 1), (1, 2), (2, 2), (2, 3), (2, 3), (3, 3), (3, 4), (3, 5), (4, 5), (4, 5)],
      'black': [(1, 2), (2, 3), (2, 3), (3, 4), (3, 4), (3, 5), (4, 5), (4, 99), (4, 99), (4, 99)],
    };
    for (final entry in shipTemplates.entries) {
      final color = entry.key;
      for (final (c, sw) in entry.value) {
        deck.add({
          'id': nextId('ship'),
          'type': 'ship',
          'color': color,
          'name': sw >= 99 ? '${shipColorNames[color]}(骷髅)' : shipColorNames[color]!,
          'coins': c,
          'swords': sw,
          'skull': sw >= 99,
        });
      }
    }

    // 3. 人物卡 (Persons)
    void addPerson(String role, String title, int cost, int vpVal, {int count = 1, String? color, int swords = 0}) {
      for (var i = 0; i < count; i++) {
        deck.add({
          'id': nextId('person'),
          'type': 'person',
          'role': role,
          'name': title,
          'cost': cost,
          'vp': vpVal,
          if (color != null) 'color': color,
          if (swords > 0) 'swords': swords,
        });
      }
    }

    // 水手 & 海盗
    addPerson('sailor', '水手', 3, 1, count: 6, swords: 1);
    addPerson('sailor', '老练水手', 5, 2, count: 3, swords: 1);
    addPerson('pirate', '海盗猎人', 5, 1, count: 3, swords: 2);
    addPerson('pirate', '海盗首领', 7, 2, count: 2, swords: 2);

    // 五色商人
    const traderNames = {
      'yellow': '黄帆贸易商',
      'blue': '蓝帆贸易商',
      'red': '红帆贸易商',
      'green': '绿帆贸易商',
      'black': '黑帆贸易商',
    };
    for (final c in shipColors) {
      addPerson('trader_$c', traderNames[c]!, 3, 1, count: 2, color: c);
    }

    // 远征专家 (定居者、牧师、船长)
    addPerson('settler', '定居者', 4, 1, count: 5);
    addPerson('priest', '牧师', 4, 1, count: 5);
    addPerson('captain', '船长', 4, 1, count: 5);

    // 特殊人物 (总督、小丑、海军上将、贵妇)
    addPerson('governor', '总督', 7, 1, count: 4);
    addPerson('jester', '小丑', 4, 1, count: 3);
    addPerson('jester', '皇家弄臣', 5, 2, count: 2);
    addPerson('admiral', '海军上将', 5, 1, count: 3);
    addPerson('admiral', '舰队统帅', 7, 2, count: 3);
    addPerson('mademoiselle', '贵族淑女', 6, 2, count: 2);
    addPerson('mademoiselle', '总督夫人', 8, 3, count: 2);

    // 4. 征税卡 (Tax cards)
    for (var i = 0; i < 2; i++) {
      deck.add({
        'id': nextId('tax'),
        'type': 'tax',
        'taxMode': 'max_swords',
        'name': '王室军备税（最高武力+1金）',
      });
      deck.add({
        'id': nextId('tax'),
        'type': 'tax',
        'taxMode': 'min_vp',
        'name': '王室济贫税（最低分数+1金）',
      });
    }

    deck.shuffle(rng);
  }

  int playerSwords(int seat) {
    var total = 0;
    for (final c in crew[seat]) {
      final role = c['role'] as String? ?? '';
      if (role == 'sailor') total += 1;
      if (role == 'pirate') total += 2;
    }
    return total;
  }

  int roleCount(int seat, String role) {
    var cnt = 0;
    for (final c in crew[seat]) {
      if (c['role'] == role) cnt++;
    }
    return cnt;
  }

  void _recalcVp() {
    for (var s = 0; s < players; s++) {
      var sum = 0;
      for (final c in crew[s]) {
        sum += asInt(c['vp'], 0);
      }
      for (final e in expeditions[s]) {
        sum += asInt(e['vp'], 0);
      }
      vp[s] = sum;
    }
  }

  int distinctShipColorsInHarbor() {
    final colors = <String>{};
    for (final c in harbor) {
      if (c['type'] == 'ship') {
        colors.add(asStr(c['color']));
      }
    }
    return colors.length;
  }

  int computeAllowance(int seat) {
    final colors = distinctShipColorsInHarbor();
    final base = colors >= 5 ? 3 : (colors == 4 ? 2 : 1);
    return base + roleCount(seat, 'governor');
  }

  int effectiveHireCost(int seat, Map<String, dynamic> personCard, {required bool isOtherTurn}) {
    final base = asInt(personCard['cost'], 0);
    final discount = roleCount(seat, 'mademoiselle');
    final discounted = max(1, base - discount);
    return isOtherTurn ? discounted + 1 : discounted;
  }

  bool canTakeCard(int seat, Map<String, dynamic> card, {required bool isOtherTurn}) {
    final t = asStr(card['type']);
    if (t == 'ship') {
      if (!isOtherTurn) return true;
      // Non-active player must pay 1 coin to active player; can pay from existing coins or the ship's own yield
      final yieldCoins = asInt(card['coins'], 0) + roleCount(seat, 'trader_${card['color']}');
      return coins[seat] + yieldCoins >= 1;
    }
    if (t == 'person') {
      final cost = effectiveHireCost(seat, card, isOtherTurn: isOtherTurn);
      return coins[seat] >= cost;
    }
    return false;
  }

  bool canClaimExpedition(int seat, Map<String, dynamic> exp) {
    final reqs = (exp['reqs'] as List).cast<String>();
    final counts = <String, int>{};
    for (final r in reqs) {
      counts[r] = (counts[r] ?? 0) + 1;
    }
    for (final entry in counts.entries) {
      if (roleCount(seat, entry.key) < entry.value) return false;
    }
    return true;
  }

  Map<String, dynamic>? _drawCard() {
    if (deck.isEmpty && discard.isNotEmpty) {
      deck.addAll(discard);
      discard.clear();
      deck.shuffle(rng);
    }
    if (deck.isEmpty) return null;
    return deck.removeLast();
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'discover') {
      if (seat != turn) throw GameError('当前不是你的探索回合');
      if (type == 'flip') {
        _doFlip();
        return;
      }
      if (type == 'stop') {
        if (harbor.isEmpty) throw GameError('港口内还没有牌，必须先翻牌');
        _startTradePhase();
        return;
      }
      throw GameError('未知探索操作');
    }

    if (phase == 'trade') {
      if (subPhase == 'active_trade') {
        if (seat != turn) throw GameError('等待当前回合船长贸易');
        if (type == 'claim_exp') {
          _doClaimExpedition(seat, asStr(action['id']));
          return;
        }
        if (type == 'take') {
          _doTakeFromHarbor(seat, action, isOtherTurn: false);
          return;
        }
        if (type == 'done' || type == 'pass') {
          _advanceFromActiveTrade();
          return;
        }
        throw GameError('未知贸易操作');
      }
      if (subPhase == 'other_trade') {
        if (seat != tradeSeat) throw GameError('还没轮到你进行顺风贸易');
        if (type == 'take') {
          _doTakeFromHarbor(seat, action, isOtherTurn: true);
          return;
        }
        if (type == 'pass' || type == 'done') {
          lastEvent = '${name(seat)} 放弃顺风贸易';
          _advanceOtherTrade();
          return;
        }
        throw GameError('未知顺风贸易操作');
      }
    }

    throw GameError('非法操作');
  }

  void _doFlip() {
    lastBust = null;
    while (true) {
      final card = _drawCard();
      if (card == null) {
        if (harbor.isEmpty) {
          _endTurn();
        } else {
          _startTradePhase();
        }
        return;
      }

      final cType = asStr(card['type']);
      if (cType == 'exp') {
        openExpeditions.add(card);
        lastEvent = '${name(turn)} 翻出远征任务【${card['name']}】，已置入远征区！';
        host.log(lastEvent);
        // Keep drawing until a non-exp/non-tax card enters harbor (or busts)
        if (deck.isEmpty && discard.isEmpty) {
          if (harbor.isNotEmpty) {
            _startTradePhase();
          } else {
            _endTurn();
          }
          return;
        }
        continue;
      }

      if (cType == 'tax') {
        _resolveTax(card);
        discard.add(card);
        if (deck.isEmpty && discard.isEmpty) {
          if (harbor.isNotEmpty) {
            _startTradePhase();
          } else {
            _endTurn();
          }
          return;
        }
        continue;
      }

      if (cType == 'ship') {
        final color = asStr(card['color']);
        final duplicate = harbor.any((c) => c['type'] == 'ship' && c['color'] == color);
        final swords = playerSwords(turn);
        final reqSwords = asInt(card['swords'], 99);

        if (duplicate) {
          if (swords >= reqSwords) {
            discard.add(card);
            lastEvent = '${name(turn)} 翻出重复的【${card['name']}】(武力$reqSwords)，凭借 $swords 点武力成功击退！';
            host.log(lastEvent);
            return;
          } else {
            // BUST!
            lastBust = {
              'seat': turn,
              'card': card,
            };
            discard.addAll(harbor);
            discard.add(card);
            harbor.clear();

            // Jester bonus for all players
            final jesterGains = <String>[];
            for (var s = 0; s < players; s++) {
              final j = roleCount(s, 'jester');
              if (j > 0) {
                coins[s] += j;
                jesterGains.add('${name(s)}+$j金');
              }
            }
            final jText = jesterGains.isEmpty ? '' : '（小丑触发：${jesterGains.join('、')}）';
            lastEvent = '${name(turn)} 翻出重复颜色的【${card['name']}】且武力不足($swords<$reqSwords)，爆港清空！$jText';
            host.log(lastEvent);
            _endTurn();
            return;
          }
        } else {
          harbor.add(card);
          lastEvent = '${name(turn)} 翻出【${card['name']}】（+${card['coins']}金，武力${card['skull'] == true ? '骷髅' : card['swords']}）';
          return;
        }
      }

      // Person card
      harbor.add(card);
      lastEvent = '${name(turn)} 翻出人物【${card['name']}】（雇佣费${card['cost']}金，${card['vp']}分）';
      return;
    }
  }

  void _resolveTax(Map<String, dynamic> card) {
    final notes = <String>[];
    for (var s = 0; s < players; s++) {
      if (coins[s] >= 12) {
        final lost = coins[s] ~/ 2;
        coins[s] -= lost;
        notes.add('${name(s)}金币过半(-$lost)');
      }
    }
    final mode = asStr(card['taxMode']);
    if (mode == 'max_swords') {
      final sw = [for (var s = 0; s < players; s++) playerSwords(s)];
      final maxSw = sw.reduce(max);
      if (maxSw > 0) {
        for (var s = 0; s < players; s++) {
          if (sw[s] == maxSw) {
            coins[s] += 1;
            notes.add('${name(s)}武力最高+1金');
          }
        }
      }
    } else {
      final minV = vp.reduce(min);
      for (var s = 0; s < players; s++) {
        if (vp[s] == minV) {
          coins[s] += 1;
          notes.add('${name(s)}分数最低+1金');
        }
      }
    }
    final detail = notes.isEmpty ? '无人受影响' : notes.join('，');
    lastEvent = '触发【${card['name']}】：$detail';
    host.log(lastEvent);
  }

  void _startTradePhase() {
    phase = 'trade';
    subPhase = 'active_trade';
    allowance = computeAllowance(turn);
    final adm = roleCount(turn, 'admiral');
    if (harbor.length >= 5 && adm > 0) {
      final bonus = adm * 2;
      coins[turn] += bonus;
      lastEvent = '${name(turn)} 停止翻牌进入贸易阶段（可拿 $allowance 张，海军上将奖励 +$bonus 金）';
      host.log(lastEvent);
    } else {
      lastEvent = '${name(turn)} 停止翻牌进入贸易阶段（可拿 $allowance 张）';
    }
    _checkAutoAdvanceActiveTrade();
  }

  void _doClaimExpedition(int seat, String expId) {
    final idx = openExpeditions.indexWhere((e) => e['id'] == expId);
    if (idx < 0) throw GameError('未找到该远征任务');
    final exp = openExpeditions[idx];
    if (!canClaimExpedition(seat, exp)) {
      throw GameError('你的船员图标不足以完成该远征任务');
    }
    openExpeditions.removeAt(idx);
    expeditions[seat].add(exp);
    final gainCoins = asInt(exp['coins'], 0);
    coins[seat] += gainCoins;
    _recalcVp();
    lastEvent = '${name(seat)} 完成了远征【${exp['name']}】，获得 ${exp['vp']} 分与 $gainCoins 金！';
    host.log(lastEvent);
    _checkAutoAdvanceActiveTrade();
  }

  void _doTakeFromHarbor(int seat, Map<String, dynamic> action, {required bool isOtherTurn}) {
    if (!isOtherTurn && allowance <= 0) {
      throw GameError('本回合拿牌次数已用完');
    }
    int idx = asInt(action['index'], -1);
    final cardId = asStr(action['id']);
    if (idx < 0 || idx >= harbor.length) {
      idx = harbor.indexWhere((c) => c['id'] == cardId);
    }
    if (idx < 0 || idx >= harbor.length) {
      throw GameError('无效的港口卡牌选择');
    }
    final card = harbor[idx];
    if (!canTakeCard(seat, card, isOtherTurn: isOtherTurn)) {
      throw GameError('金币不足，无法拿取该卡牌');
    }

    harbor.removeAt(idx);
    final cType = asStr(card['type']);
    if (cType == 'ship') {
      final color = asStr(card['color']);
      final yieldCoins = asInt(card['coins'], 0) + roleCount(seat, 'trader_$color');
      coins[seat] += yieldCoins;
      if (isOtherTurn) {
        coins[seat] -= 1;
        coins[turn] += 1;
        lastEvent = '${name(seat)} 顺风贸易拿取【${card['name']}】(+${yieldCoins - 1}净金，支付 ${name(turn)} 1金)';
      } else {
        lastEvent = '${name(seat)} 拿取【${card['name']}】获得 $yieldCoins 金';
      }
      discard.add(card);
    } else if (cType == 'person') {
      final cost = effectiveHireCost(seat, card, isOtherTurn: isOtherTurn);
      coins[seat] -= cost;
      if (isOtherTurn) {
        coins[turn] += 1;
      }
      crew[seat].add(card);
      _recalcVp();
      lastEvent = '${name(seat)} 花费 $cost 金雇佣了【${card['name']}】';
      host.log(lastEvent);
    }

    if (isOtherTurn) {
      _advanceOtherTrade();
    } else {
      allowance -= 1;
      _checkAutoAdvanceActiveTrade();
    }
  }

  void _checkAutoAdvanceActiveTrade() {
    final canClaimAny = openExpeditions.any((e) => canClaimExpedition(turn, e));
    final canTakeAny = allowance > 0 && harbor.any((c) => canTakeCard(turn, c, isOtherTurn: false));
    if (!canClaimAny && !canTakeAny) {
      _advanceFromActiveTrade();
    }
  }

  void _advanceFromActiveTrade() {
    if (harbor.isEmpty || players <= 1) {
      _endTurn();
      return;
    }
    subPhase = 'other_trade';
    tradeSeat = (turn + 1) % players;
    _prepareOtherTradeSeat();
  }

  void _advanceOtherTrade() {
    if (harbor.isEmpty) {
      _endTurn();
      return;
    }
    tradeSeat = (tradeSeat + 1) % players;
    if (tradeSeat == turn) {
      _endTurn();
      return;
    }
    _prepareOtherTradeSeat();
  }

  void _prepareOtherTradeSeat() {
    while (tradeSeat != turn) {
      // Admiral triggers if >=5 cards in harbor when a player's trade turn begins
      final adm = roleCount(tradeSeat, 'admiral');
      if (harbor.length >= 5 && adm > 0) {
        coins[tradeSeat] += adm * 2;
      }
      // Jester triggers if harbor is empty (already handled above)
      final hasPlayable = harbor.any((c) => canTakeCard(tradeSeat, c, isOtherTurn: true));
      if (hasPlayable) {
        return;
      }
      tradeSeat = (tradeSeat + 1) % players;
    }
    _endTurn();
  }

  void _endTurn() {
    if (harbor.isNotEmpty) {
      discard.addAll(harbor);
      harbor.clear();
    }
    _recalcVp();

    final nextTurn = (turn + 1) % players;
    final roundFinished = nextTurn == 0;
    if (roundFinished) {
      final reachedTarget = vp.any((v) => v >= targetVp);
      if (reachedTarget || round >= 25) {
        _over = true;
        phase = 'end';
        final p = placings!;
        final winners = [
          for (var s = 0; s < players; s++)
            if (p[s] == 1) '${name(s)}(${vp[s]}分/${coins[s]}金)',
        ];
        lastEvent = '游戏结束！获胜者：${winners.join('、')}';
        host.log(lastEvent);
        return;
      }
      round += 1;
    }

    turn = nextTurn;
    phase = 'discover';
    subPhase = 'flip';
    allowance = 0;
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'turn': turn,
      'phase': phase,
      'subPhase': subPhase,
      'tradeSeat': tradeSeat,
      'allowance': allowance,
      'targetVp': targetVp,
      'deckCount': deck.length,
      'discardCount': discard.length,
      'harbor': harbor,
      'openExpeditions': openExpeditions,
      'coins': coins,
      'vp': vp,
      'swords': [for (var s = 0; s < players; s++) playerSwords(s)],
      'crew': crew,
      'expeditions': expeditions,
      'distinctColors': distinctShipColorsInHarbor(),
      'lastEvent': lastEvent,
      'lastBust': lastBust,
      'over': _over,
      if (_over) 'placings': placings,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over) return null;
    if (phase == 'discover' && seat == turn) {
      if (harbor.isEmpty) return {'type': 'flip'};

      // Easy bot flips more recklessly or stops early
      if (botLevel == 0) {
        if (harbor.length >= 2 && rng.nextBool()) return {'type': 'stop'};
        return {'type': 'flip'};
      }

      // Check how many unprotected ship colors are in harbor
      final mySwords = playerSwords(seat);
      var riskyColors = 0;
      for (final c in harbor) {
        if (c['type'] == 'ship') {
          if (mySwords < 4) riskyColors++;
        }
      }
      final hasAffordableGoodPerson = harbor.any(
        (c) => c['type'] == 'person' && asInt(c['vp'], 0) >= 1 && canTakeCard(seat, c, isOtherTurn: false),
      );
      if (distinctShipColorsInHarbor() >= 4) return {'type': 'stop'};
      if (hasAffordableGoodPerson && riskyColors >= 1) return {'type': 'stop'};
      if (riskyColors >= 3) return {'type': 'stop'};
      if (harbor.length >= 4) return {'type': 'stop'};
      return {'type': 'flip'};
    }

    if (phase == 'trade') {
      final isOther = subPhase == 'other_trade';
      if (!isOther && seat == turn) {
        for (final exp in openExpeditions) {
          if (canClaimExpedition(seat, exp)) {
            return {'type': 'claim_exp', 'id': exp['id']};
          }
        }
      }
      if ((isOther && seat == tradeSeat) || (!isOther && seat == turn)) {
        if (!isOther && allowance <= 0) return {'type': 'done'};

        // Find best affordable person or ship
        var bestIdx = -1;
        var bestScore = -1;
        for (var i = 0; i < harbor.length; i++) {
          final c = harbor[i];
          if (!canTakeCard(seat, c, isOtherTurn: isOther)) continue;
          var score = 0;
          if (c['type'] == 'person') {
            final v = asInt(c['vp'], 0);
            final role = asStr(c['role']);
            score = v * 10 + 15;
            if (role == 'settler' || role == 'priest' || role == 'captain') {
              score += 8;
            } else if (role == 'sailor' || role == 'pirate' || role == 'governor' || role == 'admiral') {
              score += 6;
            }
          } else if (c['type'] == 'ship') {
            final color = asStr(c['color']);
            final gain = asInt(c['coins'], 0) + roleCount(seat, 'trader_$color') - (isOther ? 1 : 0);
            if (gain <= 0 && isOther) continue;
            score = gain * 4;
          }
          if (score > bestScore) {
            bestScore = score;
            bestIdx = i;
          }
        }
        if (bestIdx >= 0 && bestScore > 0) {
          return {'type': 'take', 'index': bestIdx, 'id': harbor[bestIdx]['id']};
        }
        return {'type': isOther ? 'pass' : 'done'};
      }
    }
    return null;
  }
}
