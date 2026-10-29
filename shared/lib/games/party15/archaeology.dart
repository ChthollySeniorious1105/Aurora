import 'dart:math';

import '../../src/engine.dart';

const List<String> kArchCardNames = [
  '🏺 陶片',
  '🪙 古币',
  '🪬 护身符',
  '🏆 圣杯',
  '📜 莎草纸',
  '👑 法老面具',
  '🗺️ 藏宝图',
  '🥷 盗贼',
  '🌪️ 沙尘暴',
];

const List<int> kArchTradeValues = [1, 2, 3, 4, 4, 5, 3];

const List<List<int>> kArchSetValues = [
  [1, 2, 3, 4, 5], // 0: Shard (1..5)
  [2, 5, 10, 18, 30], // 1: Coin (1..5)
  [3, 7, 14, 24, 40], // 2: Talisman (1..5)
  [4, 10, 20, 35], // 3: Cup (1..4)
  [5, 12, 24, 42], // 4: Scroll (1..4)
  [6, 16, 32], // 5: Mask (1..3)
];

int archSetGold(int artifact, int count) {
  if (artifact < 0 || artifact >= kArchSetValues.length || count <= 0) return 0;
  final table = kArchSetValues[artifact];
  var total = 0;
  var rem = count;
  while (rem > 0) {
    final take = min(rem, table.length);
    total += table[take - 1];
    rem -= take;
  }
  return total;
}

class ArchaeologyGame extends GameEngine {
  ArchaeologyGame(super.setup);

  static const int cardMap = 6;
  static const int cardThief = 7;
  static const int cardSandstorm = 8;

  List<int> digDeck = [];
  late List<List<int>> hands;
  List<int> market = [];
  late List<List<int>> pyramid; // 3 chambers: cost 1, 2, 3 Maps
  late List<List<int>> museum; // museum[seat][0..5]
  late List<int> gold;
  late List<int> sandstormRemaining;

  int turn = 0;
  String phase = 'action'; // 'action', 'thief', 'sandstorm', 'over'
  int finalTurnsLeft = -1;
  String lastEvent = '';
  bool _over = false;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over ? rankByScore(gold) : null;

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'sandstorm') {
      return [
        for (var s = 0; s < players; s++)
          if (sandstormRemaining[s] > 0) s,
      ];
    }
    return [turn];
  }

  @override
  void start() {
    final fast = setup.opt<String>('mode', 'standard') == 'fast';
    final treasures = <int>[
      for (var i = 0; i < (fast ? 14 : 18); i++) 0, // Shard
      for (var i = 0; i < (fast ? 10 : 14); i++) 1, // Coin
      for (var i = 0; i < (fast ? 9 : 12); i++) 2, // Talisman
      for (var i = 0; i < (fast ? 6 : 8); i++) 3, // Cup
      for (var i = 0; i < (fast ? 5 : 6); i++) 4, // Scroll
      for (var i = 0; i < 4; i++) 5, // Mask
      for (var i = 0; i < 6; i++) 6, // Map
    ];
    treasures.shuffle(rng);

    var cursor = 0;
    hands = [
      for (var s = 0; s < players; s++)
        [for (var i = 0; i < 4; i++) treasures[cursor++]],
    ];
    market = [for (var i = 0; i < 5; i++) treasures[cursor++]];
    pyramid = [
      [for (var i = 0; i < 3; i++) treasures[cursor++]], // Chamber 0 (1 Map)
      [for (var i = 0; i < 5; i++) treasures[cursor++]], // Chamber 1 (2 Maps)
      [for (var i = 0; i < 7; i++) treasures[cursor++]], // Chamber 2 (3 Maps)
    ];

    // Seat 0 draws 1 initial treasure card for turn 1
    final firstDraw = treasures[cursor++];
    hands[0].add(firstDraw);

    digDeck = treasures.sublist(cursor);
    final numThieves = fast ? 4 : 6;
    final numSandstorms = fast ? 4 : 5;
    for (var i = 0; i < numThieves; i++) {
      digDeck.add(cardThief);
    }
    for (var i = 0; i < numSandstorms; i++) {
      digDeck.add(cardSandstorm);
    }
    digDeck.shuffle(rng);

    museum = [
      for (var s = 0; s < players; s++) List<int>.filled(6, 0),
    ];
    gold = List<int>.filled(players, 0);
    sandstormRemaining = List<int>.filled(players, 0);
    turn = 0;
    phase = 'action';
    finalTurnsLeft = -1;
    _over = false;
    lastEvent = '探险开始！${name(0)} 挖掘到了 ${kArchCardNames[firstDraw]}。';
    host.log(lastEvent);
  }

  /// Resolves drawing [card] for [seat] (Treasure 0..6, Thief 7, or Sandstorm 8).
  void resolveDigCard(int seat, int card) {
    if (card >= 0 && card <= 6) {
      hands[seat].add(card);
      phase = 'action';
      lastEvent = '${name(seat)} 从挖掘场抽到了 ${kArchCardNames[card]}。';
      host.log(lastEvent);
      return;
    }
    if (card == cardThief) {
      final targets = [
        for (var s = 0; s < players; s++)
          if (s != seat && hands[s].isNotEmpty) s,
      ];
      if (targets.isEmpty) {
        phase = 'action';
        lastEvent = '${name(seat)} 遭遇了 🥷 盗贼，但其他玩家手牌为空！';
      } else {
        phase = 'thief';
        lastEvent = '${name(seat)} 抽到了 🥷 盗贼！请选择一名对手随机偷取 1 张手牌。';
      }
      host.log(lastEvent);
      return;
    }
    if (card == cardSandstorm) {
      var anyAffected = false;
      for (var s = 0; s < players; s++) {
        if (hands[s].length > 4) {
          sandstormRemaining[s] = hands[s].length ~/ 2;
          anyAffected = true;
        } else {
          sandstormRemaining[s] = 0;
        }
      }
      if (anyAffected) {
        phase = 'sandstorm';
        lastEvent = '🌪️ 沙尘暴来袭！手牌超过 4 张的玩家必须弃置一半手牌到集市！';
      } else {
        phase = 'action';
        lastEvent = '🌪️ 沙尘暴席卷而过，所有玩家手牌均不超过 4 张，安然无恙！';
      }
      host.log(lastEvent);
    }
  }

  void _startTurnFor(int seat) {
    turn = seat;
    if (digDeck.isEmpty) {
      phase = 'action';
      lastEvent = '挖掘场已空，轮到 ${name(turn)} 进行最后行动。';
      host.log(lastEvent);
      return;
    }
    final card = digDeck.removeLast();
    if (digDeck.isEmpty && finalTurnsLeft < 0) {
      finalTurnsLeft = players;
    }
    resolveDigCard(turn, card);
  }

  void _finishGame() {
    // Auto-sell any remaining artifacts (0..5) in each player's hand so no sets go unbanked
    for (var s = 0; s < players; s++) {
      for (var art = 0; art < 6; art++) {
        final cnt = hands[s].where((c) => c == art).length;
        if (cnt > 0) {
          hands[s].removeWhere((c) => c == art);
          museum[s][art] += cnt;
          gold[s] += archSetGold(art, cnt);
        }
      }
    }
    _over = true;
    phase = 'over';
    final best = gold.reduce(max);
    final winners = [
      for (var s = 0; s < players; s++)
        if (gold[s] == best) name(s),
    ];
    lastEvent = '考古探险结束！获胜者：${winners.join('、')}（$best 金币）';
    host.log(lastEvent);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'sandstorm') {
      if (sandstormRemaining[seat] <= 0) {
        throw GameError('你不需要在沙尘暴中弃牌');
      }
      if (type != 'sandstorm') {
        throw GameError('请先完成沙尘暴弃牌');
      }
      final rawCards = action['cards'];
      List<int> toDiscard;
      if (rawCards is List && rawCards.isNotEmpty) {
        toDiscard = asIntList(rawCards);
      } else if (action.containsKey('card')) {
        toDiscard = [asInt(action['card'])];
      } else {
        toDiscard = hands[seat].sublist(0, sandstormRemaining[seat]);
      }
      if (toDiscard.length > sandstormRemaining[seat]) {
        throw GameError('只需弃置 ${sandstormRemaining[seat]} 张牌');
      }
      final tempHand = List<int>.of(hands[seat]);
      for (final c in toDiscard) {
        final idx = tempHand.indexOf(c);
        if (idx < 0) throw GameError('手牌中没有该卡牌');
        tempHand.removeAt(idx);
      }
      hands[seat] = tempHand;
      market.addAll(toDiscard);
      sandstormRemaining[seat] -= toDiscard.length;
      if (sandstormRemaining.every((r) => r <= 0)) {
        phase = 'action';
        lastEvent = '沙尘暴平息，轮到 ${name(turn)} 行动。';
      } else {
        lastEvent = '${name(seat)} 向集市遗落了 ${toDiscard.length} 张牌。';
      }
      host.log(lastEvent);
      return;
    }

    if (seat != turn) throw GameError('还没轮到你行动');

    if (phase == 'thief') {
      if (type != 'thief') throw GameError('请先选择盗贼偷取的目标玩家');
      var target = asInt(action['target']);
      if (target < 0 || target >= players || target == seat || hands[target].isEmpty) {
        // Fallback if only one valid target or invalid target specified
        throw GameError('无效的偷取目标');
      }
      final idx = rng.nextInt(hands[target].length);
      final stolen = hands[target].removeAt(idx);
      hands[seat].add(stolen);
      phase = 'action';
      lastEvent = '${name(seat)} 发动🥷盗贼，从 ${name(target)} 手中偷走了 1 张牌！';
      host.log(lastEvent);
      return;
    }

    if (phase != 'action') throw GameError('当前阶段无法执行此操作');

    switch (type) {
      case 'dig':
        if (digDeck.isEmpty) throw GameError('挖掘场已空');
        final card = digDeck.removeLast();
        resolveDigCard(seat, card);

      case 'trade':
        List<int> give = action['give'] is List
            ? asIntList(action['give'])
            : (action.containsKey('giveCard') ? [asInt(action['giveCard'])] : const []);
        List<int> take = action['take'] is List
            ? asIntList(action['take'])
            : (action.containsKey('takeCard') ? [asInt(action['takeCard'])] : const []);
        if (give.isEmpty || take.isEmpty) {
          throw GameError('请选择要拿出的手牌和要换取的集市牌');
        }
        final tempHand = List<int>.of(hands[seat]);
        var giveVal = 0;
        for (final c in give) {
          final i = tempHand.indexOf(c);
          if (i < 0) throw GameError('手牌中没有指定的交易卡牌');
          tempHand.removeAt(i);
          giveVal += (c >= 0 && c < kArchTradeValues.length) ? kArchTradeValues[c] : 1;
        }
        final tempMarket = List<int>.of(market);
        var takeVal = 0;
        for (final c in take) {
          final i = tempMarket.indexOf(c);
          if (i < 0) throw GameError('集市中没有指定的交易卡牌');
          tempMarket.removeAt(i);
          takeVal += (c >= 0 && c < kArchTradeValues.length) ? kArchTradeValues[c] : 1;
        }
        if (giveVal < takeVal && give.length < take.length) {
          throw GameError('提供的卡牌交易价值不足（提供 $giveVal < 索取 $takeVal）');
        }
        hands[seat] = [...tempHand, ...take];
        market = [...tempMarket, ...give];
        lastEvent = '${name(seat)} 在中央集市用 ${give.length} 张牌换取了 ${take.length} 张牌。';
        host.log(lastEvent);

      case 'pyramid':
        var chamber = asInt(action['chamber'], -1);
        final mapCount = hands[seat].where((c) => c == cardMap).length;
        if (chamber < 0) {
          for (var ch = 2; ch >= 0; ch--) {
            if (pyramid[ch].isNotEmpty && mapCount >= ch + 1) {
              chamber = ch;
              break;
            }
          }
        }
        if (chamber < 0 || chamber >= 3) {
          throw GameError('请选择有效的金字塔密室');
        }
        final cost = chamber + 1;
        if (mapCount < cost) {
          throw GameError('探索该密室需要 $cost 张藏宝图');
        }
        if (pyramid[chamber].isEmpty) {
          throw GameError('该金字塔密室已被探索一空');
        }
        var removed = 0;
        hands[seat].removeWhere((c) {
          if (c == cardMap && removed < cost) {
            removed++;
            return true;
          }
          return false;
        });
        final loot = List<int>.of(pyramid[chamber]);
        pyramid[chamber].clear();
        hands[seat].addAll(loot);
        lastEvent = '${name(seat)} 消耗 $cost 张🗺️藏宝图探索金字塔密室，获得 ${loot.length} 张宝藏！';
        host.log(lastEvent);

      case 'sell':
        final art = asInt(action['artifact']);
        if (art < 0 || art >= 6) {
          throw GameError('只能向博物馆出售文物（0~5）');
        }
        final owned = hands[seat].where((c) => c == art).length;
        if (owned <= 0) {
          throw GameError('手牌中没有该种文物');
        }
        final count = action.containsKey('count') ? asInt(action['count']) : owned;
        if (count <= 0 || count > owned) {
          throw GameError('出售数量无效');
        }
        var removed = 0;
        hands[seat].removeWhere((c) {
          if (c == art && removed < count) {
            removed++;
            return true;
          }
          return false;
        });
        final earned = archSetGold(art, count);
        museum[seat][art] += count;
        gold[seat] += earned;
        lastEvent = '${name(seat)} 向博物馆出售 $count 张 ${kArchCardNames[art]}，获得 +$earned 金币！';
        host.log(lastEvent);

      case 'end_turn':
        if (digDeck.isEmpty) {
          if (finalTurnsLeft < 0) finalTurnsLeft = players;
          finalTurnsLeft--;
          if (finalTurnsLeft <= 0) {
            _finishGame();
            return;
          }
        }
        final next = (turn + 1) % players;
        _startTurnFor(next);

      default:
        throw GameError('未知操作：$type');
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over) return null;
    if (phase == 'sandstorm') {
      if (sandstormRemaining[seat] <= 0) return null;
      // Discard lowest value cards first
      final sorted = List<int>.of(hands[seat])
        ..sort((a, b) => kArchTradeValues[a].compareTo(kArchTradeValues[b]));
      return {
        'type': 'sandstorm',
        'cards': sorted.sublist(0, sandstormRemaining[seat]),
      };
    }
    if (seat != turn) return null;

    if (phase == 'thief') {
      var bestOpp = -1;
      var maxCards = 0;
      for (var s = 0; s < players; s++) {
        if (s != seat && hands[s].length > maxCards) {
          maxCards = hands[s].length;
          bestOpp = s;
        }
      }
      if (bestOpp >= 0) {
        return {'type': 'thief', 'target': bestOpp};
      }
      return null;
    }

    // In 'action' phase:
    // 1. Explore Pyramid if we have enough maps
    final mapCount = hands[seat].where((c) => c == cardMap).length;
    for (var ch = 2; ch >= 0; ch--) {
      if (pyramid[ch].isNotEmpty && mapCount >= ch + 1) {
        return {'type': 'pyramid', 'chamber': ch};
      }
    }

    // 2. Sell full sets or large sets (or any set if deck is empty or hand > 5)
    for (var art = 5; art >= 0; art--) {
      final cnt = hands[seat].where((c) => c == art).length;
      final maxSet = kArchSetValues[art].length;
      if (cnt >= maxSet || (cnt >= 3 && hands[seat].length > 4) || (digDeck.isEmpty && cnt > 0)) {
        return {'type': 'sell', 'artifact': art, 'count': cnt};
      }
    }

    // 3. End turn
    return {'type': 'end_turn'};
  }

  @override
  Map<String, dynamic> view(int seat) => {
        'turn': turn,
        'phase': phase,
        'digCount': digDeck.length,
        'market': List<int>.of(market),
        'pyramidCounts': [for (final ch in pyramid) ch.length],
        'hands': [
          for (var s = 0; s < players; s++)
            (s == seat || _over) ? List<int>.of(hands[s]) : const <int>[],
        ],
        'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
        'museum': [for (var s = 0; s < players; s++) List<int>.of(museum[s])],
        'gold': List<int>.of(gold),
        'sandstormRemaining': List<int>.of(sandstormRemaining),
        'lastEvent': lastEvent,
        'over': _over,
      };
}
