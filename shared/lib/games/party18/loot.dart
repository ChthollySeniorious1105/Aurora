import '../../src/engine.dart';

class PirateColorInfo {
  final int id;
  final String name;
  final String emoji;
  const PirateColorInfo(this.id, this.name, this.emoji);
}

const List<PirateColorInfo> kPirateColors = [
  PirateColorInfo(0, '蓝海盗', '🟦'),
  PirateColorInfo(1, '绿海盗', '🟩'),
  PirateColorInfo(2, '黄海盗', '🟨'),
  PirateColorInfo(3, '红海盗', '🟥'),
];

class LootGame extends GameEngine {
  LootGame(super.setup);

  int round = 1;
  int turn = 0;
  int playSeq = 0;
  int consecutivePasses = 0;
  String phase = 'act'; // 'act' | 'over'

  /// Draw deck of cards:
  /// {'kind': 'merchant'|'pirate'|'captain'|'admiral', 'value': 2..8, 'color': -1|0..3, 'strength': 0..5}
  late List<Map<String, dynamic>> deck;

  /// Secret hands per player: hands[seat].
  late List<List<Map<String, dynamic>>> hands;

  /// Active Merchant Ships on the sea:
  /// {
  ///   'id': int,
  ///   'value': int (2..8),
  ///   'owner': int (seat),
  ///   'attacks': Map<String, int> (seatStr -> totalStrength),
  ///   'colors': Map<String, int> (seatStr -> color 0..3),
  ///   'cardsBySeat': Map<String, List<Map<String, dynamic>>>,
  ///   'trumpSeat': int (-1 or latest Captain/Admiral player),
  /// }
  late List<Map<String, dynamic>> ships;

  /// Captured gold treasury per seat.
  late List<int> gold;

  /// Captured ship values per seat.
  late List<List<int>> capturedShips;

  int nextShipId = 1;
  String lastEvent = '海盗舰队扬帆起航！放出商船或派遣四色海盗争夺黄金宝船！';

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => true;

  @override
  List<int>? get placings {
    if (!isOver) return null;
    final adjusted = <num>[
      for (var s = 0; s < players; s++)
        gold[s] * 100 + capturedShips[s].length,
    ];
    return rankByScore(adjusted);
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    return [turn];
  }

  @override
  void start() {
    final mode = setup.opt<String>('mode', 'standard');
    round = 1;
    turn = 0;
    playSeq = 0;
    consecutivePasses = 0;
    phase = 'act';
    nextShipId = 1;

    deck = _buildDeck(fast: mode == 'fast');
    deck.shuffle(rng);

    hands = [
      for (var s = 0; s < players; s++)
        <Map<String, dynamic>>[
          for (var i = 0; i < 6 && deck.isNotEmpty; i++) deck.removeLast(),
        ],
    ];
    ships = <Map<String, dynamic>>[];
    gold = List<int>.filled(players, 0);
    capturedShips = [for (var s = 0; s < players; s++) <int>[]];

    lastEvent = '海盗劫掠船开局！每人起始 6 张手牌，回合开始时自动捕获你战力独占鳌头的商船！';
    host.log('【海盗劫掠船】大战打响！牌库剩余 ${deck.length} 张。');
  }

  List<Map<String, dynamic>> _buildDeck({required bool fast}) {
    final cards = <Map<String, dynamic>>[];

    // Merchant ships: values 2..8
    final shipValues = fast
        ? <int>[2, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 8]
        : <int>[
            2, 2, 2, 2, 2,
            3, 3, 3, 3, 3, 3,
            4, 4, 4, 4, 4,
            5, 5, 5, 5,
            6, 6,
            7, 7,
            8,
          ];
    for (final v in shipValues) {
      cards.add({
        'kind': 'merchant',
        'value': v,
        'color': -1,
        'strength': 0,
      });
    }

    // Colored Pirate cards: 4 colors (0..3), strengths 1..4
    for (var col = 0; col < 4; col++) {
      final strengths = fast
          ? <int>[1, 1, 2, 2, 2, 3, 3, 4]
          : <int>[1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 4, 4];
      for (final str in strengths) {
        cards.add({
          'kind': 'pirate',
          'value': 0,
          'color': col,
          'strength': str,
        });
      }
      // 1 Pirate Captain per color (🏴‍☠️ strength +5)
      cards.add({
        'kind': 'captain',
        'value': 0,
        'color': col,
        'strength': 5,
      });
    }

    // 1 Admiral (⚓ defends your own Merchant Ship, strength +5)
    cards.add({
      'kind': 'admiral',
      'value': 0,
      'color': -1,
      'strength': 5,
    });

    return cards;
  }

  /// Determine the sole leader of a Merchant Ship:
  /// - If nobody has attacked it, the ship's owner is its uncontested leader.
  /// - If attacked, find the highest attack strength. If a single player holds the highest
  ///   strength, they are the sole leader; if tied for highest and one of the tied players
  ///   holds the ship's trumpSeat (latest Captain/Admiral), they lead; otherwise -1 (deadlock).
  int shipLeader(Map<String, dynamic> ship) {
    final attacks = (ship['attacks'] as Map).cast<String, int>();
    if (attacks.isEmpty) {
      return (ship['owner'] as num).toInt();
    }
    var maxStr = -1;
    final topSeats = <int>[];
    for (final entry in attacks.entries) {
      final s = int.tryParse(entry.key) ?? -1;
      final str = entry.value;
      if (s < 0 || s >= players) continue;
      if (str > maxStr) {
        maxStr = str;
        topSeats
          ..clear()
          ..add(s);
      } else if (str == maxStr) {
        topSeats.add(s);
      }
    }
    if (topSeats.length == 1) {
      return topSeats.first;
    }
    final trumpSeat = (ship['trumpSeat'] as num?)?.toInt() ?? -1;
    if (trumpSeat >= 0 && topSeats.contains(trumpSeat)) {
      return trumpSeat;
    }
    return -1;
  }

  /// At the start of [seat]'s turn: capture all Merchant Ships where [seat] holds sole highest strength (or uncontested owner).
  List<int> resolveStartOfTurnCaptures(int seat) {
    final capturedVals = <int>[];
    final remaining = <Map<String, dynamic>>[];
    for (final ship in ships) {
      final leader = shipLeader(ship);
      if (leader == seat) {
        final val = (ship['value'] as num).toInt();
        gold[seat] += val;
        capturedShips[seat].add(val);
        capturedVals.add(val);
      } else {
        remaining.add(ship);
      }
    }
    ships = remaining;
    if (capturedVals.isNotEmpty) {
      final sum = capturedVals.fold<int>(0, (a, b) => a + b);
      final msg = '💰 ${name(seat)} 在回合开始捕获了 ${capturedVals.length} 艘商船 (${capturedVals.map((v) => "$v💰").join("、")})，入账 +$sum 金币！';
      lastEvent = msg;
      host.log(msg);
    }
    return capturedVals;
  }

  bool canAttackShipWithCard(int seat, Map<String, dynamic> ship, Map<String, dynamic> card) {
    final kind = asStr(card['kind']);
    final col = asInt(card['color'], -1);
    final colors = (ship['colors'] as Map).cast<String, int>();
    final myExistingCol = colors['$seat'];

    if (kind == 'admiral') {
      // Admiral defends your own Merchant Ship (or a ship you already attacked)
      final owner = (ship['owner'] as num).toInt();
      return owner == seat;
    }

    if (kind == 'pirate' || kind == 'captain') {
      if (col < 0 || col >= 4) return false;
      if (myExistingCol != null) {
        // Must keep adding to your own color fleet on that ship
        return myExistingCol == col;
      }
      // Cannot use a color already used by another player on this ship
      for (final entry in colors.entries) {
        if (entry.key != '$seat' && entry.value == col) {
          return false;
        }
      }
      return true;
    }

    return false;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'draw':
        _handleDraw(seat);
        break;
      case 'launch':
        _handleLaunch(seat, action);
        break;
      case 'attack':
        _handleAttack(seat, action);
        break;
      default:
        throw GameError('未知操作：$type');
    }
  }

  void _handleDraw(int seat) {
    if (deck.isNotEmpty) {
      final drawn = deck.removeLast();
      hands[seat].add(drawn);
      consecutivePasses = 0;
      lastEvent = '${name(seat)} 从牌库摸取了 1 张手牌（牌库剩余 ${deck.length} 张）';
      host.log(lastEvent);
    } else {
      // Deck is empty: discard 1 unplayable card if any or pass
      if (hands[seat].isNotEmpty) {
        var dropIdx = 0;
        for (var i = 0; i < hands[seat].length; i++) {
          if (hands[seat][i]['kind'] != 'merchant') {
            dropIdx = i;
            break;
          }
        }
        hands[seat].removeAt(dropIdx);
      }
      consecutivePasses++;
      lastEvent = '${name(seat)} 在牌库耗尽后整理弃置了 1 张手牌';
      host.log(lastEvent);
    }
    _advanceTurn();
  }

  void _handleLaunch(int seat, Map<String, dynamic> action) {
    final cIdx = asInt(action['cardIdx'], -1);
    if (cIdx < 0 || cIdx >= hands[seat].length) {
      throw GameError('手牌编号无效');
    }
    final card = hands[seat][cIdx];
    if (card['kind'] != 'merchant') {
      throw GameError('只有商船卡 (2~8💰) 才能驶入海域');
    }

    hands[seat].removeAt(cIdx);
    final val = asInt(card['value'], 2);
    final ship = <String, dynamic>{
      'id': nextShipId++,
      'value': val,
      'owner': seat,
      'attacks': <String, int>{},
      'colors': <String, int>{},
      'cardsBySeat': <String, List<Map<String, dynamic>>>{},
      'trumpSeat': -1,
    };
    ships.add(ship);
    consecutivePasses = 0;
    lastEvent = '⛵ ${name(seat)} 放出了价值 $val💰 的黄金商船！';
    host.log(lastEvent);
    _advanceTurn();
  }

  void _handleAttack(int seat, Map<String, dynamic> action) {
    final sIdx = asInt(action['shipIdx'], -1);
    final cIdx = asInt(action['cardIdx'], -1);
    if (sIdx < 0 || sIdx >= ships.length) {
      throw GameError('目标商船编号无效');
    }
    if (cIdx < 0 || cIdx >= hands[seat].length) {
      throw GameError('手牌编号无效');
    }

    final ship = ships[sIdx];
    final card = hands[seat][cIdx];
    final kind = asStr(card['kind']);
    if (kind == 'merchant') {
      throw GameError('商船卡请使用【放出商船 (launch)】指令');
    }

    final colors = (ship['colors'] as Map).cast<String, int>();
    final attacks = (ship['attacks'] as Map).cast<String, int>();
    final cardsBySeat = (ship['cardsBySeat'] as Map).cast<String, List<Map<String, dynamic>>>();
    final col = asInt(card['color'], -1);
    final str = asInt(card['strength'], 1);

    if (kind == 'admiral') {
      if ((ship['owner'] as num).toInt() != seat) {
        throw GameError('海军上将 ⚓ 只能用于保卫你自己放出的商船');
      }
    } else if (kind == 'pirate' || kind == 'captain') {
      final myExistingCol = colors['$seat'];
      if (myExistingCol != null && myExistingCol != col) {
        throw GameError('你在该商船已使用${kPirateColors[myExistingCol].name}，必须继续使用同色海盗进攻');
      }
      for (final entry in colors.entries) {
        if (entry.key != '$seat' && entry.value == col) {
          throw GameError('该商船已有其他玩家使用${kPirateColors[col].name}，不可撞色');
        }
      }
      colors['$seat'] = col;
    } else {
      throw GameError('无效卡牌类型：$kind');
    }

    hands[seat].removeAt(cIdx);
    attacks['$seat'] = (attacks['$seat'] ?? 0) + str;
    final seatCards = cardsBySeat.putIfAbsent('$seat', () => <Map<String, dynamic>>[]);
    seatCards.add(Map<String, dynamic>.of(card));

    if (kind == 'captain' || kind == 'admiral') {
      ship['trumpSeat'] = seat;
    }

    consecutivePasses = 0;
    final shipVal = ship['value'];
    String cardLabel;
    if (kind == 'admiral') {
      cardLabel = '⚓海军上将(+5)';
    } else if (kind == 'captain') {
      cardLabel = '🏴‍☠️${kPirateColors[col].emoji}${kPirateColors[col].name}船长(+5)';
    } else {
      cardLabel = '${kPirateColors[col].emoji}${kPirateColors[col].name}(+$str)';
    }

    lastEvent = '⚔️ ${name(seat)} 派遣【$cardLabel】进攻 $shipVal💰 商船（当前战力 ${attacks['$seat']}）！';
    host.log(lastEvent);
    _advanceTurn();
  }

  void _advanceTurn() {
    final next = (turn + 1) % players;
    if (next == 0) {
      round++;
    }
    turn = next;

    // Start-of-turn capture rule for the incoming player!
    resolveStartOfTurnCaptures(turn);

    // Check endgame: deck is empty and either a player emptied their hand or everyone passed
    final anyEmptyHand = hands.any((h) => h.isEmpty);
    if ((deck.isEmpty && anyEmptyHand) || consecutivePasses >= players || round > 28) {
      _finishGame();
    }
  }

  void _finishGame() {
    // Award any remaining ships on the sea to their current sole leader
    for (final ship in ships) {
      final leader = shipLeader(ship);
      if (leader >= 0 && leader < players) {
        final val = (ship['value'] as num).toInt();
        gold[leader] += val;
        capturedShips[leader].add(val);
      }
    }
    ships.clear();
    phase = 'over';

    var bestSeat = 0;
    for (var s = 1; s < players; s++) {
      if (gold[s] > gold[bestSeat]) bestSeat = s;
    }
    lastEvent = '🏴‍☠️ 海盗分赃结算完毕！${name(bestSeat)} 以 ${gold[bestSeat]}💰 黄金宝藏加冕海盗王！';
    host.log(lastEvent);
  }

  @override
  Map<String, dynamic> view(int seat) {
    final validPlayer = seat >= 0 && seat < players;
    return {
      'round': round,
      'turn': turn,
      'phase': phase,
      'deckCount': deck.length,
      'gold': List<int>.of(gold),
      'capturedShips': [
        for (final cs in capturedShips) List<int>.of(cs),
      ],
      'handCounts': [
        for (final h in hands) h.length,
      ],
      'myHand': validPlayer
          ? [for (final c in hands[seat]) Map<String, dynamic>.of(c)]
          : const <Map<String, dynamic>>[],
      'ships': [
        for (final s in ships)
          {
            'id': s['id'],
            'value': s['value'],
            'owner': s['owner'],
            'leader': shipLeader(s),
            'trumpSeat': s['trumpSeat'],
            'attacks': Map<String, int>.of((s['attacks'] as Map).cast<String, int>()),
            'colors': Map<String, int>.of((s['colors'] as Map).cast<String, int>()),
            'cardsBySeat': {
              for (final e in (s['cardsBySeat'] as Map).entries)
                e.key as String: [
                  for (final c in (e.value as List))
                    Map<String, dynamic>.of((c as Map).cast<String, dynamic>()),
                ],
            },
          },
      ],
      'lastEvent': lastEvent,
      'canAct': !isOver && seat == turn,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;
    final myHand = hands[seat];

    // 1. Check if we can attack a high-value contested ship and take the lead
    for (var sIdx = 0; sIdx < ships.length; sIdx++) {
      final ship = ships[sIdx];
      final leader = shipLeader(ship);
      if (leader == seat) continue; // Already leading this ship
      final attacks = (ship['attacks'] as Map).cast<String, int>();
      final myCur = attacks['$seat'] ?? 0;
      var maxEnemy = 0;
      for (final e in attacks.entries) {
        if (e.key != '$seat' && e.value > maxEnemy) {
          maxEnemy = e.value;
        }
      }
      for (var cIdx = 0; cIdx < myHand.length; cIdx++) {
        final card = myHand[cIdx];
        if (canAttackShipWithCard(seat, ship, card)) {
          final str = asInt(card['strength'], 1);
          if (myCur + str > maxEnemy) {
            return {'type': 'attack', 'shipIdx': sIdx, 'cardIdx': cIdx};
          }
        }
      }
    }

    // 2. Launch a Merchant Ship if we have one and also have pirates to defend/attack
    for (var cIdx = 0; cIdx < myHand.length; cIdx++) {
      if (myHand[cIdx]['kind'] == 'merchant') {
        return {'type': 'launch', 'cardIdx': cIdx};
      }
    }

    // 3. Any legal attack on an active ship
    for (var sIdx = 0; sIdx < ships.length; sIdx++) {
      for (var cIdx = 0; cIdx < myHand.length; cIdx++) {
        if (canAttackShipWithCard(seat, ships[sIdx], myHand[cIdx])) {
          return {'type': 'attack', 'shipIdx': sIdx, 'cardIdx': cIdx};
        }
      }
    }

    // 4. Otherwise draw a card
    return {'type': 'draw'};
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    gold[seat] = -999;
    phase = 'over';
    lastEvent = '${name(seat)} 降帆投降，海盗战结束！';
    host.log(lastEvent);
  }
}
