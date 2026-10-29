import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a14_common.dart';

class ShingokiBoard extends StatefulWidget {
  final GameContext g;
  const ShingokiBoard(this.g, {super.key});
  @override
  State<ShingokiBoard> createState() => _ShingokiBoardState();
}

class _ShingokiBoardState extends State<ShingokiBoard> {
  GameContext get g => widget.g;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _onBoardTapUp(
    TapUpDetails details,
    int size,
    double cellPx,
  ) {
    if (!_canPlay) return;
    final pos = details.localPosition;

    var bestR1 = -1, bestC1 = -1, bestR2 = -1, bestC2 = -1;
    var bestEdgeDistSq = double.infinity;

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        final mx = (c + 1.0) * cellPx;
        final my = (r + 0.5) * cellPx;
        final d2 = (pos.dx - mx) * (pos.dx - mx) + (pos.dy - my) * (pos.dy - my);
        if (d2 < bestEdgeDistSq) {
          bestEdgeDistSq = d2;
          bestR1 = r;
          bestC1 = c;
          bestR2 = r;
          bestC2 = c + 1;
        }
      }
    }

    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        final mx = (c + 0.5) * cellPx;
        final my = (r + 1.0) * cellPx;
        final d2 = (pos.dx - mx) * (pos.dx - mx) + (pos.dy - my) * (pos.dy - my);
        if (d2 < bestEdgeDistSq) {
          bestEdgeDistSq = d2;
          bestR1 = r;
          bestC1 = c;
          bestR2 = r + 1;
          bestC2 = c;
        }
      }
    }

    if (bestR1 >= 0 && bestEdgeDistSq <= (cellPx * 0.65) * (cellPx * 0.65)) {
      g.act({'type': 'edge', 'r1': bestR1, 'c1': bestC1, 'r2': bestR2, 'c2': bestC2});
    }
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

    final rawCluesFlat = v['cluesFlat'];
    final cluesFlat = <Map<String, dynamic>?>[
      if (rawCluesFlat is List)
        for (final e in rawCluesFlat) e is Map ? e.cast<String, dynamic>() : null,
    ];
    final hSegs = aIntGrid(v['hSegs']);
    final vSegs = aIntGrid(v['vSegs']);
    final clueRaySums = aInts(v['clueRaySums']);
    final satisfiedClues = aInts(v['satisfiedClues']).toSet();
    final violatedClues = aInts(v['violatedClues']).toSet();
    final unvisitedClues = aInts(v['unvisitedClues']).toSet();
    final badDegreeVertices = aInts(v['badDegreeVertices']).toSet();
    final satisfiedClueCount = aInt(v['satisfiedClueCount'], 0);
    final totalClues = math.max(1, aInt(v['totalClues'], 1));
    final activeSegCount = aInt(v['activeSegCount'], 0);
    final isSingleLoop = v['isSingleLoop'] == true;
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '信号灯回路竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出信号灯回路（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final loopStr = isSingleLoop
          ? '✓ 单一闭环成形'
          : (badDegreeVertices.isNotEmpty
              ? '⚠ 格点分叉/断头'
              : (violatedClues.isNotEmpty ? '⚠ 信号灯直转或臂长不符' : '点击相邻格点连线'));
      status =
          '第 $round/$totalRounds 题（$size×$size）· 信号灯 $satisfiedClueCount/$totalClues · 线段 $activeSegCount · $loopStr · ${left}s';
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
        cluesFlat: cluesFlat,
        hSegs: hSegs,
        vSegs: vSegs,
        clueRaySums: clueRaySums,
        satisfiedClues: satisfiedClues,
        violatedClues: violatedClues,
        unvisitedClues: unvisitedClues,
        badDegreeVertices: badDegreeVertices,
        satisfiedClueCount: satisfiedClueCount,
        totalClues: totalClues,
        activeSegCount: activeSegCount,
        isSingleLoop: isSingleLoop,
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
                    (r) => '${r['score']} 分 · 解出 ${r['solved']}/$totalRounds 题',
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
    final sat = aInt(p['satisfiedClues'], 0);
    final tot = math.max(1, aInt(p['totalClues'], 4));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot灯', null),
    };
    return A14ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (sat / tot),
      badge: badge,
      badgeColor: col,
      dim: st == 'resigned',
      sub: '积分 $score · 解出 $solved/$totalRounds',
    );
  }

  Widget _buildWorkspace(
    BuildContext context, {
    required ColorScheme cs,
    required int size,
    required List<Map<String, dynamic>?> cluesFlat,
    required List<List<int>> hSegs,
    required List<List<int>> vSegs,
    required List<int> clueRaySums,
    required Set<int> satisfiedClues,
    required Set<int> violatedClues,
    required Set<int> unvisitedClues,
    required Set<int> badDegreeVertices,
    required int satisfiedClueCount,
    required int totalClues,
    required int activeSegCount,
    required bool isSingleLoop,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 52.0 : 45.0;
    final boardPx = size * cellPx;

    final gridCard = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _onBoardTapUp(d, size, cellPx),
        child: SizedBox(
          width: boardPx,
          height: boardPx,
          child: CustomPaint(
            painter: _ShingokiPainter(
              size: size,
              cellPx: cellPx,
              cluesFlat: cluesFlat,
              hSegs: hSegs,
              vSegs: vSegs,
              clueRaySums: clueRaySums,
              satisfiedClues: satisfiedClues,
              violatedClues: violatedClues,
              badDegreeVertices: badDegreeVertices,
              isSingleLoop: isSingleLoop,
            ),
          ),
        ),
      ),
    );

    final toolbar = Container(
      constraints: BoxConstraints(maxWidth: wide ? 235 : 340),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              A14Chip('信号灯 $satisfiedClueCount/$totalClues', const Color(0xFF00897B), size: 11),
              A14Chip('回路线段 $activeSegCount', cs.primary, size: 11),
              A14Chip(
                isSingleLoop && violatedClues.isEmpty
                    ? '✓ 闭环达标'
                    : (badDegreeVertices.isNotEmpty || violatedClues.isNotEmpty ? '⚠ 存在冲突' : '待成闭环'),
                isSingleLoop && violatedClues.isEmpty
                    ? Colors.green
                    : (badDegreeVertices.isNotEmpty || violatedClues.isNotEmpty ? Colors.redAccent : Colors.blueGrey),
                size: 11,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: const [
              A14Chip('○ 白灯 = 直行贯通', Color(0xFF475569), size: 10),
              A14Chip('● 黑灯 = 90°直角转弯', Color(0xFF1E293B), size: 10),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _canPlay ? () => g.act({'type': 'clear'}) : null,
                icon: const Icon(Icons.layers_clear, size: 15),
                label: const Text('清空', style: TextStyle(fontSize: 12)),
              ),
              FilledButton.tonalIcon(
                onPressed: _canPlay ? () => g.act({'type': 'pass'}) : null,
                icon: const Icon(Icons.flag_outlined, size: 15),
                label: const Text('放弃', style: TextStyle(fontSize: 12)),
              ),
            ],
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
                gridCard,
                const SizedBox(width: 12),
                toolbar,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                gridCard,
                const SizedBox(height: 8),
                toolbar,
              ]),
      ),
    );
  }
}

class _ShingokiPainter extends CustomPainter {
  final int size;
  final double cellPx;
  final List<Map<String, dynamic>?> cluesFlat;
  final List<List<int>> hSegs;
  final List<List<int>> vSegs;
  final List<int> clueRaySums;
  final Set<int> satisfiedClues;
  final Set<int> violatedClues;
  final Set<int> badDegreeVertices;
  final bool isSingleLoop;

  const _ShingokiPainter({
    required this.size,
    required this.cellPx,
    required this.cluesFlat,
    required this.hSegs,
    required this.vSegs,
    required this.clueRaySums,
    required this.satisfiedClues,
    required this.violatedClues,
    required this.badDegreeVertices,
    required this.isSingleLoop,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      const Radius.circular(12),
    );
    canvas.drawRRect(bgRect, Paint()..color = const Color(0xFFF8FAFC));

    final guidePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // 1. Draw faint grid edges between adjacent vertices
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        canvas.drawLine(
          Offset((c + 0.5) * cellPx, (r + 0.5) * cellPx),
          Offset((c + 1.5) * cellPx, (r + 0.5) * cellPx),
          guidePaint,
        );
      }
    }
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        canvas.drawLine(
          Offset((c + 0.5) * cellPx, (r + 0.5) * cellPx),
          Offset((c + 0.5) * cellPx, (r + 1.5) * cellPx),
          guidePaint,
        );
      }
    }

    // 2. Draw active loop segments
    final segColor = isSingleLoop ? const Color(0xFF00897B) : const Color(0xFF0288D1);
    final segPaint = Paint()
      ..color = segColor
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    for (var r = 0; r < size; r++) {
      final row = r < hSegs.length ? hSegs[r] : const <int>[];
      for (var c = 0; c < size - 1; c++) {
        if (c < row.length && row[c] == 1) {
          canvas.drawLine(
            Offset((c + 0.5) * cellPx, (r + 0.5) * cellPx),
            Offset((c + 1.5) * cellPx, (r + 0.5) * cellPx),
            segPaint,
          );
        }
      }
    }

    for (var r = 0; r < size - 1; r++) {
      final row = r < vSegs.length ? vSegs[r] : const <int>[];
      for (var c = 0; c < size; c++) {
        if (c < row.length && row[c] == 1) {
          canvas.drawLine(
            Offset((c + 0.5) * cellPx, (r + 0.5) * cellPx),
            Offset((c + 0.5) * cellPx, (r + 1.5) * cellPx),
            segPaint,
          );
        }
      }
    }

    // 3. Draw vertices and Traffic Light Clue circles
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final center = Offset((c + 0.5) * cellPx, (r + 0.5) * cellPx);
        final clue = idx < cluesFlat.length ? cluesFlat[idx] : null;
        final isSat = satisfiedClues.contains(idx);
        final isViol = violatedClues.contains(idx);
        final isBadDeg = badDegreeVertices.contains(idx);

        if (clue == null) {
          canvas.drawCircle(
            center,
            isBadDeg ? 5.5 : 3.6,
            Paint()..color = isBadDeg ? const Color(0xFFD32F2F) : const Color(0xFF334155),
          );
          continue;
        }

        final color = aStr(clue['color']);
        final isWhiteLight = color == 'W';
        final targetLen = aInt(clue['len'], 2);
        final curSum = idx < clueRaySums.length ? clueRaySums[idx] : 0;
        final radius = cellPx * 0.34;

        final fillColor = isWhiteLight ? Colors.white : const Color(0xFF0F172A);
        final ringColor = isSat
            ? const Color(0xFF2E7D32)
            : (isViol ? const Color(0xFFD32F2F) : const Color(0xFF0F172A));

        canvas.drawCircle(center, radius, Paint()..color = fillColor);
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = ringColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSat || isViol ? 3.0 : 2.4,
        );

        final textColor = isWhiteLight
            ? (isSat
                ? const Color(0xFF1B5E20)
                : (isViol ? const Color(0xFFC62828) : const Color(0xFF0F172A)))
            : (isSat
                ? const Color(0xFF81C784)
                : (isViol ? const Color(0xFFFF8A80) : Colors.white));

        final tp = TextPainter(
          text: TextSpan(
            text: '$targetLen',
            style: TextStyle(
              fontSize: cellPx * 0.34,
              fontWeight: FontWeight.w900,
              color: textColor,
              fontFamilyFallback: kFontFallback,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

        if (curSum > 0) {
          final subTp = TextPainter(
            text: TextSpan(
              text: '$curSum/$targetLen',
              style: TextStyle(
                fontSize: cellPx * 0.16,
                fontWeight: FontWeight.w800,
                color: isSat
                    ? const Color(0xFF2E7D32)
                    : (isViol ? const Color(0xFFC62828) : const Color(0xFF475569)),
                fontFamilyFallback: kFontFallback,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          subTp.paint(
            canvas,
            Offset(center.dx - subTp.width / 2, center.dy + radius + 1),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShingokiPainter old) => true;
}
