import 'dart:math';

import '../../src/engine.dart';

const List<String> _suits = ['S', 'H', 'D', 'C'];
const List<String> _ranks = ['6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];
const Map<String, String> _suitNames = {'S': '♠黑桃', 'H': '♥红桃', 'D': '♦方片', 'C': '♣梅花'};

List<String> durakDeck() => [
      for (final s in _suits)
        for (final r in _ranks) '$r$s',
    ];

/// Card rank 6..14 (6=6 .. 9=9, T=10, J=11, Q=12, K=13, A=14).
int durakRank(String card) {
  if (card.length < 2) return 0;
  final r = card.substring(0, card.length - 1);
  final idx = _ranks.indexOf(r);
  return idx >= 0 ? idx + 6 : 0;
}

String durakSuit(String card) => card.isEmpty ? '' : card[card.length - 1];

void durakSort(List<String> cards, String trumpSuit) {
  cards.sort((a, b) {
    final ta = durakSuit(a) == trumpSuit ? 1 : 0;
    final tb = durakSuit(b) == trumpSuit ? 1 : 0;
    if (ta != tb) return ta.compareTo(tb);
    final rc = durakRank(a).compareTo(durakRank(b));
    if (rc != 0) return rc;
    return _suits.indexOf(durakSuit(a)).compareTo(_suits.indexOf(durakSuit(b)));
  });
}

/// Returns true if [defCard] legally beats [atkCard] given [trumpSuit].
bool durakBeats(String defCard, String atkCard, String trumpSuit) {
  final ds = durakSuit(defCard);
  final as = durakSuit(atkCard);
  if (ds == as) return durakRank(defCard) > durakRank(atkCard);
  if (ds == trumpSuit && as != trumpSuit) return true;
  return false;
}

/// 杜拉克 / 傻瓜牌 (Durak) 2~6人经典攻防扑克游戏
class Durak extends GameEngine {
  Durak(super.setup);

  List<String> talon = [];
  String trumpCard = '';
  String trumpSuit = 'S';
  int discardCount = 0;

  List<List<String>> hands = [];
  int attacker = 0;
  int defender = 1;
  int turn = 0;
  String phase = 'attack'; // attack | defend | over
  int boutNo = 0;

  /// Cards currently on the table: each entry is `{'attack': String, 'defense': String?}`.
  List<Map<String, String?>> table = [];

  /// Order in which players emptied their hands once the talon is empty.
  List<int> finishedOrder = [];
  int durakLoser = -1;
  final List<String> log = [];

  void _log(String msg) {
    log.add(msg);
    if (log.length > 12) log.removeAt(0);
    host.log(msg);
  }

  @override
  bool get isOver => phase == 'over';

  @override
  List<int> get waitingFor => isOver ? const [] : [turn];

  @override
  List<int>? get placings {
    if (!isOver) return null;
    final res = List<int>.filled(players, players);
    for (var i = 0; i < finishedOrder.length; i++) {
      res[finishedOrder[i]] = i + 1;
    }
    if (durakLoser >= 0 && durakLoser < players) {
      res[durakLoser] = finishedOrder.length + 1;
    }
    return res;
  }

  /// Ranks (6..14) currently present on the table (either as attack or defense).
  Set<int> tableRanks() {
    final s = <int>{};
    for (final pair in table) {
      final a = pair['attack'];
      final d = pair['defense'];
      if (a != null) s.add(durakRank(a));
      if (d != null) s.add(durakRank(d));
    }
    return s;
  }

  /// Whether [card] can be played as an attack right now.
  bool canAttackWith(String card) {
    if (table.isEmpty) return true;
    if (table.length >= 6 || hands[defender].isEmpty) return false;
    return tableRanks().contains(durakRank(card));
  }

  List<String> legalAttackCards(int seat) {
    if (phase != 'attack' || seat != attacker) return const [];
    return hands[seat].where(canAttackWith).toList();
  }

  List<String> legalDefenseCards(int seat) {
    if (phase != 'defend' || seat != defender || table.isEmpty) return const [];
    final atk = table.last['attack'];
    if (atk == null) return const [];
    return hands[seat].where((c) => durakBeats(c, atk, trumpSuit)).toList();
  }

  int _nextActive(int from, {int? exclude}) {
    for (var i = 1; i <= players; i++) {
      final s = (from + i) % players;
      if (s == exclude) continue;
      if (hands[s].isNotEmpty) return s;
    }
    return (from + 1) % players;
  }

  void _checkPlayerFinished(int s) {
    if (talon.isEmpty && hands[s].isEmpty && !finishedOrder.contains(s)) {
      finishedOrder.add(s);
      _log('${name(s)} 出完所有手牌，成功脱身（第 ${finishedOrder.length} 名）！');
    }
  }

  bool _checkGameOver() {
    if (talon.isNotEmpty) return false;
    for (var s = 0; s < players; s++) {
      if (hands[s].isEmpty && !finishedOrder.contains(s)) {
        finishedOrder.add(s);
      }
    }
    final active = [
      for (var s = 0; s < players; s++)
        if (hands[s].isNotEmpty) s,
    ];
    if (active.length <= 1) {
      durakLoser = active.isNotEmpty ? active.first : -1;
      phase = 'over';
      turn = -1;
      if (durakLoser >= 0) {
        _log('游戏结束！${name(durakLoser)} 成为最后的杜拉克（傻瓜）！');
      } else {
        _log('游戏结束！全员打光手牌！');
      }
      return true;
    }
    return false;
  }

  @override
  void start() {
    final deck = shuffled(durakDeck(), rng);
    hands = [
      for (var s = 0; s < players; s++) deck.sublist(s * 6, (s + 1) * 6),
    ];
    talon = deck.sublist(players * 6);
    // Bottom card of talon is talon.first (drawn last via talon.removeLast()).
    trumpCard = talon.isNotEmpty ? talon.first : deck.last;
    trumpSuit = durakSuit(trumpCard);
    for (final h in hands) {
      durakSort(h, trumpSuit);
    }

    // Player with lowest trump attacks first (or seat 0 if none).
    attacker = 0;
    var lowestTrump = 99;
    for (var s = 0; s < players; s++) {
      for (final c in hands[s]) {
        if (durakSuit(c) == trumpSuit && durakRank(c) < lowestTrump) {
          lowestTrump = durakRank(c);
          attacker = s;
        }
      }
    }
    defender = _nextActive(attacker);
    turn = attacker;
    phase = 'attack';
    boutNo = 1;
    table = [];
    discardCount = 0;
    finishedOrder = [];
    durakLoser = -1;
    _log('杜拉克开始：底牌亮出主花色 $trumpCard（${_suitNames[trumpSuit] ?? trumpSuit}），${name(attacker)} 先攻，${name(defender)} 防守');
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (seat < 0 || seat >= players) throw GameError('无效座位');
    if (isOver) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');
    final type = asStr(action['type']);

    if (phase == 'attack') {
      if (type == 'attack') {
        final card = asStr(action['card']);
        if (!hands[seat].contains(card)) throw GameError('你手中没有这张牌');
        if (table.isNotEmpty) {
          if (table.length >= 6 || hands[defender].isEmpty) {
            throw GameError('本轮进攻张数已达上限');
          }
          if (!tableRanks().contains(durakRank(card))) {
            throw GameError('追加进攻的牌点数必须与桌面上已有的牌点数相同');
          }
        }
        hands[seat].remove(card);
        table.add({'attack': card, 'defense': null});
        _log('${name(seat)} 打出 $card 进攻 ${name(defender)}');
        _checkPlayerFinished(seat);
        if (_checkGameOver()) return;
        phase = 'defend';
        turn = defender;
        return;
      }

      if (type == 'done' || type == 'pass') {
        if (table.isEmpty) {
          throw GameError('本轮尚未发起进攻，请先打出一张进攻牌');
        }
        _endBoutBeaten();
        return;
      }

      throw GameError(table.isEmpty ? '请打出一张牌发起进攻' : '请追加同点数牌进攻，或结束进攻');
    }

    if (phase == 'defend') {
      if (type == 'defend') {
        final card = asStr(action['card']);
        if (!hands[seat].contains(card)) throw GameError('你手中没有这张牌');
        final atk = table.last['attack']!;
        if (!durakBeats(card, atk, trumpSuit)) {
          throw GameError('$card 无法管住 $atk（需同花色更大点数，或用主牌管副牌）');
        }
        hands[seat].remove(card);
        table.last['defense'] = card;
        _log('${name(seat)} 用 $card 挡住 $atk');
        _checkPlayerFinished(seat);
        if (_checkGameOver()) return;

        // If attacker already finished the game (0 cards and empty talon), end bout automatically.
        if (talon.isEmpty && hands[attacker].isEmpty) {
          _endBoutBeaten();
          return;
        }
        phase = 'attack';
        turn = attacker;
        return;
      }

      if (type == 'take') {
        final countTaken = table.fold<int>(0, (acc, p) => acc + 1 + (p['defense'] != null ? 1 : 0));
        for (final p in table) {
          hands[defender].add(p['attack']!);
          if (p['defense'] != null) hands[defender].add(p['defense']!);
        }
        durakSort(hands[defender], trumpSuit);
        table.clear();
        _log('${name(defender)} 放弃防守，收下桌面全部 $countTaken 张牌');
        _replenish(attacker, defender);
        if (_checkGameOver()) return;

        // Defender loses attack turn; player after defender becomes next attacker.
        attacker = _nextActive(defender);
        defender = _nextActive(attacker, exclude: attacker);
        boutNo++;
        phase = 'attack';
        turn = attacker;
        _log('第 $boutNo 轮：${name(attacker)} 进攻，${name(defender)} 防守');
        return;
      }

      throw GameError('防守方请选择可管住的牌防守，或放弃收牌');
    }
  }

  void _endBoutBeaten() {
    final discarded = table.fold<int>(0, (acc, p) => acc + 1 + (p['defense'] != null ? 1 : 0));
    discardCount += discarded;
    table.clear();
    _log('${name(defender)} 成功防住全部进攻，$discarded 张牌进入弃牌堆');
    _replenish(attacker, defender);
    if (_checkGameOver()) return;

    // Defender becomes the next attacker (or next active player if defender finished).
    attacker = hands[defender].isNotEmpty ? defender : _nextActive(defender);
    defender = _nextActive(attacker, exclude: attacker);
    boutNo++;
    phase = 'attack';
    turn = attacker;
    _log('第 $boutNo 轮：${name(attacker)} 进攻，${name(defender)} 防守');
  }

  void _replenish(int boutAttacker, int boutDefender) {
    final order = <int>[boutAttacker];
    for (var i = 1; i < players; i++) {
      final s = (boutAttacker + i) % players;
      if (s != boutDefender) order.add(s);
    }
    if (!order.contains(boutDefender)) order.add(boutDefender);

    for (final s in order) {
      while (hands[s].length < 6 && talon.isNotEmpty) {
        hands[s].add(talon.removeLast());
      }
      durakSort(hands[s], trumpSuit);
      _checkPlayerFinished(s);
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final isPlayer = seat >= 0 && seat < players;
    final legal = isPlayer && turn == seat
        ? (phase == 'attack' ? legalAttackCards(seat) : legalDefenseCards(seat))
        : <String>[];
    return {
      'phase': phase,
      'boutNo': boutNo,
      'attacker': attacker,
      'defender': defender,
      'turn': turn,
      'trumpCard': trumpCard,
      'trumpSuit': trumpSuit,
      'talonCount': talon.length,
      'discardCount': discardCount,
      'hand': isPlayer ? hands[seat] : <String>[],
      'legalCards': legal,
      'handCounts': [for (final h in hands) h.length],
      'table': [
        for (final p in table) {'attack': p['attack'], 'defense': p['defense']},
      ],
      'maxAttacks': min(6, table.length + hands[defender].length),
      'finishedOrder': finishedOrder,
      'durakLoser': durakLoser,
      'placings': placings,
      'log': log,
    };
  }

  int _cardCost(String c) => (durakSuit(c) == trumpSuit ? 100 : 0) + durakRank(c);

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;

    if (phase == 'attack') {
      final legal = legalAttackCards(seat);
      if (table.isEmpty) {
        if (legal.isEmpty) return null;
        final sorted = List.of(legal)..sort((a, b) => _cardCost(a).compareTo(_cardCost(b)));
        if (botLevel == 0 && sorted.length > 1 && rng.nextInt(3) == 0) {
          return {'type': 'attack', 'card': sorted[rng.nextInt(sorted.length)]};
        }
        return {'type': 'attack', 'card': sorted.first};
      } else {
        if (legal.isEmpty) return {'type': 'done'};
        final sorted = List.of(legal)..sort((a, b) => _cardCost(a).compareTo(_cardCost(b)));
        final best = sorted.first;
        // While talon still has cards, don't waste trump cards on follow-up attacks.
        if (talon.isNotEmpty && durakSuit(best) == trumpSuit) {
          return {'type': 'done'};
        }
        return {'type': 'attack', 'card': best};
      }
    }

    if (phase == 'defend') {
      final legal = legalDefenseCards(seat);
      if (legal.isEmpty) return {'type': 'take'};
      final sorted = List.of(legal)..sort((a, b) => _cardCost(a).compareTo(_cardCost(b)));
      return {'type': 'defend', 'card': sorted.first};
    }

    return null;
  }
}

const String durakRules = '''
# 杜拉克 / 傻瓜牌 (Durak)
俄罗斯及东欧最家喻户晓的国民扑克游戏（支持 2~6 人）。游戏的目标不是成为第一名，而是**避免成为最后一名手里还剩牌的“杜拉克（傻瓜）”**！

# 牌组与发牌
- 使用经典 36 张牌组：四种花色（♠ ♥ ♦ ♣）的 `6, 7, 8, 9, 10, J, Q, K, A`（6 最小，A 最大）。
- 开局每人发 6 张手牌。剩余牌作为摸牌堆（Talon），并将摸牌堆最底下一张牌翻开压在牌堆下方，其花色即为整局的**主花色（Trump）**（这张亮出的底牌会在摸牌堆被摸空时最后一张摸走）。
- 开局时持有最小主牌的玩家率先担任第 1 轮的**进攻方（Attacker）**，其顺时针下一位玩家担任**防守方（Defender）**。

# 攻防回合流程
1. **发起进攻**：进攻方打出一张牌放到桌面上向防守方发起进攻。
2. **防守或放弃**：
   - **防守（Defend）**：防守方必须打出一张能管住该进攻牌的手牌——**同花色且点数更大**的牌，或者当进攻牌是副牌时用任意一张**主花色牌**管住。
   - **放弃收牌（Take）**：若防守方无法管住或选择放弃，则将桌面上所有进攻牌与防守牌全部收入自己手牌。
3. **追加进攻（Throw-in）**：
   - 当防守方成功管住当前进攻牌后，进攻方若手中持有**与桌面上任意一张牌（不论是进攻牌还是防守牌）点数相同**的牌，可以继续追加打出（每轮最多进攻 6 张，且不超过防守方本轮初始手牌数）；或者选择**结束进攻（Done）**。
4. **回合结算与补牌**：
   - **防守成功**：若进攻方选择结束进攻，桌面上所有牌移入弃牌堆！双方依次从摸牌堆补牌至 6 张（先攻后守），随后**原防守方成为下一轮的进攻方**，向其下家发起进攻！
   - **防守失败（收牌）**：原防守方收下桌面所有牌并丧失进攻权，其余玩家补牌至 6 张，由**原防守方的下一位玩家**担任新一轮的进攻方！

# 脱身与胜负
- 当摸牌堆被摸空后，打光手牌的玩家即刻按顺序成功脱身（第 1 名、第 2 名……）。
- 当场上只剩最后 1 名玩家手中有牌时，游戏立即结束，该玩家即为本局的“杜拉克（傻瓜）”！
''';
