import 'dart:math';

import '../../src/engine.dart';

const List<String> phase10Colors = ['R', 'B', 'G', 'Y'];
const Map<String, String> phase10ColorNames = {
  'R': '红',
  'B': '蓝',
  'G': '绿',
  'Y': '黄',
};

class PhaseReq {
  final String type; // 'set', 'run', 'color'
  final int count;
  const PhaseReq(this.type, this.count);
}

class PhaseDef {
  final int index;
  final String title;
  final List<PhaseReq> reqs;
  const PhaseDef(this.index, this.title, this.reqs);
}

const List<PhaseDef> kPhase10Defs = [
  PhaseDef(1, '阶段1：两组三条 (3+3)', [PhaseReq('set', 3), PhaseReq('set', 3)]),
  PhaseDef(2, '阶段2：一组三条 + 一组四连顺 (3+顺4)', [PhaseReq('set', 3), PhaseReq('run', 4)]),
  PhaseDef(3, '阶段3：一组四条 + 一组四连顺 (4+顺4)', [PhaseReq('set', 4), PhaseReq('run', 4)]),
  PhaseDef(4, '阶段4：一组七连顺 (顺7)', [PhaseReq('run', 7)]),
  PhaseDef(5, '阶段5：同色六张 (同色6)', [PhaseReq('color', 6)]),
  PhaseDef(6, '阶段6：一组八连顺 (顺8)', [PhaseReq('run', 8)]),
  PhaseDef(7, '阶段7：两组四条 (4+4)', [PhaseReq('set', 4), PhaseReq('set', 4)]),
  PhaseDef(8, '阶段8：同色七张 (同色7)', [PhaseReq('color', 7)]),
  PhaseDef(9, '阶段9：一组五条 + 一组一对 (5+2)', [PhaseReq('set', 5), PhaseReq('set', 2)]),
  PhaseDef(10, '阶段10：一组五条 + 一组三条 (5+3)', [PhaseReq('set', 5), PhaseReq('set', 3)]),
];

PhaseDef phase10Def(int phaseIndex) =>
    kPhase10Defs[(phaseIndex - 1).clamp(0, kPhase10Defs.length - 1)];

/// Builds the 108-card Phase 10 deck:
/// - 4 colors (`R, B, G, Y`) × numbers `1..12` × 2 copies = 96 cards
/// - `'W'` (Wild 百搭) × 8 copies
/// - `'S'` (Skip 跳过) × 4 copies
List<String> buildPhase10Deck() => [
      for (final c in phase10Colors)
        for (var n = 1; n <= 12; n++) ...['$c$n', '$c$n'],
      for (var i = 0; i < 8; i++) 'W',
      for (var i = 0; i < 4; i++) 'S',
    ];

bool phase10IsWild(String card) => card == 'W';
bool phase10IsSkip(String card) => card == 'S';

String? phase10CardColor(String card) {
  if (card == 'W' || card == 'S' || card.isEmpty) return null;
  return card.substring(0, 1);
}

int? phase10CardNumber(String card) {
  if (card == 'W' || card == 'S' || card.length < 2) return null;
  return int.tryParse(card.substring(1));
}

/// Penalty points for a card left in hand at the end of a round:
/// - `1..9`: 5 pts
/// - `10..12`: 10 pts
/// - `'S'` (Skip): 15 pts
/// - `'W'` (Wild): 25 pts
int phase10CardPenalty(String card) {
  if (card == 'W') return 25;
  if (card == 'S') return 15;
  final n = phase10CardNumber(card) ?? 1;
  return n >= 10 ? 10 : 5;
}

int phase10HandPenalty(List<String> hand) =>
    hand.fold<int>(0, (s, c) => s + phase10CardPenalty(c));

/// Checks if [cards] is a valid Set of at least [minCount] cards (same number + Wilds, no Skips).
/// Returns the set's target number (`1..12`) if valid, or `null`.
int? phase10ValidateSet(List<String> cards, int minCount) {
  if (cards.length < minCount) return null;
  if (cards.any(phase10IsSkip)) return null;
  int? targetNum;
  for (final c in cards) {
    if (phase10IsWild(c)) continue;
    final n = phase10CardNumber(c);
    if (n == null) return null;
    if (targetNum == null) {
      targetNum = n;
    } else if (targetNum != n) {
      return null;
    }
  }
  return targetNum ?? 12; // If all wilds, treat as 12
}

/// Checks if [cards] is a valid Color group of at least [minCount] cards (same color + Wilds, no Skips).
/// Returns the group's color (`'R'/'B'/'G'/'Y'`) if valid, or `null`.
String? phase10ValidateColor(List<String> cards, int minCount) {
  if (cards.length < minCount) return null;
  if (cards.any(phase10IsSkip)) return null;
  String? targetColor;
  for (final c in cards) {
    if (phase10IsWild(c)) continue;
    final col = phase10CardColor(c);
    if (col == null) return null;
    if (targetColor == null) {
      targetColor = col;
    } else if (targetColor != col) {
      return null;
    }
  }
  return targetColor ?? 'R';
}

/// Checks if [cards] can form a consecutive Run of length `cards.length >= minCount` within `1..12`.
/// Returns `(startNum, endNum)` if valid, or `null`.
(int, int)? phase10ValidateRun(List<String> cards, int minCount) {
  final len = cards.length;
  if (len < minCount || len > 12) return null;
  if (cards.any(phase10IsSkip)) return null;

  final naturals = <int>[];
  for (final c in cards) {
    if (phase10IsWild(c)) {
      continue;
    } else {
      final n = phase10CardNumber(c);
      if (n == null) return null;
      naturals.add(n);
    }
  }
  // Duplicate natural numbers cannot appear in a single run
  if (naturals.toSet().length != naturals.length) return null;
  if (naturals.isEmpty) {
    return (1, len);
  }
  naturals.sort();
  final minNat = naturals.first;
  final maxNat = naturals.last;
  final span = maxNat - minNat + 1;
  if (span > len) return null;

  final start = max(1, min(minNat, 13 - len));
  final end = start + len - 1;
  if (end <= 12 && minNat >= start && maxNat <= end) {
    return (start, end);
  }
  return null;
}

/// Validates whether [melds] satisfies [phaseIndex] using cards from [hand].
bool phase10ValidatePhaseMelds(
  List<String> hand,
  int phaseIndex,
  List<List<String>> melds,
) {
  final def = phase10Def(phaseIndex);
  if (melds.length != def.reqs.length) return false;

  // Verify all cards exist in hand with multiplicity
  final pool = List<String>.of(hand);
  for (final m in melds) {
    for (final c in m) {
      if (!pool.remove(c)) return false;
    }
  }

  for (var i = 0; i < def.reqs.length; i++) {
    final req = def.reqs[i];
    final m = melds[i];
    final ok = switch (req.type) {
      'set' => phase10ValidateSet(m, req.count) != null,
      'color' => phase10ValidateColor(m, req.count) != null,
      'run' => phase10ValidateRun(m, req.count) != null,
      _ => false,
    };
    if (!ok) return false;
  }
  return true;
}

List<String>? _findSetFromPool(List<String> pool, int count) {
  final byNum = <int, List<String>>{};
  final wilds = <String>[];
  for (final c in pool) {
    if (phase10IsWild(c)) {
      wilds.add(c);
    } else {
      final n = phase10CardNumber(c);
      if (n != null) {
        (byNum[n] ??= []).add(c);
      }
    }
  }
  // Prefer sets that use the fewest wilds, and higher numbers first to shed penalty
  final candidates = byNum.entries.toList()
    ..sort((a, b) {
      final lenCmp = b.value.length.compareTo(a.value.length);
      if (lenCmp != 0) return lenCmp;
      return b.key.compareTo(a.key);
    });

  for (final e in candidates) {
    final nat = e.value;
    if (nat.length + wilds.length >= count) {
      final takeNat = min(count, nat.length);
      final takeWild = count - takeNat;
      return [
        ...nat.take(takeNat),
        ...wilds.take(takeWild),
      ];
    }
  }
  return null;
}

List<String>? _findColorFromPool(List<String> pool, int count) {
  final byCol = <String, List<String>>{};
  final wilds = <String>[];
  for (final c in pool) {
    if (phase10IsWild(c)) {
      wilds.add(c);
    } else {
      final col = phase10CardColor(c);
      if (col != null) {
        (byCol[col] ??= []).add(c);
      }
    }
  }
  final candidates = byCol.entries.toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  for (final e in candidates) {
    final nat = e.value;
    if (nat.length + wilds.length >= count) {
      final takeNat = min(count, nat.length);
      final takeWild = count - takeNat;
      return [
        ...nat.take(takeNat),
        ...wilds.take(takeWild),
      ];
    }
  }
  return null;
}

List<String>? _findRunFromPool(List<String> pool, int count) {
  final byNum = <int, String>{};
  final wilds = <String>[];
  for (final c in pool) {
    if (phase10IsWild(c)) {
      wilds.add(c);
    } else {
      final n = phase10CardNumber(c);
      if (n != null && !byNum.containsKey(n)) {
        byNum[n] = c;
      }
    }
  }

  List<String>? bestWindow;
  var bestWildsUsed = 999;

  for (var start = 1; start <= 13 - count; start++) {
    final chosen = <String>[];
    var wildsNeeded = 0;
    for (var n = start; n < start + count; n++) {
      if (byNum.containsKey(n)) {
        chosen.add(byNum[n]!);
      } else {
        wildsNeeded += 1;
      }
    }
    if (wildsNeeded <= wilds.length && chosen.isNotEmpty) {
      if (wildsNeeded < bestWildsUsed) {
        bestWildsUsed = wildsNeeded;
        bestWindow = [
          ...chosen,
          ...wilds.take(wildsNeeded),
        ];
      }
    }
  }
  return bestWindow;
}

/// Automatically searches [hand] for a valid combination of melds satisfying [phaseIndex].
/// Returns `List<List<String>>` if achievable, or `null`.
List<List<String>>? phase10FindPhaseMelds(List<String> hand, int phaseIndex) {
  final def = phase10Def(phaseIndex);
  final reqs = def.reqs;

  List<List<String>>? tryOrder(List<int> order) {
    final pool = List<String>.of(hand);
    final result = List<List<String>?>.filled(reqs.length, null);
    for (final idx in order) {
      final req = reqs[idx];
      final found = switch (req.type) {
        'set' => _findSetFromPool(pool, req.count),
        'color' => _findColorFromPool(pool, req.count),
        'run' => _findRunFromPool(pool, req.count),
        _ => null,
      };
      if (found == null) return null;
      for (final c in found) {
        pool.remove(c);
      }
      result[idx] = found;
    }
    return [for (final r in result) r!];
  }

  if (reqs.length == 1) {
    return tryOrder([0]);
  }
  return tryOrder([0, 1]) ?? tryOrder([1, 0]);
}

/// Checks if [card] can hit (extend) an existing table meld [meld].
bool phase10CanHitMeld(Map<String, dynamic> meld, String card) {
  if (phase10IsSkip(card)) return false;
  final type = asStr(meld['type']);
  final cards = (meld['cards'] as List).map((e) => '$e').toList();

  if (type == 'set') {
    final targetNum = asInt(meld['targetNum'], phase10ValidateSet(cards, 1) ?? 1);
    return phase10IsWild(card) || phase10CardNumber(card) == targetNum;
  }

  if (type == 'color') {
    final targetColor =
        asStr(meld['targetColor'], phase10ValidateColor(cards, 1) ?? 'R');
    return phase10IsWild(card) || phase10CardColor(card) == targetColor;
  }

  if (type == 'run') {
    if (cards.length >= 12) return false;
    return phase10ValidateRun([...cards, card], cards.length + 1) != null;
  }

  return false;
}

class Phase10Game extends GameEngine {
  late int maxPhase;
  int round = 1;
  int startPlayer = 0;
  int turn = 0;

  /// Current phase:
  /// - `'draw'`: Active player draws 1 card from `deck` (`draw_deck`) or `discardPile` (`take_discard`)
  /// - `'action'`: Active player may `complete_phase`, `hit_meld`, and ends turn with `discard`
  String phase = 'draw';

  List<String> deck = [];
  List<String> discardPile = [];
  late List<List<String>> hands;
  late List<int> phaseIndex; // Current phase 1..maxPhase for each player
  late List<bool> phaseCompleted; // Whether player completed their phase in the current hand
  late List<int> penalties; // Cumulative penalty score (lower is better)
  late List<int> scores; // Composite ranking score: completedPhases * 10000 - penalties

  List<Map<String, dynamic>> tableMelds = [];
  Set<int> skippedSeats = {};

  int turnsInRound = 0;
  List<String> actionLog = [];
  Map<String, dynamic>? lastRoundSummary;

  bool _over = false;
  List<int>? _placings;

  Phase10Game(super.setup) {
    maxPhase = setup.opt<int>('maxPhase', 5);
    hands = List.generate(players, (_) => <String>[]);
    phaseIndex = List.filled(players, 1);
    phaseCompleted = List.filled(players, false);
    penalties = List.filled(players, 0);
    scores = List.filled(players, 10000);
  }

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players) throw GameError('无法认输');
    _over = true;
    final winners = [
      for (var i = 0; i < players; i++)
        if (i != seat) i,
    ];
    _placings = rankWinners(players, winners);
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    _updateCompositeScores();
    _startRound();
  }

  void _updateCompositeScores() {
    for (var s = 0; s < players; s++) {
      scores[s] = phaseIndex[s] * 10000 - penalties[s];
    }
  }

  void _sortHand(List<String> hand) {
    hand.sort((a, b) {
      if (a == b) return 0;
      if (a == 'W') return -1;
      if (b == 'W') return 1;
      if (a == 'S') return 1;
      if (b == 'S') return -1;
      final na = phase10CardNumber(a) ?? 0;
      final nb = phase10CardNumber(b) ?? 0;
      if (na != nb) return na.compareTo(nb);
      return (phase10CardColor(a) ?? '').compareTo(phase10CardColor(b) ?? '');
    });
  }

  void _startRound() {
    deck = shuffled(buildPhase10Deck(), rng);
    for (var s = 0; s < players; s++) {
      hands[s] = [for (var i = 0; i < 10; i++) deck.removeLast()];
      _sortHand(hands[s]);
      phaseCompleted[s] = false;
    }
    // Start discard pile with a non-Skip card so startPlayer is not immediately confused
    var firstDiscard = deck.removeLast();
    while (firstDiscard == 'S' && deck.isNotEmpty) {
      deck.insert(0, firstDiscard);
      firstDiscard = deck.removeLast();
    }
    discardPile = [firstDiscard];
    tableMelds = [];
    skippedSeats = {};
    turnsInRound = 0;
    actionLog = [];
    phase = 'draw';
    turn = startPlayer;

    host.log(
      '第 $round 局开始：${[
        for (var s = 0; s < players; s++) '${name(s)}[阶段${phaseIndex[s]}/$maxPhase]'
      ].join(' · ')}',
    );
  }

  void _ensureDeckNotEmpty() {
    if (deck.isNotEmpty) return;
    if (discardPile.length > 1) {
      final top = discardPile.removeLast();
      deck = shuffled(discardPile, rng);
      discardPile = [top];
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'draw') {
      if (type == 'draw_deck') {
        _ensureDeckNotEmpty();
        if (deck.isEmpty) throw GameError('牌库已无牌可摸');
        final c = deck.removeLast();
        hands[seat].add(c);
        _sortHand(hands[seat]);
        phase = 'action';
        actionLog.add('${name(seat)} 从牌库摸取 1 张牌');
        return;
      }

      if (type == 'take_discard') {
        if (discardPile.isEmpty) throw GameError('弃牌堆为空');
        if (phase10IsSkip(discardPile.last)) {
          throw GameError('跳过牌 (S) 不能从弃牌堆捡起');
        }
        final c = discardPile.removeLast();
        hands[seat].add(c);
        _sortHand(hands[seat]);
        phase = 'action';
        actionLog.add('${name(seat)} 从弃牌堆拿取了 [$c]');
        return;
      }

      throw GameError('摸牌阶段请选择摸牌库 (draw_deck) 或捡弃牌 (take_discard)');
    }

    if (phase == 'action') {
      if (type == 'complete_phase') {
        if (phaseCompleted[seat]) {
          throw GameError('你本局已经完成了当前阶段');
        }
        final curPhase = phaseIndex[seat];
        List<List<String>>? melds;
        if (action['melds'] is List) {
          melds = [
            for (final m in (action['melds'] as List))
              (m as List).map((e) => '$e').toList(),
          ];
          if (!phase10ValidatePhaseMelds(hands[seat], curPhase, melds)) {
            throw GameError('所选牌组不满足当前【${phase10Def(curPhase).title}】的要求');
          }
        } else {
          melds = phase10FindPhaseMelds(hands[seat], curPhase);
          if (melds == null) {
            throw GameError('当前手牌尚未凑齐【${phase10Def(curPhase).title}】所需牌组');
          }
        }

        final def = phase10Def(curPhase);
        for (var i = 0; i < melds.length; i++) {
          final mCards = melds[i];
          final req = def.reqs[i];
          for (final c in mCards) {
            hands[seat].remove(c);
          }
          final meldEntry = <String, dynamic>{
            'id': tableMelds.length,
            'owner': seat,
            'type': req.type,
            'cards': List<String>.of(mCards),
          };
          if (req.type == 'set') {
            meldEntry['targetNum'] = phase10ValidateSet(mCards, 1) ?? 1;
          } else if (req.type == 'color') {
            meldEntry['targetColor'] = phase10ValidateColor(mCards, 1) ?? 'R';
          } else if (req.type == 'run') {
            final bounds = phase10ValidateRun(mCards, 1);
            meldEntry['runStart'] = bounds?.$1 ?? 1;
            meldEntry['runEnd'] = bounds?.$2 ?? mCards.length;
          }
          tableMelds.add(meldEntry);
        }

        phaseCompleted[seat] = true;
        actionLog.add(
          '🎉 ${name(seat)} 成功铺下【${def.title}】！现在可以向桌面牌组贴牌 (Hit)',
        );
        host.log('🎉 ${name(seat)} 完成了【${def.title}】！');

        if (hands[seat].isEmpty) {
          _finishRound(winnerSeat: seat);
        }
        return;
      }

      if (type == 'hit_meld') {
        if (!phaseCompleted[seat]) {
          throw GameError('必须先完成你本局的阶段铺牌，才能向桌面牌组贴牌 (hit_meld)');
        }
        final meldIdx = asInt(action['meldIndex'], 0);
        final card = asStr(action['card']);
        if (meldIdx < 0 || meldIdx >= tableMelds.length) {
          throw GameError('无效的目标牌组编号');
        }
        if (!hands[seat].contains(card)) {
          throw GameError('手牌中没有卡牌 $card');
        }
        final meld = tableMelds[meldIdx];
        if (!phase10CanHitMeld(meld, card)) {
          throw GameError('卡牌 [$card] 无法贴入该桌面牌组');
        }

        hands[seat].remove(card);
        final mCards = (meld['cards'] as List).cast<String>()..add(card);
        if (meld['type'] == 'run') {
          final bounds = phase10ValidateRun(mCards, 1);
          meld['runStart'] = bounds?.$1 ?? 1;
          meld['runEnd'] = bounds?.$2 ?? mCards.length;
        }
        actionLog.add('${name(seat)} 将 [$card] 贴入桌面牌组 #${meldIdx + 1}');

        if (hands[seat].isEmpty) {
          _finishRound(winnerSeat: seat);
        }
        return;
      }

      if (type == 'discard') {
        var card = asStr(action['card']);
        if (card.isEmpty && hands[seat].isNotEmpty) {
          card = hands[seat].last;
        }
        if (!hands[seat].remove(card)) {
          throw GameError('手牌中没有卡牌 $card');
        }
        discardPile.add(card);

        if (phase10IsSkip(card)) {
          var target = asInt(action['targetSeat'], (seat + 1) % players);
          if (target < 0 || target >= players || target == seat) {
            target = (seat + 1) % players;
          }
          skippedSeats.add(target);
          actionLog.add(
            '🚫 ${name(seat)} 打出跳过牌 [S]，指定跳过 ${name(target)} 的下个回合！',
          );
        } else {
          actionLog.add('${name(seat)} 弃出 [$card]');
        }

        if (hands[seat].isEmpty) {
          _finishRound(winnerSeat: seat);
          return;
        }

        _advanceTurn();
        return;
      }

      throw GameError('行动阶段可执行 complete_phase / hit_meld / discard');
    }

    throw GameError('未知阶段：$phase');
  }

  void _advanceTurn() {
    turnsInRound += 1;
    if (turnsInRound >= players * 12) {
      // If a hand drags on too long, anyone whose hand is closest or has completed phase finishes
      for (var s = 0; s < players; s++) {
        if (!phaseCompleted[s] &&
            phase10FindPhaseMelds(hands[s], phaseIndex[s]) != null) {
          phaseCompleted[s] = true;
        }
      }
      _finishRound(winnerSeat: turn);
      return;
    }

    var next = (turn + 1) % players;
    for (var tries = 0; tries < players; tries++) {
      if (skippedSeats.remove(next)) {
        actionLog.add('⏭️ ${name(next)} 因跳过牌 (Skip) 跳过本回合');
        next = (next + 1) % players;
      } else {
        break;
      }
    }
    turn = next;
    phase = 'draw';
  }

  void _finishRound({required int winnerSeat}) {
    final handPens = [
      for (var s = 0; s < players; s++) phase10HandPenalty(hands[s]),
    ];
    final completedThisHand = List<bool>.of(phaseCompleted);
    var someoneClearedAll = false;

    for (var s = 0; s < players; s++) {
      penalties[s] += handPens[s];
      if (phaseCompleted[s]) {
        if (phaseIndex[s] >= maxPhase) {
          someoneClearedAll = true;
          phaseIndex[s] = maxPhase + 1;
        } else {
          phaseIndex[s] += 1;
        }
      }
    }
    _updateCompositeScores();

    lastRoundSummary = {
      'round': round,
      'winnerSeat': winnerSeat,
      'completedThisHand': completedThisHand,
      'handPenalties': handPens,
      'phaseIndex': List<int>.of(phaseIndex),
      'penalties': List<int>.of(penalties),
    };

    host.log(
      '第 $round 局结束（${name(winnerSeat)} 清空手牌）：${[
        for (var s = 0; s < players; s++)
          '${name(s)} 阶段${min(phaseIndex[s], maxPhase)}/$maxPhase(罚分${penalties[s]})'
      ].join(' · ')}',
    );

    if (someoneClearedAll || round >= maxPhase * 3) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('十阶段纸牌比赛结束！');
    } else {
      round += 1;
      startPlayer = (startPlayer + 1) % players;
      _startRound();
    }
  }

  /// Scores how useful [card] is to keeping in [hand] for [curPhase].
  int _cardKeepValue(List<String> hand, int curPhase, String card) {
    if (phase10IsWild(card)) return 100;
    if (phase10IsSkip(card)) return -20; // Eagerly play Skip cards on opponents!
    final n = phase10CardNumber(card) ?? 1;
    final col = phase10CardColor(card) ?? 'R';
    final def = phase10Def(curPhase);

    var val = 0;
    for (final req in def.reqs) {
      if (req.type == 'set') {
        final sameNum = hand.where((c) => phase10CardNumber(c) == n).length;
        val += sameNum * 15;
      } else if (req.type == 'color') {
        final sameCol = hand.where((c) => phase10CardColor(c) == col).length;
        val += sameCol * 15;
      } else if (req.type == 'run') {
        final adj = hand
            .where((c) {
              final cn = phase10CardNumber(c);
              return cn != null && (cn - n).abs() <= 2 && cn != n;
            })
            .length;
        final dup = hand.where((c) => phase10CardNumber(c) == n).length;
        val += adj * 10 - (dup > 1 ? 12 : 0);
      }
    }
    return val - phase10CardPenalty(card);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'draw') {
      if (discardPile.isNotEmpty && !phase10IsSkip(discardPile.last)) {
        final top = discardPile.last;
        if (phase10IsWild(top)) {
          return {'type': 'take_discard'};
        }
        if (!phaseCompleted[seat]) {
          final withTop = [...hands[seat], top];
          if (phase10FindPhaseMelds(withTop, phaseIndex[seat]) != null) {
            return {'type': 'take_discard'};
          }
        } else {
          for (final m in tableMelds) {
            if (phase10CanHitMeld(m, top)) {
              return {'type': 'take_discard'};
            }
          }
        }
      }
      return {'type': 'draw_deck'};
    }

    if (phase == 'action') {
      // 1. Complete phase if possible
      if (!phaseCompleted[seat]) {
        final melds = phase10FindPhaseMelds(hands[seat], phaseIndex[seat]);
        if (melds != null) {
          return {'type': 'complete_phase', 'melds': melds};
        }
      }

      // 2. If phase is completed, hit any table meld if possible (keep at least 0 or 1 card)
      if (phaseCompleted[seat]) {
        for (var mIdx = 0; mIdx < tableMelds.length; mIdx++) {
          final m = tableMelds[mIdx];
          for (final c in hands[seat]) {
            if (phase10CanHitMeld(m, c)) {
              return {
                'type': 'hit_meld',
                'meldIndex': mIdx,
                'card': c,
              };
            }
          }
        }
      }

      // 3. Discard the least useful card (or play Skip on the leading opponent)
      final hand = hands[seat];
      if (hand.contains('S')) {
        // Target opponent with highest phaseIndex
        var target = (seat + 1) % players;
        var bestPhase = -1;
        for (var s = 0; s < players; s++) {
          if (s != seat && phaseIndex[s] > bestPhase) {
            bestPhase = phaseIndex[s];
            target = s;
          }
        }
        return {'type': 'discard', 'card': 'S', 'targetSeat': target};
      }

      var worstCard = hand.first;
      var worstVal = 999999;
      for (final c in hand) {
        final v = _cardKeepValue(hand, phaseIndex[seat], c);
        if (v < worstVal) {
          worstVal = v;
          worstCard = c;
        }
      }
      return {'type': 'discard', 'card': worstCard};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final hasSeat = seat >= 0 && seat < players;
    final myHand = hasSeat ? List<String>.of(hands[seat]) : <String>[];
    final myCurPhase = hasSeat ? phaseIndex[seat].clamp(1, maxPhase) : 1;
    final canComplete = hasSeat &&
        seat == turn &&
        phase == 'action' &&
        !phaseCompleted[seat] &&
        phase10FindPhaseMelds(myHand, myCurPhase) != null;

    return {
      'round': round,
      'maxPhase': maxPhase,
      'phase': phase,
      'turn': turn,
      'deckCount': deck.length,
      'discardTop': discardPile.isNotEmpty ? discardPile.last : null,
      'discardCount': discardPile.length,
      'phaseIndex': [
        for (final p in phaseIndex) p.clamp(1, maxPhase),
      ],
      'phaseTitles': [
        for (final p in phaseIndex) phase10Def(p.clamp(1, maxPhase)).title,
      ],
      'phaseCompleted': List<bool>.of(phaseCompleted),
      'penalties': List<int>.of(penalties),
      'scores': List<int>.of(scores),
      'handCounts': [for (final h in hands) h.length],
      'hand': myHand,
      'canCompletePhase': canComplete,
      'tableMelds': [
        for (final m in tableMelds)
          {
            'id': m['id'],
            'owner': m['owner'],
            'type': m['type'],
            'cards': List<String>.of((m['cards'] as List).cast<String>()),
          },
      ],
      'skippedSeats': skippedSeats.toList(),
      'actionLog': List<String>.of(actionLog.reversed.take(6)),
      'lastRoundSummary': lastRoundSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
