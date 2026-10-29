import 'dart:math';

import '../../src/engine.dart';

class CityDef {
  final int id;
  final String name;
  final double x;
  final double y;
  const CityDef(this.id, this.name, this.x, this.y);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'x': x, 'y': y};
}

class RouteDef {
  final int id;
  final int from;
  final int to;
  final int length;
  final String color; // 'R','B','G','Y','K','P','O','C' or 'X' (grey)
  final int slot; // 0 or 1 for double routes
  const RouteDef(this.id, this.from, this.to, this.length, this.color, [this.slot = 0]);

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'to': to,
        'length': length,
        'color': color,
        'slot': slot,
      };
}

class TicketDef {
  final int id;
  final int from;
  final int to;
  final int points;
  const TicketDef(this.id, this.from, this.to, this.points);

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'to': to,
        'points': points,
      };
}

const List<String> kTrainColors = ['R', 'B', 'G', 'Y', 'K', 'P', 'O', 'C'];
const String kWildCard = 'W';
const String kGreyRoute = 'X';

const Map<String, String> kColorNames = {
  'R': '红',
  'B': '蓝',
  'G': '绿',
  'Y': '黄',
  'K': '黑',
  'P': '紫',
  'O': '橙',
  'C': '白',
  'W': '彩车头',
  'X': '灰',
};

String normalizeTrainColor(String raw) {
  switch (raw.trim().toUpperCase()) {
    case 'R':
    case 'RED':
    case '红':
      return 'R';
    case 'B':
    case 'BLUE':
    case '蓝':
      return 'B';
    case 'G':
    case 'GREEN':
    case '绿':
      return 'G';
    case 'Y':
    case 'YELLOW':
    case '黄':
      return 'Y';
    case 'K':
    case 'BLACK':
    case '黑':
      return 'K';
    case 'P':
    case 'PURPLE':
    case '紫':
      return 'P';
    case 'O':
    case 'ORANGE':
    case '橙':
      return 'O';
    case 'C':
    case 'S':
    case 'WHITE':
    case '白':
      return 'C';
    case 'W':
    case 'WILD':
    case '彩车头':
      return 'W';
    case 'X':
    case 'GREY':
    case 'GRAY':
    case '灰':
      return 'X';
    default:
      return raw;
  }
}

int routePointsForLength(int length) {
  switch (length) {
    case 1:
      return 1;
    case 2:
      return 2;
    case 3:
      return 4;
    case 4:
      return 7;
    case 5:
      return 10;
    case 6:
      return 15;
    default:
      return length;
  }
}

const List<CityDef> kTicketCities = [
  CityDef(0, '乌鲁木齐', 0.11, 0.20),
  CityDef(1, '哈尔滨', 0.87, 0.13),
  CityDef(2, '沈阳', 0.80, 0.27),
  CityDef(3, '北京', 0.66, 0.31),
  CityDef(4, '呼和浩特', 0.49, 0.26),
  CityDef(5, '兰州', 0.33, 0.43),
  CityDef(6, '西安', 0.48, 0.50),
  CityDef(7, '郑州', 0.63, 0.48),
  CityDef(8, '济南', 0.75, 0.41),
  CityDef(9, '成都', 0.29, 0.64),
  CityDef(10, '重庆', 0.43, 0.68),
  CityDef(11, '武汉', 0.62, 0.65),
  CityDef(12, '南京', 0.78, 0.56),
  CityDef(13, '上海', 0.89, 0.62),
  CityDef(14, '昆明', 0.26, 0.85),
  CityDef(15, '广州', 0.63, 0.86),
];

const List<RouteDef> kTicketRoutes = [
  RouteDef(0, 0, 5, 6, 'Y'),
  RouteDef(1, 0, 4, 6, 'O'),
  RouteDef(2, 1, 2, 2, 'C'),
  RouteDef(3, 2, 3, 3, 'R', 0),
  RouteDef(4, 2, 3, 3, 'K', 1),
  RouteDef(5, 3, 4, 2, 'B'),
  RouteDef(6, 4, 5, 4, 'G'),
  RouteDef(7, 3, 8, 2, 'X'),
  RouteDef(8, 3, 7, 3, 'Y', 0),
  RouteDef(9, 3, 7, 3, 'P', 1),
  RouteDef(10, 5, 6, 3, 'R'),
  RouteDef(11, 5, 9, 3, 'P'),
  RouteDef(12, 6, 7, 2, 'O', 0),
  RouteDef(13, 6, 7, 2, 'C', 1),
  RouteDef(14, 7, 8, 2, 'G'),
  RouteDef(15, 8, 12, 3, 'B'),
  RouteDef(16, 6, 9, 3, 'Y'),
  RouteDef(17, 6, 10, 3, 'K'),
  RouteDef(18, 6, 11, 4, 'G'),
  RouteDef(19, 7, 11, 3, 'X'),
  RouteDef(20, 7, 12, 3, 'O'),
  RouteDef(21, 9, 10, 1, 'X', 0),
  RouteDef(22, 9, 10, 1, 'X', 1),
  RouteDef(23, 12, 13, 1, 'R', 0),
  RouteDef(24, 12, 13, 1, 'B', 1),
  RouteDef(25, 10, 11, 4, 'P'),
  RouteDef(26, 11, 12, 3, 'C'),
  RouteDef(27, 9, 14, 4, 'K'),
  RouteDef(28, 10, 14, 4, 'B'),
  RouteDef(29, 14, 15, 5, 'G'),
  RouteDef(30, 10, 15, 5, 'Y'),
  RouteDef(31, 11, 15, 4, 'R', 0),
  RouteDef(32, 11, 15, 4, 'O', 1),
  RouteDef(33, 13, 15, 6, 'P'),
];

const List<TicketDef> kAllTickets = [
  TicketDef(0, 0, 3, 12), // 乌鲁木齐 - 北京
  TicketDef(1, 0, 9, 11), // 乌鲁木齐 - 成都
  TicketDef(2, 0, 13, 18), // 乌鲁木齐 - 上海
  TicketDef(3, 1, 3, 5), // 哈尔滨 - 北京
  TicketDef(4, 1, 13, 11), // 哈尔滨 - 上海
  TicketDef(5, 1, 15, 16), // 哈尔滨 - 广州
  TicketDef(6, 2, 6, 8), // 沈阳 - 西安
  TicketDef(7, 2, 11, 9), // 沈阳 - 武汉
  TicketDef(8, 3, 6, 5), // 北京 - 西安
  TicketDef(9, 3, 9, 8), // 北京 - 成都
  TicketDef(10, 3, 11, 6), // 北京 - 武汉
  TicketDef(11, 3, 13, 7), // 北京 - 上海
  TicketDef(12, 3, 15, 10), // 北京 - 广州
  TicketDef(13, 4, 10, 9), // 呼和浩特 - 重庆
  TicketDef(14, 4, 12, 8), // 呼和浩特 - 南京
  TicketDef(15, 5, 11, 7), // 兰州 - 武汉
  TicketDef(16, 5, 14, 7), // 兰州 - 昆明
  TicketDef(17, 5, 15, 11), // 兰州 - 广州
  TicketDef(18, 6, 13, 7), // 西安 - 上海
  TicketDef(19, 6, 14, 8), // 西安 - 昆明
  TicketDef(20, 6, 15, 8), // 西安 - 广州
  TicketDef(21, 7, 14, 10), // 郑州 - 昆明
  TicketDef(22, 8, 10, 8), // 济南 - 重庆
  TicketDef(23, 9, 13, 10), // 成都 - 上海
  TicketDef(24, 9, 15, 9), // 成都 - 广州
  TicketDef(25, 12, 14, 11), // 南京 - 昆明
];

class TicketRide extends GameEngine {
  late int initialCars;
  late List<int> cars;
  late List<int> routeScores;
  late List<List<String>> hands;
  late List<List<TicketDef>> tickets;
  late List<List<TicketDef>> pendingTickets;
  late List<int> routeOwners;

  List<String> deck = [];
  List<String> discard = [];
  List<String> market = [];
  List<TicketDef> ticketDeck = [];

  int turn = 0;
  String phase = 'init_tickets'; // 'init_tickets' | 'play' | 'draw2' | 'keep_tickets' | 'end'
  int drawsLeft = 2;
  int? finalTurnsLeft;
  int totalTurns = 0;

  String lastAction = '';
  bool over = false;
  List<int> finalScores = [];
  List<int> ticketBonuses = [];
  List<int> longestPaths = [];
  List<bool> hasLongestBonus = [];

  TicketRide(super.setup);

  @override
  void start() {
    initialCars = setup.opt<int>('cars', 35);
    cars = List.filled(players, initialCars);
    routeScores = List.filled(players, 0);
    hands = [for (var i = 0; i < players; i++) <String>[]];
    tickets = [for (var i = 0; i < players; i++) <TicketDef>[]];
    pendingTickets = [for (var i = 0; i < players; i++) <TicketDef>[]];
    routeOwners = List.filled(kTicketRoutes.length, -1);

    // Build train deck: 12 of each of 8 colors + 14 wildcards = 110 cards
    final rawDeck = <String>[
      for (final c in kTrainColors)
        for (var i = 0; i < 12; i++) c,
      for (var i = 0; i < 14; i++) kWildCard,
    ];
    deck = shuffled(rawDeck, rng);
    discard = [];
    market = [];

    for (var s = 0; s < players; s++) {
      for (var i = 0; i < 4; i++) {
        hands[s].add(deck.removeLast());
      }
      hands[s].sort();
    }

    _refillMarket();

    ticketDeck = shuffled(kAllTickets, rng);
    for (var s = 0; s < players; s++) {
      for (var i = 0; i < 3 && ticketDeck.isNotEmpty; i++) {
        pendingTickets[s].add(ticketDeck.removeLast());
      }
    }

    turn = 0;
    phase = 'init_tickets';
    drawsLeft = 2;
    finalTurnsLeft = null;
    totalTurns = 0;
    over = false;
    lastAction = '游戏开始：请每位玩家保留至少 2 张初始车票任务';
  }

  String? _drawFromDeck() {
    if (deck.isEmpty && discard.isNotEmpty) {
      deck = shuffled(discard, rng);
      discard.clear();
    }
    if (deck.isEmpty) return null;
    return deck.removeLast();
  }

  void _refillMarket() {
    for (var attempt = 0; attempt < 5; attempt++) {
      while (market.length < 5) {
        final c = _drawFromDeck();
        if (c == null) break;
        market.add(c);
      }
      final wilds = market.where((c) => c == kWildCard).length;
      if (wilds >= 3 && (deck.length + discard.length) >= 3) {
        discard.addAll(market);
        market.clear();
        host.log('市场出现 3 张及以上彩车头，自动刷新市场！');
        continue;
      }
      break;
    }
  }

  bool get _hasDrawableForSecondCard {
    if (deck.isNotEmpty || discard.isNotEmpty) return true;
    return market.any((c) => c != kWildCard);
  }

  bool isTicketConnected(int seat, TicketDef t) {
    final visited = <int>{t.from};
    final q = <int>[t.from];
    while (q.isNotEmpty) {
      final cur = q.removeLast();
      if (cur == t.to) return true;
      for (final r in kTicketRoutes) {
        if (routeOwners[r.id] != seat) continue;
        final next = r.from == cur ? r.to : (r.to == cur ? r.from : -1);
        if (next >= 0 && visited.add(next)) {
          q.add(next);
        }
      }
    }
    return false;
  }

  int longestContinuousPath(int seat) {
    final owned = [
      for (final r in kTicketRoutes)
        if (routeOwners[r.id] == seat) r
    ];
    if (owned.isEmpty) return 0;

    final adj = <int, List<RouteDef>>{};
    for (final r in owned) {
      (adj[r.from] ??= []).add(r);
      (adj[r.to] ??= []).add(r);
    }

    var best = 0;
    final usedRoute = <int>{};

    void dfs(int city, int acc) {
      if (acc > best) best = acc;
      final edges = adj[city];
      if (edges == null) return;
      for (final r in edges) {
        if (usedRoute.contains(r.id)) continue;
        usedRoute.add(r.id);
        final next = r.from == city ? r.to : r.from;
        dfs(next, acc + r.length);
        usedRoute.remove(r.id);
      }
    }

    for (final city in adj.keys) {
      dfs(city, 0);
    }
    return best;
  }

  /// Checks whether [seat] can claim route [routeId], returning the list of valid
  /// payment color choices (`'R'..'C'` or `'W'`). Empty list = cannot claim.
  List<String> validClaimColors(int seat, int routeId) {
    if (routeId < 0 || routeId >= kTicketRoutes.length) return const [];
    if (routeOwners[routeId] != -1) return const [];
    final r = kTicketRoutes[routeId];
    if (cars[seat] < r.length) return const [];

    // Check double route rule
    for (final other in kTicketRoutes) {
      if (other.id == r.id) continue;
      final samePair = (other.from == r.from && other.to == r.to) ||
          (other.from == r.to && other.to == r.from);
      if (!samePair) continue;
      if (routeOwners[other.id] == seat) {
        // Same player cannot claim both parallel routes
        return const [];
      }
      if (players <= 3 && routeOwners[other.id] != -1) {
        // In 2-3p games, only one of the parallel routes can be claimed
        return const [];
      }
    }

    final counts = <String, int>{};
    for (final c in hands[seat]) {
      counts[c] = (counts[c] ?? 0) + 1;
    }
    final wilds = counts[kWildCard] ?? 0;

    if (r.color != kGreyRoute) {
      final have = (counts[r.color] ?? 0) + wilds;
      return have >= r.length ? [r.color] : const [];
    }

    final valid = <String>[];
    for (final c in kTrainColors) {
      final cCount = counts[c] ?? 0;
      if (cCount > 0 && cCount + wilds >= r.length) {
        valid.add(c);
      }
    }
    if (wilds >= r.length) {
      valid.add(kWildCard);
    }
    return valid;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'init_tickets') {
      if (seat < 0 || seat >= players || pendingTickets[seat].isEmpty) {
        throw GameError('你已完成初始车票选择');
      }
      if (type != 'keep_tickets') {
        throw GameError('请先选择要保留的初始车票');
      }
      _handleKeepTickets(seat, action, minKeep: 2, isInit: true);
      return;
    }

    if (seat != turn) throw GameError('还没轮到你行动');

    if (phase == 'keep_tickets') {
      if (type != 'keep_tickets') {
        throw GameError('请先选择要保留的车票');
      }
      _handleKeepTickets(seat, action, minKeep: 1, isInit: false);
      return;
    }

    if (phase == 'draw2') {
      if (type == 'draw_market' || (type == 'draw' && asStr(action['source']) == 'market')) {
        _handleDrawMarket(seat, asInt(action['index']));
        return;
      }
      if (type == 'draw_deck' || (type == 'draw' && asStr(action['source']) == 'deck')) {
        _handleDrawDeck(seat);
        return;
      }
      throw GameError('请摸取第 2 张车厢卡');
    }

    if (phase == 'play') {
      if (type == 'draw_market' || (type == 'draw' && asStr(action['source']) == 'market')) {
        _handleDrawMarket(seat, asInt(action['index']));
        return;
      }
      if (type == 'draw_deck' || (type == 'draw' && asStr(action['source']) == 'deck')) {
        _handleDrawDeck(seat);
        return;
      }
      if (type == 'claim') {
        _handleClaimRoute(seat, action);
        return;
      }
      if (type == 'draw_tickets') {
        if (ticketDeck.isEmpty) throw GameError('车票牌库已空');
        pendingTickets[seat].clear();
        for (var i = 0; i < 3 && ticketDeck.isNotEmpty; i++) {
          pendingTickets[seat].add(ticketDeck.removeLast());
        }
        phase = 'keep_tickets';
        lastAction = '${name(seat)} 抽取了 ${pendingTickets[seat].length} 张车票任务';
        return;
      }
      throw GameError('未知操作');
    }

    throw GameError('当前阶段无法执行该操作');
  }

  void _handleKeepTickets(int seat, Map<String, dynamic> action,
      {required int minKeep, required bool isInit}) {
    final pending = pendingTickets[seat];
    final effectiveMin = min(minKeep, pending.length);
    final rawIdx = action['indices'];
    if (rawIdx is! List) throw GameError('请指定保留的车票索引');
    final idxSet = <int>{};
    for (final x in rawIdx) {
      final i = asInt(x);
      if (i >= 0 && i < pending.length) idxSet.add(i);
    }
    if (idxSet.length < effectiveMin) {
      throw GameError('至少需要保留 $effectiveMin 张车票');
    }
    final sortedIdx = idxSet.toList()..sort();
    for (var i = 0; i < pending.length; i++) {
      if (idxSet.contains(i)) {
        tickets[seat].add(pending[i]);
      } else {
        // Put unkept tickets at bottom of ticketDeck
        ticketDeck.insert(0, pending[i]);
      }
    }
    pending.clear();

    if (isInit) {
      host.log('${name(seat)} 保留了 ${sortedIdx.length} 张初始车票');
      if (pendingTickets.every((p) => p.isEmpty)) {
        phase = 'play';
        turn = 0;
        drawsLeft = 2;
        lastAction = '初始车票选择完毕，轮到 ${name(0)} 行动';
      }
    } else {
      lastAction = '${name(seat)} 保留了 ${sortedIdx.length} 张新车票';
      host.log(lastAction);
      _finishTurn();
    }
  }

  void _handleDrawMarket(int seat, int idx) {
    if (idx < 0 || idx >= market.length) throw GameError('无效的市场卡牌位置');
    final card = market[idx];
    if (card == kWildCard && drawsLeft < 2) {
      throw GameError('已摸过 1 张牌，不能再拿取明牌彩车头');
    }
    market.removeAt(idx);
    hands[seat].add(card);
    hands[seat].sort();
    _refillMarket();

    if (card == kWildCard) {
      drawsLeft = 0;
      lastAction = '${name(seat)} 从市场拿取了明牌【彩车头】';
      host.log(lastAction);
      _finishTurn();
    } else {
      drawsLeft--;
      lastAction = '${name(seat)} 从市场拿取了【${kColorNames[card]}色车厢】';
      if (drawsLeft <= 0 || !_hasDrawableForSecondCard) {
        host.log(lastAction);
        _finishTurn();
      } else {
        phase = 'draw2';
      }
    }
  }

  void _handleDrawDeck(int seat) {
    final card = _drawFromDeck();
    if (card == null) throw GameError('车厢牌库已空');
    hands[seat].add(card);
    hands[seat].sort();
    drawsLeft--;
    lastAction = '${name(seat)} 从牌库盲抽了 1 张车厢卡';
    if (drawsLeft <= 0 || !_hasDrawableForSecondCard) {
      host.log(lastAction);
      _finishTurn();
    } else {
      phase = 'draw2';
    }
  }

  void _handleClaimRoute(int seat, Map<String, dynamic> action) {
    final routeId = asInt(action['route']);
    final validColors = validClaimColors(seat, routeId);
    if (validColors.isEmpty) {
      throw GameError('无法占领该铁路线路（可能已被占领、车厢不足或手牌不足）');
    }
    final r = kTicketRoutes[routeId];
    var chosen = normalizeTrainColor(asStr(action['color']));
    if (r.color != kGreyRoute) {
      chosen = r.color;
    } else if (chosen.isEmpty || !validColors.contains(chosen)) {
      if (chosen.isNotEmpty && !validColors.contains(chosen)) {
        throw GameError('所选颜色手牌不足以支付该线路');
      }
      chosen = validColors.first;
    }

    // Spend cards: first spend up to r.length of `chosen`, then fill remainder with 'W'
    var needed = r.length;
    if (chosen != kWildCard) {
      for (var i = hands[seat].length - 1; i >= 0 && needed > 0; i--) {
        if (hands[seat][i] == chosen) {
          discard.add(hands[seat].removeAt(i));
          needed--;
        }
      }
    }
    for (var i = hands[seat].length - 1; i >= 0 && needed > 0; i--) {
      if (hands[seat][i] == kWildCard) {
        discard.add(hands[seat].removeAt(i));
        needed--;
      }
    }

    // If market had fewer than 5 cards due to depleted deck, refill from discard
    if (market.length < 5) {
      _refillMarket();
    }

    routeOwners[routeId] = seat;
    cars[seat] -= r.length;
    final pts = routePointsForLength(r.length);
    routeScores[seat] += pts;

    final c1 = kTicketCities[r.from].name;
    final c2 = kTicketCities[r.to].name;
    lastAction = '${name(seat)} 修建了【$c1 - $c2】（长度 ${r.length}，+$pts 分）';
    host.log(lastAction);

    _finishTurn();
  }

  void _finishTurn() {
    totalTurns++;
    if (finalTurnsLeft == null) {
      if (cars[turn] <= 2) {
        finalTurnsLeft = players;
        host.log('${name(turn)} 剩余车厢仅 ${cars[turn]} 节，触发最后一轮！');
      }
    }

    if (finalTurnsLeft != null) {
      finalTurnsLeft = finalTurnsLeft! - 1;
      if (finalTurnsLeft! <= 0) {
        _endGame();
        return;
      }
    }

    // Check if any move is possible in the game or turn limit reached
    final anyUnclaimed = routeOwners.any((o) => o == -1);
    if (!anyUnclaimed || totalTurns >= 220) {
      _endGame();
      return;
    }

    turn = (turn + 1) % players;
    drawsLeft = 2;
    phase = 'play';

    // If the active player cannot draw cards, draw tickets, or claim any route, end game
    final canDraw = deck.isNotEmpty || discard.isNotEmpty || market.isNotEmpty;
    final canTicket = ticketDeck.isNotEmpty;
    final canClaim = [for (var i = 0; i < kTicketRoutes.length; i++) i]
        .any((id) => validClaimColors(turn, id).isNotEmpty);
    if (!canDraw && !canTicket && !canClaim) {
      _endGame();
    }
  }

  void _endGame() {
    over = true;
    phase = 'end';
    ticketBonuses = List.filled(players, 0);
    longestPaths = List.filled(players, 0);
    hasLongestBonus = List.filled(players, false);
    finalScores = List.filled(players, 0);

    for (var s = 0; s < players; s++) {
      var tBonus = 0;
      for (final t in tickets[s]) {
        if (isTicketConnected(s, t)) {
          tBonus += t.points;
        } else {
          tBonus -= t.points;
        }
      }
      ticketBonuses[s] = tBonus;
      longestPaths[s] = longestContinuousPath(s);
    }

    final maxPath = longestPaths.reduce(max);
    for (var s = 0; s < players; s++) {
      if (maxPath > 0 && longestPaths[s] == maxPath) {
        hasLongestBonus[s] = true;
      }
      finalScores[s] =
          routeScores[s] + ticketBonuses[s] + (hasLongestBonus[s] ? 10 : 0);
    }

    final best = finalScores.reduce(max);
    final winNames = [
      for (var s = 0; s < players; s++)
        if (finalScores[s] == best) name(s)
    ].join('、');
    lastAction = '游戏结束！$winNames 以 $best 分获胜！';
    host.log(lastAction);
  }

  @override
  List<int> get waitingFor {
    if (over) return const [];
    if (phase == 'init_tickets') {
      return [
        for (var s = 0; s < players; s++)
          if (pendingTickets[s].isNotEmpty) s
      ];
    }
    return [turn];
  }

  @override
  bool get isOver => over;

  @override
  List<int>? get placings {
    if (!over) return null;
    return rankByScore(finalScores);
  }

  @override
  bool get canResign => !over && players == 2;

  @override
  void resign(int seat) {
    if (!canResign || seat < 0 || seat >= players) throw GameError('无法认输');
    _endGame();
    final other = 1 - seat;
    finalScores[seat] = -999;
    if (finalScores[other] <= -999) finalScores[other] = 0;
    lastAction = '${name(seat)} 认输，${name(other)} 获胜！';
    host.log(lastAction);
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'turn': turn,
      'phase': phase,
      'drawsLeft': drawsLeft,
      'finalTurnsLeft': finalTurnsLeft,
      'lastAction': lastAction,
      'over': over,
      'market': List<String>.of(market),
      'deckCount': deck.length + discard.length,
      'ticketDeckCount': ticketDeck.length,
      'routeOwners': List<int>.of(routeOwners),
      'myHand': seat >= 0 && seat < players ? List<String>.of(hands[seat]) : const <String>[],
      'myTickets': seat >= 0 && seat < players
          ? [
              for (final t in tickets[seat])
                {
                  ...t.toJson(),
                  'done': isTicketConnected(seat, t),
                },
            ]
          : const [],
      'pendingTickets': seat >= 0 && seat < players
          ? [for (final t in pendingTickets[seat]) t.toJson()]
          : const [],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'cars': cars[s],
            'routeScore': routeScores[s],
            'handCount': hands[s].length,
            'ticketCount': tickets[s].length,
            if (over) 'finalScore': finalScores[s],
            if (over) 'ticketBonus': ticketBonuses[s],
            if (over) 'longestPath': longestPaths[s],
            if (over) 'longestBonus': hasLongestBonus[s],
          },
      ],
      if (over)
        'final': [
          for (var s = 0; s < players; s++)
            {
              'seat': s,
              'name': name(s),
              'routeScore': routeScores[s],
              'ticketBonus': ticketBonuses[s],
              'longestPath': longestPaths[s],
              'longestBonus': hasLongestBonus[s],
              'score': finalScores[s],
              'win': finalScores[s] == finalScores.reduce(max),
            },
        ],
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || !waitingFor.contains(seat)) return null;

    if (phase == 'init_tickets') {
      final p = pendingTickets[seat];
      if (p.length <= 2) {
        return {
          'type': 'keep_tickets',
          'indices': [for (var i = 0; i < p.length; i++) i],
        };
      }
      // Keep the 2 shorter/easier tickets
      final idx = [for (var i = 0; i < p.length; i++) i];
      idx.sort((a, b) => p[a].points.compareTo(p[b].points));
      return {'type': 'keep_tickets', 'indices': idx.sublist(0, 2)};
    }

    if (phase == 'keep_tickets') {
      final p = pendingTickets[seat];
      // Keep any already-connected tickets, otherwise keep the single lowest-point ticket
      final connected = <int>[
        for (var i = 0; i < p.length; i++)
          if (isTicketConnected(seat, p[i])) i
      ];
      if (connected.isNotEmpty) {
        return {'type': 'keep_tickets', 'indices': connected};
      }
      var bestIdx = 0;
      for (var i = 1; i < p.length; i++) {
        if (p[i].points < p[bestIdx].points) bestIdx = i;
      }
      return {
        'type': 'keep_tickets',
        'indices': [bestIdx],
      };
    }

    if (phase == 'draw2') {
      return _botDrawCard(seat, allowWildMarket: false);
    }

    // phase == 'play'
    // 1. Check claimable routes
    final claimable = <(RouteDef, String, int)>[];
    for (final r in kTicketRoutes) {
      final colors = validClaimColors(seat, r.id);
      if (colors.isEmpty) continue;
      // Prefer color that uses fewer wildcards
      final chosen = colors.first;
      var priority = r.length * 10;
      if (_routeHelpsTicket(seat, r)) {
        priority += 100;
      }
      claimable.add((r, chosen, priority));
    }

    if (claimable.isNotEmpty) {
      claimable.sort((a, b) => b.$3.compareTo(a.$3));
      final top = claimable.first;
      // Claim immediately if it helps a ticket, or length >= 3, or hand is large, or final round
      final canDrawMore = deck.isNotEmpty || discard.isNotEmpty || market.isNotEmpty;
      if (top.$3 >= 30 ||
          hands[seat].length >= 8 ||
          finalTurnsLeft != null ||
          !canDrawMore ||
          botLevel == 0) {
        return {
          'type': 'claim',
          'route': top.$1.id,
          'color': top.$2,
        };
      }
    }

    // 2. Otherwise draw cards if available
    final drawMove = _botDrawCard(seat, allowWildMarket: true);
    if (drawMove != null) return drawMove;

    // 3. Fallback to any claimable route or drawing tickets
    if (claimable.isNotEmpty) {
      final top = claimable.first;
      return {'type': 'claim', 'route': top.$1.id, 'color': top.$2};
    }
    if (ticketDeck.isNotEmpty) {
      return {'type': 'draw_tickets'};
    }
    return null;
  }

  bool _routeHelpsTicket(int seat, RouteDef route) {
    for (final t in tickets[seat]) {
      if (isTicketConnected(seat, t)) continue;
      // Check if route touches component of t.from or t.to
      if (route.from == t.from ||
          route.to == t.from ||
          route.from == t.to ||
          route.to == t.to) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic>? _botDrawCard(int seat, {required bool allowWildMarket}) {
    final counts = <String, int>{};
    for (final c in hands[seat]) {
      counts[c] = (counts[c] ?? 0) + 1;
    }

    // Check market for useful cards
    if (allowWildMarket) {
      final wildIdx = market.indexOf(kWildCard);
      if (wildIdx >= 0 && botLevel >= 1) {
        return {'type': 'draw_market', 'index': wildIdx};
      }
    }

    var bestIdx = -1;
    var bestCount = -1;
    for (var i = 0; i < market.length; i++) {
      final c = market[i];
      if (c == kWildCard && !allowWildMarket) continue;
      final cnt = counts[c] ?? 0;
      if (cnt > bestCount) {
        bestCount = cnt;
        bestIdx = i;
      }
    }
    if (bestIdx >= 0 && (bestCount >= 1 || (deck.isEmpty && discard.isEmpty))) {
      return {'type': 'draw_market', 'index': bestIdx};
    }
    if (deck.isNotEmpty || discard.isNotEmpty) {
      return {'type': 'draw_deck'};
    }
    if (bestIdx >= 0) {
      return {'type': 'draw_market', 'index': bestIdx};
    }
    return null;
  }
}
