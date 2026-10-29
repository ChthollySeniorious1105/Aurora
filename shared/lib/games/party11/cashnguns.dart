import 'dart:math';

import '../../src/engine.dart';

class LootCard {
  final String id;
  final String kind; // 'cash' | 'diamond' | 'painting' | 'first_aid' | 'clip' | 'godfather'
  final int value;
  final String name;

  const LootCard({
    required this.id,
    required this.kind,
    required this.value,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'value': value,
        'name': name,
      };
}

List<LootCard> buildCashNGunsLootDeck() {
  final deck = <LootCard>[];
  var id = 0;
  for (var i = 0; i < 15; i++) {
    deck.add(LootCard(id: 'loot_${id++}', kind: 'cash', value: 5000, name: '\$5,000 钞票'));
  }
  for (var i = 0; i < 15; i++) {
    deck.add(LootCard(id: 'loot_${id++}', kind: 'cash', value: 10000, name: '\$10,000 钞票'));
  }
  for (var i = 0; i < 10; i++) {
    deck.add(LootCard(id: 'loot_${id++}', kind: 'cash', value: 20000, name: '\$20,000 钞票'));
  }
  for (var i = 0; i < 5; i++) {
    deck.add(LootCard(id: 'loot_${id++}', kind: 'diamond', value: 1000, name: '💎 钻石 \$1,000'));
  }
  for (var i = 0; i < 3; i++) {
    deck.add(LootCard(id: 'loot_${id++}', kind: 'diamond', value: 5000, name: '💎 钻石 \$5,000'));
  }
  deck.add(LootCard(id: 'loot_${id++}', kind: 'diamond', value: 10000, name: '💎 巨钻 \$10,000'));
  for (var i = 0; i < 10; i++) {
    deck.add(LootCard(id: 'loot_${id++}', kind: 'painting', value: 0, name: '🖼️ 名画'));
  }
  for (var i = 0; i < 2; i++) {
    deck.add(LootCard(id: 'loot_${id++}', kind: 'first_aid', value: 0, name: '➕ 急救包'));
  }
  for (var i = 0; i < 2; i++) {
    deck.add(LootCard(id: 'loot_${id++}', kind: 'clip', value: 0, name: '🔫 实弹弹夹'));
  }
  deck.add(LootCard(id: 'loot_${id++}', kind: 'godfather', value: 0, name: '🎩 教父宝座'));
  return deck;
}

/// Set-collection value for paintings: 1->$4k, 2->$12k, 3->$30k, 4->$60k, 5+->$100k.
int cashNGunsPaintingValue(int count) {
  if (count <= 0) return 0;
  const table = [0, 4000, 12000, 30000, 60000, 100000];
  return count < table.length ? table[count] : 100000;
}

class CashNGunsGame extends GameEngine {
  CashNGunsGame(super.setup);

  late int maxRounds;
  int round = 1;
  int godfather = 0;
  String phase = 'aim'; // 'aim' | 'courage' | 'loot' | 'end'

  late List<int> wounds;
  late List<List<String>> ammo;
  late List<List<LootCard>> lootWon;
  late List<LootCard> deck;
  late List<LootCard> tableLoot;

  late List<int> aimTarget;
  late List<String?> aimBullet;
  late List<String?> courageChoice;
  late List<bool> ducked;
  late List<bool> woundedThisRound;
  late List<String?> revealedBullets;

  List<int> looters = [];
  int lootTurnIdx = 0;
  String lastEvent = '';
  bool _over = false;

  @override
  bool get isOver => _over;

  bool alive(int seat) => seat >= 0 && seat < players && wounds[seat] < 3;

  int get aliveCount {
    var c = 0;
    for (var s = 0; s < players; s++) {
      if (alive(s)) c++;
    }
    return c;
  }

  int diamondCount(int seat) => lootWon[seat].where((c) => c.kind == 'diamond').length;
  int paintingCount(int seat) => lootWon[seat].where((c) => c.kind == 'painting').length;

  /// Seat of the surviving player who has the strictly highest diamond count (>0), or -1 if tied/none.
  int get diamondBonusWinner {
    var maxD = 0;
    var bestSeat = -1;
    var tie = false;
    for (var s = 0; s < players; s++) {
      if (!alive(s)) continue;
      final d = diamondCount(s);
      if (d > maxD) {
        maxD = d;
        bestSeat = s;
        tie = false;
      } else if (d == maxD && d > 0) {
        tie = true;
      }
    }
    return (maxD > 0 && !tie) ? bestSeat : -1;
  }

  /// Total loot score in dollars for [seat] (0 if eliminated).
  int totalCash(int seat) {
    if (!alive(seat)) return 0;
    var sum = 0;
    for (final c in lootWon[seat]) {
      if (c.kind == 'cash' || c.kind == 'diamond') {
        sum += c.value;
      }
    }
    sum += cashNGunsPaintingValue(paintingCount(seat));
    if (diamondBonusWinner == seat) {
      sum += 60000;
    }
    return sum;
  }

  @override
  void start() {
    maxRounds = setup.opt<int>('rounds', 8);
    round = 1;
    godfather = 0;
    wounds = List<int>.filled(players, 0);
    ammo = [
      for (var s = 0; s < players; s++)
        ['click', 'click', 'click', 'click', 'click', 'bang', 'bang', 'bang'],
    ];
    lootWon = [for (var s = 0; s < players; s++) <LootCard>[]];
    deck = shuffled(buildCashNGunsLootDeck(), rng);
    tableLoot = [];
    aimTarget = List<int>.filled(players, -1);
    aimBullet = List<String?>.filled(players, null);
    courageChoice = List<String?>.filled(players, null);
    ducked = List<bool>.filled(players, false);
    woundedThisRound = List<bool>.filled(players, false);
    revealedBullets = List<String?>.filled(players, null);
    _over = false;
    _startRound();
  }

  void _startRound() {
    if (round > maxRounds || aliveCount <= 1 || deck.length < 8) {
      _finishGame();
      return;
    }
    // Check if all alive players are out of ammo
    if ([for (var s = 0; s < players; s++) if (alive(s)) ammo[s].length].every((n) => n == 0)) {
      _finishGame();
      return;
    }
    tableLoot = [for (var i = 0; i < 8 && deck.isNotEmpty; i++) deck.removeAt(0)];
    for (var s = 0; s < players; s++) {
      aimTarget[s] = -1;
      aimBullet[s] = null;
      courageChoice[s] = null;
      ducked[s] = false;
      woundedThisRound[s] = false;
      revealedBullets[s] = null;
    }
    looters = [];
    lootTurnIdx = 0;
    phase = 'aim';
    lastEvent = '第 $round / $maxRounds 轮开始：所有幸存玩家同时选择子弹并瞄准一名对手！';
    host.log(lastEvent);
  }

  void _finishGame() {
    _over = true;
    phase = 'end';
    lastEvent = '分赃结束！清点各玩家战利品与钻石加成。';
    host.log(lastEvent);
  }

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'aim') {
      return [
        for (var s = 0; s < players; s++)
          if (alive(s) && aimTarget[s] < 0) s,
      ];
    }
    if (phase == 'courage') {
      return [
        for (var s = 0; s < players; s++)
          if (alive(s) && courageChoice[s] == null) s,
      ];
    }
    if (phase == 'loot' && looters.isNotEmpty) {
      return [looters[lootTurnIdx % looters.length]];
    }
    return const [];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (!waitingFor.contains(seat)) throw GameError('当前无需你操作');
    final type = asStr(action['type']);

    if (phase == 'aim') {
      if (type != 'aim') throw GameError('请执行瞄准操作');
      final target = asInt(action['target'], -1);
      final bullet = asStr(action['bullet']);
      if (target == seat || !alive(target)) {
        throw GameError('必须瞄准一名存活的其他玩家');
      }
      if ((bullet != 'click' && bullet != 'bang') || !ammo[seat].contains(bullet)) {
        throw GameError('你手中没有该类型的子弹 ($bullet)');
      }
      aimTarget[seat] = target;
      aimBullet[seat] = bullet;

      if (waitingFor.isEmpty) {
        phase = 'courage';
        // Untargeted alive players automatically hold ground ('stay')
        for (var s = 0; s < players; s++) {
          if (alive(s) && !aimTarget.contains(s)) {
            courageChoice[s] = 'stay';
          }
        }
        lastEvent = '所有玩家已举枪！被瞄准的玩家请选择【坚守】或【卧倒】';
        host.log(lastEvent);
        if (waitingFor.isEmpty) {
          _resolveStandoff();
        }
      }
      return;
    }

    if (phase == 'courage') {
      if (type != 'courage') throw GameError('请选择坚守 (stay) 或卧倒 (duck)');
      final choice = asStr(action['choice']);
      if (choice != 'stay' && choice != 'duck') {
        throw GameError('无效的选择：$choice');
      }
      courageChoice[seat] = choice;
      if (waitingFor.isEmpty) {
        _resolveStandoff();
      }
      return;
    }

    if (phase == 'loot') {
      if (type != 'loot') throw GameError('请挑选一张战利品');
      var idx = asInt(action['index'], -1);
      if (idx < 0 || idx >= tableLoot.length) {
        final cardId = asStr(action['card']);
        idx = tableLoot.indexWhere((c) => c.id == cardId);
      }
      if (idx < 0 || idx >= tableLoot.length) {
        throw GameError('无效的战利品索引');
      }
      final card = tableLoot.removeAt(idx);
      lootWon[seat].add(card);
      var extra = '';
      if (card.kind == 'first_aid') {
        wounds[seat] = 0;
        extra = '（治愈全部伤势！）';
      } else if (card.kind == 'clip') {
        ammo[seat].add('bang');
        extra = '（获得 1 发实弹！）';
      } else if (card.kind == 'godfather') {
        godfather = seat;
        extra = '（夺取教父宝座！）';
      }
      lastEvent = '${name(seat)} 拿走了【${card.name}】$extra';
      host.log(lastEvent);

      lootTurnIdx++;
      if (tableLoot.isEmpty) {
        round++;
        _startRound();
      }
      return;
    }

    throw GameError('未知阶段或操作');
  }

  void _resolveStandoff() {
    // Discard used ammo and mark ducking players
    for (var s = 0; s < players; s++) {
      if (!alive(s)) continue;
      final b = aimBullet[s];
      if (b != null) {
        ammo[s].remove(b);
      }
      ducked[s] = courageChoice[s] == 'duck';
      revealedBullets[s] = b;
    }

    // Standing players fire at standing targets
    final hitLogs = <String>[];
    for (var s = 0; s < players; s++) {
      if (!alive(s) || ducked[s]) continue;
      final t = aimTarget[s];
      if (t >= 0 && !ducked[t] && aimBullet[s] == 'bang') {
        wounds[t] = min(3, wounds[t] + 1);
        woundedThisRound[t] = true;
        hitLogs.add('${name(s)} 实弹击中 ${name(t)}');
      }
    }

    // Ensure godfather is alive if possible
    if (!alive(godfather)) {
      for (var i = 1; i < players; i++) {
        final cand = (godfather + i) % players;
        if (alive(cand)) {
          godfather = cand;
          break;
        }
      }
    }

    looters = [
      for (var i = 0; i < players; i++) (godfather + i) % players,
    ].where((s) => alive(s) && !ducked[s] && !woundedThisRound[s]).toList();

    if (aliveCount == 0) {
      _finishGame();
      return;
    }

    if (looters.isEmpty) {
      tableLoot.clear();
      lastEvent = hitLogs.isEmpty ? '全员卧倒，无人参与本轮分赃！' : '${hitLogs.join('；')}。无人毫发无伤，本轮战利品作废！';
      host.log(lastEvent);
      round++;
      _startRound();
    } else {
      phase = 'loot';
      lootTurnIdx = 0;
      final prefix = hitLogs.isEmpty ? '无人中弹！' : '${hitLogs.join('；')}！';
      lastEvent = '$prefix 毫发无伤的坚守者按顺位挑选战利品';
      host.log(lastEvent);
    }
  }

  @override
  List<int>? get placings {
    if (!_over) return null;
    return rankByScore([
      for (var s = 0; s < players; s++) (alive(s) ? 10000000 + totalCash(s) : -wounds[s]),
    ]);
  }

  @override
  Map<String, dynamic> view(int seat) {
    final showTargets = phase != 'aim';
    final showBullets = phase == 'loot' || phase == 'end';
    return {
      'round': round,
      'maxRounds': maxRounds,
      'phase': phase,
      'godfather': godfather,
      'wounds': wounds,
      'alive': [for (var s = 0; s < players; s++) alive(s)],
      'ammoCounts': [for (var s = 0; s < players; s++) ammo[s].length],
      'myAmmo': seat >= 0 && seat < players ? ammo[seat] : const <String>[],
      'myAimTarget': seat >= 0 && seat < players ? aimTarget[seat] : -1,
      'myAimBullet': seat >= 0 && seat < players ? aimBullet[seat] : null,
      'myCourage': seat >= 0 && seat < players ? courageChoice[seat] : null,
      'hasAimed': [for (var s = 0; s < players; s++) aimTarget[s] >= 0],
      'aimTargets': showTargets ? aimTarget : [for (var s = 0; s < players; s++) s == seat ? aimTarget[s] : -1],
      'hasChosenCourage': [for (var s = 0; s < players; s++) courageChoice[s] != null],
      'ducked': showBullets ? ducked : List<bool>.filled(players, false),
      'woundedThisRound': showBullets ? woundedThisRound : List<bool>.filled(players, false),
      'revealedBullets': showBullets ? revealedBullets : List<String?>.filled(players, null),
      'tableLoot': [for (final c in tableLoot) c.toJson()],
      'looters': looters,
      'lootTurn': (phase == 'loot' && looters.isNotEmpty) ? looters[lootTurnIdx % looters.length] : -1,
      'lootWon': [
        for (var s = 0; s < players; s++) [for (final c in lootWon[s]) c.toJson()],
      ],
      'totalCash': [for (var s = 0; s < players; s++) totalCash(s)],
      'diamondCounts': [for (var s = 0; s < players; s++) diamondCount(s)],
      'paintingCounts': [for (var s = 0; s < players; s++) paintingCount(s)],
      'diamondBonusWinner': diamondBonusWinner,
      'lastEvent': lastEvent,
      if (_over) 'placings': placings,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || !waitingFor.contains(seat)) return null;

    if (phase == 'aim') {
      final targets = [for (var s = 0; s < players; s++) if (s != seat && alive(s)) s];
      if (targets.isEmpty) return null;
      // Prefer aiming at the richest alive opponent on higher bot levels
      targets.sort((a, b) => totalCash(b).compareTo(totalCash(a)));
      final target = botLevel == 0 ? targets[rng.nextInt(targets.length)] : targets.first;
      final myHand = ammo[seat];
      final hasBang = myHand.contains('bang');
      final hasClick = myHand.contains('click');
      String bullet;
      if (hasBang && hasClick) {
        bullet = rng.nextDouble() < 0.4 ? 'bang' : 'click';
      } else {
        bullet = myHand.first;
      }
      return {'type': 'aim', 'target': target, 'bullet': bullet};
    }

    if (phase == 'courage') {
      final gunsAtMe = aimTarget.where((t) => t == seat).length;
      if (wounds[seat] >= 2 && gunsAtMe >= 1) {
        return {'type': 'courage', 'choice': 'duck'};
      }
      if (gunsAtMe >= 2 && rng.nextDouble() < 0.7) {
        return {'type': 'courage', 'choice': 'duck'};
      }
      return {'type': 'courage', 'choice': 'stay'};
    }

    if (phase == 'loot') {
      if (tableLoot.isEmpty) return null;
      var bestIdx = 0;
      var bestScore = -1;
      for (var i = 0; i < tableLoot.length; i++) {
        final c = tableLoot[i];
        var val = c.value;
        if (c.kind == 'first_aid') {
          val = wounds[seat] >= 2 ? 25000 : (wounds[seat] == 1 ? 9000 : 1000);
        } else if (c.kind == 'diamond') {
          val = c.value + 12000;
        } else if (c.kind == 'painting') {
          final curP = paintingCount(seat);
          val = cashNGunsPaintingValue(curP + 1) - cashNGunsPaintingValue(curP);
        } else if (c.kind == 'godfather') {
          val = godfather == seat ? 1000 : 11000;
        } else if (c.kind == 'clip') {
          val = 8000;
        }
        if (val > bestScore) {
          bestScore = val;
          bestIdx = i;
        }
      }
      return {'type': 'loot', 'index': bestIdx};
    }

    return null;
  }
}
