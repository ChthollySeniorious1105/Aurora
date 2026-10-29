import '../../src/engine.dart';

class EvidenceSymbol {
  final int id;
  final String name;
  final String icon;
  final int totalInDeck;

  const EvidenceSymbol(this.id, this.name, this.icon, this.totalInDeck);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'totalInDeck': totalInDeck,
      };
}

/// The 8 classic Evidence Symbols in Sherlock 13.
const List<EvidenceSymbol> kSherlockSymbols = [
  EvidenceSymbol(0, '烟斗', '🪈', 5),
  EvidenceSymbol(1, '灯泡', '💡', 5),
  EvidenceSymbol(2, '拳头', '✊', 5),
  EvidenceSymbol(3, '警徽', '🛡️', 5),
  EvidenceSymbol(4, '书籍', '📖', 5),
  EvidenceSymbol(5, '项链', '📿', 4),
  EvidenceSymbol(6, '眼睛', '👁️', 3),
  EvidenceSymbol(7, '骷髅', '💀', 3),
];

class SuspectCard {
  final int id;
  final String name;
  final List<int> symbols;

  const SuspectCard(this.id, this.name, this.symbols);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'symbols': symbols,
      };
}

/// The 13 classic Suspect Cards in Sherlock 13 (each with 2-3 unique symbols).
const List<SuspectCard> kSherlockSuspects = [
  SuspectCard(0, '夏洛克·福尔摩斯', [0, 1, 2]),
  SuspectCard(1, '约翰·华生医生', [0, 2, 6]),
  SuspectCard(2, '莫里亚蒂教授', [1, 4, 7]),
  SuspectCard(3, '艾琳·艾德勒', [1, 5, 7]),
  SuspectCard(4, '雷斯垂德探长', [0, 3, 4]),
  SuspectCard(5, '格雷格森探长', [2, 3, 4]),
  SuspectCard(6, '霍普金斯探长', [0, 3, 6]),
  SuspectCard(7, '贝恩斯探长', [1, 2, 3]),
  SuspectCard(8, '布莱德斯特里特探长', [2, 3]),
  SuspectCard(9, '哈德森太太', [0, 5]),
  SuspectCard(10, '玛丽·摩斯坦', [4, 5]),
  SuspectCard(11, '迈克罗夫特·福尔摩斯', [1, 4, 5]),
  SuspectCard(12, '巴斯克维尔猎犬', [6, 7]),
];

int sherlockSymbolCount(List<int> hand, int symbol) {
  var c = 0;
  for (final id in hand) {
    if (kSherlockSuspects[id].symbols.contains(symbol)) c++;
  }
  return c;
}

List<int> sherlockAllSymbolCounts(List<int> hand) => [
      for (var s = 0; s < 8; s++) sherlockSymbolCount(hand, s),
    ];

class Sherlock13Game extends GameEngine {
  Sherlock13Game(super.setup);

  int culprit = -1;
  late List<List<int>> hands;
  late List<bool> eliminated;
  late List<List<bool?>> publicHasSymbol; // [player][symbol] -> true/false/null
  late List<Map<String, int>> knownExactCounts; // [viewer]['$target:$symbol'] -> count

  int turn = 0;
  int? winner;
  List<Map<String, dynamic>> history = [];
  String lastEvent = '';
  bool _over = false;

  @override
  bool get isOver => _over;

  @override
  void start() {
    final deck = shuffled([for (var i = 0; i < 13; i++) i], rng);
    culprit = deck.removeAt(0);
    final perPlayer = 12 ~/ players;
    hands = [
      for (var s = 0; s < players; s++)
        (deck.sublist(s * perPlayer, (s + 1) * perPlayer)..sort()),
    ];
    eliminated = List<bool>.filled(players, false);
    publicHasSymbol = [
      for (var p = 0; p < players; p++) List<bool?>.filled(8, null),
    ];
    knownExactCounts = [
      for (var viewer = 0; viewer < players; viewer++)
        {
          for (var sym = 0; sym < 8; sym++) '$viewer:$sym': sherlockSymbolCount(hands[viewer], sym),
        },
    ];
    turn = 0;
    winner = null;
    history = [];
    _over = false;
    lastEvent = '1 张真凶牌已暗置中央，其余 12 张嫌疑人牌已均分！轮流提问或指认凶手。';
    host.log(lastEvent);
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn || eliminated[seat]) throw GameError('还没轮到你行动');
    final type = asStr(action['type']);

    if (type == 'ask_all') {
      final sym = asInt(action['symbol'], -1);
      if (sym < 0 || sym >= 8) throw GameError('请选择有效的证物符号 (0..7)');
      final holders = <int>[];
      for (var p = 0; p < players; p++) {
        final cnt = sherlockSymbolCount(hands[p], sym);
        final has = cnt > 0;
        publicHasSymbol[p][sym] = has;
        if (has) {
          holders.add(p);
        } else {
          for (var v = 0; v < players; v++) {
            knownExactCounts[v]['$p:$sym'] = 0;
          }
        }
      }
      final symName = kSherlockSymbols[sym].name;
      final holderNames = holders.isEmpty ? '无人持有' : holders.map(name).join('、');
      lastEvent = '${name(seat)} 全场询问【$symName】：持有者为 [$holderNames]';
      host.log(lastEvent);
      history.add({
        'type': 'ask_all',
        'seat': seat,
        'symbol': sym,
        'holders': holders,
        'text': lastEvent,
      });
      _advanceTurn();
      return;
    }

    if (type == 'ask_one') {
      final target = asInt(action['target'], -1);
      final sym = asInt(action['symbol'], -1);
      if (target < 0 || target >= players || target == seat) {
        throw GameError('请选择一名其他玩家进行单独询问');
      }
      if (sym < 0 || sym >= 8) throw GameError('请选择有效的证物符号 (0..7)');
      final cnt = sherlockSymbolCount(hands[target], sym);
      knownExactCounts[seat]['$target:$sym'] = cnt;
      publicHasSymbol[target][sym] = cnt > 0;
      if (cnt == 0) {
        for (var v = 0; v < players; v++) {
          knownExactCounts[v]['$target:$sym'] = 0;
        }
      }
      final symName = kSherlockSymbols[sym].name;
      lastEvent = '${name(seat)} 单独询问 ${name(target)} 持有多少个【$symName】（共 $cnt 个）';
      host.log(lastEvent);
      history.add({
        'type': 'ask_one',
        'seat': seat,
        'target': target,
        'symbol': sym,
        'count': cnt,
        'text': lastEvent,
      });
      _advanceTurn();
      return;
    }

    if (type == 'accuse') {
      final suspect = asInt(action['suspect'], -1);
      if (suspect < 0 || suspect >= 13) throw GameError('请选择有效的嫌疑人 (0..12)');
      final suspectName = kSherlockSuspects[suspect].name;
      if (suspect == culprit) {
        winner = seat;
        _over = true;
        lastEvent = '${name(seat)} 成功指认出真凶【$suspectName】，赢得推理胜利！';
        host.log(lastEvent);
        history.add({
          'type': 'accuse',
          'seat': seat,
          'suspect': suspect,
          'correct': true,
          'text': lastEvent,
        });
      } else {
        eliminated[seat] = true;
        lastEvent = '${name(seat)} 指认【$suspectName】错误，失去后续指认资格！';
        host.log(lastEvent);
        history.add({
          'type': 'accuse',
          'seat': seat,
          'suspect': suspect,
          'correct': false,
          'text': lastEvent,
        });
        if (eliminated.every((e) => e)) {
          _over = true;
          lastEvent = '全员指认失败！真凶是【${kSherlockSuspects[culprit].name}】。';
          host.log(lastEvent);
        } else {
          _advanceTurn();
        }
      }
      return;
    }

    throw GameError('未知操作：$type');
  }

  void _advanceTurn() {
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (!eliminated[next]) {
        turn = next;
        return;
      }
    }
  }

  /// Deduces candidate suspect IDs (0..12) still consistent with [seat]'s knowledge.
  List<int> deduceCandidates(int seat) {
    final myCards = (seat >= 0 && seat < players) ? hands[seat].toSet() : <int>{};
    final wrongAccused = <int>{
      for (final h in history)
        if (h['type'] == 'accuse' && h['correct'] == false) h['suspect'] as int,
    };
    // Any symbol where we know the sum across all players equals totalInDeck cannot be on culprit
    final impossibleSymbols = <int>{};
    final requiredSymbols = <int>{};
    if (seat >= 0 && seat < players) {
      for (var sym = 0; sym < 8; sym++) {
        var knownSum = 0;
        var allKnown = true;
        for (var p = 0; p < players; p++) {
          final k = knownExactCounts[seat]['$p:$sym'];
          if (k != null) {
            knownSum += k;
          } else {
            allKnown = false;
            if (publicHasSymbol[p][sym] == true) {
              knownSum += 1; // at least 1
            }
          }
        }
        final total = kSherlockSymbols[sym].totalInDeck;
        if (knownSum >= total) {
          impossibleSymbols.add(sym);
        } else if (allKnown && knownSum < total) {
          requiredSymbols.add(sym);
        }
      }
    }

    final out = <int>[];
    for (final s in kSherlockSuspects) {
      if (myCards.contains(s.id) || wrongAccused.contains(s.id)) continue;
      if (s.symbols.any(impossibleSymbols.contains)) continue;
      if (!requiredSymbols.every(s.symbols.contains)) continue;
      out.add(s.id);
    }
    if (out.isEmpty) {
      return [
        for (var i = 0; i < 13; i++)
          if (!myCards.contains(i) && !wrongAccused.contains(i)) i,
      ];
    }
    return out;
  }

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (winner != null) {
      return rankWinners(players, [winner!]);
    }
    return List<int>.filled(players, 1);
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = (seat >= 0 && seat < players) ? hands[seat] : const <int>[];
    return {
      'turn': turn,
      'eliminated': eliminated,
      'winner': winner,
      'culprit': _over ? culprit : -1,
      'myHand': myHand,
      'mySymbolCounts': sherlockAllSymbolCounts(myHand),
      'handCounts': [for (var p = 0; p < players; p++) hands[p].length],
      'publicHasSymbol': publicHasSymbol,
      'knownExactCounts': (seat >= 0 && seat < players) ? knownExactCounts[seat] : const <String, int>{},
      'candidates': (seat >= 0 && seat < players) ? deduceCandidates(seat) : const <int>[],
      'history': history,
      'lastEvent': lastEvent,
      'symbolsCatalog': [for (final s in kSherlockSymbols) s.toJson()],
      'suspectsCatalog': [for (final s in kSherlockSuspects) s.toJson()],
      if (_over) ...{
        'allHands': hands,
        'placings': placings,
      },
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn || eliminated[seat]) return null;

    final cands = deduceCandidates(seat);
    // Accuse immediately if narrowed down to 1 candidate, or after enough inquiries
    if (cands.length == 1 || history.length >= players * 2 + 2) {
      final pick = cands[rng.nextInt(cands.length)];
      return {'type': 'accuse', 'suspect': pick};
    }

    // Find an unknown (player, symbol) pair to inquire about
    for (var sym = 0; sym < 8; sym++) {
      final unknownPlayers = <int>[
        for (var p = 0; p < players; p++)
          if (p != seat && knownExactCounts[seat]['$p:$sym'] == null) p,
      ];
      if (unknownPlayers.length >= 2 && publicHasSymbol.any((row) => row[sym] == null)) {
        return {'type': 'ask_all', 'symbol': sym};
      }
      if (unknownPlayers.isNotEmpty) {
        return {'type': 'ask_one', 'target': unknownPlayers.first, 'symbol': sym};
      }
    }

    return {'type': 'accuse', 'suspect': cands.first};
  }
}
