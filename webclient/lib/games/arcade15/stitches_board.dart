import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a15_common.dart';

class StitchesBoard extends StatefulWidget {
  final GameContext g;
  const StitchesBoard(this.g, {super.key});
  @override
  State<StitchesBoard> createState() => _StitchesBoardState();
}

class _StitchesBoardState extends State<StitchesBoard> {
  GameContext get g => widget.g;

  static const List<Color> _regionColors = [
    Color(0xFFFFF8E1), // Soft Amber
    Color(0xFFE3F2FD), // Soft Blue
    Color(0xFFF3E5F5), // Soft Purple
    Color(0xFFE0F2F1), // Soft Teal
    Color(0xFFFFF3E0), // Soft Orange
    Color(0xFFFCE4EC), // Soft Pink
    Color(0xFFF1F8E9), // Soft Lime
    Color(0xFFE8EAF6), // Soft Indigo
    Color(0xFFE0F7FA), // Soft Cyan
  ];

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  int _regAt(List<int> regionMap, int size, int r, int c) {
    if (r < 0 || r >= size || c < 0 || c >= size) return -1;
    final idx = r * size + c;
    return idx < regionMap.length ? regionMap[idx] : -1;
  }

  void _onGridTapUp(
    TapUpDetails details,
    int size,
    double cellPx,
    List<int> regionMap,
  ) {
    if (!_canPlay) return;
    final pos = details.localPosition;

    var bestR1 = -1, bestC1 = -1, bestR2 = -1, bestC2 = -1;
    var bestDistSq = double.infinity;

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        if (_regAt(regionMap, size, r, c) == _regAt(regionMap, size, r, c + 1)) continue;
        final mx = (c + 1.0) * cellPx;
        final my = (r + 0.5) * cellPx;
        final d2 = (pos.dx - mx) * (pos.dx - mx) + (pos.dy - my) * (pos.dy - my);
        if (d2 < bestDistSq) {
          bestDistSq = d2;
          bestR1 = r;
          bestC1 = c;
          bestR2 = r;
          bestC2 = c + 1;
        }
      }
    }

    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        if (_regAt(regionMap, size, r, c) == _regAt(regionMap, size, r + 1, c)) continue;
        final mx = (c + 0.5) * cellPx;
        final my = (r + 1.0) * cellPx;
        final d2 = (pos.dx - mx) * (pos.dx - mx) + (pos.dy - my) * (pos.dy - my);
        if (d2 < bestDistSq) {
          bestDistSq = d2;
          bestR1 = r;
          bestC1 = c;
          bestR2 = r + 1;
          bestC2 = c;
        }
      }
    }

    if (bestR1 >= 0 && bestDistSq <= (cellPx * 0.78) * (cellPx * 0.78)) {
      g.act({'type': 'stitch', 'r1': bestR1, 'c1': bestC1, 'r2': bestR2, 'c2': bestC2});
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
    final regionMap = aInts(v['regionMap']);
    final totalPairs = math.max(1, aInt(v['totalPairs'], 5));
    final rowClues = aInts(v['rowClues']);
    final colClues = aInts(v['colClues']);
    final hStitches = aIntGrid(v['hStitches']);
    final vStitches = aIntGrid(v['vStitches']);
    final satisfiedPairs = aInts(v['satisfiedPairs']).toSet();
    final violatedPairs = aInts(v['violatedPairs']).toSet();
    final cellHoleCounts = aInts(v['cellHoleCounts']);
    final overloadedCells = aInts(v['overloadedCells']).toSet();
    final rowCounts = aInts(v['rowCounts']);
    final colCounts = aInts(v['colCounts']);
    final satisfiedRows = aInts(v['satisfiedRows']).toSet();
    final violatedRows = aInts(v['violatedRows']).toSet();
    final satisfiedCols = aInts(v['satisfiedCols']).toSet();
    final violatedCols = aInts(v['violatedCols']).toSet();
    final satisfiedPairCount = aInt(v['satisfiedPairCount'], 0);
    final activeStitchCount = aInt(v['activeStitchCount'], 0);
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '跨宫缝线竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出跨宫缝线（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (overloadedCells.isNotEmpty) '单格多针孔冲突',
        if (violatedPairs.isNotEmpty) '相邻宫超额缝合',
        if (violatedRows.isNotEmpty || violatedCols.isNotEmpty) '行列针孔超标',
      ];
      final warnStr = warnings.isEmpty ? '点击跨区域边界缝合' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 邻宫缝合 $satisfiedPairCount/$totalPairs · 缝线 $activeStitchCount · $warnStr · ${left}s';
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
        regionMap: regionMap,
        totalPairs: totalPairs,
        rowClues: rowClues,
        colClues: colClues,
        hStitches: hStitches,
        vStitches: vStitches,
        satisfiedPairs: satisfiedPairs,
        violatedPairs: violatedPairs,
        cellHoleCounts: cellHoleCounts,
        overloadedCells: overloadedCells,
        rowCounts: rowCounts,
        colCounts: colCounts,
        satisfiedRows: satisfiedRows,
        violatedRows: violatedRows,
        satisfiedCols: satisfiedCols,
        violatedCols: violatedCols,
        satisfiedPairCount: satisfiedPairCount,
        activeStitchCount: activeStitchCount,
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
    final sat = aInt(p['satisfiedPairs'], 0);
    final tot = math.max(1, aInt(p['totalPairs'], 5));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot针', null),
    };
    return A15ProgressTile(
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
    required List<int> regionMap,
    required int totalPairs,
    required List<int> rowClues,
    required List<int> colClues,
    required List<List<int>> hStitches,
    required List<List<int>> vStitches,
    required Set<int> satisfiedPairs,
    required Set<int> violatedPairs,
    required List<int> cellHoleCounts,
    required Set<int> overloadedCells,
    required List<int> rowCounts,
    required List<int> colCounts,
    required Set<int> satisfiedRows,
    required Set<int> violatedRows,
    required Set<int> satisfiedCols,
    required Set<int> violatedCols,
    required int satisfiedPairCount,
    required int activeStitchCount,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 46.0 : 40.0;
    final headerPx = 34.0;
    final gridSpan = size * cellPx;

    const wallBorder = BorderSide(color: Color(0xFF0F172A), width: 2.8);
    const innerBorder = BorderSide(color: Color(0x55475569), width: 0.7);

    final gridStack = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _onGridTapUp(d, size, cellPx, regionMap),
      child: SizedBox(
        width: gridSpan,
        height: gridSpan,
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < size; r++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var c = 0; c < size; c++)
                        () {
                          final idx = r * size + c;
                          final regId = _regAt(regionMap, size, r, c).clamp(0, 99);
                          final isOver = overloadedCells.contains(idx);
                          final baseBg = _regionColors[regId % _regionColors.length];
                          final bgColor = isOver
                              ? const Color(0xFFFFCDD2)
                              : baseBg;
                          return Container(
                            width: cellPx,
                            height: cellPx,
                            decoration: BoxDecoration(
                              color: bgColor,
                              border: Border(
                                top: _regAt(regionMap, size, r - 1, c) != regId ? wallBorder : innerBorder,
                                bottom: _regAt(regionMap, size, r + 1, c) != regId ? wallBorder : innerBorder,
                                left: _regAt(regionMap, size, r, c - 1) != regId ? wallBorder : innerBorder,
                                right: _regAt(regionMap, size, r, c + 1) != regId ? wallBorder : innerBorder,
                              ),
                            ),
                          );
                        }(),
                    ],
                  ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _StitchesOverlayPainter(
                    size: size,
                    cellPx: cellPx,
                    regionMap: regionMap,
                    hStitches: hStitches,
                    vStitches: vStitches,
                    overloadedCells: overloadedCells,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final boardCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141C26),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top column clues row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: headerPx,
                height: headerPx,
                child: const Center(
                  child: Text('针孔', style: TextStyle(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.bold)),
                ),
              ),
              for (var c = 0; c < size; c++)
                _buildClueHeader(
                  width: cellPx,
                  height: headerPx,
                  cur: c < colCounts.length ? colCounts[c] : 0,
                  target: c < colClues.length ? colClues[c] : 0,
                  isSat: satisfiedCols.contains(c),
                  isViol: violatedCols.contains(c),
                ),
            ],
          ),
          // Left row clues + grid
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = 0; r < size; r++)
                    _buildClueHeader(
                      width: headerPx,
                      height: cellPx,
                      cur: r < rowCounts.length ? rowCounts[r] : 0,
                      target: r < rowClues.length ? rowClues[r] : 0,
                      isSat: satisfiedRows.contains(r),
                      isViol: violatedRows.contains(r),
                    ),
                ],
              ),
              gridStack,
            ],
          ),
        ],
      ),
    );

    final noConflict = overloadedCells.isEmpty &&
        violatedPairs.isEmpty &&
        violatedRows.isEmpty &&
        violatedCols.isEmpty;

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
              A15Chip('邻宫缝合 $satisfiedPairCount/$totalPairs', const Color(0xFF00897B), size: 11),
              A15Chip('行列达标 ${satisfiedRows.length + satisfiedCols.length}/${size * 2}', cs.primary, size: 11),
              A15Chip(
                noConflict
                    ? '✓ 无重孔/超额冲突'
                    : (overloadedCells.isNotEmpty ? '⚠ 单格重孔冲突' : '⚠ 缝线/行列超标'),
                noConflict ? Colors.green : Colors.redAccent,
                size: 11,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '点击不同颜色区域之间的粗黑边界即可缝合/拆线',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
                label: const Text('拆线重置', style: TextStyle(fontSize: 12)),
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

  Widget _buildClueHeader({
    required double width,
    required double height,
    required int cur,
    required int target,
    required bool isSat,
    required bool isViol,
  }) {
    final bg = isViol
        ? const Color(0x44D32F2F)
        : (isSat ? const Color(0x442E7D32) : const Color(0xFF1E293B));
    final fg = isViol
        ? const Color(0xFFFF8A80)
        : (isSat ? const Color(0xFF81C784) : Colors.white);
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: const Color(0x3394A3B8), width: 0.5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$target',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: fg, height: 1.0),
            ),
            Text(
              '$cur/$target',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg.withValues(alpha: 0.75), height: 1.0),
            ),
          ],
        ),
      ),
    );
  }
}

class _StitchesOverlayPainter extends CustomPainter {
  final int size;
  final double cellPx;
  final List<int> regionMap;
  final List<List<int>> hStitches;
  final List<List<int>> vStitches;
  final Set<int> overloadedCells;

  const _StitchesOverlayPainter({
    required this.size,
    required this.cellPx,
    required this.regionMap,
    required this.hStitches,
    required this.vStitches,
    required this.overloadedCells,
  });

  int _regAt(int r, int c) {
    if (r < 0 || r >= size || c < 0 || c >= size) return -1;
    final i = r * size + c;
    return i < regionMap.length ? regionMap[i] : -1;
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final slotPaint = Paint()
      ..color = const Color(0x55334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    // 1. Draw faint candidate stitch slots across region borders
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        if (_regAt(r, c) != _regAt(r, c + 1)) {
          final p1 = Offset((c + 0.72) * cellPx, (r + 0.5) * cellPx);
          final p2 = Offset((c + 1.28) * cellPx, (r + 0.5) * cellPx);
          canvas.drawLine(p1, p2, slotPaint);
          canvas.drawCircle(p1, 2.8, slotPaint);
          canvas.drawCircle(p2, 2.8, slotPaint);
        }
      }
    }
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        if (_regAt(r, c) != _regAt(r + 1, c)) {
          final p1 = Offset((c + 0.5) * cellPx, (r + 0.72) * cellPx);
          final p2 = Offset((c + 0.5) * cellPx, (r + 1.28) * cellPx);
          canvas.drawLine(p1, p2, slotPaint);
          canvas.drawCircle(p1, 2.8, slotPaint);
          canvas.drawCircle(p2, 2.8, slotPaint);
        }
      }
    }

    // 2. Draw active stitches (thread + 2 endpoint holes)
    void drawStitch(Offset p1, Offset p2, bool conflict) {
      final mainColor = conflict ? const Color(0xFFD32F2F) : const Color(0xFF0F172A);
      final accentColor = conflict ? const Color(0xFFFF8A80) : const Color(0xFF00E5FF);

      // Outer shadow/casing
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 6.5
          ..strokeCap = StrokeCap.round,
      );
      // Inner stitch thread
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = mainColor
          ..strokeWidth = 3.8
          ..strokeCap = StrokeCap.round,
      );
      // Endpoint holes
      for (final p in [p1, p2]) {
        canvas.drawCircle(p, 5.2, Paint()..color = mainColor);
        canvas.drawCircle(p, 2.4, Paint()..color = accentColor);
      }
    }

    for (var r = 0; r < size; r++) {
      final row = r < hStitches.length ? hStitches[r] : const <int>[];
      for (var c = 0; c < size - 1; c++) {
        if (c < row.length && row[c] == 1) {
          final p1 = Offset((c + 0.62) * cellPx, (r + 0.5) * cellPx);
          final p2 = Offset((c + 1.38) * cellPx, (r + 0.5) * cellPx);
          final conflict = overloadedCells.contains(r * size + c) ||
              overloadedCells.contains(r * size + c + 1);
          drawStitch(p1, p2, conflict);
        }
      }
    }

    for (var r = 0; r < size - 1; r++) {
      final row = r < vStitches.length ? vStitches[r] : const <int>[];
      for (var c = 0; c < size; c++) {
        if (c < row.length && row[c] == 1) {
          final p1 = Offset((c + 0.5) * cellPx, (r + 0.62) * cellPx);
          final p2 = Offset((c + 0.5) * cellPx, (r + 1.38) * cellPx);
          final conflict = overloadedCells.contains(r * size + c) ||
              overloadedCells.contains((r + 1) * size + c);
          drawStitch(p1, p2, conflict);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StitchesOverlayPainter old) => true;
}
