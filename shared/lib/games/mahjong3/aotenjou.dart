import '../../src/engine.dart';
import 'tiles.dart';

/// Next dora tile from indicator [ind] (0..33) in Riichi Mahjong order.
int aotenjouNextDora(int ind) {
  if (ind >= 0 && ind < 27) {
    final s = ind ~/ 9;
    final r = ind % 9;
    return s * 9 + (r + 1) % 9;
  }
  if (ind >= 27 && ind <= 30) {
    return 27 + (ind - 27 + 1) % 4;
  }
  if (ind >= 31 && ind <= 33) {
    return 31 + (ind - 31 + 1) % 3;
  }
  return 0;
}

/// Uncapped exponential basic points formula (青天井规则):
/// `basePoints = fu * 2^(han + 2)`
int aotenjouBasePoints(int fu, int han) {
  final shift = (han + 2).clamp(0, 50);
  return fu * (1 << shift);
}

int ceil100(int x) => ((x + 99) ~/ 100) * 100;

int aotenjouRonPoints(int fu, int han, {required bool isDealer}) {
  final bp = aotenjouBasePoints(fu, han);
  return ceil100(bp * (isDealer ? 6 : 4));
}

(int dealerPay, int nonDealerPay) aotenjouTsumoPayments(int fu, int han, {required bool isDealer}) {
  final bp = aotenjouBasePoints(fu, han);
  if (isDealer) return (0, ceil100(bp * 2));
  return (ceil100(bp * 2), ceil100(bp));
}

class AotenjouValue {
  final int fu;
  final int han;
  final int basePoints;
  final List<(String, int)> yaku;
  const AotenjouValue(this.fu, this.han, this.basePoints, this.yaku);

  String get label => [for (final (n, h) in yaku) '$n(${h}番)'].join(' ');
  List<List<Object>> toJson() => [for (final (n, h) in yaku) [n, h]];
}

class AotenjouCtx {
  final int winTile;
  final bool tsumo;
  final bool riichi;
  final bool doubleRiichi;
  final bool ippatsu;
  final bool rinshan;
  final bool chankan;
  final bool haitei;
  final bool houtei;
  final bool tenhou;
  final bool chiihou;
  final int seatWind; // 27..30
  final int roundWind; // 27..30
  final int dora;
  final int uraDora;
  final int redDora;

  const AotenjouCtx({
    required this.winTile,
    this.tsumo = false,
    this.riichi = false,
    this.doubleRiichi = false,
    this.ippatsu = false,
    this.rinshan = false,
    this.chankan = false,
    this.haitei = false,
    this.houtei = false,
    this.tenhou = false,
    this.chiihou = false,
    this.seatWind = kEast,
    this.roundWind = kEast,
    this.dora = 0,
    this.uraDora = 0,
    this.redDora = 0,
  });
}

bool _isKokushi(List<int> c) {
  if (countTotal(c) != 14) return false;
  const yaochu = [0, 8, 9, 17, 18, 26, 27, 28, 29, 30, 31, 32, 33];
  var pairs = 0;
  for (final k in yaochu) {
    if (c[k] == 0) return false;
    if (c[k] == 2) pairs++;
  }
  return pairs == 1;
}

int _yakuhaiCount(AotenjouCtx ctx, int t) {
  var v = 0;
  if (isDragon(t)) v++;
  if (t == ctx.seatWind) v++;
  if (t == ctx.roundWind) v++;
  return v;
}

/// Evaluates a complete 14-tile hand under Aotenjou (青天井) rules.
/// Every hand calculates true `fu` and `han` (including Yakuman = 13 han each),
/// and `basePoints = fu * 2^(han + 2)` without any Mangan cap.
AotenjouValue? aotenjouEvaluate(
  List<int> concealed,
  List<Meld> melds,
  AotenjouCtx ctx,
) {
  final needSets = 4 - melds.length;
  if (needSets < 0 || countTotal(concealed) != needSets * 3 + 2) return null;

  final closed = melds.every((m) => m.concealed);
  final all = List<int>.of(concealed);
  for (final m in melds) {
    for (final t in m.tiles) {
      all[t]++;
    }
  }

  AotenjouValue? best;
  void consider(AotenjouValue? v) {
    if (v == null) return;
    if (best == null ||
        v.basePoints > best!.basePoints ||
        (v.basePoints == best!.basePoints && v.han > best!.han)) {
      best = v;
    }
  }

  void addSituational(List<(String, int)> y) {
    if (ctx.tenhou) y.add(('天和', 13));
    if (ctx.chiihou) y.add(('地和', 13));
    if (ctx.doubleRiichi) {
      y.add(('双立直', 2));
    } else if (ctx.riichi) {
      y.add(('立直', 1));
    }
    if (ctx.ippatsu && (ctx.riichi || ctx.doubleRiichi)) y.add(('一发', 1));
    if (ctx.tsumo && closed) y.add(('门前清自摸和', 1));
    if (ctx.rinshan) y.add(('岭上开花', 1));
    if (ctx.chankan) y.add(('抢杠', 1));
    if (ctx.haitei && ctx.tsumo && !ctx.rinshan) y.add(('海底捞月', 1));
    if (ctx.houtei && !ctx.tsumo) y.add(('河底捞鱼', 1));
  }

  AotenjouValue finish(List<(String, int)> yaku, int fu) {
    final items = List<(String, int)>.of(yaku);
    if (ctx.dora > 0) items.add(('宝牌', ctx.dora));
    if (ctx.redDora > 0) items.add(('赤宝牌', ctx.redDora));
    if ((ctx.riichi || ctx.doubleRiichi) && ctx.uraDora > 0) items.add(('里宝牌', ctx.uraDora));
    final han = items.fold<int>(0, (a, b) => a + b.$2);
    return AotenjouValue(fu, han, aotenjouBasePoints(fu, han), items);
  }

  // 1. Kokushi Musou (国士无双 = 13 han)
  if (melds.isEmpty && _isKokushi(concealed)) {
    final y = <(String, int)>[];
    addSituational(y);
    y.add(('国士无双', 13));
    final fu = ctx.tsumo ? 30 : 40;
    return finish(y, fu);
  }

  final suits = <int>{};
  var hasHonor = false;
  var allSimple = true;
  var allYaojiu = true;
  var allTerminals = true;
  var allHonors = true;
  var allGreen = true;
  const greens = {19, 20, 21, 23, 25, kHatsu};
  for (var t = 0; t < kKinds; t++) {
    if (all[t] == 0) continue;
    if (t < 27) {
      suits.add(t ~/ 9);
      allHonors = false;
      if (!isTerminal(t)) allTerminals = false;
    } else {
      hasHonor = true;
      allTerminals = false;
    }
    if (isYaojiu(t)) {
      allSimple = false;
    } else {
      allYaojiu = false;
    }
    if (!greens.contains(t)) allGreen = false;
  }

  // 2. Standard decompositions (4 sets + 1 pair)
  for (final (pair, cSets) in standardDecomps(concealed)) {
    final placements = <int>[];
    if (pair == ctx.winTile) placements.add(-1);
    for (var i = 0; i < cSets.length; i++) {
      final s = cSets[i];
      final hit = s.chow
          ? (ctx.winTile >= s.tile && ctx.winTile <= s.tile + 2 && ctx.winTile < 27 && ctx.winTile ~/ 9 == s.tile ~/ 9)
          : s.tile == ctx.winTile;
      if (hit) placements.add(i);
    }
    if (placements.isEmpty) placements.add(-1);

    for (final pl in placements) {
      final sets = <MSet>[
        for (var i = 0; i < cSets.length; i++)
          MSet(
            cSets[i].chow,
            cSets[i].tile,
            kong: false,
            concealed: !(i == pl && cSets[i].pung && !ctx.tsumo),
            melded: false,
          ),
        for (final m in melds) setFromMeld(m),
      ];

      // wait: 0 ryanmen, 1 kanchan, 2 penchan, 3 tanki, 4 shanpon
      int wait;
      if (pl == -1) {
        wait = 3;
      } else {
        final g = cSets[pl];
        if (g.pung) {
          wait = 4;
        } else if (ctx.winTile == g.tile + 1) {
          wait = 1;
        } else if ((ctx.winTile == g.tile + 2 && g.tile % 9 == 0) || (ctx.winTile == g.tile && g.tile % 9 == 6)) {
          wait = 2;
        } else {
          wait = 0;
        }
      }

      final y = <(String, int)>[];
      addSituational(y);

      final chows = [for (final s in sets) if (s.chow) s.tile];
      final pungs = [for (final s in sets) if (s.pung) s];
      final pairYakuhai = _yakuhaiCount(ctx, pair);
      final pinfu = closed && chows.length == 4 && pairYakuhai == 0 && wait == 0;
      if (pinfu) y.add(('平和', 1));
      if (allSimple) y.add(('断幺九', 1));

      if (closed) {
        final cnt = <int, int>{};
        for (final c in chows) {
          cnt[c] = (cnt[c] ?? 0) + 1;
        }
        var pk = 0;
        for (final v in cnt.values) {
          pk += v ~/ 2;
        }
        if (pk >= 2) {
          y.add(('二杯口', 3));
        } else if (pk == 1) {
          y.add(('一杯口', 1));
        }
      }

      // Yakuhai
      for (final p in pungs) {
        if (p.tile == kHaku) y.add(('役牌 白', 1));
        if (p.tile == kHatsu) y.add(('役牌 发', 1));
        if (p.tile == kChun) y.add(('役牌 中', 1));
        if (p.tile == ctx.seatWind) y.add(('自风 ${windNames[p.tile - 27]}', 1));
        if (p.tile == ctx.roundWind) y.add(('场风 ${windNames[p.tile - 27]}', 1));
      }

      // Sanshoku Doujun & Ittsu
      final chowSet = chows.toSet();
      for (var n = 0; n < 7; n++) {
        if (chowSet.contains(n) && chowSet.contains(n + 9) && chowSet.contains(n + 18)) {
          y.add(('三色同顺', closed ? 2 : 1));
          break;
        }
      }
      for (var s = 0; s < 3; s++) {
        if (chowSet.contains(s * 9) && chowSet.contains(s * 9 + 3) && chowSet.contains(s * 9 + 6)) {
          y.add(('一气通贯', closed ? 2 : 1));
        }
      }

      // Chanta / Junchan / Honroutou
      final allSetsYaojiu =
          isYaojiu(pair) && sets.every((s) => s.chow ? (s.tile % 9 == 0 || s.tile % 9 == 6) : isYaojiu(s.tile));
      if (allSetsYaojiu && chows.isNotEmpty) {
        y.add((hasHonor ? '混全带幺九' : '纯全带幺九', hasHonor ? (closed ? 2 : 1) : (closed ? 3 : 2)));
      }
      if (allYaojiu && !allTerminals && !allHonors) y.add(('混老头', 2));

      // Toitoi & Ankous & Kans
      if (pungs.length == 4) y.add(('对对和', 2));
      final ankou = pungs.where((p) => p.concealed).length;
      if (ankou == 4) {
        y.add(('四暗刻', 13));
      } else if (ankou == 3) {
        y.add(('三暗刻', 2));
      }
      final kans = pungs.where((p) => p.kong).length;
      if (kans == 4) {
        y.add(('四杠子', 13));
      } else if (kans == 3) {
        y.add(('三杠子', 2));
      }
      for (var n = 0; n < 9; n++) {
        if (pungs.any((p) => p.tile == n) &&
            pungs.any((p) => p.tile == n + 9) &&
            pungs.any((p) => p.tile == n + 18)) {
          y.add(('三色同刻', 2));
        }
      }

      // Dragons & Winds Yakuman / Shousangen
      final dragonTrips = pungs.where((p) => isDragon(p.tile)).length;
      if (dragonTrips == 3) {
        y.add(('大三元', 13));
      } else if (dragonTrips == 2 && isDragon(pair)) {
        y.add(('小三元', 2));
      }
      final windTrips = pungs.where((p) => isWind(p.tile)).length;
      if (windTrips == 4) {
        y.add(('大四喜', 26));
      } else if (windTrips == 3 && isWind(pair)) {
        y.add(('小四喜', 13));
      }

      if (allHonors) y.add(('字一色', 13));
      if (allTerminals) y.add(('清老头', 13));
      if (allGreen) y.add(('绿一色', 13));

      // Honitsu / Chinitsu
      if (suits.length == 1) {
        if (hasHonor) {
          y.add(('混一色', closed ? 3 : 2));
        } else {
          y.add(('清一色', closed ? 6 : 5));
        }
      }

      if (y.isEmpty) continue;

      // Calculate true Fu
      int fu;
      if (pinfu) {
        fu = ctx.tsumo ? 20 : 30;
      } else {
        fu = 20;
        if (closed && !ctx.tsumo) fu += 10; // menzen-ron
        if (ctx.tsumo) fu += 2;
        if (wait == 1 || wait == 2 || wait == 3) fu += 2;
        fu += pairYakuhai * 2;
        for (final p in pungs) {
          var f = 2;
          if (isYaojiu(p.tile)) f *= 2;
          if (p.concealed) f *= 2;
          if (p.kong) f *= 4;
          fu += f;
        }
        fu = ((fu + 9) ~/ 10) * 10;
        if (fu == 20) fu = 30;
      }

      consider(finish(y, fu));
    }
  }

  // 3. Chiitoitsu (七对子 = 2 han, 25 fu)
  if (melds.isEmpty && isSevenPairs(concealed) && concealed.every((x) => x <= 2)) {
    final y = <(String, int)>[];
    addSituational(y);
    y.add(('七对子', 2));
    if (allSimple) y.add(('断幺九', 1));
    if (allHonors) {
      y.add(('字一色', 13));
    } else if (allYaojiu) {
      y.add(('混老头', 2));
    }
    if (suits.length == 1) {
      if (hasHonor) {
        y.add(('混一色', 3));
      } else {
        y.add(('清一色', 6));
      }
    }
    consider(finish(y, 25));
  }

  return best;
}

bool aotenjouCanFormHand(List<int> concealed, int meldCount) {
  if (meldCount == 0 && _isKokushi(concealed)) return true;
  if (meldCount == 0 && isSevenPairs(concealed) && concealed.every((x) => x <= 2)) return true;
  return isStandardWin(concealed);
}

List<int> aotenjouWaits(List<int> concealed, List<Meld> melds) {
  final out = <int>[];
  for (var t = 0; t < kKinds; t++) {
    if (concealed[t] >= 4) continue;
    concealed[t]++;
    final ok = aotenjouCanFormHand(concealed, melds.length);
    concealed[t]--;
    if (ok) out.add(t);
  }
  return out;
}

class _AoClaim {
  final int tile;
  final int from;
  final bool chankan;
  final Map<int, Set<String>> opts; // seat -> {'ron', 'pon', 'kan', 'chi'}
  final Map<int, List<int>> chis;
  final Map<int, AotenjouValue> ronVal;
  final Map<int, Map<String, dynamic>> resp = {};
  _AoClaim(this.tile, this.from, this.chankan, this.opts, {this.chis = const {}, this.ronVal = const {}});
  List<int> get pending => [for (final s in opts.keys) if (!resp.containsKey(s)) s]..sort();
}

class _AoDiscard {
  final int tile;
  bool taken = false;
  final bool tsumogiri;
  final bool riichi;
  _AoDiscard(this.tile, {this.tsumogiri = false, this.riichi = false});
}

/// 青天井麻将 (Aotenjou Mahjong)
class AotenjouGame extends GameEngine {
  AotenjouGame(super.setup);

  static const int kStartPoints = 1000000;

  late final int totalRounds = setup.opt<int>('rounds', 4);
  late final bool redDoraOn = setup.opt<bool>('redDora', true);

  late List<int> scores = List.filled(players, kStartPoints);
  int handNo = 0;
  int dealer = 0;
  int roundWind = kEast;
  int riichiPool = 0; // 1000-pt sticks
  bool over = false;
  List<Map<String, dynamic>> history = [];

  // Hand state
  String phase = 'act'; // act, claim, settle, over, pause
  String pausedPhase = '';
  List<List<int>> hands = [];
  List<List<Meld>> melds = [];
  List<List<_AoDiscard>> discards = [];
  List<bool> riichi = [];
  List<bool> ippatsu = [];
  List<int> drawn = [];
  List<int> wall = [];
  List<int> doraIndicators = [];
  List<int> uraIndicators = [];
  int doraShown = 1;
  int turn = 0;
  bool canZimo = false;
  bool afterKong = false;
  bool anyCall = false;
  int discardCount = 0;
  int lastDiscardSeat = -1;
  String lastAction = '';
  Map<String, dynamic>? lastEvent;
  int eventSeq = 0;
  _AoClaim? claim;
  List<int> handDelta = [];
  List<Map<String, dynamic>> events = [];
  Map<String, dynamic>? settle;
  Set<int> ready = {};
  int nextDealer = -1;

  void _event(String t, int seat, [int tile = -1]) {
    lastEvent = {'t': t, 'seat': seat, if (tile >= 0) 'tile': tileCode(tile)};
    eventSeq++;
  }

  int seatWind(int s) => (s - dealer + players) % players;
  int seatWindKind(int s) => kEast + seatWind(s);

  List<String> get activeDoraIndicators => [
        for (var i = 0; i < doraShown && i < doraIndicators.length; i++) tileCode(doraIndicators[i])
      ];

  List<int> get activeDoraTiles => [
        for (var i = 0; i < doraShown && i < doraIndicators.length; i++) aotenjouNextDora(doraIndicators[i])
      ];

  @override
  void start() {
    dealer = rng.nextInt(players);
    _startHand();
  }

  void _startHand() {
    handNo++;
    wall = <int>[for (var t = 0; t < kKinds; t++) for (var k = 0; k < 4; k++) t]..shuffle(rng);
    hands = List.generate(players, (_) => List.filled(kKinds, 0));
    melds = List.generate(players, (_) => <Meld>[]);
    discards = List.generate(players, (_) => <_AoDiscard>[]);
    riichi = List.filled(players, false);
    ippatsu = List.filled(players, false);
    drawn = List.filled(players, -1);
    handDelta = List.filled(players, 0);
    events = [];
    settle = null;
    claim = null;
    afterKong = false;
    anyCall = false;
    discardCount = 0;
    lastDiscardSeat = -1;
    nextDealer = -1;

    doraIndicators = [for (var i = 0; i < 4; i++) wall.removeLast()];
    uraIndicators = [for (var i = 0; i < 4; i++) wall.removeLast()];
    doraShown = 1;

    for (var i = 0; i < 13; i++) {
      for (var s = 0; s < players; s++) {
        hands[s][wall.removeLast()]++;
      }
    }
    final extra = wall.removeLast();
    hands[dealer][extra]++;
    drawn[dealer] = extra;

    turn = dealer;
    phase = 'act';
    canZimo = true;
    final doraTile = aotenjouNextDora(doraIndicators.first);
    host.log('第 $handNo/$totalRounds 局开始，庄家 ${name(dealer)}，宝牌指示牌 ${tileName(doraIndicators.first)}（宝牌 ${tileName(doraTile)}）');
    lastAction = '宝牌：${tileName(doraTile)} · ${name(dealer)} 出牌';
  }

  int _countDora(List<int> concealed, List<Meld> ms, List<int> indicators, int count) {
    final all = List<int>.of(concealed);
    for (final m in ms) {
      for (final t in m.tiles) {
        all[t]++;
      }
    }
    var d = 0;
    for (var i = 0; i < count && i < indicators.length; i++) {
      final dt = aotenjouNextDora(indicators[i]);
      d += all[dt];
    }
    return d;
  }

  int _countRedDora(List<int> concealed, List<Meld> ms) {
    if (!redDoraOn) return 0;
    final all = List<int>.of(concealed);
    for (final m in ms) {
      for (final t in m.tiles) {
        all[t]++;
      }
    }
    // Count up to 1 red 5 per suit (5m = 4, 5p = 13, 5s = 22)
    var r = 0;
    if (all[4] > 0) r++;
    if (all[13] > 0) r++;
    if (all[22] > 0) r++;
    return r;
  }

  AotenjouValue? selfEval(int s) {
    final winTile = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : _anyTile(s);
    return aotenjouEvaluate(
      hands[s],
      melds[s],
      AotenjouCtx(
        winTile: winTile,
        tsumo: true,
        riichi: riichi[s],
        ippatsu: ippatsu[s],
        rinshan: afterKong,
        haitei: wall.isEmpty && !afterKong,
        tenhou: s == dealer && discardCount == 0 && !anyCall,
        chiihou: s != dealer && discards[s].isEmpty && !anyCall,
        seatWind: seatWindKind(s),
        roundWind: roundWind,
        dora: _countDora(hands[s], melds[s], doraIndicators, doraShown),
        uraDora: riichi[s] ? _countDora(hands[s], melds[s], uraIndicators, doraShown) : 0,
        redDora: _countRedDora(hands[s], melds[s]),
      ),
    );
  }

  AotenjouValue? ronEval(int o, int t, {bool chankan = false}) {
    final c = List<int>.of(hands[o]);
    c[t]++;
    return aotenjouEvaluate(
      c,
      melds[o],
      AotenjouCtx(
        winTile: t,
        tsumo: false,
        riichi: riichi[o],
        ippatsu: ippatsu[o],
        chankan: chankan,
        houtei: wall.isEmpty && !chankan,
        seatWind: seatWindKind(o),
        roundWind: roundWind,
        dora: _countDora(c, melds[o], doraIndicators, doraShown),
        uraDora: riichi[o] ? _countDora(c, melds[o], uraIndicators, doraShown) : 0,
        redDora: _countRedDora(c, melds[o]),
      ),
    );
  }

  bool get canSelfTsumo => phase == 'act' && canZimo && selfEval(turn) != null;

  /// Tiles the turn player can discard to declare Riichi.
  List<int> riichiDiscards(int s) {
    if (phase != 'act' || turn != s || riichi[s] || wall.isEmpty || scores[s] < 1000) return const [];
    if (melds[s].any((m) => m.isExposed)) return const [];
    final out = <int>[];
    for (var t = 0; t < kKinds; t++) {
      if (hands[s][t] <= 0) continue;
      hands[s][t]--;
      final w = aotenjouWaits(hands[s], melds[s]);
      hands[s][t]++;
      if (w.isNotEmpty) out.add(t);
    }
    return out;
  }

  List<(int, bool)> selfKongs() {
    if (phase != 'act' || wall.isEmpty) return const [];
    final s = turn;
    final out = <(int, bool)>[];
    for (var t = 0; t < kKinds; t++) {
      if (riichi[s]) {
        if (t == drawn[s] && hands[s][t] == 4) out.add((t, false));
      } else {
        if (hands[s][t] == 4) out.add((t, false));
        if (hands[s][t] >= 1 && melds[s].any((m) => m.isPeng && m.tile == t)) out.add((t, true));
      }
    }
    return out;
  }

  List<int> chiOptions(int s, int t) {
    if (t >= 27 || riichi[s]) return const [];
    final h = hands[s];
    final r = rankOf(t);
    final out = <int>[];
    for (var lo = t - 2; lo <= t; lo++) {
      final lr = r - (t - lo);
      if (lr < 1 || lr > 7) continue;
      var ok = true;
      for (var k = lo; k < lo + 3; k++) {
        if (k != t && h[k] == 0) ok = false;
      }
      if (ok) out.add(lo);
    }
    return out;
  }

  List<int> legalDiscards(int s) {
    if (riichi[s] && drawn[s] >= 0 && hands[s][drawn[s]] > 0) return [drawn[s]];
    return [for (var t = 0; t < kKinds; t++) if (hands[s][t] > 0) t];
  }

  bool _draw(int s, {bool kong = false}) {
    turn = s;
    if (wall.isEmpty) {
      _drawnGame();
      return false;
    }
    final t = wall.removeLast();
    hands[s][t]++;
    drawn[s] = t;
    phase = 'act';
    canZimo = true;
    afterKong = kong;
    return true;
  }

  void _coverPause(void Function() next) {
    final ms = claimCoverDelayMs(rng);
    if (ms == 0) {
      next();
      return;
    }
    pausedPhase = phase;
    phase = 'pause';
    host.schedule(ms, () {
      if (phase != 'pause') return;
      phase = pausedPhase;
      next();
    });
  }

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? rankByScore(scores) : null;

  @override
  int get botDelayMs => phase == 'claim' ? 500 : 700;

  @override
  List<int> get waitingFor {
    switch (phase) {
      case 'act':
        return [turn];
      case 'claim':
        return claim!.pending;
      case 'settle':
        return [for (var s = 0; s < players; s++) if (!ready.contains(s)) s];
      default:
        return const [];
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> a) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('你不在座位上');
    final rawType = asStr(a['type']).isNotEmpty ? asStr(a['type']) : asStr(a['t']);
    switch (phase) {
      case 'act':
        if (seat != turn) throw GameError('还没轮到你');
        _handleAct(seat, rawType, a);
        return;
      case 'claim':
        _handleClaim(seat, rawType, a);
        return;
      case 'settle':
        if (rawType != 'next' && rawType != 'confirm') throw GameError('请等待下一局');
        ready.add(seat);
        if (ready.length >= players) _nextHand();
        return;
    }
    throw GameError('现在不能操作');
  }

  void _handleAct(int s, String type, Map<String, dynamic> a) {
    if (type == 'tsumo' || type == 'hu') {
      final r = canZimo ? selfEval(s) : null;
      if (r == null) throw GameError('现在不能自摸（需要至少一番役种）');
      final t = drawn[s] >= 0 && hands[s][drawn[s]] > 0 ? drawn[s] : _anyTile(s);
      _settleWin({s: (t, r)}, -1);
      return;
    }
    if (type == 'riichi') {
      final rds = riichiDiscards(s);
      if (rds.isEmpty) throw GameError('当前不能宣布立直（需门前清且听牌）');
      var t = tileFromCode(a['tile']);
      if (!rds.contains(t)) t = rds.first;
      riichi[s] = true;
      ippatsu[s] = true;
      scores[s] -= 1000;
      handDelta[s] -= 1000;
      riichiPool++;
      host.log('${name(s)} 宣布立直！（供托 -1000）');
      _event('riichi', s, t);
      _discard(s, t, isRiichiDeclare: true);
      return;
    }
    if (type == 'kan' || type == 'gang') {
      final ks = selfKongs();
      if (ks.isEmpty) throw GameError('现在不能杠');
      var t = tileFromCode(a['tile']);
      final match = ks.where((e) => e.$1 == t).toList();
      final chosen = match.isNotEmpty ? match.first : ks.first;
      _selfKong(s, chosen.$1, chosen.$2);
      return;
    }
    if (type == 'discard') {
      final t = tileFromCode(a['tile']);
      if (t < 0 || t >= kKinds || hands[s][t] <= 0) throw GameError('你没有这张牌');
      if (!legalDiscards(s).contains(t)) throw GameError('立直后只能摸切刚摸到的牌');
      _discard(s, t);
      return;
    }
    throw GameError('请出牌');
  }

  int _anyTile(int s) {
    for (var t = kKinds - 1; t >= 0; t--) {
      if (hands[s][t] > 0) return t;
    }
    return 0;
  }

  void _discard(int s, int t, {bool isRiichiDeclare = false}) {
    hands[s][t]--;
    final giri = drawn[s] == t;
    drawn[s] = -1;
    if (!isRiichiDeclare) ippatsu[s] = false;
    discards[s].add(_AoDiscard(t, tsumogiri: giri, riichi: isRiichiDeclare));
    discardCount++;
    canZimo = false;
    afterKong = false;
    lastDiscardSeat = s;
    lastAction = isRiichiDeclare ? '${name(s)} 立直打出 ${tileName(t)}' : '${name(s)} 打出 ${tileName(t)}';
    if (!isRiichiDeclare) _event('discard', s, t);

    final opts = <int, Set<String>>{};
    final chis = <int, List<int>>{};
    final ronVal = <int, AotenjouValue>{};
    for (var o = 0; o < players; o++) {
      if (o == s) continue;
      final set = <String>{};
      final r = ronEval(o, t);
      if (r != null) {
        set.add('ron');
        ronVal[o] = r;
      }
      if (wall.isNotEmpty && !riichi[o]) {
        if (hands[o][t] >= 2) set.add('pon');
        if (hands[o][t] >= 3) set.add('kan');
        if (o == (s + 1) % players) {
          final c = chiOptions(o, t);
          if (c.isNotEmpty) {
            set.add('chi');
            chis[o] = c;
          }
        }
      }
      if (set.isNotEmpty) opts[o] = set;
    }
    if (opts.isEmpty) {
      _coverPause(() => _draw((s + 1) % players));
    } else {
      claim = _AoClaim(t, s, false, opts, chis: chis, ronVal: ronVal);
      phase = 'claim';
    }
  }

  int _prio(String type) => switch (type) { 'ron' => 30, 'kan' || 'pon' => 20, 'chi' => 10, _ => 0 };

  int _maxPrio(_AoClaim c, int s) {
    var best = 0;
    for (final o in c.opts[s]!) {
      final p = _prio(o);
      if (p > best) best = p;
    }
    return best;
  }

  void _handleClaim(int s, String rawType, Map<String, dynamic> a) {
    final c = claim!;
    final o = c.opts[s];
    if (o == null) throw GameError('你没有可执行的操作');
    if (c.resp.containsKey(s)) throw GameError('你已经选择了');
    final type = switch (rawType) {
      'hu' => 'ron',
      'peng' => 'pon',
      'gang' => 'kan',
      _ => rawType,
    };
    if (type != 'pass' && !o.contains(type)) throw GameError('不能执行该操作');
    final r = <String, dynamic>{'type': type};
    if (type == 'chi') {
      final lo = tileFromCode(a['tile']);
      final list = c.chis[s] ?? const [];
      r['lo'] = list.contains(lo) ? lo : list.first;
    }
    c.resp[s] = r;
    final pend = c.pending;
    final ronDeclared = c.resp.values.any((e) => e['type'] == 'ron');
    if (ronDeclared) {
      if (pend.any((p) => c.opts[p]!.contains('ron'))) return;
    } else {
      var best = 0;
      for (final e in c.resp.values) {
        final p = _prio(e['type'] as String);
        if (p > best) best = p;
      }
      if (pend.any((p) => _maxPrio(c, p) > best)) return;
    }
    _resolveClaim();
  }

  void _resolveClaim() {
    final c = claim!;
    claim = null;
    final rons = [
      for (var i = 1; i < players; i++)
        if (c.resp[(c.from + i) % players]?['type'] == 'ron') (c.from + i) % players
    ];
    if (rons.isNotEmpty) {
      if (c.chankan) {
        hands[c.from][c.tile]--;
      } else {
        discards[c.from].last.taken = true;
      }
      final wins = {for (final h in rons) h: (c.tile, c.ronVal[h]!)};
      _settleWin(wins, c.from, chankan: c.chankan);
      return;
    }
    if (c.chankan) {
      _finishKakan(c.from, c.tile);
      return;
    }
    var bestSeat = -1, best = 0;
    for (final e in c.resp.entries) {
      final p = _prio(e.value['type'] as String);
      if (p > best) {
        best = p;
        bestSeat = e.key;
      }
    }
    if (bestSeat < 0) {
      _draw((c.from + 1) % players);
      return;
    }
    final r = c.resp[bestSeat]!;
    final type = r['type'] as String;
    final s = bestSeat;
    discards[c.from].last.taken = true;
    anyCall = true;
    for (var i = 0; i < players; i++) {
      ippatsu[i] = false;
    }
    if (type == 'kan') {
      hands[s][c.tile] -= 3;
      melds[s].add(Meld('mgang', c.tile, claimed: c.tile, from: c.from));
      if (doraShown < 4) doraShown++;
      lastAction = '${name(s)} 杠 ${tileName(c.tile)}';
      host.log(lastAction);
      _event('kan', s, c.tile);
      _draw(s, kong: true);
      return;
    }
    if (type == 'pon') {
      hands[s][c.tile] -= 2;
      melds[s].add(Meld('peng', c.tile, claimed: c.tile, from: c.from));
      lastAction = '${name(s)} 碰 ${tileName(c.tile)}';
      _event('pon', s, c.tile);
    } else {
      final lo = r['lo'] as int;
      for (var k = lo; k < lo + 3; k++) {
        if (k != c.tile) hands[s][k]--;
      }
      melds[s].add(Meld('chi', lo, claimed: c.tile, from: c.from));
      lastAction = '${name(s)} 吃 ${tileName(c.tile)}';
      _event('chi', s, c.tile);
    }
    turn = s;
    phase = 'act';
    canZimo = false;
    afterKong = false;
    drawn[s] = -1;
  }

  void _selfKong(int s, int t, bool bu) {
    anyCall = true;
    for (var i = 0; i < players; i++) {
      ippatsu[i] = false;
    }
    if (bu) {
      final opts = <int, Set<String>>{};
      final ronVal = <int, AotenjouValue>{};
      for (var o = 0; o < players; o++) {
        if (o == s) continue;
        final r = ronEval(o, t, chankan: true);
        if (r != null) {
          opts[o] = {'ron'};
          ronVal[o] = r;
        }
      }
      if (opts.isNotEmpty) {
        claim = _AoClaim(t, s, true, opts, ronVal: ronVal);
        phase = 'claim';
        lastAction = '${name(s)} 加杠 ${tileName(t)}';
        _event('kan', s, t);
        return;
      }
      _finishKakan(s, t);
      return;
    }
    hands[s][t] -= 4;
    melds[s].add(Meld('agang', t));
    if (doraShown < 4) doraShown++;
    lastAction = '${name(s)} 暗杠 ${tileName(t)}';
    host.log(lastAction);
    _event('kan', s, t);
    _draw(s, kong: true);
  }

  void _finishKakan(int s, int t) {
    hands[s][t]--;
    melds[s].firstWhere((m) => m.isPeng && m.tile == t).kind = 'bgang';
    if (doraShown < 4) doraShown++;
    lastAction = '${name(s)} 加杠 ${tileName(t)}';
    host.log(lastAction);
    _event('kan', s, t);
    _draw(s, kong: true);
  }

  void _pay(int from, int to, int amt) {
    scores[from] -= amt;
    scores[to] += amt;
    handDelta[from] -= amt;
    handDelta[to] += amt;
  }

  void _settleWin(Map<int, (int, AotenjouValue)> wins, int from, {bool chankan = false}) {
    final tsumo = from < 0;
    var firstWinner = true;
    for (final e in wins.entries) {
      final w = e.key;
      final (tile, val) = e.value;
      if (tsumo) hands[w][tile]--;
      drawn[w] = -1;
      final pay = <String, int>{};
      var totalWon = 0;
      if (tsumo) {
        final (dPay, ndPay) = aotenjouTsumoPayments(val.fu, val.han, isDealer: w == dealer);
        for (var o = 0; o < players; o++) {
          if (o == w) continue;
          final amt = (w == dealer || o != dealer) ? ndPay : dPay;
          _pay(o, w, amt);
          pay['$o'] = amt;
          totalWon += amt;
        }
      } else {
        final amt = aotenjouRonPoints(val.fu, val.han, isDealer: w == dealer);
        _pay(from, w, amt);
        pay['$from'] = amt;
        totalWon += amt;
      }
      if (firstWinner && riichiPool > 0) {
        final bonus = riichiPool * 1000;
        scores[w] += bonus;
        handDelta[w] += bonus;
        totalWon += bonus;
        riichiPool = 0;
        firstWinner = false;
      }
      events.add({
        'kind': 'hu',
        'seat': w,
        'from': from,
        'tile': tileCode(tile),
        'zimo': tsumo,
        'tsumo': tsumo,
        'rob': chankan,
        'fu': val.fu,
        'han': val.han,
        'basePoints': val.basePoints,
        'points': totalWon,
        'items': val.toJson(),
        'pay': pay,
        'hand': codesOfCounts(hands[w]),
      });
      host.log(tsumo
          ? '${name(w)} 自摸 ${tileName(tile)}！${val.fu}符${val.han}番（基本点 ${val.basePoints}）+$totalWon 点'
          : '${name(w)} 荣和 ${name(from)} 的 ${tileName(tile)}！${val.fu}符${val.han}番（基本点 ${val.basePoints}）+$totalWon 点');
      _event(tsumo ? 'tsumo' : 'ron', w, tile);
    }
    lastAction = tsumo ? '${name(wins.keys.first)} 自摸' : '${wins.keys.map(name).join('、')} 荣和';
    nextDealer = wins.containsKey(dealer) ? dealer : (dealer + 1) % players;
    _endHand();
  }

  void _drawnGame() {
    // Exhaustive draw: tenpai payments (total 3000 split)
    final tenpai = [for (var s = 0; s < players; s++) aotenjouWaits(hands[s], melds[s]).isNotEmpty];
    final tCount = tenpai.where((x) => x).length;
    if (tCount > 0 && tCount < players) {
      final recv = 3000 ~/ tCount;
      final give = 3000 ~/ (players - tCount);
      for (var s = 0; s < players; s++) {
        final d = tenpai[s] ? recv : -give;
        scores[s] += d;
        handDelta[s] += d;
      }
    }
    host.log('荒牌流局（听牌 ${tCount} 人）');
    lastAction = '荒牌流局';
    nextDealer = (dealer + 1) % players;
    _endHand();
  }

  void _endHand() {
    claim = null;
    settle = {
      'hand': handNo,
      'events': events,
      'win': events.any((e) => e['kind'] == 'hu'),
      'delta': List.of(handDelta),
      'dealer': dealer,
      'doraIndicators': activeDoraIndicators,
    };
    history.add({'hand': handNo, 'delta': List.of(handDelta)});
    ready = {};
    if (handNo >= totalRounds) {
      if (riichiPool > 0) {
        final top = ranking().first;
        scores[top] += riichiPool * 1000;
        handDelta[top] += riichiPool * 1000;
        riichiPool = 0;
      }
      phase = 'over';
      over = true;
      final order = ranking();
      host.log('全部 $totalRounds 局结束！${[
        for (var i = 0; i < order.length; i++) '第${i + 1} ${name(order[i])} ${scores[order[i]]}'
      ].join('，')}');
    } else {
      phase = 'settle';
    }
  }

  List<int> ranking() => List.generate(players, (i) => i)..sort((a, b) => scores[b].compareTo(scores[a]));

  void _nextHand() {
    if (nextDealer >= 0) dealer = nextDealer;
    _startHand();
  }

  @override
  Map<String, dynamic> view(int seat) {
    final reveal = phase == 'settle' || phase == 'over';
    final seats = <Map<String, dynamic>>[];
    for (var s = 0; s < players; s++) {
      final n = countTotal(hands[s]);
      final hasDrawn = phase == 'act' && turn == s && drawn[s] >= 0 && hands[s][drawn[s]] > 0;
      seats.add({
        'count': n,
        'drawn': hasDrawn,
        'hand': s == seat || reveal ? codesOfCounts(hands[s]) : null,
        'melds': [for (final m in melds[s]) m.toJson(hide: m.concealed && s != seat && !reveal)],
        'discards': [
          for (final d in discards[s])
            {'t': tileCode(d.tile), 'taken': d.taken, 'tg': d.tsumogiri, 'riichi': d.riichi}
        ],
        'riichi': riichi[s],
        'wind': seatWind(s),
        'score': scores[s],
        'delta': handDelta[s],
      });
    }
    final v = <String, dynamic>{
      'rule': 'aotenjou',
      'phase': phase == 'pause' ? 'claim' : phase,
      'hand': handNo,
      'hands': totalRounds,
      'rounds': totalRounds,
      'dealer': dealer,
      'turn': turn,
      'wall': wall.length,
      'doraIndicators': activeDoraIndicators,
      'doraTiles': [for (final t in activeDoraTiles) tileCode(t)],
      'riichiPool': riichiPool,
      'seats': seats,
      'last': lastAction,
      'lastDiscard': lastDiscardSeat,
      'event': lastEvent == null ? null : {...lastEvent!, 'seq': eventSeq},
      'waiting': phase == 'claim' ? [for (final s in waitingFor) if (s == seat) s] : waitingFor,
      'over': over,
      'settle': settle,
      'history': history,
    };
    if (claim != null) {
      v['claimTile'] = tileCode(claim!.tile);
      v['claimFrom'] = claim!.from;
      v['claimChankan'] = claim!.chankan;
    } else if (phase == 'pause' && lastDiscardSeat >= 0 && discards[lastDiscardSeat].isNotEmpty) {
      v['claimTile'] = tileCode(discards[lastDiscardSeat].last.tile);
      v['claimFrom'] = lastDiscardSeat;
      v['claimChankan'] = false;
    }
    if (over) v['ranking'] = ranking();
    if (seat >= 0 && seat < players) {
      final my = <String, dynamic>{
        'drawn': phase == 'act' && turn == seat && drawn[seat] >= 0 && hands[seat][drawn[seat]] > 0
            ? tileCode(drawn[seat])
            : null,
      };
      if (phase == 'act' && turn == seat) {
        my['canTsumo'] = canSelfTsumo;
        my['canHu'] = canSelfTsumo;
        final rds = riichiDiscards(seat);
        my['canRiichi'] = rds.isNotEmpty;
        my['riichiTiles'] = [for (final t in rds) tileCode(t)];
        my['kongs'] = [for (final (t, _) in selfKongs()) tileCode(t)];
        my['discardable'] = [for (final t in legalDiscards(seat)) tileCode(t)];
      }
      if (phase == 'claim' && claim!.opts.containsKey(seat) && !claim!.resp.containsKey(seat)) {
        final c = claim!;
        my['claim'] = c.opts[seat]!.toList();
        my['chis'] = [
          for (final lo in c.chis[seat] ?? const <int>[]) [for (var k = lo; k < lo + 3; k++) tileCode(k)]
        ];
      }
      final n = countTotal(hands[seat]);
      if (n % 3 == 1 && (phase == 'act' || phase == 'claim' || phase == 'pause')) {
        my['waits'] = [for (final t in aotenjouWaits(hands[seat], melds[seat])) tileCode(t)];
      }
      v['me'] = my;
    }
    return v;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    switch (phase) {
      case 'settle':
        return {'type': 'next'};
      case 'claim':
        final c = claim!;
        final opts = c.opts[seat];
        if (opts == null || c.resp.containsKey(seat)) return null;
        if (opts.contains('ron')) return {'type': 'ron'};
        if (opts.contains('kan')) return {'type': 'kan'};
        if (opts.contains('pon')) {
          // Pon yakuhai or if already open
          final isY = isDragon(c.tile) || c.tile == seatWindKind(seat) || c.tile == roundWind;
          if (isY || melds[seat].isNotEmpty) return {'type': 'pon'};
        }
        if (opts.contains('chi') && melds[seat].isNotEmpty) {
          return {'type': 'chi', 'tile': tileCode(c.chis[seat]!.first)};
        }
        return {'type': 'pass'};
      case 'act':
        if (seat != turn) return null;
        if (canSelfTsumo) return {'type': 'tsumo'};
        final rds = riichiDiscards(seat);
        if (rds.isNotEmpty) {
          return {'type': 'riichi', 'tile': tileCode(rds.first)};
        }
        final ks = selfKongs();
        if (ks.isNotEmpty) {
          return {'type': 'kan', 'tile': tileCode(ks.first.$1)};
        }
        final disc = legalDiscards(seat);
        var bestT = disc.first;
        var bestScore = 1 << 20;
        for (final t in disc) {
          final v = tileValue(hands[seat], t);
          if (v < bestScore) {
            bestScore = v;
            bestT = t;
          }
        }
        return {'type': 'discard', 'tile': tileCode(bestT)};
    }
    return null;
  }
}
