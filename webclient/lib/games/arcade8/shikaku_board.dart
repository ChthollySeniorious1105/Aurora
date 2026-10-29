import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a8_common.dart';

class ShikakuBoard extends StatefulWidget {
  final GameContext g;
  const ShikakuBoard(this.g, {super.key});
  @override
  State<ShikakuBoard> createState() => _ShikakuBoardState();
}

class _ShikakuBoardState extends State<ShikakuBoard> {
  GameContext get g => widget.g;
  int _toolMode = 0; // 0 = 框选矩形 (拖拽或两点对角), 1 = 点击拆除
  (int, int)? _anchorCell;
  (int, int)? _hoverCell;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  (int, int) _posToCell(Offset localPos, double cellPx, int size) {
    final c = (localPos.dx ~/ cellPx).clamp(0, size - 1);
    final r = (localPos.dy ~/ cellPx).clamp(0, size - 1);
    return (r, c);
  }

  int _findRectAt(List<Map<String, dynamic>> rects, int r, int c) {
    for (var i = 0; i < rects.length; i++) {
      final rect = rects[i];
      if (r >= aInt(rect['r1']) &&
          r <= aInt(rect['r2']) &&
          c >= aInt(rect['c1']) &&
          c <= aInt(rect['c2'])) {
        return i;
      }
    }
    return -1;
  }

  void _handleCellTap(int r, int c, List<Map<String, dynamic>> rects) {
    if (!_canPlay) return;
    if (_toolMode == 1) {
      final idx = _findRectAt(rects, r, c);
      if (idx >= 0) {
        g.act({'type': 'remove', 'index': idx});
      }
      setState(() {
        _anchorCell = null;
        _hoverCell = null;
      });
      return;
    }

    if (_anchorCell == null) {
      setState(() {
        _anchorCell = (r, c);
        _hoverCell = (r, c);
      });
    } else {
      final (r1, c1) = _anchorCell!;
      setState(() {
        _anchorCell = null;
        _hoverCell = null;
      });
      if (r1 == r && c1 == c) {
        // Clicking the same cell again removes an existing rectangle covering it
        final idx = _findRectAt(rects, r, c);
        if (idx >= 0) {
          g.act({'type': 'remove', 'index': idx});
        }
      } else {
        g.act({
          'type': 'rect',
          'r1': math.min(r1, r),
          'c1': math.min(c1, c),
          'r2': math.max(r1, r),
          'c2': math.max(c1, c),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = aStr(v['phase']);
    final round = aInt(v['round'], 1);
    final totalRounds = math.max(1, aInt(v['totalRounds'], 3));
    final size = math.max(5, aInt(v['size'], 6));
    final left = aInt(v['left'], 0);
    final clues = aInts(v['clues']);
    final rects = aMaps(v['rects']);
    final clueOk = aBools(v['clueOk']);
    final coveredCount = aInt(v['coveredCount'], 0);
    final totalCells = math.max(1, aInt(v['totalCells'], size * size));
    final okRects = aInt(v['okRects'], 0);
    final totalClues = math.max(1, aInt(v['totalClues'], 6));
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '数方分割竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已完成数方分割（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final hint = _anchorCell != null
          ? ' · 已选起点 (${_anchorCell!.$1 + 1},${_anchorCell!.$2 + 1})，请点击对角格'
          : ' · 拖拽或点击两对角画框';
      status =
          '第 $round/$totalRounds 题（$size×$size）· 线索达标 $okRects/$totalClues · 覆盖 $coveredCount/$totalCells$hint · ${left}s';
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
        rects: rects,
        clueOk: clueOk,
        coveredCount: coveredCount,
        totalCells: totalCells,
        okRects: okRects,
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
    final okRects = aInt(p['okRects'], 0);
    final totalClues = math.max(1, aInt(p['totalClues'], 6));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$okRects/$totalClues框', null),
    };
    return A8ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (okRects / totalClues),
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
    required List<Map<String, dynamic>> rects,
    required List<bool> clueOk,
    required int coveredCount,
    required int totalCells,
    required int okRects,
    required int totalClues,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 52.0 : 45.0;
    final sidePx = size * cellPx;

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141E2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF64B5F6).withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final (r, c) = _posToCell(d.localPosition, cellPx, size);
          _handleCellTap(r, c, rects);
        },
        onSecondaryTapUp: (d) {
          if (!_canPlay) return;
          final (r, c) = _posToCell(d.localPosition, cellPx, size);
          final idx = _findRectAt(rects, r, c);
          if (idx >= 0) {
            g.act({'type': 'remove', 'index': idx});
          }
          setState(() {
            _anchorCell = null;
            _hoverCell = null;
          });
        },
        onPanStart: (d) {
          if (!_canPlay || _toolMode != 0) return;
          final cell = _posToCell(d.localPosition, cellPx, size);
          setState(() {
            _anchorCell = cell;
            _hoverCell = cell;
          });
        },
        onPanUpdate: (d) {
          if (!_canPlay || _toolMode != 0 || _anchorCell == null) return;
          final cell = _posToCell(d.localPosition, cellPx, size);
          if (_hoverCell != cell) {
            setState(() => _hoverCell = cell);
          }
        },
        onPanEnd: (_) {
          if (!_canPlay || _toolMode != 0 || _anchorCell == null || _hoverCell == null) return;
          final (r1, c1) = _anchorCell!;
          final (r2, c2) = _hoverCell!;
          setState(() {
            _anchorCell = null;
            _hoverCell = null;
          });
          g.act({
            'type': 'rect',
            'r1': math.min(r1, r2),
            'c1': math.min(c1, c2),
            'r2': math.max(r1, r2),
            'c2': math.max(c1, c2),
          });
        },
        child: SizedBox(
          width: sidePx,
          height: sidePx,
          child: CustomPaint(
            size: Size(sidePx, sidePx),
            painter: _ShikakuPainter(
              gridSize: size,
              cellPx: cellPx,
              clues: clues,
              rects: rects,
              clueOk: clueOk,
              anchorCell: _anchorCell,
              hoverCell: _hoverCell,
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
          A8Chip('线索 $okRects/$totalClues', cs.primary, size: 11),
          A8Chip(
            '覆盖 $coveredCount/$totalCells',
            coveredCount == totalCells ? Colors.teal : Colors.blueGrey,
            size: 11,
          ),
          ChoiceChip(
            label: const Text('📐 框选矩形', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == 0,
            onSelected: (_) => setState(() {
              _toolMode = 0;
              _anchorCell = null;
              _hoverCell = null;
            }),
          ),
          ChoiceChip(
            label: const Text('⌫ 点击拆除', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            selected: _toolMode == 1,
            onSelected: (_) => setState(() {
              _toolMode = 1;
              _anchorCell = null;
              _hoverCell = null;
            }),
          ),
          OutlinedButton.icon(
            onPressed: _canPlay
                ? () {
                    setState(() {
                      _anchorCell = null;
                      _hoverCell = null;
                    });
                    g.act({'type': 'clear'});
                  }
                : null,
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

class _ShikakuPainter extends CustomPainter {
  final int gridSize;
  final double cellPx;
  final List<int> clues;
  final List<Map<String, dynamic>> rects;
  final List<bool> clueOk;
  final (int, int)? anchorCell;
  final (int, int)? hoverCell;

  _ShikakuPainter({
    required this.gridSize,
    required this.cellPx,
    required this.clues,
    required this.rects,
    required this.clueOk,
    required this.anchorCell,
    required this.hoverCell,
  });

  static const List<Color> _palette = [
    Color(0xFF42A5F5),
    Color(0xFF26A69A),
    Color(0xFFAB47BC),
    Color(0xFFFFA726),
    Color(0xFFEC407A),
    Color(0xFF66BB6A),
    Color(0xFF5C6BC0),
    Color(0xFF26C6DA),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw base cells
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final rect = Rect.fromLTWH(c * cellPx + 1.5, r * cellPx + 1.5, cellPx - 3, cellPx - 3);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        canvas.drawRRect(rrect, Paint()..color = const Color(0xFFF3F6F9));
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = const Color(0xFFCFD8DC)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }

    // 2. Draw placed rectangles
    for (var i = 0; i < rects.length; i++) {
      final rm = rects[i];
      final r1 = aInt(rm['r1']), c1 = aInt(rm['c1']);
      final r2 = aInt(rm['r2']), c2 = aInt(rm['c2']);
      final area = aInt(rm['area'], (r2 - r1 + 1) * (c2 - c1 + 1));
      final ok = rm['ok'] == true;
      final baseCol = _palette[i % _palette.length];

      final boxRect = Rect.fromLTWH(
        c1 * cellPx + 2.5,
        r1 * cellPx + 2.5,
        (c2 - c1 + 1) * cellPx - 5,
        (r2 - r1 + 1) * cellPx - 5,
      );
      final rrect = RRect.fromRectAndRadius(boxRect, const Radius.circular(8));

      canvas.drawRRect(
        rrect,
        Paint()
          ..color = ok
              ? baseCol.withValues(alpha: 0.30)
              : const Color(0xFFFF5252).withValues(alpha: 0.24),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = ok ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );

      // Draw small area badge in top-right corner of the rectangle
      final tp = TextPainter(
        text: TextSpan(
          text: ok ? '✓$area' : '$area',
          style: TextStyle(
            fontSize: cellPx * 0.22,
            fontWeight: FontWeight.w800,
            color: ok ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
            fontFamilyFallback: kFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(boxRect.right - tp.width - 4, boxRect.top + 2));
    }

    // 3. Draw active drag / two-tap selection preview
    if (anchorCell != null) {
      final (ar, ac) = anchorCell!;
      final (hr, hc) = hoverCell ?? anchorCell!;
      final r1 = math.min(ar, hr), c1 = math.min(ac, hc);
      final r2 = math.max(ar, hr), c2 = math.max(ac, hc);
      final w = c2 - c1 + 1, h = r2 - r1 + 1;
      final previewRect = Rect.fromLTWH(
        c1 * cellPx + 2.0,
        r1 * cellPx + 2.0,
        w * cellPx - 4,
        h * cellPx - 4,
      );
      final rrect = RRect.fromRectAndRadius(previewRect, const Radius.circular(8));
      canvas.drawRRect(
        rrect,
        Paint()..color = const Color(0xFF29B6F6).withValues(alpha: 0.28),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xFF0288D1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${w * h}',
          style: TextStyle(
            fontSize: cellPx * 0.24,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF01579B),
            fontFamilyFallback: kFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(previewRect.left + 5, previewRect.top + 2));
    }

    // 4. Draw numbered clue circles
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final idx = r * gridSize + c;
        final clue = idx < clues.length ? clues[idx] : 0;
        if (clue <= 0) continue;
        final ok = idx < clueOk.length && clueOk[idx];
        final center = Offset((c + 0.5) * cellPx, (r + 0.5) * cellPx);

        canvas.drawCircle(
          center,
          cellPx * 0.32,
          Paint()..color = ok ? const Color(0xFF2E7D32) : const Color(0xFF263238),
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '$clue',
            style: TextStyle(
              fontSize: cellPx * 0.38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFamilyFallback: kFontFallback,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShikakuPainter old) =>
      old.gridSize != gridSize ||
      old.clues != clues ||
      old.rects != rects ||
      old.clueOk != clueOk ||
      old.anchorCell != anchorCell ||
      old.hoverCell != hoverCell;
}
