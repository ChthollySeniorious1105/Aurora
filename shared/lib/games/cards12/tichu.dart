import 'dart:math';

import '../../src/engine.dart';

const String tichuRules = '''
# 地主牌 Tichu 规则说明

## 基本配置
- **人数与组队**：固定 4 人 2v2 搭档对战（座位 0 与 2 一队，座位 1 与 3 一队）。
- **56 张专属牌组**：52 张标准扑克牌（2..A，四门花色 S/H/D/C）+ 4 张特殊牌：
  - **雀（MJ，点数 1，0 分）**：持有雀牌的玩家固定先手首引；打出含雀牌的牌型时，可同时宣告一个**许愿点数（2..A）**，此后首位持有该点数且能合法出牌（含单张或组合）的玩家**必须**打出含该点数的牌，直至愿望达成。
  - **犬（DOG，0 分）**：只能在空桌面领出时单张打出，打出后本墩立即结束，并将领出权直接移交给自己的**搭档**（若搭档已出完手牌，则顺延给搭档下家）。
  - **凤（PHX，-25 分）**：百搭与半级单张。在组合牌（对子、连对、三条、葫芦、顺子）中可充当任意 1 张普通点数（2..A）；作为单张领出时算作 1.5 点，跟打单张时点数等于「桌面当前单张点数 + 0.5」（可压过除龙以外的任何单张，但不能压龙）。
  - **龙（DRG，+25 分，点数 15）**：最强单张（仅能单出，可压过 A 及凤，仅能被炸弹压制）。若用龙赢得一墩，赢家必须将该墩所有牌**赠送给一名对手**（`give_dragon`）。

## 合法牌型与压制规则
- **普通牌型**（跟牌必须同牌型、同张数且点数严格更大）：
  - **单张（single）**：MJ(1) < 2 < 3 < ... < K(13) < A(14) < PHX(上一张+0.5) < DRG(15)。
  - **对子（pair）**、**连对（pair_steps，至少 2 连对）**、**三条（triple）**、**葫芦（full_house，三带二，比较三条点数）**、**顺子（straight，至少 5 张连续点数，MJ 可作 1）**。
- **炸弹（Bomb，可随时压制任何普通牌型、龙或更小的炸弹，不含特殊牌）**：
  - **四条炸弹（four_bomb）**：4 张同点数普通牌。
  - **同花顺炸弹（sf_bomb）**：至少 5 张同花色连续普通牌（任何同花顺炸弹均大于四条炸弹；同花顺炸弹之间先比张数，再比最高点数）。

## 地主宣告（Tichu Call）与计分结算
- **叫地主（Tichu Call）**：任何玩家在打出自己本局第 1 张牌之前，均可宣告「地主（Tichu）」。若该玩家夺得本局**头游（第 1 名出完牌）**，本队额外 **+100 分**；否则本队 **-100 分**。
- **双关（1-2 Double Victory）**：若同一队两名搭档包揽第 1 名（头游）与第 2 名（二游），牌局立即结束，卡牌分直接按 **200 : 0** 结算（外加各自 Tichu 奖惩分）！
- **常规结算**：当第 3 名玩家出完手牌时本局结束：
  - 最后一名未出完牌玩家（末游）的**剩余手牌**归对手队伍所有；
  - 末游本局已吃到的**墩牌（captured）**归本局**头游（第 1 名）**所有；
  - 统计各队分牌：**5（+5 分）**、**10（+10 分）**、**K（+10 分）**、**龙 DRG（+25 分）**、**凤 PHX（-25 分）**，整副牌合计恒为 100 分。
- **终局胜负**：率先达到房间设定目标分（且两队不平分）的队伍获胜。
''';

const List<String> kTichuSuits = ['S', 'H', 'D', 'C'];
const List<String> kTichuRanks = [
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'T',
  'J',
  'Q',
  'K',
  'A',
];

const Map<int, String> kTichuRankLabels = {
  1: '雀(1)',
  2: '2',
  3: '3',
  4: '4',
  5: '5',
  6: '6',
  7: '7',
  8: '8',
  9: '9',
  10: '10',
  11: 'J',
  12: 'Q',
  13: 'K',
  14: 'A',
  15: '龙(DRG)',
};

/// Build the 56-card Tichu deck (52 standard + MJ, DOG, PHX, DRG).
List<String> buildTichuDeck() => [
      for (final r in kTichuRanks)
        for (final s in kTichuSuits) '$r$s',
      'MJ',
      'DOG',
      'PHX',
      'DRG',
    ];

/// Point value of a single Tichu card (deck total = 100).
int tichuCardPoints(String card) {
  if (card == 'DRG') return 25;
  if (card == 'PHX') return -25;
  if (card == 'MJ' || card == 'DOG' || card.isEmpty) return 0;
  final r = card.substring(0, card.length - 1);
  if (r == '5') return 5;
  if (r == 'T' || r == 'K') return 10;
  return 0;
}

/// Numeric rank of a non-Phoenix card:
/// DOG=0, MJ=1, 2..9=2..9, T=10, J=11, Q=12, K=13, A=14, DRG=15.
int tichuCardRank(String card) {
  if (card == 'DOG') return 0;
  if (card == 'MJ') return 1;
  if (card == 'DRG') return 15;
  if (card == 'PHX') return -1;
  final r = card.substring(0, card.length - 1);
  final idx = kTichuRanks.indexOf(r);
  return idx >= 0 ? idx + 2 : 0;
}

String tichuCardSuit(String card) {
  if (card == 'MJ' || card == 'DOG' || card == 'PHX' || card == 'DRG') {
    return '';
  }
  return card.isNotEmpty ? card[card.length - 1] : '';
}

class TichuCombo {
  final String type; // 'single','pair','pair_steps','triple','full_house','straight','four_bomb','sf_bomb','dog'
  final int length;
  final double rank; // primary rank for comparison
  final List<String> cards;

  const TichuCombo({
    required this.type,
    required this.length,
    required this.rank,
    required this.cards,
  });

  bool get isBomb => type == 'four_bomb' || type == 'sf_bomb';

  Map<String, dynamic> toJson() => {
        'type': type,
        'length': length,
        'rank': rank,
        'cards': cards,
      };
}

/// Evaluates whether [cards] form a legal Tichu combination.
/// [lastSingleRank] is used when evaluating a single `'PHX'` on top of a previous single.
TichuCombo? evaluateTichuCombo(List<String> cards, {double? lastSingleRank}) {
  if (cards.isEmpty) return null;
  final n = cards.length;

  if (n == 1) {
    final c = cards.first;
    if (c == 'DOG') {
      return TichuCombo(type: 'dog', length: 1, rank: 0, cards: List.of(cards));
    }
    if (c == 'PHX') {
      final r = lastSingleRank != null ? lastSingleRank + 0.5 : 1.5;
      return TichuCombo(
          type: 'single', length: 1, rank: r, cards: List.of(cards));
    }
    final rk = tichuCardRank(c);
    if (rk <= 0) return null;
    return TichuCombo(
      type: 'single',
      length: 1,
      rank: rk.toDouble(),
      cards: List.of(cards),
    );
  }

  // Multi-card combinations cannot contain DOG or DRG
  if (cards.contains('DOG') || cards.contains('DRG')) return null;

  final hasPhx = cards.contains('PHX');
  final normals = cards.where((c) => c != 'PHX').toList();
  // At most 1 PHX exists in the deck
  if (cards.length - normals.length > 1) return null;

  final ranks = normals.map(tichuCardRank).toList()..sort();
  if (ranks.any((r) => r <= 0)) return null;

  // Pair (2 cards, rank 2..14, MJ cannot be paired)
  if (n == 2) {
    if (ranks.contains(1)) return null;
    if (hasPhx) {
      return TichuCombo(
        type: 'pair',
        length: 2,
        rank: ranks.first.toDouble(),
        cards: List.of(cards),
      );
    }
    if (ranks[0] == ranks[1]) {
      return TichuCombo(
        type: 'pair',
        length: 2,
        rank: ranks[0].toDouble(),
        cards: List.of(cards),
      );
    }
    return null;
  }

  // Triple (3 cards, rank 2..14)
  if (n == 3) {
    if (ranks.contains(1)) return null;
    if (hasPhx && ranks[0] == ranks[1]) {
      return TichuCombo(
        type: 'triple',
        length: 3,
        rank: ranks[0].toDouble(),
        cards: List.of(cards),
      );
    }
    if (!hasPhx && ranks[0] == ranks[1] && ranks[1] == ranks[2]) {
      return TichuCombo(
        type: 'triple',
        length: 3,
        rank: ranks[0].toDouble(),
        cards: List.of(cards),
      );
    }
    return null;
  }

  // 4-of-a-kind Bomb (no PHX, no MJ)
  if (n == 4 && !hasPhx && !ranks.contains(1)) {
    if (ranks[0] == ranks[1] && ranks[1] == ranks[2] && ranks[2] == ranks[3]) {
      return TichuCombo(
        type: 'four_bomb',
        length: 4,
        rank: ranks[0].toDouble(),
        cards: List.of(cards),
      );
    }
  }

  // Full House (5 cards: 3 of a kind + pair, no MJ)
  if (n == 5 && !ranks.contains(1)) {
    final counts = <int, int>{};
    for (final r in ranks) {
      counts[r] = (counts[r] ?? 0) + 1;
    }
    if (!hasPhx && counts.length == 2 && counts.values.contains(3)) {
      final tripleRank =
          counts.entries.firstWhere((e) => e.value == 3).key.toDouble();
      return TichuCombo(
        type: 'full_house',
        length: 5,
        rank: tripleRank,
        cards: List.of(cards),
      );
    }
    if (hasPhx && counts.length == 2) {
      final entries = counts.entries.toList();
      // Could be (3, 1) + PHX or (2, 2) + PHX (pick higher rank as triple)
      if ((entries[0].value == 3 && entries[1].value == 1) ||
          (entries[1].value == 3 && entries[0].value == 1)) {
        final tripleRank =
            entries.firstWhere((e) => e.value == 3).key.toDouble();
        return TichuCombo(
          type: 'full_house',
          length: 5,
          rank: tripleRank,
          cards: List.of(cards),
        );
      }
      if (entries[0].value == 2 && entries[1].value == 2) {
        final tripleRank = max(entries[0].key, entries[1].key).toDouble();
        return TichuCombo(
          type: 'full_house',
          length: 5,
          rank: tripleRank,
          cards: List.of(cards),
        );
      }
    }
  }

  // Pair Steps (连对: even length >= 4, consecutive pairs in 2..14)
  if (n >= 4 && n.isEven && !ranks.contains(1)) {
    final numPairs = n ~/ 2;
    final counts = <int, int>{};
    for (final r in ranks) {
      counts[r] = (counts[r] ?? 0) + 1;
    }
    if (counts.length == numPairs && counts.values.every((v) => v <= 2)) {
      final keys = counts.keys.toList()..sort();
      var consecutive = true;
      for (var i = 1; i < keys.length; i++) {
        if (keys[i] != keys[i - 1] + 1) {
          consecutive = false;
          break;
        }
      }
      final neededPhx =
          counts.values.fold<int>(0, (s, v) => s + (2 - v));
      if (consecutive && neededPhx == (hasPhx ? 1 : 0)) {
        return TichuCombo(
          type: 'pair_steps',
          length: n,
          rank: keys.last.toDouble(),
          cards: List.of(cards),
        );
      }
    }
  }

  // Straight / Straight Flush Bomb (length >= 5, ranks in 1..14)
  if (n >= 5) {
    final uniqueRanks = ranks.toSet();
    if (uniqueRanks.length == ranks.length) {
      final minR = ranks.first;
      final maxR = ranks.last;
      if (!hasPhx && maxR - minR == n - 1) {
        // Check if Straight Flush Bomb (no MJ, all same suit)
        final suits = normals.map(tichuCardSuit).toSet();
        if (!ranks.contains(1) && suits.length == 1 && !suits.contains('')) {
          return TichuCombo(
            type: 'sf_bomb',
            length: n,
            rank: maxR.toDouble(),
            cards: List.of(cards),
          );
        }
        return TichuCombo(
          type: 'straight',
          length: n,
          rank: maxR.toDouble(),
          cards: List.of(cards),
        );
      }
      if (hasPhx && maxR - minR <= n - 1) {
        // PHX fills internal gap or extends high (up to 14) or low (down to 1)
        final highRank =
            (maxR - minR == n - 2) ? min(14, maxR + 1) : maxR;
        if (highRank - (n - 1) >= 1) {
          return TichuCombo(
            type: 'straight',
            length: n,
            rank: highRank.toDouble(),
            cards: List.of(cards),
          );
        }
      }
    }
  }

  return null;
}

/// Returns true if [candidate] can legally beat [current] (or lead when [current] is null).
bool canBeatTichuCombo(TichuCombo candidate, TichuCombo? current) {
  if (current == null) {
    return true;
  }
  if (candidate.type == 'dog') {
    return false; // Dog can only be played on an empty table lead
  }
  if (candidate.isBomb) {
    if (!current.isBomb) return true;
    if (candidate.type == 'sf_bomb' && current.type == 'four_bomb') return true;
    if (candidate.type == 'four_bomb' && current.type == 'sf_bomb') {
      return false;
    }
    if (candidate.length != current.length) {
      return candidate.length > current.length;
    }
    return candidate.rank > current.rank;
  }
  if (current.isBomb) return false;
  if (candidate.type != current.type || candidate.length != current.length) {
    return false;
  }
  // Phoenix single cannot beat Dragon (rank 15)
  if (candidate.type == 'single' &&
      candidate.cards.first == 'PHX' &&
      current.rank >= 15) {
    return false;
  }
  return candidate.rank > current.rank;
}

/// Enumerates legal plays from [hand] given [current] table combo.
List<TichuCombo> generateLegalTichuPlays(
  List<String> hand,
  TichuCombo? current,
) {
  final results = <TichuCombo>[];
  final lastSingle =
      (current != null && current.type == 'single') ? current.rank : null;

  // Group normal cards by rank (1..15)
  final byRank = <int, List<String>>{};
  final bySuit = <String, List<String>>{};
  var hasPhx = false;
  for (final c in hand) {
    if (c == 'PHX') {
      hasPhx = true;
      continue;
    }
    final r = tichuCardRank(c);
    byRank.putIfAbsent(r, () => []).add(c);
    final s = tichuCardSuit(c);
    if (s.isNotEmpty && r >= 2 && r <= 14) {
      bySuit.putIfAbsent(s, () => []).add(c);
    }
  }

  void tryAdd(List<String> cards) {
    final combo = evaluateTichuCombo(cards, lastSingleRank: lastSingle);
    if (combo != null && canBeatTichuCombo(combo, current)) {
      results.add(combo);
    }
  }

  // 1. All 4-of-a-kind bombs and straight flush bombs
  for (final entry in byRank.entries) {
    if (entry.key >= 2 && entry.key <= 14 && entry.value.length == 4) {
      tryAdd(entry.value);
    }
  }
  for (final suitCards in bySuit.values) {
    if (suitCards.length >= 5) {
      final sorted = List<String>.of(suitCards)
        ..sort((a, b) => tichuCardRank(a).compareTo(tichuCardRank(b)));
      for (var len = 5; len <= sorted.length; len++) {
        for (var i = 0; i + len <= sorted.length; i++) {
          final slice = sorted.sublist(i, i + len);
          if (tichuCardRank(slice.last) - tichuCardRank(slice.first) ==
              len - 1) {
            tryAdd(slice);
          }
        }
      }
    }
  }

  // 2. Singles
  if (current == null || current.type == 'single') {
    for (final c in hand) {
      tryAdd([c]);
    }
  }

  // 3. Pairs
  if (current == null || current.type == 'pair') {
    for (final entry in byRank.entries) {
      if (entry.key >= 2 && entry.key <= 14) {
        if (entry.value.length >= 2) {
          tryAdd(entry.value.sublist(0, 2));
        } else if (hasPhx && entry.value.isNotEmpty) {
          tryAdd([entry.value.first, 'PHX']);
        }
      }
    }
  }

  // 4. Triples
  if (current == null || current.type == 'triple') {
    for (final entry in byRank.entries) {
      if (entry.key >= 2 && entry.key <= 14) {
        if (entry.value.length >= 3) {
          tryAdd(entry.value.sublist(0, 3));
        } else if (hasPhx && entry.value.length >= 2) {
          tryAdd([entry.value[0], entry.value[1], 'PHX']);
        }
      }
    }
  }

  // 5. Full Houses
  if (current == null || current.type == 'full_house') {
    final triples = <int, List<String>>{};
    final pairs = <int, List<String>>{};
    for (final e in byRank.entries) {
      if (e.key >= 2 && e.key <= 14) {
        if (e.value.length >= 3) triples[e.key] = e.value.sublist(0, 3);
        if (e.value.length >= 2) pairs[e.key] = e.value.sublist(0, 2);
      }
    }
    for (final t in triples.entries) {
      for (final p in pairs.entries) {
        if (t.key != p.key) {
          tryAdd([...t.value, ...p.value]);
        }
      }
      if (hasPhx) {
        for (final e in byRank.entries) {
          if (e.key >= 2 && e.key <= 14 && e.key != t.key && e.value.isNotEmpty) {
            tryAdd([...t.value, e.value.first, 'PHX']);
          }
        }
      }
    }
    if (hasPhx) {
      for (final p1 in pairs.entries) {
        for (final p2 in pairs.entries) {
          if (p1.key > p2.key) {
            tryAdd([...p1.value, 'PHX', ...p2.value]);
          }
        }
      }
    }
  }

  // 6. Pair Steps (连对)
  if (current == null || current.type == 'pair_steps') {
    final minPairs = current != null ? current.length ~/ 2 : 2;
    final maxPairs = current != null ? current.length ~/ 2 : 7;
    for (var k = minPairs; k <= maxPairs; k++) {
      for (var start = 2; start + k - 1 <= 14; start++) {
        final cards = <String>[];
        var phxUsed = false;
        var ok = true;
        for (var r = start; r < start + k; r++) {
          final list = byRank[r] ?? const [];
          if (list.length >= 2) {
            cards.addAll(list.sublist(0, 2));
          } else if (list.length == 1 && hasPhx && !phxUsed) {
            cards.add(list.first);
            cards.add('PHX');
            phxUsed = true;
          } else {
            ok = false;
            break;
          }
        }
        if (ok) tryAdd(cards);
      }
    }
  }

  // 7. Straights (length >= 5)
  if (current == null || current.type == 'straight') {
    final minLen = current != null ? current.length : 5;
    final maxLen = current != null ? current.length : min(14, hand.length);
    for (var len = minLen; len <= maxLen; len++) {
      for (var start = 1; start + len - 1 <= 14; start++) {
        final cards = <String>[];
        var phxUsed = false;
        var ok = true;
        for (var r = start; r < start + len; r++) {
          final list = byRank[r] ?? const [];
          if (list.isNotEmpty) {
            cards.add(list.first);
          } else if (hasPhx && !phxUsed) {
            cards.add('PHX');
            phxUsed = true;
          } else {
            ok = false;
            break;
          }
        }
        if (ok) tryAdd(cards);
      }
    }
  }

  return results;
}

/// Returns true if [hand] has a normal card of [wishRank] AND at least one legal
/// play on [current] that includes a card of [wishRank].
bool canFulfillTichuWish(
  List<String> hand,
  TichuCombo? current,
  int? wishRank,
) {
  if (wishRank == null || wishRank < 2 || wishRank > 14) return false;
  final hasWishCard = hand.any((c) => tichuCardRank(c) == wishRank);
  if (!hasWishCard) return false;
  final legal = generateLegalTichuPlays(hand, current);
  return legal.any(
    (combo) => combo.cards.any((c) => tichuCardRank(c) == wishRank),
  );
}

class TichuGame extends GameEngine {
  TichuGame(super.setup);

  late int targetScore;
  int round = 1;
  String phase = 'play'; // 'play' | 'give_dragon'
  int turn = 0;

  List<List<String>> hands = [[], [], [], []];
  List<List<String>> capturedCards = [[], [], [], []];
  List<bool> playedFirstCard = [false, false, false, false];
  List<bool> tichuCalled = [false, false, false, false];
  List<int> finishOrder = [];

  TichuCombo? currentCombo;
  int? lastPlaySeat;
  int passCount = 0;
  List<String> trickPile = [];
  List<Map<String, dynamic>> currentTrickPlays = [];

  int? activeWish; // 2..14 when Mahjong wish is active
  List<int> teamScores = [0, 0];
  Map<String, dynamic>? lastHandSummary;
  bool _over = false;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings {
    if (!_over) return null;
    final winTeam = teamScores[0] >= teamScores[1] ? 0 : 1;
    return [
      for (var s = 0; s < 4; s++) (s % 2 == winTeam) ? 1 : 2,
    ];
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    targetScore = setup.opt<int>('targetScore', 300);
    _startHand();
  }

  void _startHand() {
    final deck = shuffled(buildTichuDeck(), rng);
    hands = [
      for (var s = 0; s < 4; s++) _sortHand(deck.sublist(s * 14, (s + 1) * 14)),
    ];
    capturedCards = [[], [], [], []];
    playedFirstCard = [false, false, false, false];
    tichuCalled = [false, false, false, false];
    finishOrder = [];
    currentCombo = null;
    lastPlaySeat = null;
    passCount = 0;
    trickPile = [];
    currentTrickPlays = [];
    activeWish = null;
    phase = 'play';

    // Holder of Mahjong ('MJ') leads the first trick
    turn = 0;
    for (var s = 0; s < 4; s++) {
      if (hands[s].contains('MJ')) {
        turn = s;
        break;
      }
    }
    host.log('第 $round 局开始，${name(turn)} 持有雀牌（MJ）先手领出！');
  }

  List<String> _sortHand(Iterable<String> cards) {
    final list = List<String>.of(cards);
    list.sort((a, b) {
      final ra = a == 'PHX' ? 14.5 : tichuCardRank(a).toDouble();
      final rb = b == 'PHX' ? 14.5 : tichuCardRank(b).toDouble();
      if (ra != rb) return ra.compareTo(rb);
      return a.compareTo(b);
    });
    return list;
  }

  int _activeRemainingCount() =>
      [for (var s = 0; s < 4; s++) if (hands[s].isNotEmpty) s].length;

  int _nextActiveSeat(int from) {
    for (var i = 1; i <= 4; i++) {
      final s = (from + i) % 4;
      if (hands[s].isNotEmpty) return s;
    }
    return from;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat < 0 || seat >= 4) throw GameError('无效座位');

    final type = asStr(action['type']);

    // Any player who has not played their first card yet can declare Tichu
    if (type == 'call_tichu') {
      if (playedFirstCard[seat] || hands[seat].isEmpty) {
        throw GameError('已经出过牌，不能再宣告地主（Tichu）');
      }
      if (tichuCalled[seat]) {
        throw GameError('你已经宣告过地主（Tichu）');
      }
      tichuCalled[seat] = true;
      host.log('${name(seat)} 宣告「地主 Tichu」（±100分）！');
      return;
    }

    if (seat != turn) {
      throw GameError('当前不是你的回合');
    }

    if (phase == 'give_dragon') {
      if (type != 'give_dragon') {
        throw GameError('请先选择将龙墩赠送给哪位对手');
      }
      final target = asInt(action['target'], -1);
      if (target < 0 || target >= 4 || target % 2 == seat % 2) {
        throw GameError('必须将龙墩赠送给一名对手');
      }
      capturedCards[target].addAll(trickPile);
      host.log('${name(seat)} 将龙墩赠送给对手 ${name(target)}');
      trickPile.clear();
      currentTrickPlays.clear();
      currentCombo = null;
      lastPlaySeat = null;
      passCount = 0;
      phase = 'play';
      if (_checkHandEnd()) return;
      turn = hands[seat].isNotEmpty ? seat : _nextActiveSeat(seat);
      return;
    }

    if (type == 'pass') {
      if (currentCombo == null) {
        throw GameError('领出回合不能过牌');
      }
      if (canFulfillTichuWish(hands[seat], currentCombo, activeWish)) {
        throw GameError('手中持有许愿点数 ${kTichuRankLabels[activeWish]} 且能合法打出，不能过牌！');
      }
      currentTrickPlays.add({'seat': seat, 'type': 'pass', 'cards': const <String>[]});
      passCount++;

      // Count how many other players need to pass before trick resolves
      final neededPasses = hands[lastPlaySeat!].isNotEmpty
          ? _activeRemainingCount() - 1
          : _activeRemainingCount();

      if (passCount >= neededPasses) {
        _resolveTrick();
      } else {
        turn = _nextActiveSeat(seat);
      }
      return;
    }

    if (type == 'play') {
      final rawCards = action['cards'];
      if (rawCards is! List || rawCards.isEmpty) {
        throw GameError('请选择要打出的牌');
      }
      final playCards = [for (final c in rawCards) '$c'];

      // Verify ownership
      final tempHand = List<String>.of(hands[seat]);
      for (final c in playCards) {
        if (!tempHand.remove(c)) {
          throw GameError('手牌中没有 $c');
        }
      }

      if (playCards.contains('DOG') && currentCombo != null) {
        throw GameError('犬（DOG）只能在空桌面领出时单张打出');
      }

      final lastSingle =
          (currentCombo != null && currentCombo!.type == 'single')
              ? currentCombo!.rank
              : null;
      final combo = evaluateTichuCombo(playCards, lastSingleRank: lastSingle);
      if (combo == null) {
        throw GameError('不合法的牌型组合');
      }
      if (!canBeatTichuCombo(combo, currentCombo)) {
        throw GameError('所选牌型无法压过当前桌面牌型');
      }

      // Enforce Mahjong wish if active
      if (activeWish != null &&
          canFulfillTichuWish(hands[seat], currentCombo, activeWish)) {
        final fulfills =
            playCards.any((c) => tichuCardRank(c) == activeWish);
        if (!fulfills) {
          throw GameError(
              '必须打出包含雀牌许愿点数（${kTichuRankLabels[activeWish]}）的合法牌型！');
        }
      }

      // Check optional wish declaration when playing MJ
      int? declaredWish;
      if (playCards.contains('MJ') && action['wish'] != null) {
        final w = asInt(action['wish'], 0);
        if (w >= 2 && w <= 14) {
          declaredWish = w;
        }
      }

      // Commit card removal
      hands[seat] = tempHand;
      playedFirstCard[seat] = true;

      // Check if activeWish was fulfilled by this play
      if (activeWish != null &&
          playCards.any((c) => tichuCardRank(c) == activeWish)) {
        host.log('${name(seat)} 打出 ${kTichuRankLabels[activeWish]}，完成了雀牌许愿！');
        activeWish = null;
      }

      // Apply new wish if MJ was played with a wish
      if (declaredWish != null) {
        activeWish = declaredWish;
        host.log('${name(seat)} 打出雀牌并许愿点数：${kTichuRankLabels[declaredWish]}！');
      }

      if (hands[seat].isEmpty && !finishOrder.contains(seat)) {
        finishOrder.add(seat);
        host.log('${name(seat)} 出完手牌（第 ${finishOrder.length} 名）！');
      }

      // Special case: Dog immediately transfers lead to partner
      if (combo.type == 'dog') {
        final partner = (seat + 2) % 4;
        currentCombo = null;
        lastPlaySeat = null;
        passCount = 0;
        trickPile.clear();
        currentTrickPlays = [
          {'seat': seat, 'type': 'dog', 'cards': playCards},
        ];
        if (_checkHandEnd()) return;
        turn = hands[partner].isNotEmpty ? partner : _nextActiveSeat(partner);
        host.log('${name(seat)} 打出犬（DOG），由搭档 ${name(turn)} 领出！');
        return;
      }

      currentCombo = combo;
      lastPlaySeat = seat;
      passCount = 0;
      trickPile.addAll(playCards);
      currentTrickPlays.add({
        'seat': seat,
        'type': combo.type,
        'cards': playCards,
      });

      if (_checkHandEnd()) return;
      turn = _nextActiveSeat(seat);
      return;
    }

    throw GameError('未知操作类型: $type');
  }

  void _resolveTrick() {
    final winner = lastPlaySeat!;
    final isDragonTrick =
        currentCombo != null &&
        currentCombo!.type == 'single' &&
        currentCombo!.cards.first == 'DRG';

    if (isDragonTrick) {
      phase = 'give_dragon';
      turn = winner;
      return;
    }

    capturedCards[winner].addAll(trickPile);
    trickPile.clear();
    currentTrickPlays.clear();
    currentCombo = null;
    lastPlaySeat = null;
    passCount = 0;

    if (_checkHandEnd()) return;
    turn = hands[winner].isNotEmpty ? winner : _nextActiveSeat(winner);
  }

  bool _checkHandEnd() {
    // 1. Check 1-2 Double Victory (partners finished 1st and 2nd)
    final doubleVictory = finishOrder.length >= 2 &&
        (finishOrder[0] % 2 == finishOrder[1] % 2);

    // 2. Check if 3 players have finished
    final threeFinished = finishOrder.length >= 3;

    if (!doubleVictory && !threeFinished) return false;

    _scoreHand(doubleVictory: doubleVictory);
    return true;
  }

  void _scoreHand({required bool doubleVictory}) {
    // Resolve any remaining cards on the table
    if (trickPile.isNotEmpty && lastPlaySeat != null) {
      final isDragon = currentCombo != null &&
          currentCombo!.type == 'single' &&
          currentCombo!.cards.first == 'DRG';
      if (isDragon) {
        final oppA = (lastPlaySeat! + 1) % 4;
        final oppB = (lastPlaySeat! + 3) % 4;
        final ptsA = capturedCards[oppA].fold<int>(0, (s, c) => s + tichuCardPoints(c));
        final ptsB = capturedCards[oppB].fold<int>(0, (s, c) => s + tichuCardPoints(c));
        final target = ptsA <= ptsB ? oppA : oppB;
        capturedCards[target].addAll(trickPile);
      } else {
        capturedCards[lastPlaySeat!].addAll(trickPile);
      }
      trickPile.clear();
    }

    // Complete finishOrder with remaining seats
    for (var s = 0; s < 4; s++) {
      if (!finishOrder.contains(s)) {
        finishOrder.add(s);
      }
    }

    final firstSeat = finishOrder.first;
    final lastSeat = finishOrder.last;

    // Tichu declarations bonus (+100 if 1st, -100 otherwise)
    final tichuDelta = [0, 0];
    for (var s = 0; s < 4; s++) {
      if (tichuCalled[s]) {
        tichuDelta[s % 2] += (s == firstSeat) ? 100 : -100;
      }
    }

    final cardPoints = [0, 0];
    if (doubleVictory) {
      final winTeam = firstSeat % 2;
      cardPoints[winTeam] = 200;
      cardPoints[1 - winTeam] = 0;
    } else {
      // Last place's remaining hand cards go to the opposing team
      final oppTeamSeat = (lastSeat + 1) % 4;
      capturedCards[oppTeamSeat].addAll(hands[lastSeat]);
      hands[lastSeat].clear();

      // Last place's captured trick cards go to 1st place (firstSeat)
      if (lastSeat != firstSeat) {
        capturedCards[firstSeat].addAll(capturedCards[lastSeat]);
        capturedCards[lastSeat].clear();
      }

      for (var s = 0; s < 4; s++) {
        final pts =
            capturedCards[s].fold<int>(0, (sum, c) => sum + tichuCardPoints(c));
        cardPoints[s % 2] += pts;
      }
    }

    final roundDelta = [
      cardPoints[0] + tichuDelta[0],
      cardPoints[1] + tichuDelta[1],
    ];
    teamScores[0] += roundDelta[0];
    teamScores[1] += roundDelta[1];

    lastHandSummary = {
      'round': round,
      'doubleVictory': doubleVictory,
      'finishOrder': List<int>.of(finishOrder),
      'cardPoints': cardPoints,
      'tichuDelta': tichuDelta,
      'roundDelta': roundDelta,
      'teamScores': List<int>.of(teamScores),
    };

    host.log(
      '第 $round 局结算：${doubleVictory ? '双关 200:0！' : '牌分 ${cardPoints[0]}:${cardPoints[1]}'} '
      '本局得分 ${roundDelta[0]}:${roundDelta[1]}（总分 ${teamScores[0]}:${teamScores[1]}）',
    );

    if ((teamScores[0] >= targetScore || teamScores[1] >= targetScore) &&
        teamScores[0] != teamScores[1]) {
      _over = true;
      return;
    }
    if (round >= 10 && teamScores[0] != teamScores[1]) {
      _over = true;
      return;
    }

    round++;
    _startHand();
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand =
        (seat >= 0 && seat < 4) ? List<String>.of(hands[seat]) : const <String>[];
    final canCallTichu = seat >= 0 &&
        seat < 4 &&
        !_over &&
        !playedFirstCard[seat] &&
        !tichuCalled[seat] &&
        hands[seat].isNotEmpty;

    final mustFulfillWish = seat >= 0 &&
        seat < 4 &&
        !_over &&
        phase == 'play' &&
        turn == seat &&
        canFulfillTichuWish(hands[seat], currentCombo, activeWish);

    return {
      'round': round,
      'targetScore': targetScore,
      'phase': phase,
      'turn': turn,
      'handCounts': [for (var s = 0; s < 4; s++) hands[s].length],
      'capturedPoints': [
        for (var s = 0; s < 4; s++)
          capturedCards[s].fold<int>(0, (sum, c) => sum + tichuCardPoints(c)),
      ],
      'tichuCalled': List<bool>.of(tichuCalled),
      'playedFirstCard': List<bool>.of(playedFirstCard),
      'finishOrder': List<int>.of(finishOrder),
      'currentCombo': currentCombo?.toJson(),
      'lastPlaySeat': lastPlaySeat,
      'trickPoints':
          trickPile.fold<int>(0, (sum, c) => sum + tichuCardPoints(c)),
      'currentTrickPlays': List<Map<String, dynamic>>.of(currentTrickPlays),
      'activeWish': activeWish,
      'mustFulfillWish': mustFulfillWish,
      'canCallTichu': canCallTichu,
      'teamScores': List<int>.of(teamScores),
      'myHand': myHand,
      'lastHandSummary': lastHandSummary,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'give_dragon') {
      final oppA = (seat + 1) % 4;
      final oppB = (seat + 3) % 4;
      final ptsA =
          capturedCards[oppA].fold<int>(0, (s, c) => s + tichuCardPoints(c));
      final ptsB =
          capturedCards[oppB].fold<int>(0, (s, c) => s + tichuCardPoints(c));
      return {'type': 'give_dragon', 'target': ptsA <= ptsB ? oppA : oppB};
    }

    final hand = hands[seat];
    // Consider calling Tichu before playing first card if hand is very strong
    if (!playedFirstCard[seat] && !tichuCalled[seat] && botLevel >= 1) {
      final highCount = hand
          .where((c) => c == 'DRG' || c == 'PHX' || tichuCardRank(c) == 14)
          .length;
      if (highCount >= 4) {
        return {'type': 'call_tichu'};
      }
    }

    var plays = generateLegalTichuPlays(hand, currentCombo);
    if (activeWish != null &&
        canFulfillTichuWish(hand, currentCombo, activeWish)) {
      plays = plays
          .where((p) => p.cards.any((c) => tichuCardRank(c) == activeWish))
          .toList();
    }

    if (plays.isEmpty) {
      return {'type': 'pass'};
    }

    // If partner is currently winning the trick with a high play and we don't have to fulfill wish, pass
    final partner = (seat + 2) % 4;
    final mustWish = activeWish != null &&
        canFulfillTichuWish(hand, currentCombo, activeWish);
    if (!mustWish &&
        currentCombo != null &&
        lastPlaySeat == partner &&
        (hands[partner].isEmpty || currentCombo!.rank >= 11)) {
      return {'type': 'pass'};
    }

    // Prefer non-bomb multi-card plays or lowest-rank single/combo to shed cards fast
    plays.sort((a, b) {
      if (a.isBomb != b.isBomb) return a.isBomb ? 1 : -1;
      if (currentCombo == null && a.type == 'dog' && hands[partner].isNotEmpty) {
        return -1;
      }
      if (currentCombo == null && b.type == 'dog' && hands[partner].isNotEmpty) {
        return 1;
      }
      if (currentCombo == null && a.length != b.length) {
        return b.length.compareTo(a.length);
      }
      return a.rank.compareTo(b.rank);
    });

    final chosen = plays.first;
    final action = <String, dynamic>{
      'type': 'play',
      'cards': chosen.cards,
    };
    if (chosen.cards.contains('MJ')) {
      // Pick a rank 2..14 that we don't hold (or high rank A) as the wish
      var wish = 14;
      for (var r = 14; r >= 2; r--) {
        if (!hand.any((c) => tichuCardRank(c) == r)) {
          wish = r;
          break;
        }
      }
      action['wish'] = wish;
    }
    return action;
  }
}
