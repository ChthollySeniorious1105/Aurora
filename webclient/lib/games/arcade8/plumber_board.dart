import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a8_common.dart';

class PlumberBoard extends StatefulWidget {
  final GameContext g;
  const PlumberBoard(this.g, {super.key});
  @override
  State<PlumberBoard> createState() => _PlumberBoardState();
}

class _PlumberBoardState extends State<PlumberBoard> {
  GameContext get g => widget.g;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = aStr(v['phase']);
    final round = aInt(v['round'], 1);
    final totalRounds = math.max(1, aInt(v['totalRounds'], 3));
    final size = math.max(5, aInt(v['size'], 5));
    final left = aInt(v['left'], 0);
    final types = aStrs(v['types']);
    final rots = aInts(v['rots']);
    final gauges = aInts(v['gauges']).toSet();
    final wet = aInts(v['wet']).toSet();
    final leaks = aInts(v['leaks']).toSet();
    final wetLeaks = aInts(v['wetLeaks']).toSet();
    final litGauges = aInts(v['litGauges']).toSet();
    final drainReached = v['drainReached'] == true;
    final wetCount = aInt(v['wetCount'], 1);
    final totalCells = math.max(1, aInt(v['totalCells'], size * size));
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '水管工接管竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 水网已全线贯通（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final leakStr = leaks.isEmpty ? '零漏水' : '漏水点 ${leaks.length} 处';
      final drainStr = drainReached ? '排出口已通水' : '排出口待接通';
      status =
          '第 $round/$totalRounds 题（$size×$size）· 通水 $wetCount/$totalCells · $drainStr · $leakStr · ${left}s';
    }

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > box.maxHeight * 1.12;
      final sideW = wide ? math.min(200.0, box.maxWidth * 0.24) : 0.0;
      final topStripH = wide ? 0.0 : 58.0;

      final playerTiles = Wrap(
        direction: wide ? Axis.vertical : Axis.horizontal,
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final s in g.seatsFromMe())
            if (s < ps.length) _buildPlayerTile(s, ps[s], totalRounds, wide ? sideW - 12 : 140),
        ],
      );

      final workspace = _buildWorkspace(
        context,
        cs: cs,
        size: size,
        round: round,
        totalRounds: totalRounds,
        types: types,
        rots: rots,
        gauges: gauges,
        wet: wet,
        leaks: leaks,
        wetLeaks: wetLeaks,
        litGauges: litGauges,
        drainReached: drainReached,
        wetCount: wetCount,
        totalCells: totalCells,
        wide: wide,
      );

      Widget body;
      if (wide) {
        body = Row(children: [
          SizedBox(
            width: sideW,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(6),
                child: FittedBox(fit: BoxFit.scaleDown, child: playerTiles),
              ),
            ),
          ),
          Expanded(child: Center(child: workspace)),
        ]);
      } else {
        body = Column(children: [
          SizedBox(
            height: topStripH,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: playerTiles),
              ),
            ),
          ),
          Expanded(child: Center(child: workspace)),
        ]);
      }

      return Column(children: [
        SizedBox(height: 38, child: aStatus(status, highlight: _canPlay)),
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: body),
            if (phase == 'over')
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: aRanking(
                    g,
                    aMaps(v['final']),
                    (r) => '${r['score']} 分 · 通关 ${r['solved']}/$totalRounds 题',
                  ),
                ),
              ),
          ]),
        ),
      ]);
    });
  }

  Widget _buildPlayerTile(int s, Map<String, dynamic> p, int totalRounds, double width) {
    final st = aStr(p['status']);
    final score = aInt(p['score'], 0);
    final solved = aInt(p['solved'], 0);
    final wetCount = aInt(p['wetCount'], 1);
    final totalCells = math.max(1, aInt(p['totalCells'], 25));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$wetCount/$totalCells通水', null),
    };
    return A8ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (wetCount / totalCells),
      badge: badge,
      badgeColor: col,
      dim: st == 'resigned',
      sub: '积分 $score · 通关 $solved/$totalRounds',
    );
  }

  Widget _buildWorkspace(
    BuildContext context, {
    required ColorScheme cs,
    required int size,
    required int round,
    required int totalRounds,
    required List<String> types,
    required List<int> rots,
    required Set<int> gauges,
    required Set<int> wet,
    required Set<int> leaks,
    required Set<int> wetLeaks,
    required Set<int> litGauges,
    required bool drainReached,
    required int wetCount,
    required int totalCells,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 52.0 : 45.0;
    final sidePx = size * cellPx;

    final pipeCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B26),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          if (!_canPlay) return;
          final c = (d.localPosition.dx ~/ cellPx).clamp(0, size - 1);
          final r = (d.localPosition.dy ~/ cellPx).clamp(0, size - 1);
          g.act({'type': 'rotate', 'r': r, 'c': c});
        },
        onSecondaryTapUp: (d) {
          if (!_canPlay) return;
          final c = (d.localPosition.dx ~/ cellPx).clamp(0, size - 1);
          final r = (d.localPosition.dy ~/ cellPx).clamp(0, size - 1);
          g.act({'type': 'rotate', 'r': r, 'c': c, 'steps': -1});
        },
        child: SizedBox(
          width: sidePx,
          height: sidePx,
          child: CustomPaint(
            size: Size(sidePx, sidePx),
            painter: _PlumberPainter(
              gridSize: size,
              cellPx: cellPx,
              types: types,
              rots: rots,
              gauges: gauges,
              wet: wet,
              leaks: leaks,
              wetLeaks: wetLeaks,
              litGauges: litGauges,
              drainReached: drainReached,
            ),
          ),
        ),
      ),
    );

    final toolbar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        direction: wide ? Axis.vertical : Axis.horizontal,
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          A8Chip('充水管道 $wetCount/$totalCells', const Color(0xFF0288D1), size: 11),
          A8Chip(
            '水压表 ${litGauges.length}/${gauges.length}',
            litGauges.length == gauges.length ? Colors.teal : Colors.blueGrey,
            size: 11,
          ),
          A8Chip(
            drainReached ? '排出口已通水' : '排出口待接通',
            drainReached ? Colors.green : Colors.blueGrey,
            size: 11,
          ),
          A8Chip(
            leaks.isEmpty ? '✓ 零漏水' : '⚠ 漏水口 ${leaks.length} 处',
            leaks.isEmpty ? Colors.green : Colors.redAccent,
            size: 11,
          ),
          OutlinedButton.icon(
            onPressed: _canPlay ? () => g.act({'type': 'reset'}) : null,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重置', style: TextStyle(fontSize: 12)),
          ),
          FilledButton.tonalIcon(
            onPressed: _canPlay ? () => g.act({'type': 'pass'}) : null,
            icon: const Icon(Icons.flag_outlined, size: 16),
            label: const Text('放弃', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: wide
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                pipeCard,
                const SizedBox(width: 12),
                toolbar,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                pipeCard,
                const SizedBox(height: 8),
                toolbar,
              ]),
      ),
    );
  }
}

class _PlumberPainter extends CustomPainter {
  final int gridSize;
  final double cellPx;
  final List<String> types;
  final List<int> rots;
  final Set<int> gauges;
  final Set<int> wet;
  final Set<int> leaks;
  final Set<int> wetLeaks;
  final Set<int> litGauges;
  final bool drainReached;

  _PlumberPainter({
    required this.gridSize,
    required this.cellPx,
    required this.types,
    required this.rots,
    required this.gauges,
    required this.wet,
    required this.leaks,
    required this.wetLeaks,
    required this.litGauges,
    required this.drainReached,
  });

  static const List<int> dr = [-1, 0, 1, 0];
  static const List<int> dc = [0, 1, 0, -1];

  static int _openPortsMask(String type, int rot) {
    final base = switch (type) {
      'I' => const [0, 2],
      'L' => const [0, 1],
      'T' => const [0, 1, 2],
      '+' => const [0, 1, 2, 3],
      'E' => const [0],
      _ => const [0, 2],
    };
    final shift = ((rot % 4) + 4) % 4;
    var mask = 0;
    for (final p in base) {
      mask |= 1 << ((p + shift) & 3);
    }
    return mask;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = gridSize * gridSize;
    final masks = List<int>.generate(
      n,
      (i) => _openPortsMask(
        i < types.length ? types[i] : 'I',
        i < rots.length ? rots[i] : 0,
      ),
    );

    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final idx = r * gridSize + c;
        final isWet = wet.contains(idx);
        final hasLeak = leaks.contains(idx);
        final rect = Rect.fromLTWH(c * cellPx + 1.5, r * cellPx + 1.5, cellPx - 3, cellPx - 3);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));

        // 1. Tile background
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = isWet ? const Color(0xFF132A3E) : const Color(0xFF1A2530),
        );
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = hasLeak
                ? const Color(0xFFFF5252).withValues(alpha: 0.75)
                : (isWet ? const Color(0xFF00B0FF).withValues(alpha: 0.55) : const Color(0xFF2E3D4C))
            ..style = PaintingStyle.stroke
            ..strokeWidth = hasLeak ? 1.8 : 1.0,
        );

        // 2. Pipe arms & center joint
        final center = Offset((c + 0.5) * cellPx, (r + 0.5) * cellPx);
        final m = masks[idx];
        final outerStroke = cellPx * 0.34;
        final innerStroke = cellPx * 0.20;

        final casingPaint = Paint()
          ..color = isWet ? const Color(0xFF0277BD) : const Color(0xFF546E7A)
          ..strokeWidth = outerStroke
          ..strokeCap = StrokeCap.round;

        final waterPaint = Paint()
          ..color = isWet ? const Color(0xFF00E5FF) : const Color(0xFF263238)
          ..strokeWidth = innerStroke
          ..strokeCap = StrokeCap.round;

        for (var d = 0; d < 4; d++) {
          if ((m & (1 << d)) == 0) continue;
          final edgePt = center + Offset(dc[d] * (cellPx * 0.48), dr[d] * (cellPx * 0.48));
          canvas.drawLine(center, edgePt, casingPaint);
        }
        canvas.drawCircle(center, outerStroke * 0.52, Paint()..color = casingPaint.color);

        for (var d = 0; d < 4; d++) {
          if ((m & (1 << d)) == 0) continue;
          final edgePt = center + Offset(dc[d] * (cellPx * 0.48), dr[d] * (cellPx * 0.48));
          canvas.drawLine(center, edgePt, waterPaint);

          // Check if this specific port is an unconnected leak
          final nr = r + dr[d], nc = c + dc[d];
          final opp = (d + 2) & 3;
          final portLeaks = nr < 0 ||
              nr >= gridSize ||
              nc < 0 ||
              nc >= gridSize ||
              (masks[nr * gridSize + nc] & (1 << opp)) == 0;
          if (portLeaks) {
            final tip = center + Offset(dc[d] * (cellPx * 0.40), dr[d] * (cellPx * 0.40));
            canvas.drawCircle(
              tip,
              cellPx * 0.11,
              Paint()..color = isWet ? const Color(0xFFFF1744) : const Color(0xFFFF8A80),
            );
          }
        }
        canvas.drawCircle(center, innerStroke * 0.55, Paint()..color = waterPaint.color);

        // 3. Special emblems: Source (0,0), Drain (N-1,N-1), or Gauge Checkpoint
        if (idx == 0) {
          // Source Valve wheel
          canvas.drawCircle(center, cellPx * 0.24, Paint()..color = const Color(0xFFD32F2F));
          canvas.drawCircle(
            center,
            cellPx * 0.24,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
          final tp = TextPainter(
            text: TextSpan(
              text: '源',
              style: TextStyle(
                fontSize: cellPx * 0.24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontFamilyFallback: kFontFallback,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
        } else if (idx == n - 1) {
          // Drain Outlet
          canvas.drawCircle(
            center,
            cellPx * 0.25,
            Paint()..color = drainReached ? const Color(0xFF00C853) : const Color(0xFF455A64),
          );
          canvas.drawCircle(
            center,
            cellPx * 0.25,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
          final tp = TextPainter(
            text: TextSpan(
              text: '终',
              style: TextStyle(
                fontSize: cellPx * 0.24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontFamilyFallback: kFontFallback,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
        } else if (gauges.contains(idx)) {
          final lit = litGauges.contains(idx);
          canvas.drawCircle(
            center,
            cellPx * 0.21,
            Paint()..color = lit ? const Color(0xFF00BFA5) : const Color(0xFF37474F),
          );
          canvas.drawCircle(
            center,
            cellPx * 0.21,
            Paint()
              ..color = lit ? const Color(0xFFA7FFEB) : const Color(0xFF90A4AE)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PlumberPainter old) =>
      old.gridSize != gridSize ||
      old.types != types ||
      old.rots != rots ||
      old.wet != wet ||
      old.leaks != leaks ||
      old.drainReached != drainReached;
}
