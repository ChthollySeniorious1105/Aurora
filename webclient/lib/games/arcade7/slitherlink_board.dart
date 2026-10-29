import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a7_common.dart';

class SlitherlinkBoard extends StatefulWidget {
  final GameContext g;
  const SlitherlinkBoard(this.g, {super.key});
  @override
  State<SlitherlinkBoard> createState() => _SlitherlinkBoardState();
}

class _SlitherlinkBoardState extends State<SlitherlinkBoard> {
  GameContext get g => widget.g;
  int _toolMode = 0; // 0 = 循环切换, 1 = 划线, 2 = 标记 ×

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _actEdge(String dir, int r, int c, {bool forceX = false}) {
    if (!_canPlay) return;
    if (forceX) {
      g.act({'type': 'edge', 'dir': dir, 'r': r, 'c': c, 'mode': 2});
    } else if (_toolMode == 0) {
      g.act({'type': 'edge', 'dir': dir, 'r': r, 'c': c});
    } else {
      g.act({'type': 'edge', 'dir': dir, 'r': r, 'c': c, 'mode': _toolMode});
    }
  }

  void _handleCanvasTap(Offset pos, int size, double pad, double cellPx, {bool forceX = false}) {
    if (!_canPlay) return;
    // Find nearest horizontal or vertical edge segment midpoint
    String? bestDir;
    var bestR = 0;
    var bestC = 0;
    var bestDist = cellPx * 0.45;

    for (var r = 0; r <= size; r++) {
      for (var c = 0; c < size; c++) {
        final mx = pad + (c + 0.5) * cellPx;
        final my = pad + r * cellPx;
        final d = (pos - Offset(mx, my)).distance;
        if (d < bestDist) {
          bestDist = d;
          bestDir = 'h';
          bestR = r;
          bestC = c;
        }
      }
    }
    for (var r = 0; r < size; r++) {
      for (var c = 0; c <= size; c++) {
        final mx = pad + c * cellPx;
        final my = pad + (r + 0.5) * cellPx;
        final d = (pos - Offset(mx, my)).distance;
        if (d < bestDist) {
          bestDist = d;
          bestDir = 'v';
          bestR = r;
          bestC = c;
        }
      }
    }

    if (bestDir != null) {
      _actEdge(bestDir, bestR, bestC, forceX: forceX);
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
    final clues = aInts(v['clues']);
    final hEdges = aInts(v['hEdges']);
    final vEdges = aInts(v['vEdges']);
    final badVertices = aInts(v['badVertices']).toSet();
    final loopComponents = aInt(v['loopComponents'], 0);
    final isSingleLoop = v['isSingleLoop'] == true;
    final cellOk = aBools(v['cellOk']);
    final okClues = aInt(v['okClues'], 0);
    final totalClues = math.max(1, aInt(v['totalClues'], 10));
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '数圈竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已连成闭合数圈（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final loopHint = badVertices.isNotEmpty
          ? ' · ⚠ 有断头或分叉顶点'
          : (isSingleLoop ? ' · 已成闭合单环' : (loopComponents > 1 ? ' · 存在 $loopComponents 个分离环' : ''));
      status = '第 $round/$totalRounds 题（$size×$size）· 线索达标 $okClues/$totalClues$loopHint · ${left}s';
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
        clues: clues,
        hEdges: hEdges,
        vEdges: vEdges,
        badVertices: badVertices,
        isSingleLoop: isSingleLoop,
        cellOk: cellOk,
        okClues: okClues,
        totalClues: totalClues,
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
                    (r) => '${r['score']} 分 · 成环 ${r['solved']}/$totalRounds 题',
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
    final okClues = aInt(p['okClues'], 0);
    final totalClues = math.max(1, aInt(p['totalClues'], 10));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$okClues/$totalClues格', null),
    };
    return A7ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (okClues / totalClues),
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
    required int round,
    required int totalRounds,
    required List<int> clues,
    required List<int> hEdges,
    required List<int> vEdges,
    required Set<int> badVertices,
    required bool isSingleLoop,
    required List<bool> cellOk,
    required int okClues,
    required int totalClues,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 48.0 : 42.0;
    const pad = 18.0;
    final canvasSide = size * cellPx + pad * 2;

    final boardCard = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A222D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF64FFDA).withValues(alpha: 0.4), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _handleCanvasTap(d.localPosition, size, pad, cellPx),
        onSecondaryTapUp: (d) => _handleCanvasTap(d.localPosition, size, pad, cellPx, forceX: true),
        child: SizedBox(
          width: canvasSide,
          height: canvasSide,
          child: CustomPaint(
            size: Size(canvasSide, canvasSide),
            painter: _SlitherlinkPainter(
              gridSize: size,
              pad: pad,
              cellPx: cellPx,
              clues: clues,
              hEdges: hEdges,
              vEdges: vEdges,
              badVertices: badVertices,
              cellOk: cellOk,
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
          A7Chip('第 $round/$totalRounds 题 · 线索 $okClues/$totalClues', cs.primary, size: 11),
          A7Chip(
            badVertices.isNotEmpty ? '⚠ 断头/分叉' : (isSingleLoop ? '已成单环' : '连线成环中'),
            badVertices.isNotEmpty ? Colors.redAccent : (isSingleLoop ? Colors.green : Colors.blueGrey),
            size: 11,
          ),
          ChoiceChip(
            label: const Text('↻ 循环', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == 0,
            onSelected: (_) => setState(() => _toolMode = 0),
          ),
          ChoiceChip(
            label: const Text('━ 划线', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == 1,
            onSelected: (_) => setState(() => _toolMode = 1),
          ),
          ChoiceChip(
            label: const Text('× 禁用', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == 2,
            onSelected: (_) => setState(() => _toolMode = 2),
          ),
          OutlinedButton.icon(
            onPressed: _canPlay ? () => g.act({'type': 'clear'}) : null,
            icon: const Icon(Icons.layers_clear, size: 16),
            label: const Text('清空', style: TextStyle(fontSize: 12)),
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
                boardCard,
                const SizedBox(width: 12),
                toolbar,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                boardCard,
                const SizedBox(height: 8),
                toolbar,
              ]),
      ),
    );
  }
}

class _SlitherlinkPainter extends CustomPainter {
  final int gridSize;
  final double pad;
  final double cellPx;
  final List<int> clues;
  final List<int> hEdges;
  final List<int> vEdges;
  final Set<int> badVertices;
  final List<bool> cellOk;

  _SlitherlinkPainter({
    required this.gridSize,
    required this.pad,
    required this.cellPx,
    required this.clues,
    required this.hEdges,
    required this.vEdges,
    required this.badVertices,
    required this.cellOk,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw cell backgrounds and clues
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final idx = r * gridSize + c;
        final clue = idx < clues.length ? clues[idx] : -1;
        final ok = idx < cellOk.length && cellOk[idx];
        final rect = Rect.fromLTWH(
          pad + c * cellPx + 3,
          pad + r * cellPx + 3,
          cellPx - 6,
          cellPx - 6,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()
            ..color = clue >= 0
                ? (ok
                    ? const Color(0xFF1B5E20).withValues(alpha: 0.42)
                    : const Color(0xFF263238).withValues(alpha: 0.65))
                : const Color(0xFF263238).withValues(alpha: 0.25),
        );

        if (clue >= 0) {
          final tp = TextPainter(
            text: TextSpan(
              text: '$clue',
              style: TextStyle(
                fontSize: cellPx * 0.46,
                fontWeight: FontWeight.w900,
                color: ok ? const Color(0xFF69F0AE) : Colors.white,
                fontFamilyFallback: kFontFallback,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }

    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 1.5;
    final activeGlowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;
    final activeLinePaint = Paint()
      ..color = const Color(0xFF64FFDA)
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round;
    final xMarkPaint = Paint()
      ..color = const Color(0xFFFF8A80)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // 2. Draw horizontal edges
    for (var r = 0; r <= gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final idx = r * gridSize + c;
        final val = idx < hEdges.length ? hEdges[idx] : 0;
        final p1 = Offset(pad + c * cellPx, pad + r * cellPx);
        final p2 = Offset(pad + (c + 1) * cellPx, pad + r * cellPx);
        if (val == 1) {
          canvas.drawLine(p1, p2, activeGlowPaint);
          canvas.drawLine(p1, p2, activeLinePaint);
        } else {
          canvas.drawLine(p1, p2, guidePaint);
          if (val == 2) {
            final mid = Offset((p1.dx + p2.dx) / 2, p1.dy);
            const s = 4.5;
            canvas.drawLine(mid + const Offset(-s, -s), mid + const Offset(s, s), xMarkPaint);
            canvas.drawLine(mid + const Offset(-s, s), mid + const Offset(s, -s), xMarkPaint);
          }
        }
      }
    }

    // 3. Draw vertical edges
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c <= gridSize; c++) {
        final idx = r * (gridSize + 1) + c;
        final val = idx < vEdges.length ? vEdges[idx] : 0;
        final p1 = Offset(pad + c * cellPx, pad + r * cellPx);
        final p2 = Offset(pad + c * cellPx, pad + (r + 1) * cellPx);
        if (val == 1) {
          canvas.drawLine(p1, p2, activeGlowPaint);
          canvas.drawLine(p1, p2, activeLinePaint);
        } else {
          canvas.drawLine(p1, p2, guidePaint);
          if (val == 2) {
            final mid = Offset(p1.dx, (p1.dy + p2.dy) / 2);
            const s = 4.5;
            canvas.drawLine(mid + const Offset(-s, -s), mid + const Offset(s, s), xMarkPaint);
            canvas.drawLine(mid + const Offset(-s, s), mid + const Offset(s, -s), xMarkPaint);
          }
        }
      }
    }

    // 4. Draw vertices
    final vSide = gridSize + 1;
    for (var r = 0; r < vSide; r++) {
      for (var c = 0; c < vSide; c++) {
        final vIdx = r * vSide + c;
        final bad = badVertices.contains(vIdx);
        final pt = Offset(pad + c * cellPx, pad + r * cellPx);
        canvas.drawCircle(
          pt,
          bad ? 5.2 : 3.2,
          Paint()..color = bad ? const Color(0xFFFF5252) : const Color(0xFFECEFF1),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SlitherlinkPainter old) =>
      old.gridSize != gridSize ||
      old.clues != clues ||
      old.hEdges != hEdges ||
      old.vEdges != vEdges ||
      old.badVertices != badVertices;
}
