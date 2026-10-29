/// Tile helpers shared by mahjong9 games (shenyangmj, changchunmj, wenzhoumj).
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

const int kEast = 27; // 1z 东
const int kSouth = 28; // 2z 南
const int kWest = 29; // 3z 西
const int kNorth = 30; // 4z 北
const int kHaku = 31; // 5z 白板
const int kHatsu = 32; // 6z 发财
const int kChun = 33; // 7z 红中
const int kYaoJi = 18; // 1s 幺鸡

bool isNumber(int t) => t >= 0 && t < 27;
bool isHonor(int t) => t >= 27 && t < 34;
bool isWind(int t) => t >= 27 && t <= 30;
bool isDragon(int t) => t >= 31 && t <= 33;
int suitOf(int t) => t < 27 ? t ~/ 9 : 3;
int rankOf(int t) => t < 27 ? t % 9 + 1 : 0;
bool isTerminal(int t) => t < 27 && (t % 9 == 0 || t % 9 == 8);
bool isYaojiu(int t) => isTerminal(t) || isHonor(t);

String tileCode(int t) {
  if (t < 0 || t >= kKinds) return 'back';
  if (t < 27) return '${t % 9 + 1}${suitLetters[t ~/ 9]}';
  return '${t - 26}z';
}

int tileFromCode(Object? c) {
  if (c is int) return c >= 0 && c < kKinds ? c : -1;
  if (c is! String || c.length != 2) return -1;
  final rawRank = int.tryParse(c[0]);
  if (rawRank == null) return -1;
  final r = rawRank == 0 ? 5 : rawRank;
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

/// Returns the next tile in cyclic order within the same suit / honor group:
/// - Number suits (1..9 -> 2..9, 1)
/// - Winds (1z..4z -> 2z, 3z, 4z, 1z)
/// - Dragons (5z..7z -> 6z, 7z, 5z)
int nextCyclicTile(int indicator) {
  if (indicator >= 0 && indicator < kNumKinds) {
    final s = indicator ~/ 9;
    final r = indicator % 9;
    return s * 9 + (r + 1) % 9;
  }
  if (indicator >= 27 && indicator <= 30) {
    return 27 + (indicator - 27 + 1) % 4;
  }
  if (indicator >= 31 && indicator <= 33) {
    return 31 + (indicator - 31 + 1) % 3;
  }
  return 0;
}

String nextCyclicTileCode(String indicatorCode) =>
    tileCode(nextCyclicTile(tileFromCode(indicatorCode)));

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

/// A called or declared meld (including `xfgang` 旋风杠 and `xiadan` 下蛋).
class Meld {
  /// 'chi', 'peng', 'mgang', 'bgang', 'agang', 'xfgang', 'xiadan'
  String kind;

  /// For chi: the lowest tile of the sequence; otherwise the primary tile.
  final int tile;

  /// The tile taken from another player (-1 for concealed / self-declared meld).
  final int claimed;

  /// Seat the tile came from (-1 for self-declared meld).
  final int from;

  /// Explicit list of tile ids for multi-kind melds (`xfgang`, `xiadan`).
  final List<int>? customTiles;

  /// Sub-kind label (e.g. 'wind' / 'dragon' / 'yao' / 'jiu').
  final String? subKind;

  Meld(
    this.kind,
    this.tile, {
    this.claimed = -1,
    this.from = -1,
    this.customTiles,
    this.subKind,
  });

  bool get isChi => kind == 'chi';
  bool get isPeng => kind == 'peng' || kind == 'pon';
  bool get isXfgang => kind == 'xfgang';
  bool get isXiadan => kind == 'xiadan';
  bool get isKong =>
      kind == 'mgang' ||
      kind == 'bgang' ||
      kind == 'agang' ||
      kind == 'xfgang' ||
      kind == 'xiadan' ||
      kind == 'minkan' ||
      kind == 'kakan' ||
      kind == 'ankan' ||
      kind == 'kan';
  bool get concealed => kind == 'agang' || kind == 'ankan';
  bool get isExposed => !concealed;
  int get size => customTiles != null ? customTiles!.length : (isKong ? 4 : 3);
  List<int> get tiles =>
      customTiles != null ? customTiles! : (isChi ? [tile, tile + 1, tile + 2] : List.filled(size, tile));

  Map<String, dynamic> toJson({bool hide = false}) => {
        'kind': kind,
        if (subKind != null) 'subKind': subKind,
        'tile': hide ? 'back' : tileCode(tile),
        'tiles': hide
            ? List.filled(size, 'back')
            : [for (final t in tiles) tileCode(t)],
        'claimed': claimed >= 0 ? tileCode(claimed) : null,
        'from': from,
      };
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

bool isAllPungs(List<int> c) {
  if (countTotal(c) % 3 != 2) return false;
  var pairs = 0;
  for (final x in c) {
    final r = x % 3;
    if (r == 1) return false;
    if (r == 2) pairs++;
  }
  return pairs == 1;
}

bool isSevenPairs(List<int> c) {
  if (countTotal(c) != 14) return false;
  for (final x in c) {
    if (x.isOdd) return false;
  }
  return true;
}

bool canSetsWild(List<int> c, int i, int wild) {
  final n = c.length;
  while (i < n && c[i] == 0) {
    i++;
  }
  if (i >= n) return true;
  // 1. Triplet at i
  final useTrip = c[i] >= 3 ? 3 : c[i];
  final needTrip = 3 - useTrip;
  if (needTrip <= wild) {
    c[i] -= useTrip;
    final ok = canSetsWild(c, i, wild - needTrip);
    c[i] += useTrip;
    if (ok) return true;
  }
  // 2. Sequences involving i (only for number tiles 0..26)
  if (i < 27) {
    final r = i % 9;
    if (r <= 6) {
      final u1 = c[i + 1] > 0 ? 1 : 0;
      final u2 = c[i + 2] > 0 ? 1 : 0;
      final needW = (1 - u1) + (1 - u2);
      if (needW <= wild) {
        c[i]--;
        c[i + 1] -= u1;
        c[i + 2] -= u2;
        final ok = canSetsWild(c, i, wild - needW);
        c[i]++;
        c[i + 1] += u1;
        c[i + 2] += u2;
        if (ok) return true;
      }
    }
    if (r >= 1 && r <= 7 && wild >= 1) {
      final u1 = c[i + 1] > 0 ? 1 : 0;
      final needW = 1 + (1 - u1);
      if (needW <= wild) {
        c[i]--;
        c[i + 1] -= u1;
        final ok = canSetsWild(c, i, wild - needW);
        c[i]++;
        c[i + 1] += u1;
        if (ok) return true;
      }
    }
    if (r >= 2 && wild >= 2) {
      c[i]--;
      final ok = canSetsWild(c, i, wild - 2);
      c[i]++;
      if (ok) return true;
    }
  }
  return false;
}

bool canAnyPairStandardWild(List<int> c, int wild) {
  final n = c.length;
  for (var p = 0; p < n; p++) {
    final use = c[p] >= 2 ? 2 : c[p];
    final need = 2 - use;
    if (need <= wild) {
      c[p] -= use;
      final ok = canSetsWild(c, 0, wild - need);
      c[p] += use;
      if (ok) return true;
    }
  }
  return false;
}

bool canPengPengWild(List<int> c, int wild) {
  final n = c.length;
  for (var p = 0; p < n; p++) {
    final use = c[p] >= 2 ? 2 : c[p];
    var remWild = wild - (2 - use);
    if (remWild < 0) continue;
    c[p] -= use;
    var ok = true;
    for (var t = 0; t < n; t++) {
      final rem = c[t] % 3;
      if (rem != 0) {
        remWild -= (3 - rem);
        if (remWild < 0) {
          ok = false;
          break;
        }
      }
    }
    c[p] += use;
    if (ok) return true;
  }
  return false;
}

bool canSevenPairsWild(List<int> c, int wild) {
  var odd = 0;
  for (var t = 0; t < c.length; t++) {
    if (c[t].isOdd) odd++;
  }
  return odd <= wild && (wild - odd).isEven;
}

/// Heuristic usefulness of a tile in hand (lower = better discard).
int tileValue(List<int> c, int t, {bool preferHonors = false, bool keepTerminals = false}) {
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
      v += keepTerminals ? 2 : -1;
    } else if (r >= 3 && r <= 7) {
      v += 1;
    }
  } else {
    if (preferHonors) {
      v += c[t] >= 2 ? 6 : 2;
    } else {
      v += c[t] >= 2 ? 2 : -1;
    }
  }
  return v;
}
