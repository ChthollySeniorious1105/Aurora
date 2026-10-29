import '../../src/engine.dart';

const List<String> _suits = ['S', 'H', 'D', 'C'];
const List<String> _ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K'];

List<String> cribDeck() => [
      for (final s in _suits)
        for (final r in _ranks) '$r$s',
    ];

/// Card rank 1..13 (A=1 .. K=13) used for runs and pairs.
int cribRank(String card) {
  if (card.length < 2) return 0;
  final r = card.substring(0, card.length - 1);
  final idx = _ranks.indexOf(r);
  return idx >= 0 ? idx + 1 : 0;
}

/// Card pip value 1..10 (A=1, 2..10=face, J/Q/K=10) used for summing to 15 and 31.
int cribVal(String card) {
  final r = cribRank(card);
  return r > 10 ? 10 : r;
}

String cribSuit(String card) => card.isEmpty ? '' : card[card.length - 1];

void cribSort(List<String> cards) {
  cards.sort((a, b) {
    final c = cribRank(a).compareTo(cribRank(b));
    if (c != 0) return c;
    return _suits.indexOf(cribSuit(a)).compareTo(_suits.indexOf(cribSuit(b)));
  });
}

/// Scores a card just played at the end of [seq] bringing the running total to [count].
({int pts, List<String> reasons}) scorePeggingPlay(List<String> seq, int count) {
  if (seq.isEmpty) return (pts: 0, reasons: const []);
  var pts = 0;
  final reasons = <String>[];
  if (count == 15) {
    pts += 2;
    reasons.add('凑15 (+2)');
  } else if (count == 31) {
    pts += 2;
    reasons.add('凑31 (+2)');
  }

  // Consecutive identical ranks at the tail of seq.
  final lastRank = cribRank(seq.last);
  var same = 0;
  for (var i = seq.length - 1; i >= 0; i--) {
    if (cribRank(seq[i]) == lastRank) {
      same++;
    } else {
      break;
    }
  }
  if (same == 2) {
    pts += 2;
    reasons.add('对子 (+2)');
  } else if (same == 3) {
    pts += 6;
    reasons.add('三条 (+6)');
  } else if (same >= 4) {
    pts += 12;
    reasons.add('四条 (+12)');
  }

  // Longest trailing run of length L >= 3 (consecutive ranks in any order, no duplicates).
  for (var len = seq.length; len >= 3; len--) {
    final tail = seq.sublist(seq.length - len);
    final ranks = <int>{};
    var minR = 99;
    var maxR = -1;
    for (final c in tail) {
      final r = cribRank(c);
      ranks.add(r);
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
    }
    if (ranks.length == len && maxR - minR == len - 1) {
      pts += len;
      reasons.add('$len连顺 (+$len)');
      break;
    }
  }

  return (pts: pts, reasons: reasons);
}

/// Scores a 4-card Cribbage hand (or crib) plus the [starter] card during the Show.
({
  int total,
  int fifteens,
  int pairs,
  int runs,
  int flush,
  int nobs,
  List<String> details,
}) scoreCribbageHand(List<String> hand4, String starter, {bool isCrib = false}) {
  final all5 = [...hand4, if (starter.isNotEmpty) starter];
  final n = all5.length;

  // 1. 15s: every subset summing to 15 scores 2 pts.
  var fifteens = 0;
  final totalMasks = 1 << n;
  for (var mask = 1; mask < totalMasks; mask++) {
    var sum = 0;
    for (var i = 0; i < n; i++) {
      if ((mask & (1 << i)) != 0) sum += cribVal(all5[i]);
    }
    if (sum == 15) fifteens += 2;
  }

  // 2. Pairs: every pair of identical rank scores 2 pts.
  var pairs = 0;
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      if (cribRank(all5[i]) == cribRank(all5[j])) pairs += 2;
    }
  }

  // 3. Runs: find largest k in 5..3 that forms at least one run of k consecutive ranks.
  var runs = 0;
  for (var k = n; k >= 3; k--) {
    var countRuns = 0;
    for (var mask = 1; mask < totalMasks; mask++) {
      // Count set bits
      var bits = 0;
      for (var i = 0; i < n; i++) {
        if ((mask & (1 << i)) != 0) bits++;
      }
      if (bits != k) continue;
      final rSet = <int>{};
      var minR = 99;
      var maxR = -1;
      for (var i = 0; i < n; i++) {
        if ((mask & (1 << i)) != 0) {
          final r = cribRank(all5[i]);
          rSet.add(r);
          if (r < minR) minR = r;
          if (r > maxR) maxR = r;
        }
      }
      if (rSet.length == k && maxR - minR == k - 1) {
        countRuns++;
      }
    }
    if (countRuns > 0) {
      runs = countRuns * k;
      break;
    }
  }

  // 4. Flush: 4 hand cards of same suit = 4 pts (hand only), + starter of same suit = 5 pts.
  var flush = 0;
  if (hand4.length == 4) {
    final s0 = cribSuit(hand4[0]);
    if (hand4.every((c) => cribSuit(c) == s0)) {
      if (starter.isNotEmpty && cribSuit(starter) == s0) {
        flush = 5;
      } else if (!isCrib) {
        flush = 4;
      }
    }
  }

  // 5. Nobs ("His Nobs"): Jack in hand4 matching starter's suit = 1 pt.
  var nobs = 0;
  if (starter.isNotEmpty) {
    final stSuit = cribSuit(starter);
    if (hand4.any((c) => cribRank(c) == 11 && cribSuit(c) == stSuit)) {
      nobs = 1;
    }
  }

  final total = fifteens + pairs + runs + flush + nobs;
  final details = <String>[
    if (fifteens > 0) '凑15 +$fifteens',
    if (pairs > 0) '对子 +$pairs',
    if (runs > 0) '顺子 +$runs',
    if (flush > 0) '同花 +$flush',
    if (nobs > 0) '同花J +$nobs',
    if (total == 0) '0分',
  ];
  return (
    total: total,
    fifteens: fifteens,
    pairs: pairs,
    runs: runs,
    flush: flush,
    nobs: nobs,
    details: details,
  );
}

/// 克里比奇 (Cribbage) 2人经典扑克游戏
class Cribbage extends GameEngine {
  Cribbage(super.setup);

  int targetScore = 61;
  String phase = 'discard'; // discard | pegging | show | over
  int dealer = 0;
  int turn = 0;
  int handNo = 0;

  List<int> scores = [0, 0];
  List<int> prevScores = [0, 0];

  List<String> deck = [];
  List<List<String>> hands = [[], []];
  List<List<String>> keptHands = [[], []];
  List<String> crib = [];
  List<bool> discarded = [false, false];
  String starter = '';

  // Pegging state
  int count = 0;
  List<String> seq = [];
  List<Map<String, dynamic>> peggedAll = [];
  List<bool> saidGo = [false, false];
  int lastPlayer = -1;
  String lastEvent = '';

  // Show / End state
  Map<String, dynamic>? showSummary;
  List<bool> ready = [false, false];
  int winner = -1;
  bool resigned = false;
  final List<String> log = [];

  int opp(int s) => 1 - s;

  void _log(String msg) {
    log.add(msg);
    if (log.length > 12) log.removeAt(0);
    host.log(msg);
  }

  @override
  bool get isOver => phase == 'over';

  @override
  List<int> get waitingFor {
    if (phase == 'discard') {
      return [
        for (var s = 0; s < 2; s++)
          if (!discarded[s]) s,
      ];
    }
    if (phase == 'pegging') return [turn];
    if (phase == 'show') {
      return [
        for (var s = 0; s < 2; s++)
          if (!ready[s]) s,
      ];
    }
    return const [];
  }

  @override
  List<int>? get placings {
    if (!isOver) return null;
    if (winner >= 0) return [winner == 0 ? 1 : 2, winner == 1 ? 1 : 2];
    return rankByScore(scores);
  }

  @override
  bool get canResign => !isOver;

  @override
  void resign(int seat) {
    if (isOver) throw GameError('对局已结束');
    if (seat < 0 || seat > 1) throw GameError('无效座位');
    winner = opp(seat);
    resigned = true;
    phase = 'over';
    _log('${name(seat)} 认输，${name(winner)} 获胜');
  }

  @override
  void start() {
    targetScore = setup.opt<int>('target', 61);
    dealer = rng.nextInt(2);
    scores = [0, 0];
    prevScores = [0, 0];
    handNo = 0;
    _log('克里比奇开始：目标 $targetScore 分');
    _deal();
  }

  void _deal() {
    handNo++;
    deck = shuffled(cribDeck(), rng);
    hands = [deck.sublist(0, 6), deck.sublist(6, 12)];
    for (final h in hands) {
      cribSort(h);
    }
    keptHands = [[], []];
    crib = [];
    discarded = [false, false];
    starter = '';
    count = 0;
    seq = [];
    peggedAll = [];
    saidGo = [false, false];
    lastPlayer = -1;
    lastEvent = '第 $handNo 手：请各选 2 张牌放入庄家（${name(dealer)}）的底牌（Crib）';
    showSummary = null;
    ready = [false, false];
    phase = 'discard';
    turn = opp(dealer);
    _log('第 $handNo 手：${name(dealer)} 坐庄，每人发 6 张牌');
  }

  bool _addScore(int seat, int pts, String reason) {
    if (pts <= 0 || isOver) return isOver;
    prevScores[seat] = scores[seat];
    scores[seat] += pts;
    lastEvent = '${name(seat)} $reason（${scores[seat]}/$targetScore）';
    _log(lastEvent);
    if (scores[seat] >= targetScore) {
      winner = seat;
      phase = 'over';
      _log('${name(seat)} 率先达到 ${scores[seat]} 分，赢得比赛！');
      return true;
    }
    return false;
  }

  bool _canPlay(int seat) => hands[seat].any((c) => count + cribVal(c) <= 31);

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (seat < 0 || seat > 1) throw GameError('无效座位');
    if (isOver) throw GameError('对局已结束');
    final type = asStr(action['type']);

    if (phase == 'discard') {
      if (type != 'discard') throw GameError('请选择 2 张牌放入 Crib');
      if (discarded[seat]) throw GameError('你已经选过底牌了');
      final raw = action['cards'];
      if (raw is! List || raw.length != 2) throw GameError('必须选择恰好 2 张牌放入 Crib');
      final c1 = asStr(raw[0]);
      final c2 = asStr(raw[1]);
      if (c1 == c2) throw GameError('不能重复选择同一张牌');
      if (!hands[seat].contains(c1) || !hands[seat].contains(c2)) {
        throw GameError('你手中没有所选的牌');
      }
      hands[seat].remove(c1);
      hands[seat].remove(c2);
      crib.addAll([c1, c2]);
      cribSort(hands[seat]);
      keptHands[seat] = List.of(hands[seat]);
      discarded[seat] = true;
      _log('${name(seat)} 已放入 2 张底牌');

      if (discarded[0] && discarded[1]) {
        cribSort(crib);
        starter = deck[12];
        _log('切出起手牌（Starter）：$starter');
        if (cribRank(starter) == 11) {
          if (_addScore(dealer, 2, 'His Heels（起手牌为J +2）')) return;
        }
        phase = 'pegging';
        turn = opp(dealer);
        count = 0;
        seq = [];
        saidGo = [false, false];
        lastPlayer = -1;
        lastEvent = '起手牌 $starter，轮到 ${name(turn)} 出牌';
      }
      return;
    }

    if (phase == 'pegging') {
      if (seat != turn) throw GameError('还没轮到你');
      if (type == 'play') {
        final card = asStr(action['card']);
        if (!hands[seat].contains(card)) throw GameError('你手中没有这张牌');
        final v = cribVal(card);
        if (count + v > 31) {
          throw GameError('当前累计 $count 点，打出 $card 会超过 31 点');
        }
        if (keptHands[seat].isEmpty) {
          keptHands[seat] = List.of(hands[seat]);
        }
        hands[seat].remove(card);
        count += v;
        seq.add(card);
        final scored = scorePeggingPlay(seq, count);
        peggedAll.add({
          'seat': seat,
          'card': card,
          'count': count,
          'pts': scored.pts,
          'desc': scored.reasons.join('、'),
        });
        if (scored.pts > 0) {
          if (_addScore(seat, scored.pts, '打出 $card（累计$count）：${scored.reasons.join('、')}')) {
            return;
          }
        } else {
          lastEvent = '${name(seat)} 打出 $card（累计 $count）';
          _log(lastEvent);
        }

        // Check if all cards have been pegged
        if (hands[0].isEmpty && hands[1].isEmpty) {
          if (count < 31) {
            if (_addScore(seat, 1, '最后一牌 (+1)')) return;
          }
          count = 0;
          seq.clear();
          _scoreShow();
          return;
        }

        if (count == 31) {
          count = 0;
          seq.clear();
          saidGo = [false, false];
          lastPlayer = -1;
          final next = opp(seat);
          turn = hands[next].isNotEmpty ? next : seat;
          return;
        }

        // count < 31 and some cards remain
        lastPlayer = seat;
        if (hands[seat].isEmpty) saidGo[seat] = true;
        final other = opp(seat);
        if (hands[other].isEmpty) saidGo[other] = true;

        if (!saidGo[other]) {
          turn = other;
        } else if (_canPlay(seat)) {
          turn = seat;
        } else {
          _awardGoAndReset(seat);
        }
        return;
      }

      if (type == 'go') {
        if (_canPlay(seat)) {
          throw GameError('你手中有不超过 31 点的可出牌，不能喊 Go');
        }
        saidGo[seat] = true;
        lastEvent = '${name(seat)} 喊 Go';
        _log(lastEvent);
        final other = opp(seat);
        if (!saidGo[other] && _canPlay(other)) {
          turn = other;
        } else {
          _awardGoAndReset(seat);
        }
        return;
      }

      throw GameError('出牌阶段请选择出牌或喊 Go');
    }

    if (phase == 'show') {
      if (type != 'next_hand' && type != 'continue') {
        throw GameError('请点击下一手继续');
      }
      ready[seat] = true;
      if (ready[0] && ready[1]) {
        dealer = opp(dealer);
        _deal();
      }
      return;
    }
  }

  void _awardGoAndReset(int fallbackSeat) {
    final lp = lastPlayer >= 0 ? lastPlayer : fallbackSeat;
    if (_addScore(lp, 1, 'Go 最后出牌 (+1)')) return;
    count = 0;
    seq.clear();
    saidGo = [false, false];
    lastPlayer = -1;
    final next = opp(lp);
    turn = hands[next].isNotEmpty ? next : lp;
  }

  void _scoreShow() {
    for (var s = 0; s < 2; s++) {
      if (keptHands[s].isEmpty && hands[s].isNotEmpty) {
        keptHands[s] = List.of(hands[s]);
      }
    }
    final nonDealer = opp(dealer);
    final ndScore = scoreCribbageHand(keptHands[nonDealer], starter, isCrib: false);
    final dlScore = scoreCribbageHand(keptHands[dealer], starter, isCrib: false);
    final crScore = scoreCribbageHand(crib, starter, isCrib: true);

    showSummary = {
      'starter': starter,
      'nonDealer': nonDealer,
      'dealer': dealer,
      'ndCards': List.of(keptHands[nonDealer]),
      'ndPts': ndScore.total,
      'ndDetails': ndScore.details,
      'dlCards': List.of(keptHands[dealer]),
      'dlPts': dlScore.total,
      'dlDetails': dlScore.details,
      'cribCards': List.of(crib),
      'cribPts': crScore.total,
      'cribDetails': crScore.details,
    };

    // 1. Non-Dealer hand
    _log('【亮牌计分】闲家 ${name(nonDealer)} 手牌：${ndScore.details.join('，')} = +${ndScore.total}');
    if (_addScore(nonDealer, ndScore.total, '闲家亮牌 (+${ndScore.total})')) return;

    // 2. Dealer hand
    _log('【亮牌计分】庄家 ${name(dealer)} 手牌：${dlScore.details.join('，')} = +${dlScore.total}');
    if (_addScore(dealer, dlScore.total, '庄家亮牌 (+${dlScore.total})')) return;

    // 3. Dealer Crib
    _log('【亮牌计分】庄家 ${name(dealer)} 底牌(Crib)：${crScore.details.join('，')} = +${crScore.total}');
    if (_addScore(dealer, crScore.total, 'Crib底牌 (+${crScore.total})')) return;

    phase = 'show';
    ready = [false, false];
  }

  @override
  Map<String, dynamic> view(int seat) {
    final isPlayer = seat == 0 || seat == 1;
    final showRevealed = phase == 'show' || (phase == 'over' && showSummary != null);
    final myHand = isPlayer
        ? (showRevealed && keptHands[seat].isNotEmpty ? keptHands[seat] : hands[seat])
        : <String>[];
    return {
      'phase': phase,
      'dealer': dealer,
      'turn': phase == 'pegging' ? turn : -1,
      'handNo': handNo,
      'targetScore': targetScore,
      'scores': scores,
      'prevScores': prevScores,
      'hand': myHand,
      'keptHand': isPlayer ? keptHands[seat] : <String>[],
      'handCounts': [hands[0].length, hands[1].length],
      'discarded': discarded,
      'cribCount': crib.length,
      'crib': showRevealed ? crib : <String>[],
      'starter': starter,
      'count': count,
      'seq': seq,
      'peggedAll': peggedAll,
      'saidGo': saidGo,
      'canPlay': isPlayer && phase == 'pegging' && turn == seat ? _canPlay(seat) : false,
      'lastEvent': lastEvent,
      'showSummary': showSummary,
      'ready': phase == 'show' ? ready : null,
      'winner': winner,
      'resigned': resigned,
      'log': log,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (phase == 'discard') {
      if (discarded[seat]) return null;
      final h = hands[seat];
      if (h.length < 2) return null;
      if (botLevel == 0) {
        return {'type': 'discard', 'cards': [h[0], h[1]]};
      }
      var bestScore = -999999;
      List<String> bestPair = [h[0], h[1]];
      for (var i = 0; i < h.length; i++) {
        for (var j = i + 1; j < h.length; j++) {
          final kept = <String>[
            for (var k = 0; k < h.length; k++)
              if (k != i && k != j) h[k],
          ];
          final base = scoreCribbageHand(kept, '', isCrib: false).total * 10;
          final c1 = h[i], c2 = h[j];
          var cribBias = 0;
          if (cribVal(c1) + cribVal(c2) == 15) cribBias += 20;
          if (cribRank(c1) == cribRank(c2)) cribBias += 20;
          if (cribRank(c1) == 5) cribBias += 10;
          if (cribRank(c2) == 5) cribBias += 10;
          final totalEval = seat == dealer ? base + cribBias : base - cribBias;
          if (totalEval > bestScore) {
            bestScore = totalEval;
            bestPair = [c1, c2];
          }
        }
      }
      return {'type': 'discard', 'cards': bestPair};
    }

    if (phase == 'pegging') {
      if (seat != turn) return null;
      final playable = hands[seat].where((c) => count + cribVal(c) <= 31).toList();
      if (playable.isEmpty) return {'type': 'go'};
      if (botLevel == 0) {
        return {'type': 'play', 'card': playable[rng.nextInt(playable.length)]};
      }
      String bestCard = playable.first;
      var bestVal = -9999;
      for (final c in playable) {
        final newCount = count + cribVal(c);
        final pts = scorePeggingPlay([...seq, c], newCount).pts;
        var val = pts * 100;
        if (newCount == 5 || newCount == 21) val -= 25; // Avoid giving easy 15 or 31
        if (botLevel >= 2 && newCount <= 10 && cribRank(c) == 5) val -= 15;
        if (val > bestVal) {
          bestVal = val;
          bestCard = c;
        }
      }
      return {'type': 'play', 'card': bestCard};
    }

    if (phase == 'show') {
      return ready[seat] ? null : {'type': 'next_hand'};
    }
    return null;
  }
}

const String cribbageRules = '''
# 克里比奇 (Cribbage)
风靡欧美数百年的经典双人扑克计分游戏，使用一副 52 张标准扑克牌与计分孔板（Pegging Track），率先到达目标分数（61 分半程快速或 121 分标准全场）的玩家立即获胜！

# 牌点与大小
- 累加点数（用于凑 15 与 31）：A = 1 点，2~10 按牌面点数，J / Q / K = 10 点。
- 顺子与对子序数：A(1)、2、3、4、5、6、7、8、9、10、J(11)、Q(12)、K(13)。

# 每手流程
1. **选底牌（Discard）**：每手发给双方各 6 张牌。双方各选 2 张牌暗置放入庄家（Dealer）的额外底牌堆（Crib），各自保留 4 张手牌。
2. **切起手牌（Starter）**：从牌堆切出一张公共起手牌。若翻出的是 J（Jack），庄家立即得 2 分（His Heels）。
3. **打点阶段（Pegging）**：
   - 从闲家（Non-Dealer）开始，双方轮流打出一张牌并累加公共点数，累计点数不可超过 31 点。
   - **凑 15（Fifteen）**：打出牌后累计点数恰好为 15，得 2 分。
   - **凑 31（Thirty-One）**：打出牌后累计点数恰好为 31，得 2 分，随后公共点数归零重计。
   - **对子 / 三条 / 四条**：紧接前一张或多张相同序数的牌，成对得 2 分、三条得 6 分、四条得 12 分。
   - **顺子（Run）**：当前计数序列末尾连续 L 张牌（L ≥ 3，顺序不限）能组成连续序数，得 L 分。
   - **喊 Go 与最后一牌（One for Last）**：若手中没有可令累计点数 ≤ 31 的牌，必须喊“Go”；能继续出牌的一方继续出牌，本轮计数序列最后出牌者得 1 分（若恰好 31 则只计 31 的 2 分），随后累计点数归零。
4. **亮牌计分（The Show）**：
   - 8 张牌全部打完后，各自收回 4 张手牌，依次按 **闲家手牌 → 庄家手牌 → 庄家底牌（Crib）** 结合公共起手牌（共 5 张）计分：
   - **凑 15**：任意张牌点数之和为 15，每组得 2 分。
   - **对子**：每对相同点数的牌得 2 分（三条=6分，四条=12分）。
   - **顺子**：3 张或以上连续序数的牌，每张得 1 分（含双顺、三顺等组合）。
   - **同花（Flush）**：4 张手牌同花色得 4 分，若起手牌也同花色得 5 分（Crib 底牌须 5 张全同花才得 5 分）。
   - **同花 J（His Nobs）**：手牌或底牌中含有与起手牌同花色的 J，得 1 分。

# 胜负条件
- 无论是打点阶段还是亮牌阶段，**只要任意一方达到或超过目标分数（61 / 121 分），立即获胜**（因此亮牌时闲家先行计分具有关键优势）！
''';
