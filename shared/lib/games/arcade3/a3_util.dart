/// Small helpers shared by the arcade3 engines (kept private to arcade3 so
/// packages remain completely independent).
library;

/// Sorts seats 0..n-1 with [cmp] (negative = a ranks better) and assigns
/// competition ranks (ties share a rank). [extra] adds per-seat fields.
List<Map<String, dynamic>> a3Ranking(
    int n, int Function(int a, int b) cmp, Map<String, dynamic> Function(int s) extra) {
  final order = [for (var s = 0; s < n; s++) s]..sort((a, b) {
      final c = cmp(a, b);
      return c != 0 ? c : a - b;
    });
  final out = <Map<String, dynamic>>[];
  var rank = 0;
  for (var i = 0; i < order.length; i++) {
    if (i == 0 || cmp(order[i], order[i - 1]) != 0) rank = i + 1;
    out.add({'s': order[i], 'rank': rank, ...extra(order[i])});
  }
  return out;
}

/// Rotates [seats] so that element `k % length` comes first (the simulator
/// only lets the first bot in waitingFor act per step).
List<int> a3Rotated(List<int> seats, int k) {
  if (seats.length < 2) return seats;
  final i = k % seats.length;
  return [...seats.sublist(i), ...seats.sublist(0, i)];
}

/// Winners' names for a log line.
String a3Winners(List<Map<String, dynamic>> ranking, String Function(int) name) =>
    [for (final r in ranking) if (r['rank'] == 1) name(r['s'] as int)].join('、');

/// Per-seat placings from an [a3Ranking] result.
List<int>? a3Placings(List<Map<String, dynamic>>? ranking, int n) {
  if (ranking == null) return null;
  final out = List<int>.filled(n, n);
  for (final r in ranking) {
    out[r['s'] as int] = r['rank'] as int;
  }
  return out;
}
