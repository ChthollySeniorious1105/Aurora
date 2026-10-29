import 'dart:math';

import '../../src/engine.dart';

/// 三国杀（2~5人标准身份局）
/// 身份：2人（主公 vs 反贼）、3人（主公、反贼、内奸）、4人（主公、忠臣、反贼、内奸）、5人（主公、忠臣、反贼×2、内奸）

class SgGeneral {
  final String id;
  final String name;
  final String kingdom; // 蜀 / 魏 / 吴 / 群
  final int maxHp;
  final String skillName;
  final String skillDesc;

  const SgGeneral(this.id, this.name, this.kingdom, this.maxHp, this.skillName, this.skillDesc);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kingdom': kingdom,
        'maxHp': maxHp,
        'skillName': skillName,
        'skillDesc': skillDesc,
      };
}

const List<SgGeneral> kSgGenerals = [
  SgGeneral('liubei', '刘备', '蜀', 4, '仁德', '出牌阶段可将手牌交给其他角色，本回合累计给出2张牌时回复1点体力'),
  SgGeneral('caocao', '曹操', '魏', 4, '奸雄', '受到伤害后，立即获得对你造成伤害的牌'),
  SgGeneral('sunquan', '孙权', '吴', 4, '制衡', '出牌阶段限一次，可弃置任意张手牌并摸等量的牌'),
  SgGeneral('guanyu', '关羽', '蜀', 4, '武圣', '可将任意红色手牌当【杀】使用或打出'),
  SgGeneral('zhangfei', '张飞', '蜀', 4, '咆哮', '出牌阶段使用【杀】无次数限制'),
  SgGeneral('zhaoyun', '赵云', '蜀', 4, '龙胆', '可将【杀】当【闪】、【闪】当【杀】使用或打出'),
  SgGeneral('zhugeliang', '诸葛亮', '蜀', 3, '观星/空城', '回合开始整理牌堆顶牌；无手牌时不能成为【杀】或【决斗】的目标'),
  SgGeneral('lvbu', '吕布', '群', 4, '无双', '使用的【杀】或【决斗】需要目标打出2张【闪】或【杀】抵消'),
  SgGeneral('diaochan', '貂蝉', '群', 3, '离间/闭月', '出牌阶段限一次弃1张牌令两名其他角色决斗；结束阶段摸1张牌'),
  SgGeneral('huangyueying', '黄月英', '蜀', 3, '集智', '每当使用一张非延时锦囊牌时，立即摸1张牌'),
  SgGeneral('ganning', '甘宁', '吴', 4, '奇袭', '可将任意黑色手牌当【过河拆桥】使用'),
  SgGeneral('guojia', '郭嘉', '魏', 3, '遗计', '每受到1点伤害，立即摸2张牌'),
];

SgGeneral sgGeneralById(String id) =>
    kSgGenerals.firstWhere((g) => g.id == id, orElse: () => kSgGenerals.first);

/// 卡牌编码格式：'kind:suit:rank'（例如 'sha:S:7', 'tao:H:3'），也兼容简写 'sha'
String sgKind(String card) {
  final idx = card.indexOf(':');
  return idx < 0 ? card : card.substring(0, idx);
}

String sgSuit(String card) {
  final parts = card.split(':');
  if (parts.length >= 2 && parts[1].isNotEmpty) return parts[1];
  // 简写卡牌默认花色
  return switch (parts[0]) {
    'tao' || 'shan' || 'wuzhong' || 'taoyuan' => 'H',
    'wanjian' => 'D',
    _ => 'S',
  };
}

int sgRank(String card) {
  final parts = card.split(':');
  if (parts.length >= 3) return int.tryParse(parts[2]) ?? 7;
  return 7;
}

bool sgIsRed(String card) {
  final s = sgSuit(card);
  return s == 'H' || s == 'D';
}

bool sgIsBlack(String card) {
  final s = sgSuit(card);
  return s == 'S' || s == 'C';
}

String sgSuitSymbol(String card) => switch (sgSuit(card)) {
      'S' => '♠',
      'H' => '♥',
      'D' => '♦',
      'C' => '♣',
      _ => '♠',
    };

String sgRankStr(int r) => switch (r) {
      1 => 'A',
      11 => 'J',
      12 => 'Q',
      13 => 'K',
      _ => '$r',
    };

String sgCardName(String card) => switch (sgKind(card)) {
      'sha' => '杀',
      'shan' => '闪',
      'tao' => '桃',
      'wuzhong' => '无中生有',
      'guohe' => '过河拆桥',
      'shunshou' => '顺手牵羊',
      'juedou' => '决斗',
      'nanman' => '南蛮入侵',
      'wanjian' => '万箭齐发',
      'taoyuan' => '桃园结义',
      'wuxie' => '无懈可击',
      'lebusishu' => '乐不思蜀',
      'zhuge' => '诸葛连弩',
      'qinggang' => '青釭剑',
      'zhangba' => '丈八蛇矛',
      'bagua' => '八卦阵',
      'minus_horse' => '赤兔(-1马)',
      'plus_horse' => '的卢(+1马)',
      _ => card,
    };

/// 卡牌类别：'basic' | 'scroll' | 'delay' | 'weapon' | 'armor' | 'minus_horse' | 'plus_horse'
String sgCategory(String card) => switch (sgKind(card)) {
      'sha' || 'shan' || 'tao' => 'basic',
      'wuzhong' ||
      'guohe' ||
      'shunshou' ||
      'juedou' ||
      'nanman' ||
      'wanjian' ||
      'taoyuan' ||
      'wuxie' =>
        'scroll',
      'lebusishu' => 'delay',
      'zhuge' || 'qinggang' || 'zhangba' => 'weapon',
      'bagua' => 'armor',
      'minus_horse' => 'minus_horse',
      'plus_horse' => 'plus_horse',
      _ => 'basic',
    };

int sgWeaponRange(String? weapon) => switch (weapon == null ? '' : sgKind(weapon)) {
      'zhuge' => 1,
      'qinggang' => 2,
      'zhangba' => 3,
      _ => 1,
    };

List<String> sgBuildDeck() {
  final d = <String>[];
  // 基本牌：杀(24张)、闪(12张)、桃(8张)
  for (final r in [5, 6, 7, 8, 9, 10, 11]) {
    d.add('sha:S:$r');
    d.add('sha:C:$r');
  }
  for (final r in [3, 4, 5, 6, 7]) {
    d.add('sha:D:$r');
  }
  for (final r in [8, 9, 10, 11, 12]) {
    d.add('sha:H:$r');
  }
  for (final r in [2, 3, 4, 5, 6, 7]) {
    d.add('shan:D:$r');
    d.add('shan:H:$r');
  }
  for (final r in [3, 4, 6, 7, 8, 9, 12]) {
    d.add('tao:H:$r');
  }
  d.add('tao:D:12');

  // 锦囊牌
  for (final r in [7, 8, 9, 11]) {
    d.add('wuzhong:H:$r');
  }
  d.addAll(['guohe:S:3', 'guohe:S:4', 'guohe:C:3', 'guohe:C:4', 'guohe:H:12']);
  d.addAll(['shunshou:S:3', 'shunshou:S:4', 'shunshou:D:3', 'shunshou:D:4']);
  d.addAll(['juedou:S:1', 'juedou:C:1', 'juedou:D:1']);
  d.addAll(['nanman:S:7', 'nanman:S:13', 'nanman:C:7']);
  d.addAll(['wanjian:H:1', 'wanjian:D:1']);
  d.add('taoyuan:H:1');
  d.addAll(['wuxie:S:11', 'wuxie:C:12', 'wuxie:D:12']);
  d.addAll(['lebusishu:S:6', 'lebusishu:C:6', 'lebusishu:H:6']);

  // 装备牌
  d.addAll(['zhuge:C:1', 'zhuge:D:1']);
  d.add('qinggang:S:6');
  d.add('zhangba:S:12');
  d.addAll(['bagua:S:2', 'bagua:C:2']);
  d.addAll(['minus_horse:H:5', 'minus_horse:S:13']);
  d.addAll(['plus_horse:H:13', 'plus_horse:C:5']);
  return d;
}

List<String> sgRolesForPlayers(int players) => switch (players) {
      2 => ['lord', 'rebel'],
      3 => ['lord', 'rebel', 'spy'],
      4 => ['lord', 'loyalist', 'rebel', 'spy'],
      _ => ['lord', 'loyalist', 'rebel', 'rebel', 'spy'],
    };

String sgRoleName(String role) => switch (role) {
      'lord' => '主公',
      'loyalist' => '忠臣',
      'rebel' => '反贼',
      'spy' => '内奸',
      _ => role,
    };

class SgEquip {
  String? weapon;
  String? armor;
  String? minusHorse;
  String? plusHorse;

  bool get isEmpty => weapon == null && armor == null && minusHorse == null && plusHorse == null;

  List<String> get all => [
        if (weapon != null) weapon!,
        if (armor != null) armor!,
        if (minusHorse != null) minusHorse!,
        if (plusHorse != null) plusHorse!,
      ];

  Map<String, dynamic> toJson() => {
        'weapon': weapon,
        'armor': armor,
        'minusHorse': minusHorse,
        'plusHorse': plusHorse,
      };
}

class SgPending {
  /// 'wuxie' | 'shan' | 'sha' | 'dying'
  String type;
  int source;
  int target;
  String card; // 触发该响应的牌
  String effect; // 'sha' | 'juedou' | 'nanman' | 'wanjian' | 'wuzhong' | 'guohe' | 'shunshou' | 'taoyuan' | 'lebusishu'
  int need; // 还需要几张闪/杀/桃
  List<int> queue; // 依次需要响应的座位（如无懈可击询问队列、AOE剩余目标队列、濒死求桃队列）
  int duelOther; // 决斗中的另一方
  int dyingSeat; // 濒死角色座位

  SgPending({
    required this.type,
    required this.source,
    required this.target,
    required this.card,
    required this.effect,
    this.need = 1,
    List<int>? queue,
    this.duelOther = -1,
    this.dyingSeat = -1,
  }) : queue = queue ?? [];

  Map<String, dynamic> toJson() => {
        'type': type,
        'source': source,
        'target': target,
        'card': card,
        'cardName': sgCardName(card),
        'effect': effect,
        'need': need,
        'queue': queue,
        'duelOther': duelOther,
        'dyingSeat': dyingSeat,
      };
}

class Sanguosha extends GameEngine {
  Sanguosha(super.setup);

  /// 'pick' | 'play' | 'discard' | 'over'
  String phase = 'play';
  int lordSeat = 0;
  late List<String> roles;
  late List<String> generals;
  late List<List<String>> generalChoices;
  late List<bool> picked;

  late List<int> hp;
  late List<int> maxHp;
  late List<bool> alive;
  late List<List<String>> hands;
  late List<SgEquip> equips;
  late List<List<String>> judges; // 判定区（如乐不思蜀）

  List<String> deck = [];
  List<String> discardPile = [];

  int turn = 0;
  int roundCount = 1;
  int shaUsed = 0;
  int rendeGiven = 0;
  bool rendeHealed = false;
  bool zhihengUsed = false;
  bool lijianUsed = false;

  SgPending? pending;
  SgPending? savedBeforeDying; // 濒死结算完后恢复的响应状态
  String? winnerRole; // 'lord' (主忠胜利) | 'rebel' (反贼胜利) | 'spy' (内奸胜利)
  List<int> winners = [];
  Map<String, dynamic>? result;
  final List<String> log = [];

  void _log(String s) {
    log.add(s);
    if (log.length > 18) log.removeAt(0);
    host.log(s);
  }

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => players == 2 && !isOver;

  @override
  void resign(int seat) {
    if (seat < 0 || seat >= players || isOver) throw GameError('无法认输');
    alive[seat] = false;
    hp[seat] = 0;
    _log('${name(seat)} 投降认输');
    _checkWinCondition();
  }

  @override
  List<int>? get placings => isOver ? rankWinners(players, winners) : null;

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    if (phase == 'pick') {
      return [for (var s = 0; s < players; s++) if (!picked[s]) s];
    }
    if (pending != null) {
      final p = pending!;
      if (p.type == 'wuxie' || p.type == 'dying') {
        return p.queue.isNotEmpty ? [p.queue.first] : [turn];
      }
      return [p.target];
    }
    return [turn];
  }

  @override
  void start() {
    final rolePool = sgRolesForPlayers(players);
    // 座位 0 固定为主公（或随机主公），其余身份随机分配
    final restRoles = shuffled(rolePool.sublist(1), rng);
    lordSeat = 0;
    roles = [
      for (var s = 0; s < players; s++) s == lordSeat ? 'lord' : restRoles[s - 1],
    ];

    final allGen = shuffled(kSgGenerals, rng);
    generalChoices = [
      for (var s = 0; s < players; s++)
        [
          for (var k = 0; k < 2; k++) allGen[(s * 2 + k) % allGen.length].id,
        ],
    ];
    generals = [for (var s = 0; s < players; s++) generalChoices[s].first];
    picked = List.filled(players, false);

    maxHp = List.filled(players, 4);
    hp = List.filled(players, 4);
    alive = List.filled(players, true);
    hands = List.generate(players, (_) => <String>[]);
    equips = List.generate(players, (_) => SgEquip());
    judges = List.generate(players, (_) => <String>[]);

    deck = shuffled(sgBuildDeck(), rng);
    discardPile = [];

    final pickOpt = setup.opt<bool>('pick', false);
    if (pickOpt) {
      phase = 'pick';
      _applyGeneralStats();
      _log('三国杀开始（$players 人局）：主公是 ${name(lordSeat)}，请选择武将');
    } else {
      picked = List.filled(players, true);
      _applyGeneralStats();
      _dealInitialHands();
      _startTurn(lordSeat, firstTurn: true);
    }
  }

  void _applyGeneralStats() {
    for (var s = 0; s < players; s++) {
      final g = sgGeneralById(generals[s]);
      final bonus = (s == lordSeat && players >= 4) ? 1 : 0;
      maxHp[s] = g.maxHp + bonus;
      hp[s] = maxHp[s];
    }
  }

  void _dealInitialHands() {
    for (var s = 0; s < players; s++) {
      hands[s] = _drawCards(4);
    }
  }

  List<String> _drawCards(int count) {
    final out = <String>[];
    for (var i = 0; i < count; i++) {
      if (deck.isEmpty) {
        if (discardPile.isEmpty) {
          deck = shuffled(sgBuildDeck(), rng);
        } else {
          deck = shuffled(discardPile, rng);
          discardPile.clear();
        }
      }
      out.add(deck.removeLast());
    }
    return out;
  }

  /// 计算 seat 到 target 的距离（考虑顺/逆时针存活玩家距离及 -1/+1 马）
  int distance(int from, int to) {
    if (from == to) return 0;
    final aliveSeats = [for (var s = 0; s < players; s++) if (alive[s]) s];
    final iFrom = aliveSeats.indexOf(from);
    final iTo = aliveSeats.indexOf(to);
    if (iFrom < 0 || iTo < 0) return 99;
    final m = aliveSeats.length;
    final cw = (iTo - iFrom + m) % m;
    final ccw = (iFrom - iTo + m) % m;
    var d = min(cw, ccw);
    if (equips[from].minusHorse != null) d -= 1;
    if (equips[to].plusHorse != null) d += 1;
    return max(1, d);
  }

  int attackRange(int seat) => sgWeaponRange(equips[seat].weapon);

  bool inAttackRange(int from, int to) => from != to && alive[to] && distance(from, to) <= attackRange(from);

  /// 诸葛亮【空城】：无手牌时不能成为【杀】或【决斗】的目标
  bool isKongcheng(int seat) => generals[seat] == 'zhugeliang' && hands[seat].isEmpty;

  bool canUseMoreSha(int seat) =>
      shaUsed == 0 ||
      generals[seat] == 'zhangfei' ||
      (equips[seat].weapon != null && sgKind(equips[seat].weapon!) == 'zhuge');

  int nextAlive(int from) {
    for (var i = 1; i <= players; i++) {
      final s = (from + i) % players;
      if (alive[s]) return s;
    }
    return from;
  }

  List<int> otherAliveFrom(int from) => [
        for (var i = 1; i < players; i++)
          if (alive[(from + i) % players]) (from + i) % players,
      ];

  void _startTurn(int seat, {bool firstTurn = false}) {
    if (isOver) return;
    turn = seat;
    shaUsed = 0;
    rendeGiven = 0;
    rendeHealed = false;
    zhihengUsed = false;
    lijianUsed = false;
    pending = null;
    savedBeforeDying = null;

    if (!firstTurn && seat == lordSeat) {
      roundCount++;
      // 疲弊机制：若战局超过 35 轮仍未分胜负，每轮全员流失1点体力加速决胜
      if (roundCount > 35) {
        _log('战局进入疲弊阶段，全员体力上限与体力 -1');
        for (var s = 0; s < players; s++) {
          if (!alive[s]) continue;
          hp[s]--;
          if (hp[s] <= 0) {
            alive[s] = false;
            _log('${name(s)} 力竭阵亡');
            if (_checkWinCondition()) return;
          }
        }
        if (!alive[seat]) {
          _startTurn(nextAlive(seat));
          return;
        }
      }
    }

    final genName = sgGeneralById(generals[seat]).name;
    _log('--- ${name(seat)}（$genName）的回合 ---');

    // 1. 诸葛亮【观星】
    if (generals[seat] == 'zhugeliang') {
      final peek = _drawCards(min(3, alive.where((x) => x).length));
      // 将红桃或好牌放回牌堆顶
      peek.sort((a, b) => (sgSuit(a) == 'H' ? 1 : 0) - (sgSuit(b) == 'H' ? 1 : 0));
      deck.addAll(peek);
      _log('${name(seat)} 发动【观星】审视了星象');
    }

    // 2. 判定阶段（乐不思蜀）
    var skipPlay = false;
    while (judges[seat].isNotEmpty) {
      final jCard = judges[seat].removeLast();
      discardPile.add(jCard);
      if (sgKind(jCard) == 'lebusishu') {
        final flip = _drawCards(1).first;
        discardPile.add(flip);
        final isHeart = sgSuit(flip) == 'H';
        _log('${name(seat)}【乐不思蜀】判定牌为 ${sgSuitSymbol(flip)}${sgCardName(flip)}：${isHeart ? '红桃，判定失效！' : '非红桃，跳过出牌阶段！'}');
        if (!isHeart) skipPlay = true;
      }
    }

    // 3. 摸牌阶段
    final drawn = _drawCards(2);
    hands[seat].addAll(drawn);
    _log('${name(seat)} 摸了 2 张牌');

    // 4. 出牌阶段或直接进入弃牌阶段
    if (skipPlay) {
      _enterDiscardOrEnd();
    } else {
      phase = 'play';
    }
  }

  void _enterDiscardOrEnd() {
    if (isOver) return;
    final limit = max(0, hp[turn]);
    if (hands[turn].length > limit) {
      phase = 'discard';
    } else {
      _finishTurn();
    }
  }

  void _finishTurn() {
    if (isOver) return;
    // 貂蝉【闭月】：结束阶段摸 1 张牌
    if (generals[turn] == 'diaochan' && alive[turn]) {
      hands[turn].addAll(_drawCards(1));
      _log('${name(turn)} 发动【闭月】摸了 1 张牌');
    }
    _startTurn(nextAlive(turn));
  }

  String _takeCardFromHand(int seat, String req) {
    final h = hands[seat];
    // 1. 精确匹配
    if (h.remove(req)) {
      discardPile.add(req);
      return req;
    }
    // 2. 按 kind 匹配（方便测试直接传 'sha' / 'shan' / 'tao' 等）
    final k = sgKind(req);
    final idx = h.indexWhere((c) => sgKind(c) == k);
    if (idx >= 0) {
      final c = h.removeAt(idx);
      discardPile.add(c);
      return c;
    }
    throw GameError('手牌中没有 $req');
  }

  bool _canPlayAsSha(int seat, String card) {
    final k = sgKind(card);
    if (k == 'sha') return true;
    if (generals[seat] == 'guanyu' && sgIsRed(card)) return true;
    if (generals[seat] == 'zhaoyun' && k == 'shan') return true;
    return false;
  }

  bool _canPlayAsShan(int seat, String card) {
    final k = sgKind(card);
    if (k == 'shan') return true;
    if (generals[seat] == 'zhaoyun' && k == 'sha') return true;
    return false;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (seat < 0 || seat >= players) throw GameError('无效座位');
    if (isOver) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'pick') {
      if (picked[seat]) throw GameError('已选过武将');
      final gId = asStr(action['general'], generalChoices[seat].first);
      if (!kSgGenerals.any((g) => g.id == gId)) throw GameError('未知武将');
      generals[seat] = gId;
      picked[seat] = true;
      _log('${name(seat)} 选择了武将【${sgGeneralById(gId).name}】');
      if (picked.every((x) => x)) {
        _applyGeneralStats();
        _dealInitialHands();
        _startTurn(lordSeat, firstTurn: true);
      }
      return;
    }

    if (pending != null) {
      _handlePending(seat, action);
      return;
    }

    if (phase == 'discard') {
      if (seat != turn) throw GameError('还没轮到你弃牌');
      final need = hands[seat].length - max(0, hp[seat]);
      if (need <= 0) {
        _finishTurn();
        return;
      }
      final raw = action['cards'];
      if (raw is! List || raw.length != need) {
        throw GameError('需要弃置 $need 张手牌');
      }
      final copy = List<String>.of(hands[seat]);
      final toDiscard = <String>[];
      for (final x in raw) {
        final s = '$x';
        var i = copy.indexOf(s);
        if (i < 0) i = copy.indexWhere((c) => sgKind(c) == sgKind(s));
        if (i < 0) throw GameError('手牌中没有 $s');
        toDiscard.add(copy.removeAt(i));
      }
      hands[seat] = copy;
      discardPile.addAll(toDiscard);
      _log('${name(seat)} 弃置了 ${toDiscard.length} 张牌');
      _finishTurn();
      return;
    }

    if (phase == 'play') {
      if (seat != turn) throw GameError('还没轮到你出牌');
      if (type == 'endPlay' || type == 'pass') {
        _enterDiscardOrEnd();
        return;
      }
      if (type == 'skill') {
        _handleSkill(seat, action);
        return;
      }
      if (type == 'play') {
        _handlePlayCard(seat, action);
        return;
      }
      throw GameError('未知操作类型: $type');
    }
  }

  void _handleSkill(int seat, Map<String, dynamic> a) {
    final skill = asStr(a['skill']);
    final gen = generals[seat];

    // 1. 刘备【仁德】
    if (skill == 'rende') {
      if (gen != 'liubei') throw GameError('只有刘备可以使用【仁德】');
      final target = asInt(a['target']);
      if (target < 0 || target >= players || target == seat || !alive[target]) {
        throw GameError('请选择一名其他存活角色');
      }
      final raw = a['cards'];
      final list = raw is List ? [for (final x in raw) '$x'] : (a['card'] != null ? ['${a['card']}'] : <String>[]);
      if (list.isEmpty) throw GameError('请选择要给出的手牌');
      final given = <String>[];
      for (final req in list) {
        final idx = hands[seat].indexWhere((c) => c == req || sgKind(c) == sgKind(req));
        if (idx < 0) throw GameError('手牌中没有 $req');
        given.add(hands[seat].removeAt(idx));
      }
      hands[target].addAll(given);
      rendeGiven += given.length;
      _log('${name(seat)} 发动【仁德】将 ${given.length} 张手牌交给 ${name(target)}');
      if (rendeGiven >= 2 && !rendeHealed && hp[seat] < maxHp[seat]) {
        rendeHealed = true;
        hp[seat]++;
        _log('${name(seat)} 因【仁德】回复 1 点体力（${hp[seat]}/${maxHp[seat]}）');
      }
      return;
    }

    // 2. 孙权【制衡】
    if (skill == 'zhiheng') {
      if (gen != 'sunquan') throw GameError('只有孙权可以使用【制衡】');
      if (zhihengUsed) throw GameError('【制衡】每回合限用一次');
      final raw = a['cards'];
      final list = raw is List ? [for (final x in raw) '$x'] : (a['card'] != null ? ['${a['card']}'] : <String>[]);
      if (list.isEmpty) throw GameError('请选择要制衡的手牌');
      for (final req in list) {
        _takeCardFromHand(seat, req);
      }
      zhihengUsed = true;
      final drawn = _drawCards(list.length);
      hands[seat].addAll(drawn);
      _log('${name(seat)} 发动【制衡】换了 ${list.length} 张牌');
      return;
    }

    // 3. 貂蝉【离间】
    if (skill == 'lijian') {
      if (gen != 'diaochan') throw GameError('只有貂蝉可以使用【离间】');
      if (lijianUsed) throw GameError('【离间】每回合限用一次');
      final targets = asIntList(a['targets']);
      if (targets.length < 2) throw GameError('请选择两名其他存活角色');
      final t1 = targets[0], t2 = targets[1];
      if (t1 == t2 || t1 == seat || t2 == seat || !alive[t1] || !alive[t2]) {
        throw GameError('离间目标不合法');
      }
      if (isKongcheng(t1) || isKongcheng(t2)) throw GameError('空城的诸葛亮不能成为决斗目标');
      final cardReq = asStr(a['card'], hands[seat].isNotEmpty ? hands[seat].first : '');
      final used = _takeCardFromHand(seat, cardReq);
      lijianUsed = true;
      _log('${name(seat)} 弃置 ${sgCardName(used)} 发动【离间】，令 ${name(t1)} 对 ${name(t2)} 决斗！');
      _startDuel(t1, t2, 'juedou:S:1');
      return;
    }

    // 4. 关羽【武圣】或赵云【龙胆】转化出【杀】
    if (skill == 'wusheng' || skill == 'longdan') {
      final cardReq = asStr(a['card']);
      final target = asInt(a['target']);
      _handlePlayCard(seat, {'type': 'play', 'card': cardReq, 'as': 'sha', 'target': target});
      return;
    }

    // 5. 甘宁【奇袭】黑色牌当【过河拆桥】
    if (skill == 'qixi') {
      if (gen != 'ganning') throw GameError('只有甘宁可以使用【奇袭】');
      final cardReq = asStr(a['card']);
      final target = asInt(a['target']);
      final idx = hands[seat].indexWhere((c) => c == cardReq || (sgKind(c) == sgKind(cardReq) && sgIsBlack(c)));
      if (idx < 0 || !sgIsBlack(hands[seat][idx])) throw GameError('【奇袭】需要一张黑色手牌');
      final used = hands[seat].removeAt(idx);
      discardPile.add(used);
      _resolveGuohe(seat, target, used);
      return;
    }

    // 6. 丈八蛇矛：两张手牌当【杀】使用
    if (skill == 'zhangba') {
      if (equips[seat].weapon == null || sgKind(equips[seat].weapon!) != 'zhangba') {
        throw GameError('未装备丈八蛇矛');
      }
      final raw = a['cards'];
      if (raw is! List || raw.length != 2) throw GameError('丈八蛇矛需要选择 2 张手牌');
      final target = asInt(a['target']);
      if (target < 0 || target >= players || !inAttackRange(seat, target)) {
        throw GameError('目标不在攻击范围内');
      }
      if (!canUseMoreSha(seat)) throw GameError('本回合已使用过【杀】');
      if (isKongcheng(target)) throw GameError('诸葛亮处于【空城】状态，不能成为【杀】的目标');
      final c1 = _takeCardFromHand(seat, '${raw[0]}');
      final c2 = _takeCardFromHand(seat, '${raw[1]}');
      shaUsed++;
      _log('${name(seat)} 发动【丈八蛇矛】（${sgCardName(c1)}+${sgCardName(c2)}）对 ${name(target)} 出【杀】');
      _initiateSha(seat, target, 'sha:S:7');
      return;
    }

    throw GameError('未知技能: $skill');
  }

  void _handlePlayCard(int seat, Map<String, dynamic> a) {
    final req = asStr(a['card']);
    final asKind = asStr(a['as']);
    final target = asInt(a['target']);

    final h = hands[seat];
    var idx = h.indexOf(req);
    if (idx < 0) idx = h.indexWhere((c) => sgKind(c) == sgKind(req));
    if (idx < 0) throw GameError('手牌中没有 $req');
    final card = h[idx];
    final effectiveKind = asKind.isNotEmpty ? asKind : sgKind(card);

    // 校验转化合法性
    if (asKind == 'sha') {
      if (!_canPlayAsSha(seat, card)) throw GameError('该牌不能当【杀】使用');
    } else if (asKind == 'guohe') {
      if (!(generals[seat] == 'ganning' && sgIsBlack(card))) throw GameError('只有甘宁可将黑色牌当【过河拆桥】');
    }

    // 装备牌
    final cat = asKind.isEmpty ? sgCategory(card) : sgCategory(effectiveKind);
    if (cat == 'weapon' || cat == 'armor' || cat == 'minus_horse' || cat == 'plus_horse') {
      h.removeAt(idx);
      final eq = equips[seat];
      if (cat == 'weapon') {
        if (eq.weapon != null) discardPile.add(eq.weapon!);
        eq.weapon = card;
      } else if (cat == 'armor') {
        if (eq.armor != null) discardPile.add(eq.armor!);
        eq.armor = card;
      } else if (cat == 'minus_horse') {
        if (eq.minusHorse != null) discardPile.add(eq.minusHorse!);
        eq.minusHorse = card;
      } else if (cat == 'plus_horse') {
        if (eq.plusHorse != null) discardPile.add(eq.plusHorse!);
        eq.plusHorse = card;
      }
      _log('${name(seat)} 装备了【${sgCardName(card)}】');
      return;
    }

    switch (effectiveKind) {
      case 'sha':
        if (target < 0 || target >= players || !inAttackRange(seat, target)) {
          throw GameError('请选择攻击范围内的合法目标');
        }
        if (!canUseMoreSha(seat)) throw GameError('本回合使用【杀】次数已达上限');
        if (isKongcheng(target)) throw GameError('诸葛亮【空城】不能成为【杀】的目标');
        h.removeAt(idx);
        discardPile.add(card);
        shaUsed++;
        _log('${name(seat)} 对 ${name(target)} 使用了【杀】');
        _initiateSha(seat, target, card);
        return;

      case 'tao':
        if (hp[seat] >= maxHp[seat]) throw GameError('体力已满，无需使用【桃】');
        h.removeAt(idx);
        discardPile.add(card);
        hp[seat]++;
        _log('${name(seat)} 使用【桃】回复 1 点体力（${hp[seat]}/${maxHp[seat]}）');
        return;

      case 'wuzhong':
        h.removeAt(idx);
        discardPile.add(card);
        _triggerJizhi(seat);
        _log('${name(seat)} 使用了【无中生有】');
        if (_openWuxieIfAny(seat, seat, card, 'wuzhong')) return;
        _resolveWuzhong(seat);
        return;

      case 'guohe':
        if (target < 0 || target >= players || target == seat || !alive[target] || !_hasAnyCard(target)) {
          throw GameError('请选择一名有牌的其他角色');
        }
        h.removeAt(idx);
        discardPile.add(card);
        _triggerJizhi(seat);
        _resolveGuohe(seat, target, card);
        return;

      case 'shunshou':
        if (target < 0 || target >= players || target == seat || !alive[target] || !_hasAnyCard(target)) {
          throw GameError('请选择一名有牌的其他角色');
        }
        if (distance(seat, target) > 1) throw GameError('【顺手牵羊】只能对距离为 1 的角色使用');
        h.removeAt(idx);
        discardPile.add(card);
        _triggerJizhi(seat);
        _log('${name(seat)} 对 ${name(target)} 使用了【顺手牵羊】');
        if (_openWuxieIfAny(seat, target, card, 'shunshou')) return;
        _resolveShunshou(seat, target);
        return;

      case 'juedou':
        if (target < 0 || target >= players || target == seat || !alive[target]) {
          throw GameError('请选择一名其他存活角色');
        }
        if (isKongcheng(target)) throw GameError('诸葛亮【空城】不能成为【决斗】的目标');
        h.removeAt(idx);
        discardPile.add(card);
        _triggerJizhi(seat);
        _log('${name(seat)} 对 ${name(target)} 使用了【决斗】');
        if (_openWuxieIfAny(seat, target, card, 'juedou')) return;
        _startDuel(seat, target, card);
        return;

      case 'nanman':
        h.removeAt(idx);
        discardPile.add(card);
        _triggerJizhi(seat);
        final q = otherAliveFrom(seat);
        _log('${name(seat)} 使用了【南蛮入侵】！');
        if (q.isEmpty) return;
        pending = SgPending(
          type: 'sha',
          source: seat,
          target: q.first,
          card: card,
          effect: 'nanman',
          queue: q,
        );
        return;

      case 'wanjian':
        h.removeAt(idx);
        discardPile.add(card);
        _triggerJizhi(seat);
        final q = otherAliveFrom(seat);
        _log('${name(seat)} 使用了【万箭齐发】！');
        if (q.isEmpty) return;
        _startWanjianQueue(seat, card, q);
        return;

      case 'taoyuan':
        h.removeAt(idx);
        discardPile.add(card);
        _triggerJizhi(seat);
        _log('${name(seat)} 使用了【桃园结义】');
        for (var i = 0; i < players; i++) {
          final s = (seat + i) % players;
          if (alive[s] && hp[s] < maxHp[s]) {
            hp[s]++;
            _log('${name(s)} 回复 1 点体力（${hp[s]}/${maxHp[s]}）');
          }
        }
        return;

      case 'lebusishu':
        if (target < 0 || target >= players || target == seat || !alive[target]) {
          throw GameError('请选择一名其他存活角色');
        }
        if (judges[target].any((c) => sgKind(c) == 'lebusishu')) {
          throw GameError('目标判定区已有【乐不思蜀】');
        }
        h.removeAt(idx);
        judges[target].add(card);
        _log('${name(seat)} 对 ${name(target)} 使用了【乐不思蜀】');
        return;

      default:
        throw GameError('该牌不能在出牌阶段主动使用');
    }
  }

  void _triggerJizhi(int seat) {
    if (generals[seat] == 'huangyueying' && alive[seat]) {
      hands[seat].addAll(_drawCards(1));
      _log('${name(seat)} 发动【集智】摸了 1 张牌');
    }
  }

  bool _hasAnyCard(int seat) =>
      hands[seat].isNotEmpty || !equips[seat].isEmpty || judges[seat].isNotEmpty;

  /// 若场上有任何存活角色手握【无懈可击】，开启无懈可击询问窗口
  bool _openWuxieIfAny(int source, int target, String card, String effect) {
    final holders = <int>[
      for (var i = 0; i < players; i++)
        if (alive[(source + i) % players] &&
            hands[(source + i) % players].any((c) => sgKind(c) == 'wuxie'))
          (source + i) % players,
    ];
    if (holders.isEmpty) return false;
    pending = SgPending(
      type: 'wuxie',
      source: source,
      target: target,
      card: card,
      effect: effect,
      queue: holders,
    );
    return true;
  }

  void _resolveWuzhong(int seat) {
    hands[seat].addAll(_drawCards(2));
    _log('${name(seat)}【无中生有】摸了 2 张牌');
  }

  void _resolveGuohe(int seat, int target, String card) {
    _log('${name(seat)} 对 ${name(target)} 使用了【过河拆桥】');
    if (_openWuxieIfAny(seat, target, card, 'guohe')) return;
    _doGuoheEffect(seat, target);
  }

  void _doGuoheEffect(int seat, int target) {
    // 优先拆装备或判定区，否则随机拆一张手牌
    final eq = equips[target];
    String? removed;
    if (judges[target].isNotEmpty && _isFriend(seat, target)) {
      removed = judges[target].removeLast();
    } else if (eq.plusHorse != null && !_isFriend(seat, target)) {
      removed = eq.plusHorse;
      eq.plusHorse = null;
    } else if (eq.armor != null && !_isFriend(seat, target)) {
      removed = eq.armor;
      eq.armor = null;
    } else if (eq.weapon != null && !_isFriend(seat, target)) {
      removed = eq.weapon;
      eq.weapon = null;
    } else if (hands[target].isNotEmpty) {
      removed = hands[target].removeAt(rng.nextInt(hands[target].length));
    } else if (eq.all.isNotEmpty) {
      if (eq.weapon != null) {
        removed = eq.weapon;
        eq.weapon = null;
      } else if (eq.armor != null) {
        removed = eq.armor;
        eq.armor = null;
      } else if (eq.minusHorse != null) {
        removed = eq.minusHorse;
        eq.minusHorse = null;
      } else if (eq.plusHorse != null) {
        removed = eq.plusHorse;
        eq.plusHorse = null;
      }
    } else if (judges[target].isNotEmpty) {
      removed = judges[target].removeLast();
    }
    if (removed != null) {
      discardPile.add(removed);
      _log('${name(seat)} 拆掉了 ${name(target)} 的【${sgCardName(removed)}】');
    }
  }

  void _resolveShunshou(int seat, int target) {
    final eq = equips[target];
    String? stolen;
    if (judges[target].isNotEmpty && _isFriend(seat, target)) {
      stolen = judges[target].removeLast();
    } else if (eq.plusHorse != null && !_isFriend(seat, target)) {
      stolen = eq.plusHorse;
      eq.plusHorse = null;
    } else if (eq.armor != null && !_isFriend(seat, target)) {
      stolen = eq.armor;
      eq.armor = null;
    } else if (hands[target].isNotEmpty) {
      stolen = hands[target].removeAt(rng.nextInt(hands[target].length));
    } else if (eq.weapon != null) {
      stolen = eq.weapon;
      eq.weapon = null;
    } else if (eq.minusHorse != null) {
      stolen = eq.minusHorse;
      eq.minusHorse = null;
    } else if (judges[target].isNotEmpty) {
      stolen = judges[target].removeLast();
    }
    if (stolen != null) {
      hands[seat].add(stolen);
      _log('${name(seat)} 顺手牵羊获得了 ${name(target)} 的 1 张牌');
    }
  }

  void _initiateSha(int source, int target, String card) {
    var need = generals[source] == 'lvbu' ? 2 : 1;
    // 检查八卦阵（青釭剑无视防具）
    final ignoreArmor = equips[source].weapon != null && sgKind(equips[source].weapon!) == 'qinggang';
    if (!ignoreArmor && equips[target].armor != null && sgKind(equips[target].armor!) == 'bagua') {
      final flip = _drawCards(1).first;
      discardPile.add(flip);
      if (sgIsRed(flip)) {
        need--;
        _log('${name(target)}【八卦阵】判定为红色（${sgSuitSymbol(flip)}），视为打出 1 张【闪】！');
        if (need <= 0) return;
      } else {
        _log('${name(target)}【八卦阵】判定为黑色（${sgSuitSymbol(flip)}），未生效');
      }
    }
    pending = SgPending(
      type: 'shan',
      source: source,
      target: target,
      card: card,
      effect: 'sha',
      need: need,
    );
  }

  void _startWanjianQueue(int source, String card, List<int> q) {
    while (q.isNotEmpty) {
      final t = q.first;
      if (equips[t].armor != null && sgKind(equips[t].armor!) == 'bagua') {
        final flip = _drawCards(1).first;
        discardPile.add(flip);
        if (sgIsRed(flip)) {
          _log('${name(t)}【八卦阵】判定为红色，自动抵消【万箭齐发】！');
          q.removeAt(0);
          continue;
        }
      }
      pending = SgPending(
        type: 'shan',
        source: source,
        target: t,
        card: card,
        effect: 'wanjian',
        queue: q,
      );
      return;
    }
    pending = null;
  }

  void _startDuel(int initiator, int responder, String card) {
    final need = generals[initiator] == 'lvbu' ? 2 : 1;
    pending = SgPending(
      type: 'sha',
      source: initiator,
      target: responder,
      card: card,
      effect: 'juedou',
      need: need,
      duelOther: initiator,
    );
  }

  void _handlePending(int seat, Map<String, dynamic> a) {
    final p = pending!;
    final type = asStr(a['type']);

    // 1. 无懈可击窗口
    if (p.type == 'wuxie') {
      if (p.queue.isEmpty || seat != p.queue.first) throw GameError('当前未轮到你响应无懈可击');
      if (type == 'pass') {
        p.queue.removeAt(0);
        if (p.queue.isEmpty) {
          pending = null;
          _resumeAfterWuxieNotUsed(p);
        }
        return;
      }
      if (type == 'wuxie' || type == 'play') {
        final req = asStr(a['card'], 'wuxie');
        final used = _takeCardFromHand(seat, req);
        if (sgKind(used) != 'wuxie') throw GameError('必须打出【无懈可击】');
        _triggerJizhi(seat);
        _log('${name(seat)} 打出【无懈可击】，抵消了【${sgCardName(p.card)}】的效果！');
        pending = null;
        return;
      }
      throw GameError('请打出无懈可击或跳过');
    }

    // 2. 濒死求桃窗口
    if (p.type == 'dying') {
      if (p.queue.isEmpty || seat != p.queue.first) throw GameError('当前未轮到你响应求桃');
      if (type == 'pass') {
        p.queue.removeAt(0);
        if (p.queue.isEmpty) {
          _resolveDeath(p.dyingSeat, p.source, p.card);
        }
        return;
      }
      if (type == 'tao' || type == 'play') {
        final req = asStr(a['card'], 'tao');
        final used = _takeCardFromHand(seat, req);
        if (sgKind(used) != 'tao') throw GameError('濒死救援必须使用【桃】');
        hp[p.dyingSeat]++;
        p.need--;
        _log('${name(seat)} 对 ${name(p.dyingSeat)} 使用【桃】，体力恢复至 ${hp[p.dyingSeat]}');
        if (hp[p.dyingSeat] >= 1) {
          final victim = p.dyingSeat;
          final src = p.source;
          final dmgCard = p.card;
          pending = savedBeforeDying;
          savedBeforeDying = null;
          _onPostDamageAlive(victim, src, dmgCard, 1);
          _advanceSavedPending();
        }
        return;
      }
      throw GameError('请使用【桃】或跳过');
    }

    // 3. 响应【闪】（杀 / 万箭齐发）
    if (p.type == 'shan') {
      if (seat != p.target) throw GameError('等待 ${name(p.target)} 响应【闪】');
      if (type == 'pass') {
        if (p.effect == 'sha') {
          pending = null;
          _dealDamage(p.source, p.target, 1, p.card);
        } else if (p.effect == 'wanjian') {
          p.queue.removeAt(0);
          final nextQ = List<int>.of(p.queue);
          pending = null;
          _dealDamage(p.source, seat, 1, p.card, afterDamage: () {
            if (!isOver && nextQ.isNotEmpty) {
              _startWanjianQueue(p.source, p.card, nextQ.where((s) => alive[s]).toList());
            }
          });
        }
        return;
      }
      if (type == 'shan' || type == 'play') {
        final req = asStr(a['card'], 'shan');
        final idx = hands[seat].indexWhere((c) => (c == req || sgKind(c) == sgKind(req)) && _canPlayAsShan(seat, c));
        if (idx < 0) throw GameError('没有可用的【闪】');
        final used = hands[seat].removeAt(idx);
        discardPile.add(used);
        p.need--;
        _log('${name(seat)} 打出了【闪】');
        if (p.need <= 0) {
          if (p.effect == 'sha') {
            pending = null;
          } else if (p.effect == 'wanjian') {
            p.queue.removeAt(0);
            final nextQ = p.queue.where((s) => alive[s]).toList();
            pending = null;
            if (nextQ.isNotEmpty) {
              _startWanjianQueue(p.source, p.card, nextQ);
            }
          }
        }
        return;
      }
      throw GameError('请打出【闪】或放弃');
    }

    // 4. 响应【杀】（南蛮入侵 / 决斗）
    if (p.type == 'sha') {
      if (seat != p.target) throw GameError('等待 ${name(p.target)} 响应【杀】');
      if (type == 'pass') {
        if (p.effect == 'juedou') {
          pending = null;
          _dealDamage(p.duelOther, seat, 1, p.card);
        } else if (p.effect == 'nanman') {
          p.queue.removeAt(0);
          final nextQ = List<int>.of(p.queue);
          pending = null;
          _dealDamage(p.source, seat, 1, p.card, afterDamage: () {
            final rem = nextQ.where((s) => alive[s]).toList();
            if (!isOver && rem.isNotEmpty) {
              pending = SgPending(
                type: 'sha',
                source: p.source,
                target: rem.first,
                card: p.card,
                effect: 'nanman',
                queue: rem,
              );
            }
          });
        }
        return;
      }
      if (type == 'sha' || type == 'play') {
        final req = asStr(a['card'], 'sha');
        final idx = hands[seat].indexWhere((c) => (c == req || sgKind(c) == sgKind(req)) && _canPlayAsSha(seat, c));
        if (idx < 0) throw GameError('没有可用的【杀】');
        final used = hands[seat].removeAt(idx);
        discardPile.add(used);
        p.need--;
        _log('${name(seat)} 打出了【杀】');
        if (p.need <= 0) {
          if (p.effect == 'juedou') {
            final nextTarget = p.duelOther;
            final nextOther = seat;
            p.target = nextTarget;
            p.duelOther = nextOther;
            p.need = generals[nextOther] == 'lvbu' ? 2 : 1;
          } else if (p.effect == 'nanman') {
            p.queue.removeAt(0);
            final rem = p.queue.where((s) => alive[s]).toList();
            if (rem.isEmpty) {
              pending = null;
            } else {
              p.target = rem.first;
              p.queue = rem;
              p.need = 1;
            }
          }
        }
        return;
      }
      throw GameError('请打出【杀】或放弃');
    }
  }

  void _resumeAfterWuxieNotUsed(SgPending p) {
    switch (p.effect) {
      case 'wuzhong':
        _resolveWuzhong(p.source);
        break;
      case 'guohe':
        _doGuoheEffect(p.source, p.target);
        break;
      case 'shunshou':
        _resolveShunshou(p.source, p.target);
        break;
      case 'juedou':
        _startDuel(p.source, p.target, p.card);
        break;
    }
  }

  void Function()? _postDyingCallback;

  void _dealDamage(int source, int victim, int dmg, String card, {void Function()? afterDamage}) {
    hp[victim] -= dmg;
    _log('${name(victim)} 受到来自 ${name(source)} 的 $dmg 点伤害（体力 ${hp[victim]}/${maxHp[victim]}）');
    if (hp[victim] <= 0) {
      savedBeforeDying = pending;
      _postDyingCallback = afterDamage;
      final savers = <int>[
        for (var i = 0; i < players; i++)
          if (alive[(turn + i) % players]) (turn + i) % players,
      ];
      _log('${name(victim)} 进入濒死状态（需要 ${1 - hp[victim]} 个【桃】）！');
      pending = SgPending(
        type: 'dying',
        source: source,
        target: savers.first,
        card: card,
        effect: 'dying',
        need: 1 - hp[victim],
        queue: savers,
        dyingSeat: victim,
      );
      return;
    }
    _onPostDamageAlive(victim, source, card, dmg);
    afterDamage?.call();
  }

  void _onPostDamageAlive(int victim, int source, String card, int dmg) {
    if (!alive[victim] || isOver) return;
    // 曹操【奸雄】：获得造成伤害的牌
    if (generals[victim] == 'caocao' && card.isNotEmpty) {
      discardPile.remove(card);
      hands[victim].add(card);
      _log('${name(victim)} 发动【奸雄】，获得了伤害牌【${sgCardName(card)}】');
    }
    // 郭嘉【遗计】：每受到1点伤害摸2张牌
    if (generals[victim] == 'guojia') {
      final drawn = _drawCards(2 * dmg);
      hands[victim].addAll(drawn);
      _log('${name(victim)} 发动【遗计】，摸了 ${drawn.length} 张牌');
    }
  }

  void _advanceSavedPending() {
    final cb = _postDyingCallback;
    _postDyingCallback = null;
    cb?.call();
  }

  void _resolveDeath(int victim, int killer, String card) {
    alive[victim] = false;
    discardPile.addAll(hands[victim]);
    hands[victim].clear();
    discardPile.addAll(equips[victim].all);
    equips[victim] = SgEquip();
    discardPile.addAll(judges[victim]);
    judges[victim].clear();
    pending = savedBeforeDying;
    savedBeforeDying = null;

    _log('${name(victim)} 阵亡！身份是【${sgRoleName(roles[victim])}】');

    if (_checkWinCondition()) return;

    // 奖惩规则：杀死反贼摸3张牌；主公误杀忠臣弃光所有手牌与装备
    if (killer >= 0 && killer < players && killer != victim && alive[killer]) {
      if (roles[victim] == 'rebel') {
        hands[killer].addAll(_drawCards(3));
        _log('${name(killer)} 击杀反贼，奖励摸 3 张牌！');
      } else if (roles[killer] == 'lord' && roles[victim] == 'loyalist') {
        discardPile.addAll(hands[killer]);
        hands[killer].clear();
        discardPile.addAll(equips[killer].all);
        equips[killer] = SgEquip();
        _log('主公 ${name(killer)} 误杀忠臣，弃置全部手牌和装备！');
      }
    }

    _advanceSavedPending();
    if (!alive[turn] && !isOver) {
      _startTurn(nextAlive(turn));
    }
  }

  bool _checkWinCondition() {
    final lordAlive = alive[lordSeat];
    final aliveSeats = [for (var s = 0; s < players; s++) if (alive[s]) s];
    final rebelsAlive = aliveSeats.where((s) => roles[s] == 'rebel').isNotEmpty;
    final spiesAlive = aliveSeats.where((s) => roles[s] == 'spy').isNotEmpty;

    if (!lordAlive) {
      // 若仅剩内奸一人存活，内奸获胜；否则反贼获胜
      if (aliveSeats.length == 1 && roles[aliveSeats.first] == 'spy') {
        winnerRole = 'spy';
        winners = [for (var s = 0; s < players; s++) if (roles[s] == 'spy') s];
      } else {
        winnerRole = 'rebel';
        winners = [for (var s = 0; s < players; s++) if (roles[s] == 'rebel') s];
      }
      _endGame();
      return true;
    }

    if (!rebelsAlive && !spiesAlive) {
      winnerRole = 'lord';
      winners = [
        for (var s = 0; s < players; s++)
          if (roles[s] == 'lord' || roles[s] == 'loyalist') s,
      ];
      _endGame();
      return true;
    }
    return false;
  }

  void _endGame() {
    phase = 'over';
    pending = null;
    final winLabel = switch (winnerRole) {
      'lord' => '主公与忠臣获胜！',
      'rebel' => '反贼阵营获胜！',
      'spy' => '内奸独占鳌头获胜！',
      _ => '游戏结束',
    };
    result = {
      'winnerRole': winnerRole,
      'winLabel': winLabel,
      'winners': winners,
      'roles': roles,
      'generals': generals,
    };
    _log('=== 游戏结束：$winLabel ===');
  }

  /// AI 辅助：判断 other 是否与 seat 同阵营
  bool _isFriend(int seat, int other) {
    if (seat == other) return true;
    final rMe = roles[seat];
    final rOther = roles[other];
    if (rMe == 'lord' || rMe == 'loyalist') {
      // 主公是公开的；若只剩主忠反，AI按身份倾向配合主公
      if (other == lordSeat) return true;
      return rOther == 'loyalist';
    }
    if (rMe == 'rebel') {
      if (other == lordSeat) return false;
      return rOther == 'rebel';
    }
    // 内奸：若主公濒危且还有反贼存活，先保主公；若只剩主公则攻击主公
    final rebelsAlive = [for (var s = 0; s < players; s++) if (alive[s] && roles[s] == 'rebel') s].isNotEmpty;
    if (rebelsAlive && other == lordSeat && hp[lordSeat] <= 2) return true;
    return false;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver) return null;
    if (phase == 'pick') {
      if (picked[seat]) return null;
      return {'type': 'pick', 'general': generalChoices[seat].first};
    }

    final h = hands[seat];

    if (pending != null) {
      final p = pending!;
      if (p.type == 'wuxie') {
        if (p.queue.isEmpty || p.queue.first != seat) return null;
        final wx = h.where((c) => sgKind(c) == 'wuxie').toList();
        if (wx.isEmpty) return {'type': 'pass'};
        final helpfulToTarget = p.effect == 'wuzhong';
        final shouldCancel = helpfulToTarget ? !_isFriend(seat, p.target) : _isFriend(seat, p.target);
        if (shouldCancel) return {'type': 'wuxie', 'card': wx.first};
        return {'type': 'pass'};
      }
      if (p.type == 'dying') {
        if (p.queue.isEmpty || p.queue.first != seat) return null;
        final taos = h.where((c) => sgKind(c) == 'tao').toList();
        if (taos.isNotEmpty && _isFriend(seat, p.dyingSeat)) {
          return {'type': 'tao', 'card': taos.first};
        }
        return {'type': 'pass'};
      }
      if (p.type == 'shan') {
        if (p.target != seat) return null;
        final shans = h.where((c) => _canPlayAsShan(seat, c)).toList();
        if (shans.isNotEmpty) return {'type': 'shan', 'card': shans.first};
        return {'type': 'pass'};
      }
      if (p.type == 'sha') {
        if (p.target != seat) return null;
        final shas = h.where((c) => _canPlayAsSha(seat, c)).toList();
        if (shas.isNotEmpty) return {'type': 'sha', 'card': shas.first};
        return {'type': 'pass'};
      }
    }

    if (seat != turn) return null;

    if (phase == 'discard') {
      final need = h.length - max<int>(0, hp[seat]);
      if (need <= 0) return {'type': 'endPlay'};
      // 优先保留桃、闪、无懈可击
      final sorted = List<String>.of(h)
        ..sort((a, b) {
          int pri(String c) => switch (sgKind(c)) {
                'tao' => 10,
                'shan' => 8,
                'wuxie' => 7,
                'sha' => 5,
                _ => 2,
              };
          return pri(a) - pri(b);
        });
      return {'type': 'discard', 'cards': sorted.sublist(0, need)};
    }

    if (phase == 'play') {
      // 1. 受伤先吃桃
      if (hp[seat] < maxHp[seat]) {
        final tao = h.where((c) => sgKind(c) == 'tao').firstOrNull;
        if (tao != null) return {'type': 'play', 'card': tao};
      }

      // 2. 穿戴未装备的装备牌
      for (final c in h) {
        final cat = sgCategory(c);
        final eq = equips[seat];
        if (cat == 'weapon' && eq.weapon == null) return {'type': 'play', 'card': c};
        if (cat == 'armor' && eq.armor == null) return {'type': 'play', 'card': c};
        if (cat == 'minus_horse' && eq.minusHorse == null) return {'type': 'play', 'card': c};
        if (cat == 'plus_horse' && eq.plusHorse == null) return {'type': 'play', 'card': c};
      }

      // 3. 无中生有 / 桃园结义
      final wz = h.where((c) => sgKind(c) == 'wuzhong').firstOrNull;
      if (wz != null) return {'type': 'play', 'card': wz};
      if (hp[seat] < maxHp[seat]) {
        final ty = h.where((c) => sgKind(c) == 'taoyuan').firstOrNull;
        if (ty != null) return {'type': 'play', 'card': ty};
      }

      final enemies = [
        for (var s = 0; s < players; s++)
          if (alive[s] && s != seat && !_isFriend(seat, s)) s,
      ];
      final targetEnemy = enemies.isNotEmpty
          ? (enemies..sort((a, b) => hp[a] - hp[b])).first
          : otherAliveFrom(seat).firstOrNull;

      if (targetEnemy != null) {
        // 4. 顺手牵羊 / 过河拆桥
        for (final e in enemies) {
          if (_hasAnyCard(e) && distance(seat, e) <= 1) {
            final ss = h.where((c) => sgKind(c) == 'shunshou').firstOrNull;
            if (ss != null) return {'type': 'play', 'card': ss, 'target': e};
          }
          if (_hasAnyCard(e)) {
            final gh = h.where((c) => sgKind(c) == 'guohe').firstOrNull;
            if (gh != null) return {'type': 'play', 'card': gh, 'target': e};
            if (generals[seat] == 'ganning') {
              final blk = h.where((c) => sgIsBlack(c) && sgKind(c) != 'tao').firstOrNull;
              if (blk != null) return {'type': 'skill', 'skill': 'qixi', 'card': blk, 'target': e};
            }
          }
        }

        // 5. 南蛮入侵 / 万箭齐发
        final nm = h.where((c) => sgKind(c) == 'nanman').firstOrNull;
        if (nm != null) return {'type': 'play', 'card': nm};
        final wj = h.where((c) => sgKind(c) == 'wanjian').firstOrNull;
        if (wj != null) return {'type': 'play', 'card': wj};

        // 6. 决斗 / 乐不思蜀
        if (!isKongcheng(targetEnemy)) {
          final jd = h.where((c) => sgKind(c) == 'juedou').firstOrNull;
          if (jd != null) return {'type': 'play', 'card': jd, 'target': targetEnemy};
        }
        if (!judges[targetEnemy].any((c) => sgKind(c) == 'lebusishu')) {
          final lb = h.where((c) => sgKind(c) == 'lebusishu').firstOrNull;
          if (lb != null) return {'type': 'play', 'card': lb, 'target': targetEnemy};
        }

        // 7. 武将主动技能
        if (generals[seat] == 'sunquan' && !zhihengUsed && h.isNotEmpty) {
          final extra = h.where((c) => sgKind(c) != 'tao' && sgKind(c) != 'sha').toList();
          if (extra.isNotEmpty) return {'type': 'skill', 'skill': 'zhiheng', 'cards': [extra.first]};
        }
        if (generals[seat] == 'diaochan' && !lijianUsed && h.isNotEmpty && enemies.length >= 2) {
          final e1 = enemies[0], e2 = enemies[1];
          if (!isKongcheng(e1) && !isKongcheng(e2)) {
            return {'type': 'skill', 'skill': 'lijian', 'card': h.first, 'targets': [e1, e2]};
          }
        }

        // 8. 出【杀】（或武圣/龙胆转化【杀】）
        if (canUseMoreSha(seat)) {
          final inRangeEnemies = enemies.where((e) => inAttackRange(seat, e) && !isKongcheng(e)).toList();
          if (inRangeEnemies.isNotEmpty) {
            final t = inRangeEnemies.first;
            final shaCard = h.where((c) => sgKind(c) == 'sha').firstOrNull;
            if (shaCard != null) return {'type': 'play', 'card': shaCard, 'target': t};
            final conv = h.where((c) => _canPlayAsSha(seat, c) && sgKind(c) != 'tao').firstOrNull;
            if (conv != null) return {'type': 'play', 'card': conv, 'as': 'sha', 'target': t};
          }
        }
      }

      return {'type': 'endPlay'};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players;
    return {
      'phase': phase,
      'turn': turn,
      'lordSeat': lordSeat,
      'roundCount': roundCount,
      'deckCount': deck.length,
      'discardCount': discardPile.length,
      'myRole': me ? roles[seat] : null,
      'roles': [
        for (var s = 0; s < players; s++)
          (s == lordSeat || !alive[s] || isOver || (me && s == seat)) ? roles[s] : 'unknown',
      ],
      'generals': [for (var s = 0; s < players; s++) sgGeneralById(generals[s]).toJson()],
      'generalIds': generals,
      'generalChoices': me && phase == 'pick'
          ? [for (final id in generalChoices[seat]) sgGeneralById(id).toJson()]
          : const [],
      'picked': picked,
      'hp': hp,
      'maxHp': maxHp,
      'alive': alive,
      'hand': me ? hands[seat] : <String>[],
      'counts': [for (final h in hands) h.length],
      'equips': [for (final e in equips) e.toJson()],
      'judges': judges,
      'shaUsed': shaUsed,
      'canSha': me && seat == turn && canUseMoreSha(seat),
      'zhihengUsed': zhihengUsed,
      'lijianUsed': lijianUsed,
      'pending': pending?.toJson(),
      'distances': me
          ? [for (var s = 0; s < players; s++) distance(seat, s)]
          : List.filled(players, 1),
      'inRange': me
          ? [for (var s = 0; s < players; s++) inAttackRange(seat, s)]
          : List.filled(players, false),
      'log': log,
      'result': result,
    };
  }
}

const String sanguoshaRules = '''
# 三国杀（标准身份局）
支持 2~5 人的经典三国卡牌对战游戏，集身份推理、武将技能、距离计算与锦囊攻防于一体。
# 身份与胜利条件
- 2人局：1 主公 vs 1 反贼。
- 3人局：1 主公、1 反贼、1 内奸。
- 4人局：1 主公、1 忠臣、1 反贼、1 内奸（主公体力上限 +1）。
- 5人局：1 主公、1 忠臣、2 反贼、1 内奸（主公体力上限 +1）。
- 胜利条件：
- 主公与忠臣：消灭所有反贼与内奸。
- 反贼：主公阵亡（若最终非内奸单挑获胜）即由反贼获胜。
- 内奸：先除掉忠臣与反贼，最后在单挑中击败主公，成为唯一存活者。
# 回合流程
- 判定阶段：结算判定区的延时锦囊（如【乐不思蜀】，翻出红桃则失效，否则跳过出牌阶段）。
- 摸牌阶段：从牌堆摸 2 张牌。
- 出牌阶段：默认每回合可使用 1 张【杀】（装备诸葛连弩或张飞【咆哮】可无限出杀），可使用锦囊牌、装备牌及武将技能。
- 弃牌阶段：手牌数不得超过当前体力值，超出部分需弃置。
# 武将名册（12名）
- 刘备【仁德】、曹操【奸雄】、孙权【制衡】、关羽【武圣】、张飞【咆哮】、赵云【龙胆】、诸葛亮【观星/空城】、吕布【无双】、貂蝉【离间/闭月】、黄月英【集智】、甘宁【奇袭】、郭嘉【遗计】。
''';
