import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a13_common.dart';

class YajilinBoard extends StatefulWidget {
  final GameContext g;
  const YajilinBoard(this.g, {super.key});
  @override
  State<YajilinBoard> createState() => _YajilinBoardState();
}

class _YajilinBoardState extends State<YajilinBoard> {
  GameContext get g => widget.g;
  bool _shadeMode = false;

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
    List<Map<String, dynamic>?> cluesFlat,
  ) {
    if (!_canPlay) return;
    final pos = details.localPosition;
    final tapR = (pos.dy ~/ cellPx).clamp(0, size - 1);
    final tapC = (pos.dx ~/ cellPx).clamp(0, size - 1);
    final tapIdx = tapR * size + tapC;

    if (_shadeMode) {
      if (tapIdx < cluesFlat.length && cluesFlat[tapIdx] == null) {
        g.act({'type': 'shade', 'r': tapR, 'c': tapC});
      }
      return;
    }

    // Check distance to nearest edge midpoint vs cell center
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

    if (bestR1 >= 0 && bestEdgeDistSq <= (cellPx * 0.58) * (cellPx * 0.58)) {
      final i1 = bestR1 * size + bestC1;
      final i2 = bestR2 * size + bestC2;
      final c1IsClue = i1 < cluesFlat.length && cluesFlat[i1] != null;
      final c2IsClue = i2 < cluesFlat.length && cluesFlat[i2] != null;
      if (!c1IsClue && !c2IsClue) {
        g.act({'type': 'edge', 'r1': bestR1, 'c1': bestC1, 'r2': bestR2, 'c2': bestC2});
        return;
      }
    }

    if (tapIdx < cluesFlat.length && cluesFlat[tapIdx] == null) {
      g.act({'type': 'shade', 'r': tapR, 'c': tapC});
    }
  }

  void _onBoardSecondaryTapUp(
    TapUpDetails details,
    int size,
    double cellPx,
    List<Map<String, dynamic>?> cluesFlat,
  ) {
    if (!_canPlay) return;
    final pos = details.localPosition;
    final tapR = (pos.dy ~/ cellPx).clamp(0, size - 1);
    final tapC = (pos.dx ~/ cellPx).clamp(0, size - 1);
    final tapIdx = tapR * size + tapC;
    if (tapIdx < cluesFlat.length && cluesFlat[tapIdx] == null) {
      g.act({'type': 'shade', 'r': tapR, 'c': tapC});
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
    final board = aInts(v['board']);
    final hSegs = aIntGrid(v['hSegs']);
    final vSegs = aIntGrid(v['vSegs']);
    final rayBlackCounts = aInts(v['rayBlackCounts']);
    final satisfiedClues = aInts(v['satisfiedClues']).toSet();
    final violatedClues = aInts(v['violatedClues']).toSet();
    final adjacentBlacks = aInts(v['adjacentBlacks']).toSet();
    final badDegreeCells = aInts(v['badDegreeCells']).toSet();
    final unvisitedLoopCells = aInts(v['unvisitedLoopCells']).toSet();
    final satisfiedClueCount = aInt(v['satisfiedClueCount'], 0);
    final totalClues = math.max(1, aInt(v['totalClues'], 1));
    final blackCount = aInt(v['blackCount'], 0);
    final activeSegCount = aInt(v['activeSegCount'], 0);
    final isSingleLoop = v['isSingleLoop'] == true;
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '箭头回路竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出箭头回路（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final loopStr = isSingleLoop
          ? '✓ 全白格闭环'
          : (adjacentBlacks.isNotEmpty
              ? '⚠ 黑格相邻'
              : (badDegreeCells.isNotEmpty ? '⚠ 线段分叉/断头' : '连接回路并涂黑方格'));
      status =
          '第 $round/$totalRounds 题（$size×$size）· 箭头 $satisfiedClueCount/$totalClues · 黑格 $blackCount · $loopStr · ${left}s';
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
        board: board,
        hSegs: hSegs,
        vSegs: vSegs,
        rayBlackCounts: rayBlackCounts,
        satisfiedClues: satisfiedClues,
        violatedClues: violatedClues,
        adjacentBlacks: adjacentBlacks,
        badDegreeCells: badDegreeCells,
        unvisitedLoopCells: unvisitedLoopCells,
        satisfiedClueCount: satisfiedClueCount,
        totalClues: totalClues,
        blackCount: blackCount,
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
    final tot = math.max(1, aInt(p['totalClues'], 3));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot箭头', null),
    };
    return A13ProgressTile(
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
    required List<int> board,
    required List<List<int>> hSegs,
    required List<List<int>> vSegs,
    required List<int> rayBlackCounts,
    required Set<int> satisfiedClues,
    required Set<int> violatedClues,
    required Set<int> adjacentBlacks,
    required Set<int> badDegreeCells,
    required Set<int> unvisitedLoopCells,
    required int satisfiedClueCount,
    required int totalClues,
    required int blackCount,
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
        onTapUp: (d) => _onBoardTapUp(d, size, cellPx, cluesFlat),
        onSecondaryTapUp: (d) => _onBoardSecondaryTapUp(d, size, cellPx, cluesFlat),
        child: SizedBox(
          width: boardPx,
          height: boardPx,
          child: CustomPaint(
            painter: _YajilinPainter(
              size: size,
              cellPx: cellPx,
              cluesFlat: cluesFlat,
              board: board,
              hSegs: hSegs,
              vSegs: vSegs,
              rayBlackCounts: rayBlackCounts,
              satisfiedClues: satisfiedClues,
              violatedClues: violatedClues,
              adjacentBlacks: adjacentBlacks,
              badDegreeCells: badDegreeCells,
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
              A13Chip('箭头 $satisfiedClueCount/$totalClues', const Color(0xFF00897B), size: 11),
              A13Chip('黑格 $blackCount · 线 $activeSegCount', cs.primary, size: 11),
              A13Chip(
                isSingleLoop && adjacentBlacks.isEmpty
                    ? '✓ 闭环达标'
                    : (adjacentBlacks.isNotEmpty || badDegreeCells.isNotEmpty ? '⚠ 存在冲突' : '待成闭环'),
                isSingleLoop && adjacentBlacks.isEmpty
                    ? Colors.green
                    : (adjacentBlacks.isNotEmpty || badDegreeCells.isNotEmpty ? Colors.redAccent : Colors.blueGrey),
                size: 11,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('━ 连线模式', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                selected: !_shadeMode,
                onSelected: (_) => setState(() => _shadeMode = false),
              ),
              ChoiceChip(
                label: const Text('■ 涂黑模式', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                selected: _shadeMode,
                onSelected: (_) => setState(() => _shadeMode = true),
              ),
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

class _YajilinPainter extends CustomPainter {
  final int size;
  final double cellPx;
  final List<Map<String, dynamic>?> cluesFlat;
  final List<int> board;
  final List<List<int>> hSegs;
  final List<List<int>> vSegs;
  final List<int> rayBlackCounts;
  final Set<int> satisfiedClues;
  final Set<int> violatedClues;
  final Set<int> adjacentBlacks;
  final Set<int> badDegreeCells;
  final bool isSingleLoop;

  static const List<String> _arrowSymbols = ['↑', '→', '↓', '←'];

  const _YajilinPainter({
    required this.size,
    required this.cellPx,
    required this.cluesFlat,
    required this.board,
    required this.hSegs,
    required this.vSegs,
    required this.rayBlackCounts,
    required this.satisfiedClues,
    required this.violatedClues,
    required this.adjacentBlacks,
    required this.badDegreeCells,
    required this.isSingleLoop,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final borderPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 1. Draw cells (Clue cells, Black cells, or Loop cells)
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final clue = idx < cluesFlat.length ? cluesFlat[idx] : null;
        final val = idx < board.length ? board[idx] : 0;
        final isSat = satisfiedClues.contains(idx);
        final isViol = violatedClues.contains(idx);
        final isAdjBlack = adjacentBlacks.contains(idx);
        final isBadDeg = badDegreeCells.contains(idx);

        final rect = Rect.fromLTWH(
          c * cellPx + 1.5,
          r * cellPx + 1.5,
          cellPx - 3.0,
          cellPx - 3.0,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));

        Color bg;
        if (clue != null) {
          bg = isSat
              ? const Color(0xFFDCFCE7)
              : (isViol ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0));
        } else if (val == 1) {
          bg = isAdjBlack ? const Color(0xFFB71C1C) : const Color(0xFF0F172A);
        } else if (isBadDeg) {
          bg = const Color(0xFFFFEBEE);
        } else {
          bg = const Color(0xFFF8FAFC);
        }

        canvas.drawRRect(rrect, Paint()..color = bg);
        canvas.drawRRect(
          rrect,
          clue != null && isSat
              ? (Paint()
                ..color = const Color(0xFF2E7D32)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0)
              : borderPaint,
        );

        if (clue != null) {
          final dir = aInt(clue['dir'], 0).clamp(0, 3);
          final count = aInt(clue['count'], 0);
          final seen = idx < rayBlackCounts.length ? rayBlackCounts[idx] : 0;
          final arrow = _arrowSymbols[dir];

          final tp = TextPainter(
            text: TextSpan(
              text: '$arrow$count',
              style: TextStyle(
                fontSize: cellPx * 0.36,
                fontWeight: FontWeight.w900,
                color: isSat ? const Color(0xFF1B5E20) : const Color(0xFF0F172A),
                fontFamilyFallback: kFontFallback,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
            canvas,
            Offset(
              (c + 0.5) * cellPx - tp.width / 2,
              (r + 0.46) * cellPx - tp.height / 2,
            ),
          );

          final subTp = TextPainter(
            text: TextSpan(
              text: '$seen/$count',
              style: TextStyle(
                fontSize: cellPx * 0.18,
                fontWeight: FontWeight.w800,
                color: seen == count
                    ? const Color(0xFF2E7D32)
                    : (seen > count ? const Color(0xFFC62828) : const Color(0xFF64748B)),
                fontFamilyFallback: kFontFallback,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          subTp.paint(
            canvas,
            Offset(
              (c + 1) * cellPx - subTp.width - 4,
              (r + 1) * cellPx - subTp.height - 2,
            ),
          );
        } else if (val == 1) {
          final inner = Rect.fromCenter(
            center: Offset((c + 0.5) * cellPx, (r + 0.5) * cellPx),
            width: cellPx * 0.46,
            height: cellPx * 0.46,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(inner, const Radius.circular(4)),
            Paint()..color = isAdjBlack ? const Color(0xFFFFCDD2) : const Color(0xFF334155),
          );
        } else {
          // Subtle center guide dot for loop cells
          canvas.drawCircle(
            Offset((c + 0.5) * cellPx, (r + 0.5) * cellPx),
            2.4,
            Paint()..color = const Color(0xFF94A3B8),
          );
        }
      }
    }

    // 2. Draw active loop segments
    final segColor = isSingleLoop ? const Color(0xFF00897B) : const Color(0xFF0288D1);
    final segPaint = Paint()
      ..color = segColor
      ..strokeWidth = 5.8
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
  }

  @override
  bool shouldRepaint(covariant _YajilinPainter old) => true;
}
