import '../../src/engine.dart';

const List<String> kGcbcEquipments = [
  '吐真剂',
  '防弹衣',
  '震撼弹',
  '急救包',
];

class GoodCopBadCopGame extends GameEngine {
  GoodCopBadCopGame(super.setup);

  late List<List<String>> cards; // cards[seat][0..2]: 'AGENT', 'KINGPIN', 'GOOD', 'BAD'
  late List<List<bool>> revealed; // revealed[seat][0..2]
  late List<Map<String, String>> investigated; // investigated[seat]['$target:$slot'] = card
  late List<int> hp;
  late List<int> maxHp;
  late List<bool> alive;
  late List<bool> hasGun;
  late List<int?> aimTarget;
  List<String> equipDeck = [];

  int turn = 0;
  String? winnerFaction; // 'good' or 'bad'
  String lastEvent = '';
  bool _over = false;

  @override
  bool get isOver => _over;

  int get agentSeat => cards.indexWhere((c) => c.contains('AGENT'));
  int get kingpinSeat => cards.indexWhere((c) => c.contains('KINGPIN'));

  String factionOf(int seat) {
    final c = cards[seat];
    if (c.contains('AGENT')) return 'good';
    if (c.contains('KINGPIN')) return 'bad';
    final goodCount = c.where((x) => x == 'GOOD').length;
    return goodCount >= 2 ? 'good' : 'bad';
  }

  List<String> get factions => [for (var s = 0; s < players; s++) factionOf(s)];

  @override
  List<int>? get placings {
    if (!_over || winnerFaction == null) return null;
    final winners = [
      for (var s = 0; s < players; s++)
        if (factionOf(s) == winnerFaction) s,
    ];
    return rankWinners(players, winners);
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    // Build integrity deck so AGENT and KINGPIN are guaranteed on different seats
    final seatOrder = shuffled([for (var s = 0; s < players; s++) s], rng);
    final aSeat = seatOrder[0];
    final kSeat = seatOrder[1];

    final totalOtherCards = players * 3 - 2;
    final goodCards = totalOtherCards ~/ 2;
    final badCards = totalOtherCards - goodCards;
    final pool = <String>[
      for (var i = 0; i < goodCards; i++) 'GOOD',
      for (var i = 0; i < badCards; i++) 'BAD',
    ]..shuffle(rng);

    var cursor = 0;
    cards = List<List<String>>.generate(players, (s) {
      if (s == aSeat) {
        final hand = ['AGENT', pool[cursor++], pool[cursor++]];
        hand.shuffle(rng);
        return hand;
      }
      if (s == kSeat) {
        final hand = ['KINGPIN', pool[cursor++], pool[cursor++]];
        hand.shuffle(rng);
        return hand;
      }
      final hand = [pool[cursor++], pool[cursor++], pool[cursor++]];
      hand.shuffle(rng);
      return hand;
    });

    revealed = [
      for (var s = 0; s < players; s++) [false, false, false],
    ];
    investigated = [
      for (var s = 0; s < players; s++) <String, String>{},
    ];
    hp = [
      for (var s = 0; s < players; s++)
        (s == aSeat || s == kSeat) ? 2 : 1,
    ];
    maxHp = List<int>.of(hp);
    alive = List<bool>.filled(players, true);
    hasGun = List<bool>.filled(players, false);
    aimTarget = List<int?>.filled(players, null);

    equipDeck = [
      for (var i = 0; i < 4; i++) ...kGcbcEquipments,
    ]..shuffle(rng);

    turn = 0;
    winnerFaction = null;
    _over = false;
    lastEvent = '无间警局开局！轮到 ${name(turn)} 行动。';
    host.log(lastEvent);
  }

  int _firstUnrevealedSlot(int seat) {
    for (var i = 0; i < 3; i++) {
      if (!revealed[seat][i]) return i;
    }
    return -1;
  }

  void _flipOwnCardIfNeeded(int seat, int? requestedSlot) {
    if (requestedSlot != null && requestedSlot >= 0 && requestedSlot < 3 && !revealed[seat][requestedSlot]) {
      revealed[seat][requestedSlot] = true;
      return;
    }
    final slot = _firstUnrevealedSlot(seat);
    if (slot >= 0) {
      revealed[seat][slot] = true;
    }
  }

  int _defaultEnemyTarget(int seat) {
    for (var i = 1; i < players; i++) {
      final p = (seat + i) % players;
      if (alive[p]) return p;
    }
    return (seat + 1) % players;
  }

  void _advanceTurn() {
    if (_over) return;
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (alive[next]) {
        turn = next;
        // If current player's aim target died, clear aimTarget
        if (aimTarget[turn] != null && !alive[aimTarget[turn]!]) {
          aimTarget[turn] = _defaultEnemyTarget(turn);
        }
        return;
      }
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');
    if (!alive[seat]) throw GameError('你已出局');

    final type = asStr(action['type']);
    switch (type) {
      case 'investigate':
        final target = asInt(action['target'], _defaultEnemyTarget(seat));
        if (target < 0 || target >= players || target == seat || !alive[target]) {
          throw GameError('请选择一名存活的其他玩家进行调查');
        }
        var slot = asInt(action['slot'], -1);
        if (slot < 0 || slot >= 3) {
          slot = _firstUnrevealedSlot(target);
          if (slot < 0) slot = 0;
        }
        final seenCard = cards[target][slot];
        investigated[seat]['$target:$slot'] = seenCard;
        lastEvent = '${name(seat)} 秘密调查了 ${name(target)} 的 ${slot + 1} 号身份牌。';
        host.log(lastEvent);
        _advanceTurn();

      case 'equip':
        final reqSlot = action.containsKey('slot') ? asInt(action['slot']) : null;
        _flipOwnCardIfNeeded(seat, reqSlot);
        if (equipDeck.isEmpty) {
          equipDeck = [...kGcbcEquipments]..shuffle(rng);
        }
        var equip = asStr(action['equip']);
        if (!kGcbcEquipments.contains(equip)) {
          equip = equipDeck.removeLast();
        }
        _applyEquipment(seat, equip, action);
        _advanceTurn();

      case 'arm':
        if (hasGun[seat]) throw GameError('你已经持有手枪');
        final reqSlot = action.containsKey('slot') ? asInt(action['slot']) : null;
        _flipOwnCardIfNeeded(seat, reqSlot);
        var target = asInt(action['target'], _defaultEnemyTarget(seat));
        if (target < 0 || target >= players || target == seat || !alive[target]) {
          target = _defaultEnemyTarget(seat);
        }
        hasGun[seat] = true;
        aimTarget[seat] = target;
        lastEvent = '${name(seat)} 翻开一张身份牌，拔出🔫手枪瞄准了 ${name(target)}！';
        host.log(lastEvent);
        _advanceTurn();

      case 'aim':
        if (!hasGun[seat]) throw GameError('你还没有手枪，请先拔枪');
        final target = asInt(action['target'], -1);
        if (target < 0 || target >= players || target == seat || !alive[target]) {
          throw GameError('请选择一名存活的其他玩家作为瞄准目标');
        }
        aimTarget[seat] = target;
        lastEvent = '${name(seat)} 将🔫枪口重新瞄准了 ${name(target)}！';
        host.log(lastEvent);
        _advanceTurn();

      case 'shoot':
        if (!hasGun[seat]) throw GameError('你还没有手枪，无法开枪');
        var target = action.containsKey('target')
            ? asInt(action['target'])
            : (aimTarget[seat] ?? -1);
        if (target < 0 || target >= players || target == seat || !alive[target]) {
          throw GameError('瞄准目标无效或已出局');
        }
        aimTarget[seat] = target;
        hp[target] -= 1;
        if (hp[target] <= 0) {
          hp[target] = 0;
          alive[target] = false;
          hasGun[target] = false;
          aimTarget[target] = null;
          revealed[target] = [true, true, true];
          if (cards[target].contains('AGENT')) {
            _over = true;
            winnerFaction = 'bad';
            lastEvent =
                '💥 ${name(seat)} 开枪击倒了正义首领 ${name(target)}（AGENT）！黑帮阵营（BAD）获胜！';
            host.log(lastEvent);
            return;
          }
          if (cards[target].contains('KINGPIN')) {
            _over = true;
            winnerFaction = 'good';
            lastEvent =
                '💥 ${name(seat)} 开枪击倒了黑帮教父 ${name(target)}（KINGPIN）！正义警探阵营（GOOD）获胜！';
            host.log(lastEvent);
            return;
          }
          lastEvent = '💥 ${name(seat)} 开枪击倒了 ${name(target)}！';
        } else {
          // Reveal Boss card if wounded so everyone knows why they survived
          final bossIdx = cards[target].indexWhere((c) => c == 'AGENT' || c == 'KINGPIN');
          if (bossIdx >= 0) {
            revealed[target][bossIdx] = true;
          }
          lastEvent = '💥 ${name(seat)} 开枪击中了 ${name(target)}（剩余 ${hp[target]} HP）！';
        }
        host.log(lastEvent);
        _advanceTurn();

      default:
        throw GameError('未知操作：$type');
    }
  }

  void _applyEquipment(int seat, String equip, Map<String, dynamic> action) {
    switch (equip) {
      case '吐真剂':
        var target = asInt(action['target'], -1);
        if (target < 0 || target >= players || target == seat || !alive[target] || _firstUnrevealedSlot(target) < 0) {
          target = -1;
          for (var s = 0; s < players; s++) {
            if (s != seat && alive[s] && _firstUnrevealedSlot(s) >= 0) {
              target = s;
              break;
            }
          }
        }
        if (target >= 0) {
          final slot = _firstUnrevealedSlot(target);
          if (slot >= 0) {
            revealed[target][slot] = true;
            lastEvent =
                '${name(seat)} 使用装备【💉吐真剂】，迫使 ${name(target)} 公开了身份牌（${cards[target][slot]}）！';
            host.log(lastEvent);
            return;
          }
        }
        lastEvent = '${name(seat)} 抽到【💉吐真剂】，但场上已无未公开身份牌。';
        host.log(lastEvent);

      case '防弹衣':
        hp[seat] += 1;
        maxHp[seat] += 1;
        lastEvent = '${name(seat)} 使用装备【🦺防弹衣】，生命值提升至 ${hp[seat]} HP！';
        host.log(lastEvent);

      case '震撼弹':
        var target = asInt(action['target'], -1);
        if (target < 0 || target >= players || target == seat || !hasGun[target]) {
          target = -1;
          for (var s = 0; s < players; s++) {
            if (s != seat && alive[s] && hasGun[s]) {
              target = s;
              break;
            }
          }
        }
        if (target >= 0 && hasGun[target]) {
          hasGun[target] = false;
          aimTarget[target] = null;
          lastEvent = '${name(seat)} 使用装备【💣震撼弹】，缴械了 ${name(target)} 的手枪！';
        } else {
          hp[seat] += 1;
          maxHp[seat] += 1;
          lastEvent = '${name(seat)} 使用装备【💣震撼弹】（无人持枪，转为防卫姿态 +1 HP）！';
        }
        host.log(lastEvent);

      case '急救包':
        var target = asInt(action['target'], seat);
        if (target < 0 || target >= players || !alive[target]) target = seat;
        if (hp[target] < maxHp[target]) {
          hp[target] += 1;
        } else {
          hp[seat] += 1;
          maxHp[seat] += 1;
        }
        lastEvent = '${name(seat)} 使用装备【🩹急救包】，恢复了 1 点生命值！';
        host.log(lastEvent);
    }
  }

  /// Bot helper using ONLY information visible to [seat] (own cards, revealed cards, and seat's own investigated map).
  String? _suspectedFaction(int seat, int target) {
    if (target == seat) return factionOf(seat);
    var goodSeen = 0;
    var badSeen = 0;
    for (var i = 0; i < 3; i++) {
      final c = revealed[target][i] ? cards[target][i] : investigated[seat]['$target:$i'];
      if (c == 'AGENT') return 'good';
      if (c == 'KINGPIN') return 'bad';
      if (c == 'GOOD') goodSeen++;
      if (c == 'BAD') badSeen++;
    }
    if (goodSeen >= 2) return 'good';
    if (badSeen >= 2) return 'bad';
    if (goodSeen > badSeen) return 'good';
    if (badSeen > goodSeen) return 'bad';
    return null;
  }

  bool _isKnownEnemyBoss(int seat, int target, String myFac) {
    final enemyBoss = myFac == 'good' ? 'KINGPIN' : 'AGENT';
    for (var i = 0; i < 3; i++) {
      final c = revealed[target][i] ? cards[target][i] : investigated[seat]['$target:$i'];
      if (c == enemyBoss) return true;
    }
    return false;
  }

  bool _isKnownFriendlyBoss(int seat, int target, String myFac) {
    final friendlyBoss = myFac == 'good' ? 'AGENT' : 'KINGPIN';
    for (var i = 0; i < 3; i++) {
      final c = revealed[target][i] ? cards[target][i] : investigated[seat]['$target:$i'];
      if (c == friendlyBoss) return true;
    }
    return false;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn || !alive[seat]) return null;
    final myFac = factionOf(seat);

    // Find best enemy target
    int? bestTarget;
    for (var s = 0; s < players; s++) {
      if (s == seat || !alive[s]) continue;
      if (_isKnownEnemyBoss(seat, s, myFac)) {
        bestTarget = s;
        break;
      }
    }
    if (bestTarget == null) {
      for (var s = 0; s < players; s++) {
        if (s == seat || !alive[s]) continue;
        if (_isKnownFriendlyBoss(seat, s, myFac)) continue;
        final sf = _suspectedFaction(seat, s);
        if (sf != null && sf != myFac) {
          bestTarget = s;
          break;
        }
      }
    }
    if (bestTarget == null) {
      for (var s = 0; s < players; s++) {
        if (s == seat || !alive[s]) continue;
        if (!_isKnownFriendlyBoss(seat, s, myFac)) {
          bestTarget = s;
          break;
        }
      }
    }
    bestTarget ??= _defaultEnemyTarget(seat);

    if (hasGun[seat]) {
      final curAim = aimTarget[seat];
      if (curAim != null && alive[curAim] && !_isKnownFriendlyBoss(seat, curAim, myFac)) {
        if (bestTarget != curAim && _isKnownEnemyBoss(seat, bestTarget, myFac)) {
          return {'type': 'aim', 'target': bestTarget};
        }
        return {'type': 'shoot'};
      }
      return {'type': 'aim', 'target': bestTarget};
    }

    // Not armed yet: investigate once if nobody has been investigated by this seat, otherwise arm!
    if (investigated[seat].isEmpty && rng.nextDouble() < 0.35) {
      for (var s = 0; s < players; s++) {
        if (s == seat || !alive[s]) continue;
        for (var i = 0; i < 3; i++) {
          if (!revealed[s][i] && !investigated[seat].containsKey('$s:$i')) {
            return {'type': 'investigate', 'target': s, 'slot': i};
          }
        }
      }
    }

    return {'type': 'arm', 'target': bestTarget};
  }

  @override
  Map<String, dynamic> view(int seat) => {
        'turn': turn,
        'cards': [
          for (var s = 0; s < players; s++)
            [
              for (var i = 0; i < 3; i++)
                (_over ||
                        s == seat ||
                        revealed[s][i] ||
                        (seat >= 0 && investigated[seat].containsKey('$s:$i')))
                    ? cards[s][i]
                    : null,
            ],
        ],
        'revealed': [
          for (var s = 0; s < players; s++) List<bool>.of(revealed[s]),
        ],
        'investigated': seat >= 0 && seat < players
            ? Map<String, String>.of(investigated[seat])
            : const <String, String>{},
        'myFaction': seat >= 0 && seat < players ? factionOf(seat) : null,
        'factions': _over ? factions : null,
        'hp': List<int>.of(hp),
        'maxHp': List<int>.of(maxHp),
        'alive': List<bool>.of(alive),
        'hasGun': List<bool>.of(hasGun),
        'aimTarget': List<int?>.of(aimTarget),
        'equipDeckCount': equipDeck.length,
        'winnerFaction': winnerFaction,
        'lastEvent': lastEvent,
        'over': _over,
      };
}
