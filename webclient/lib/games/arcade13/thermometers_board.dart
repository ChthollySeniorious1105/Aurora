import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a13_common.dart';

class ThermometersBoard extends StatefulWidget {
  final GameContext g;
  const ThermometersBoard(this.g, {super.key});
  @override
  State<ThermometersBoard> createState() => _ThermometersBoardState();
}

class _ThermometersBoardState extends State<ThermometersBoard> {
  GameContext get g => widget.g;
  bool _fillToMode = true;

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
    List<int> board,
    List<int> thermoIdMap,
    List<int> thermoPosMap,
    List<List<List<int>>> thermos,
  ) {
    if (!_canPlay) return;
    final pos = details.localPosition;
    final r = (pos.dy ~/ cellPx).clamp(0, size - 1);
    final c = (pos.dx ~/ cellPx).clamp(0, size - 1);
    final idx = r * size + c;

    if (!_fillToMode) {
      g.act({'type': 'toggle', 'r': r, 'c': c});
      return;
    }

    // In fill_to mode, if (r, c) is already the exact filled tip of its thermometer,
    // toggle (r, c) off so players can also reduce or clear the bulb by tapping.
    if (idx < thermoIdMap.length && idx < thermoPosMap.length) {
      final tId = thermoIdMap[idx];
      final tPos = thermoPosMap[idx];
      if (tId >= 0 && tId < thermos.length) {
        final cells = thermos[tId];
        var isExactTip = true;
        for (var k = 0; k < cells.length; k++) {
          final cIdx = cells[k][0] * size + cells[k][1];
          final filled = cIdx < board.length && board[cIdx] == 1;
          if ((k <= tPos) != filled) {
            isExactTip = false;
            break;
          }
        }
        if (isExactTip) {
          g.act({'type': 'toggle', 'r': r, 'c': c});
          return;
        }
      }
    }

    g.act({'type': 'fill_to', 'r': r, 'c': c});
  }

  void _onBoardSecondaryTapUp(TapUpDetails details, int size, double cellPx) {
    if (!_canPlay) return;
    final pos = details.localPosition;
    final r = (pos.dy ~/ cellPx).clamp(0, size - 1);
    final c = (pos.dx ~/ cellPx).clamp(0, size - 1);
    g.act({'type': 'toggle', 'r': r, 'c': c});
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

    final rawThermos = v['thermos'];
    final thermos = <List<List<int>>>[
      if (rawThermos is List)
        for (final t in rawThermos)
          if (t is List)
            [
              for (final rc in t)
                if (rc is List && rc.length >= 2) [aInt(rc[0], 0), aInt(rc[1], 0)],
            ],
    ];
    final thermoIdMap = aInts(v['thermoIdMap']);
    final thermoPosMap = aInts(v['thermoPosMap']);
    final rowClues = aInts(v['rowClues']);
    final colClues = aInts(v['colClues']);
    final board = aInts(v['board']);
    final rowCounts = aInts(v['rowCounts']);
    final colCounts = aInts(v['colCounts']);
    final satisfiedRows = aInts(v['satisfiedRows']).toSet();
    final violatedRows = aInts(v['violatedRows']).toSet();
    final satisfiedCols = aInts(v['satisfiedCols']).toSet();
    final violatedCols = aInts(v['violatedCols']).toSet();
    final brokenThermos = aInts(v['brokenThermos']).toSet();
    final gapCells = aInts(v['gapCells']).toSet();
    final satisfiedLines = aInt(v['satisfiedLines'], 0);
    final totalLines = math.max(1, aInt(v['totalLines'], size * 2));
    final filledCount = aInt(v['filledCount'], 0);
    final totalTargetFilled = aInt(v['totalTargetFilled'], 0);
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '温度计填充竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出温度计谜题（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (brokenThermos.isNotEmpty) '水银断层(需从球端连续填充)',
        if (violatedRows.isNotEmpty || violatedCols.isNotEmpty) '行列水银超额',
      ];
      final warnStr = warnings.isEmpty ? '水银连续正常' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 行列达标 $satisfiedLines/$totalLines · 水银 $filledCount/$totalTargetFilled · $warnStr · ${left}s';
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
        thermos: thermos,
        thermoIdMap: thermoIdMap,
        thermoPosMap: thermoPosMap,
        rowClues: rowClues,
        colClues: colClues,
        board: board,
        rowCounts: rowCounts,
        colCounts: colCounts,
        satisfiedRows: satisfiedRows,
        violatedRows: violatedRows,
        satisfiedCols: satisfiedCols,
        violatedCols: violatedCols,
        brokenThermos: brokenThermos,
        gapCells: gapCells,
        satisfiedLines: satisfiedLines,
        totalLines: totalLines,
        filledCount: filledCount,
        totalTargetFilled: totalTargetFilled,
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
    final sat = aInt(p['satisfiedLines'], 0);
    final tot = math.max(1, aInt(p['totalLines'], 10));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot行列', null),
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
    required List<List<List<int>>> thermos,
    required List<int> thermoIdMap,
    required List<int> thermoPosMap,
    required List<int> rowClues,
    required List<int> colClues,
    required List<int> board,
    required List<int> rowCounts,
    required List<int> colCounts,
    required Set<int> satisfiedRows,
    required Set<int> violatedRows,
    required Set<int> satisfiedCols,
    required Set<int> violatedCols,
    required Set<int> brokenThermos,
    required Set<int> gapCells,
    required int satisfiedLines,
    required int totalLines,
    required int filledCount,
    required int totalTargetFilled,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 46.0 : 40.0;
    final headerPx = 34.0;
    final boardPx = size * cellPx;

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF131B24),
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
                  child: Text('🌡️', style: TextStyle(fontSize: 16)),
                ),
              ),
              for (var c = 0; c < size; c++)
                _buildClueBadge(
                  width: cellPx,
                  height: headerPx,
                  clue: c < colClues.length ? colClues[c] : 0,
                  cur: c < colCounts.length ? colCounts[c] : 0,
                  sat: satisfiedCols.contains(c),
                  viol: violatedCols.contains(c),
                ),
            ],
          ),
          // Row clues + main thermometer canvas
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = 0; r < size; r++)
                    _buildClueBadge(
                      width: headerPx,
                      height: cellPx,
                      clue: r < rowClues.length ? rowClues[r] : 0,
                      cur: r < rowCounts.length ? rowCounts[r] : 0,
                      sat: satisfiedRows.contains(r),
                      viol: violatedRows.contains(r),
                    ),
                ],
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onBoardTapUp(
                  d,
                  size,
                  cellPx,
                  board,
                  thermoIdMap,
                  thermoPosMap,
                  thermos,
                ),
                onSecondaryTapUp: (d) => _onBoardSecondaryTapUp(d, size, cellPx),
                child: SizedBox(
                  width: boardPx,
                  height: boardPx,
                  child: CustomPaint(
                    painter: _ThermometersPainter(
                      size: size,
                      cellPx: cellPx,
                      thermos: thermos,
                      board: board,
                      brokenThermos: brokenThermos,
                      gapCells: gapCells,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
              A13Chip('行列 $satisfiedLines/$totalLines', const Color(0xFF00897B), size: 11),
              A13Chip('水银 $filledCount/$totalTargetFilled', const Color(0xFFD32F2F), size: 11),
              A13Chip(
                brokenThermos.isEmpty && violatedRows.isEmpty && violatedCols.isEmpty
                    ? '✓ 连续无断层'
                    : '⚠ 断层或超额',
                brokenThermos.isEmpty && violatedRows.isEmpty && violatedCols.isEmpty
                    ? Colors.green
                    : Colors.redAccent,
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
                label: const Text('🌡️ 直填至此处', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                selected: _fillToMode,
                onSelected: (_) => setState(() => _fillToMode = true),
              ),
              ChoiceChip(
                label: const Text('● 单格切换', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                selected: !_fillToMode,
                onSelected: (_) => setState(() => _fillToMode = false),
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

  Widget _buildClueBadge({
    required double width,
    required double height,
    required int clue,
    required int cur,
    required bool sat,
    required bool viol,
  }) {
    final bg = viol
        ? const Color(0xFFB71C1C)
        : (sat ? const Color(0xFF1B5E20) : const Color(0xFF1E293B));
    final border = viol
        ? const Color(0xFFFF5252)
        : (sat ? const Color(0xFF66BB6A) : const Color(0xFF475569));
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: border, width: 1.2),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$clue',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$cur/$clue',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: sat ? const Color(0xFFA5D6A7) : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThermometersPainter extends CustomPainter {
  final int size;
  final double cellPx;
  final List<List<List<int>>> thermos;
  final List<int> board;
  final Set<int> brokenThermos;
  final Set<int> gapCells;

  const _ThermometersPainter({
    required this.size,
    required this.cellPx,
    required this.thermos,
    required this.board,
    required this.brokenThermos,
    required this.gapCells,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final cellBgPaint = Paint()..color = const Color(0xFFF8FAFC);
    final gapBgPaint = Paint()..color = const Color(0xFFFFEBEE);
    final gridBorderPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Draw cell backgrounds
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final rect = Rect.fromLTWH(
          c * cellPx + 1.0,
          r * cellPx + 1.0,
          cellPx - 2.0,
          cellPx - 2.0,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        canvas.drawRRect(
          rrect,
          gapCells.contains(idx) ? gapBgPaint : cellBgPaint,
        );
        canvas.drawRRect(rrect, gridBorderPaint);
      }
    }

    // 2. Draw each Thermometer (outer casing + inner empty channel + mercury fill)
    final outerTubeWidth = cellPx * 0.50;
    final innerTubeWidth = cellPx * 0.36;
    final bulbOuterR = cellPx * 0.35;
    final bulbInnerR = cellPx * 0.28;

    for (var t = 0; t < thermos.length; t++) {
      final cells = thermos[t];
      if (cells.isEmpty) continue;
      final isBroken = brokenThermos.contains(t);

      final pts = <Offset>[
        for (final rc in cells) Offset((rc[1] + 0.5) * cellPx, (rc[0] + 0.5) * cellPx),
      ];

      final casingColor = isBroken ? const Color(0xFFC62828) : const Color(0xFF334155);
      final casingLinePaint = Paint()
        ..color = casingColor
        ..strokeWidth = outerTubeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final emptyChannelPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = innerTubeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var k = 1; k < pts.length; k++) {
        path.lineTo(pts[k].dx, pts[k].dy);
      }

      // Outer casing + bulb outer circle
      canvas.drawPath(path, casingLinePaint);
      canvas.drawCircle(pts.first, bulbOuterR, Paint()..color = casingColor);

      // Inner empty glass channel + bulb inner circle
      canvas.drawPath(path, emptyChannelPaint);
      canvas.drawCircle(pts.first, bulbInnerR, Paint()..color = const Color(0xFFE2E8F0));

      // Draw mercury in filled cells and connecting segments between consecutive filled cells
      final mercuryColor = isBroken ? const Color(0xFFFF6D00) : const Color(0xFFE53935);
      final mercuryLinePaint = Paint()
        ..color = mercuryColor
        ..strokeWidth = innerTubeWidth * 0.86
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (var k = 0; k < cells.length; k++) {
        final idx = cells[k][0] * size + cells[k][1];
        final filled = idx < board.length && board[idx] == 1;
        if (!filled) continue;

        if (k == 0) {
          canvas.drawCircle(pts[0], bulbInnerR * 0.90, Paint()..color = mercuryColor);
        } else {
          canvas.drawCircle(pts[k], innerTubeWidth * 0.43, Paint()..color = mercuryColor);
        }

        if (k + 1 < cells.length) {
          final nextIdx = cells[k + 1][0] * size + cells[k + 1][1];
          final nextFilled = nextIdx < board.length && board[nextIdx] == 1;
          if (nextFilled) {
            canvas.drawLine(pts[k], pts[k + 1], mercuryLinePaint);
          }
        }
      }

      // Draw a crisp bulb ring highlight at index 0 so the bulb is always obvious
      canvas.drawCircle(
        pts.first,
        bulbInnerR * 0.42,
        Paint()
          ..color = (cells.first[0] * size + cells.first[1] < board.length &&
                  board[cells.first[0] * size + cells.first[1]] == 1)
              ? Colors.white.withValues(alpha: 0.75)
              : const Color(0xFF64748B).withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThermometersPainter old) => true;
}
