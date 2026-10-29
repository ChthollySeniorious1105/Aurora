/// Tile helpers shared by mahjong3 games (wuhanmj, xueliu, aotenjou).
///
/// Tiles are ints 0..33:
/// - 0..8:   1m..9m (万)
/// - 9..17:  1p..9p (筒)
/// - 18..26: 1s..9s (条/索)
/// - 27..30: 1z..4z (东南西北)
/// - 31..33: 5z..7z (白发中)
library;

const int kKinds = 34;
const int kNumKinds = 27;

const List<String> suitNames = ['万', '筒', '条'];
const String suitLetters = 'mps';
const List<String> honorNames = ['东', '南', '西', '北', '白', '发', '中'];
const List<String> windNames = ['东', '南', '西', '北'];

const int kEast = 27;
const int kSouth = 28;
const int kWest = 29;
const int kNorth = 30;
const int kHaku = 31; // 5z 白板
const int kHatsu = 32; // 6z 发财
const int kChun = 33; // 7z 红中

bool isNumber(int t) => t >= 0 && t < 27;
bool isHonor(int t) => t >= 27 && t < 34;
bool isWind(int t) => t >= 27 && t <= 30;
bool isDragon(int t) => t >= 31 && t <= 33;
int suitOf(int t) => t < 27 ? t ~/ 9 : 3;
int rankOf(int t) => t < 27 ? t % 9 + 1 : 0;
bool isTerminal(int t) => t < 27 && (t % 9 == 0 || t % 9 == 8);
bool isYaojiu(int t) => isTerminal(t) || isHonor(t);
bool is258(int t) => t < 27 && (t % 9 == 1 || t % 9 == 4 || t % 9 == 7);

String tileCode(int t) {
  if (t < 0 || t >= kKinds) return 'back';
  if (t < 27) return '${t % 9 + 1}${suitLetters[t ~/ 9]}';
  return '${t - 26}z';
}

int tileFromCode(Object? c) {
  if (c is! String || c.length != 2) return -1;
  final rawRank = int.tryParse(c[0]);
  if (rawRank == null) return -1;
  final r = rawRank == 0 ? 5 : rawRank; // map '0m'/'0p'/'0s' to 5m/5p/5s
  final s = suitLetters.indexOf(c[1]);
  if (s >= 0) return r >= 1 && r <= 9 ? s * 9 + r - 1 : -1;
  if (c[1] == 'z') return r >= 1 && r <= 7 ? 26 + r : -1;
  return -1;
}

String tileName(int t) {
  if (t < 0 || t >= kKinds) return '?';
  if (t < 27) return '${'一二三四五六七八九'[t % 9]}${suitNames[t ~/ 9]}';
  return honorNames[t - 27];
}

int suitFromCodeOrIndex(Object? v) {
  if (v is int) return v >= 0 && v <= 2 ? v : -1;
  if (v is num && v.isFinite) {
    final i = v.toInt();
    return i >= 0 && i <= 2 ? i : -1;
  }
  if (v is String && v.isNotEmpty) {
    final idx = suitLetters.indexOf(v[0]);
    if (idx >= 0) return idx;
    final parsed = int.tryParse(v);
    if (parsed != null && parsed >= 0 && parsed <= 2) return parsed;
  }
  return -1;
}

/// Parse "123m456p11z" style strings into tile ids.
List<int> parseTiles(String s) {
  final out = <int>[];
  final digits = <int>[];
  for (final ch in s.split('')) {
    if ('mpsz'.contains(ch)) {
      for (final d in digits) {
        final t = tileFromCode('$d$ch');
        if (t >= 0) out.add(t);
      }
      digits.clear();
    } else if (ch.trim().isNotEmpty) {
      final d = int.tryParse(ch);
      if (d != null) digits.add(d);
    }
  }
  return out;
}

List<int> countsOf(Iterable<int> tiles, [int kinds = kKinds]) {
  final c = List<int>.filled(kinds, 0);
  for (final t in tiles) {
    if (t >= 0 && t < kinds) c[t]++;
  }
  return c;
}

int countTotal(List<int> c) {
  var n = 0;
  for (final x in c) {
    n += x;
  }
  return n;
}

List<String> codesOfCounts(List<int> c) => [
      for (var t = 0; t < c.length; t++)
        for (var k = 0; k < c[t]; k++) tileCode(t)
    ];

/// A called or declared meld.
class Meld {
  /// 'chi', 'peng'/'pon', 'mgang'/'minkan', 'bgang'/'kakan', 'agang'/'ankan'
  String kind;

  /// For chi: the lowest tile of the sequence; otherwise the tile.
  final int tile;

  /// The tile taken from another player (-1 for concealed kong).
  final int claimed;

  /// Seat the tile came from (-1 for concealed kong).
  final int from;

  Meld(this.kind, this.tile, {this.claimed = -1, this.from = -1});

  bool get isChi => kind == 'chi';
  bool get isPeng => kind == 'peng' || kind == 'pon';
  bool get isKong =>
      kind == 'mgang' ||
      kind == 'bgang' ||
      kind == 'agang' ||
      kind == 'minkan' ||
      kind == 'kakan' ||
      kind == 'ankan' ||
      kind == 'kan';
  bool get concealed => kind == 'agang' || kind == 'ankan';
  bool get isExposed => !concealed;
  int get size => isKong ? 4 : 3;
  List<int> get tiles => isChi ? [tile, tile + 1, tile + 2] : List.filled(size, tile);

  Map<String, dynamic> toJson({bool hide = false}) => {
        'kind': kind,
        'tile': hide ? 'back' : tileCode(tile),
        'tiles': hide ? const ['back', 'back', 'back', 'back'] : [for (final t in tiles) tileCode(t)],
        'claimed': claimed >= 0 ? tileCode(claimed) : null,
        'from': from,
      };
}

class MSet {
  final bool chow;
  final int tile; // chow: lowest tile
  final bool kong;
  final bool concealed;
  final bool melded;
  const MSet(this.chow, this.tile, {this.kong = false, this.concealed = true, this.melded = false});

  bool get pung => !chow;
}

MSet setFromMeld(Meld m) =>
    MSet(m.isChi, m.tile, kong: m.isKong, concealed: m.concealed, melded: true);

void decomposeSets(List<int> c, int i, List<MSet> cur, List<List<MSet>> out) {
  while (i < c.length && c[i] == 0) {
    i++;
  }
  if (i >= c.length) {
    out.add(List.of(cur));
    return;
  }
  if (c[i] >= 3) {
    c[i] -= 3;
    cur.add(MSet(false, i));
    decomposeSets(c, i, cur, out);
    cur.removeLast();
    c[i] += 3;
  }
  if (i < 27 && i % 9 <= 6 && c[i + 1] > 0 && c[i + 2] > 0) {
    c[i]--;
    c[i + 1]--;
    c[i + 2]--;
    cur.add(MSet(true, i));
    decomposeSets(c, i, cur, out);
    cur.removeLast();
    c[i]++;
    c[i + 1]++;
    c[i + 2]++;
  }
}

bool canFormSets(List<int> c, int i) {
  while (i < c.length && c[i] == 0) {
    i++;
  }
  if (i >= c.length) return true;
  if (c[i] >= 3) {
    c[i] -= 3;
    final ok = canFormSets(c, i);
    c[i] += 3;
    if (ok) return true;
  }
  if (i < 27 && i % 9 <= 6 && c[i + 1] > 0 && c[i + 2] > 0) {
    c[i]--;
    c[i + 1]--;
    c[i + 2]--;
    final ok = canFormSets(c, i);
    c[i]++;
    c[i + 1]++;
    c[i + 2]++;
    if (ok) return true;
  }
  return false;
}

List<(int pair, List<MSet> sets)> standardDecomps(List<int> concealed) {
  final out = <(int, List<MSet>)>[];
  if (countTotal(concealed) % 3 != 2) return out;
  final w = List.of(concealed);
  for (var p = 0; p < w.length; p++) {
    if (w[p] < 2) continue;
    w[p] -= 2;
    final res = <List<MSet>>[];
    decomposeSets(w, 0, [], res);
    w[p] += 2;
    for (final r in res) {
      out.add((p, r));
    }
  }
  return out;
}

bool isStandardWin(List<int> c) {
  if (countTotal(c) % 3 != 2) return false;
  final w = List.of(c);
  for (var p = 0; p < w.length; p++) {
    if (w[p] >= 2) {
      w[p] -= 2;
      final ok = canFormSets(w, 0);
      w[p] += 2;
      if (ok) return true;
    }
  }
  return false;
}

bool isSevenPairs(List<int> c) {
  if (countTotal(c) != 14) return false;
  for (final x in c) {
    if (x.isOdd) return false;
  }
  return true;
}

/// Heuristic usefulness of a tile in hand (lower = better discard).
int tileValue(List<int> c, int t) {
  var v = (c[t] - 1) * 4;
  if (t < 27) {
    final r = rankOf(t);
    for (var d = -2; d <= 2; d++) {
      if (d == 0) continue;
      final rr = r + d;
      if (rr < 1 || rr > 9) continue;
      if (c[t + d] > 0) v += d.abs() == 1 ? 3 : 2;
    }
    if (r == 1 || r == 9) {
      v -= 1;
    } else if (r >= 3 && r <= 7) {
      v += 1;
    }
  } else {
    v -= 1;
  }
  return v;
}
