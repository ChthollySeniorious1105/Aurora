import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a10_common.dart';

class MasyuBoard extends StatefulWidget {
  final GameContext g;
  const MasyuBoard(this.g, {super.key});
  @override
  State<MasyuBoard> createState() => _MasyuBoardState();
}

class _MasyuBoardState extends State<MasyuBoard> {
  GameContext get g => widget.g;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _onBoardTapUp(TapUpDetails details, int size, double cellPx) {
    if (!_canPlay) return;
    final pos = details.localPosition;
    String? bestDir;
    var bestR = -1;
    var bestC = -1;
    var bestDistSq = double.infinity;

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        final mx = (c + 1.0) * cellPx;
        final my = (r + 0.5) * cellPx;
        final d2 = (pos.dx - mx) * (pos.dx - mx) + (pos.dy - my) * (pos.dy - my);
        if (d2 < bestDistSq) {
          bestDistSq = d2;
          bestDir = 'h';
          bestR = r;
          bestC = c;
        }
      }
    }

    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        final mx = (c + 0.5) * cellPx;
        final my = (r + 1.0) * cellPx;
        final d2 = (pos.dx - mx) * (pos.dx - mx) + (pos.dy - my) * (pos.dy - my);
        if (d2 < bestDistSq) {
          bestDistSq = d2;
          bestDir = 'v';
          bestR = r;
          bestC = c;
        }
      }
    }

    if (bestDir != null && bestDistSq <= (cellPx * 0.72) * (cellPx * 0.72)) {
      g.act({'type': 'seg', 'dir': bestDir, 'r': bestR, 'c': bestC});
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
    final pearlsFlat = aInts(v['pearlsFlat']);
    final hSegs = aIntGrid(v['hSegs']);
    final vSegs = aIntGrid(v['vSegs']);
    final activeSegCount = aInt(v['activeSegCount'], 0);
    final badDegreeCells = aInts(v['badDegreeCells']).toSet();
    final satisfiedPearlCells = aInts(v['satisfiedPearlCells']).toSet();
    final violatedPearlCells = aInts(v['violatedPearlCells']).toSet();
    final totalPearls = math.max(1, aInt(v['totalPearls'], 1));
    final satisfiedPearls = aInt(v['satisfiedPearls'], 0);
    final isSingleLoop = v['isSingleLoop'] == true;
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '黑白珍珠回路竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已连通黑白珍珠回路（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final loopStr = isSingleLoop
          ? '✓ 单一闭环'
          : (badDegreeCells.isNotEmpty ? '⚠ 存在断头/分叉' : '点击相邻格之间连线');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 达标珍珠 $satisfiedPearls/$totalPearls · $loopStr · ${left}s';
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
        pearlsFlat: pearlsFlat,
        hSegs: hSegs,
        vSegs: vSegs,
        activeSegCount: activeSegCount,
        badDegreeCells: badDegreeCells,
        satisfiedPearlCells: satisfiedPearlCells,
        violatedPearlCells: violatedPearlCells,
        satisfiedPearls: satisfiedPearls,
        totalPearls: totalPearls,
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
    final sat = aInt(p['satisfiedPearls'], 0);
    final tot = math.max(1, aInt(p['totalPearls'], 5));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot珠', null),
    };
    return A10ProgressTile(
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
    required List<int> pearlsFlat,
    required List<List<int>> hSegs,
    required List<List<int>> vSegs,
    required int activeSegCount,
    required Set<int> badDegreeCells,
    required Set<int> satisfiedPearlCells,
    required Set<int> violatedPearlCells,
    required int satisfiedPearls,
    required int totalPearls,
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
            painter: _MasyuPainter(
              size: size,
              cellPx: cellPx,
              pearlsFlat: pearlsFlat,
              hSegs: hSegs,
              vSegs: vSegs,
              badDegreeCells: badDegreeCells,
              satisfiedPearlCells: satisfiedPearlCells,
              violatedPearlCells: violatedPearlCells,
              isSingleLoop: isSingleLoop,
            ),
          ),
        ),
      ),
    );

    final toolbar = Container(
      constraints: BoxConstraints(maxWidth: wide ? 230 : 340),
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
              A10Chip('珍珠 $satisfiedPearls/$totalPearls', const Color(0xFF00897B), size: 11),
              A10Chip('线段 $activeSegCount', cs.primary, size: 11),
              A10Chip(
                isSingleLoop
                    ? '✓ 单一闭环'
                    : (violatedPearlCells.isNotEmpty ? '⚠ 珍珠规则冲突' : '待成闭环'),
                isSingleLoop
                    ? Colors.green
                    : (violatedPearlCells.isNotEmpty ? Colors.redAccent : Colors.blueGrey),
                size: 11,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('○ 白珍珠：直行通过 + 至少一邻转弯', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text('● 黑珍珠：本格转弯 + 两侧邻格直行', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
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

class _MasyuPainter extends CustomPainter {
  final int size;
  final double cellPx;
  final List<int> pearlsFlat;
  final List<List<int>> hSegs;
  final List<List<int>> vSegs;
  final Set<int> badDegreeCells;
  final Set<int> satisfiedPearlCells;
  final Set<int> violatedPearlCells;
  final bool isSingleLoop;

  const _MasyuPainter({
    required this.size,
    required this.cellPx,
    required this.pearlsFlat,
    required this.hSegs,
    required this.vSegs,
    required this.badDegreeCells,
    required this.satisfiedPearlCells,
    required this.violatedPearlCells,
    required this.isSingleLoop,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final cellBgPaint = Paint()..color = const Color(0xFFF8FAFC);
    final cellBadBgPaint = Paint()..color = const Color(0xFFFFEBEE);
    final borderPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 1. Draw cells
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final rect = Rect.fromLTWH(
          c * cellPx + 1.5,
          r * cellPx + 1.5,
          cellPx - 3.0,
          cellPx - 3.0,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));
        canvas.drawRRect(
          rrect,
          badDegreeCells.contains(idx) || violatedPearlCells.contains(idx)
              ? cellBadBgPaint
              : cellBgPaint,
        );
        canvas.drawRRect(rrect, borderPaint);
      }
    }

    // 2. Draw subtle segment guide dots between adjacent cell centers
    final guidePaint = Paint()..color = const Color(0xFF94A3B8);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final cx = (c + 0.5) * cellPx;
        final cy = (r + 0.5) * cellPx;
        canvas.drawCircle(Offset(cx, cy), 2.5, guidePaint);
      }
    }

    // 3. Draw active loop segments
    final segColor = isSingleLoop ? const Color(0xFF00897B) : const Color(0xFF0288D1);
    final segPaint = Paint()
      ..color = segColor
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    for (var r = 0; r < size; r++) {
      final row = r < hSegs.length ? hSegs[r] : const <int>[];
      for (var c = 0; c < size - 1; c++) {
        if (c < row.length && row[c] == 1) {
          final p1 = Offset((c + 0.5) * cellPx, (r + 0.5) * cellPx);
          final p2 = Offset((c + 1.5) * cellPx, (r + 0.5) * cellPx);
          canvas.drawLine(p1, p2, segPaint);
        }
      }
    }

    for (var r = 0; r < size - 1; r++) {
      final row = r < vSegs.length ? vSegs[r] : const <int>[];
      for (var c = 0; c < size; c++) {
        if (c < row.length && row[c] == 1) {
          final p1 = Offset((c + 0.5) * cellPx, (r + 0.5) * cellPx);
          final p2 = Offset((c + 0.5) * cellPx, (r + 1.5) * cellPx);
          canvas.drawLine(p1, p2, segPaint);
        }
      }
    }

    // 4. Draw White Pearls (1) and Black Pearls (2)
    final pearlRadius = cellPx * 0.28;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final pType = idx < pearlsFlat.length ? pearlsFlat[idx] : 0;
        if (pType == 0) continue;

        final center = Offset((c + 0.5) * cellPx, (r + 0.5) * cellPx);
        final isSat = satisfiedPearlCells.contains(idx);
        final isViol = violatedPearlCells.contains(idx);

        final ringColor = isViol
            ? const Color(0xFFD32F2F)
            : (isSat ? const Color(0xFF2E7D32) : const Color(0xFF1E293B));

        if (pType == 1) {
          // White Pearl (○)
          canvas.drawCircle(
            center,
            pearlRadius,
            Paint()..color = Colors.white,
          );
          canvas.drawCircle(
            center,
            pearlRadius,
            Paint()
              ..color = ringColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = isSat || isViol ? 3.4 : 2.6,
          );
        } else if (pType == 2) {
          // Black Pearl (●)
          canvas.drawCircle(
            center,
            pearlRadius,
            Paint()..color = const Color(0xFF0F172A),
          );
          canvas.drawCircle(
            center,
            pearlRadius,
            Paint()
              ..color = isViol
                  ? const Color(0xFFFF1744)
                  : (isSat ? const Color(0xFF00E676) : const Color(0xFF94A3B8))
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MasyuPainter old) => true;
}
