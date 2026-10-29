import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a14_common.dart';

class CreekBoard extends StatefulWidget {
  final GameContext g;
  const CreekBoard(this.g, {super.key});
  @override
  State<CreekBoard> createState() => _CreekBoardState();
}

class _CreekBoardState extends State<CreekBoard> {
  GameContext get g => widget.g;
  int _selectedIdx = 0;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _onBoardTapUp(TapUpDetails details, int size, double cellPx, double padPx) {
    final pos = details.localPosition;
    final dx = pos.dx - padPx;
    final dy = pos.dy - padPx;
    if (dx < 0 || dy < 0 || dx >= size * cellPx || dy >= size * cellPx) return;
    final r = (dy ~/ cellPx).clamp(0, size - 1);
    final c = (dx ~/ cellPx).clamp(0, size - 1);
    setState(() => _selectedIdx = r * size + c);
    if (!_canPlay) return;
    g.act({'type': 'toggle', 'r': r, 'c': c});
  }

  void _onBoardSecondaryTapUp(TapUpDetails details, int size, double cellPx, double padPx) {
    final pos = details.localPosition;
    final dx = pos.dx - padPx;
    final dy = pos.dy - padPx;
    if (dx < 0 || dy < 0 || dx >= size * cellPx || dy >= size * cellPx) return;
    final r = (dy ~/ cellPx).clamp(0, size - 1);
    final c = (dx ~/ cellPx).clamp(0, size - 1);
    setState(() => _selectedIdx = r * size + c);
    if (!_canPlay) return;
    g.act({'type': 'set', 'r': r, 'c': c, 'val': 2});
  }

  void _onSetVal(int val, int size) {
    if (!_canPlay) return;
    final idx = _selectedIdx.clamp(0, size * size - 1);
    g.act({'type': 'set', 'r': idx ~/ size, 'c': idx % size, 'val': val});
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
    final vertexCluesFlat = aInts(v['vertexCluesFlat']);
    final board = aInts(v['board']);
    final vertexBlackCounts = aInts(v['vertexBlackCounts']);
    final satisfiedVertices = aInts(v['satisfiedVertices']).toSet();
    final violatedVertices = aInts(v['violatedVertices']).toSet();
    final isolatedWhiteCells = aInts(v['isolatedWhiteCells']).toSet();
    final whiteConnected = v['whiteConnected'] == true;
    final satisfiedClueCount = aInt(v['satisfiedClueCount'], 0);
    final totalClues = math.max(1, aInt(v['totalClues'], 1));
    final blackCount = aInt(v['blackCount'], 0);
    final whiteCount = aInt(v['whiteCount'], 0);
    final ps = aMaps(v['ps']);

    if (_selectedIdx >= size * size) {
      _selectedIdx = 0;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '溪流交点竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出溪流交点（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final creekStr = !whiteConnected
          ? '⚠ 溪流被河岸隔断'
          : (violatedVertices.isNotEmpty ? '⚠ 交点黑格超额' : '✓ 溪流连通');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 交点线索 $satisfiedClueCount/$totalClues · 河岸 $blackCount · $creekStr · ${left}s';
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
        vertexCluesFlat: vertexCluesFlat,
        board: board,
        vertexBlackCounts: vertexBlackCounts,
        satisfiedVertices: satisfiedVertices,
        violatedVertices: violatedVertices,
        isolatedWhiteCells: isolatedWhiteCells,
        whiteConnected: whiteConnected,
        satisfiedClueCount: satisfiedClueCount,
        totalClues: totalClues,
        blackCount: blackCount,
        whiteCount: whiteCount,
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
    final tot = math.max(1, aInt(p['totalClues'], 8));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot点', null),
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
    required List<int> vertexCluesFlat,
    required List<int> board,
    required List<int> vertexBlackCounts,
    required Set<int> satisfiedVertices,
    required Set<int> violatedVertices,
    required Set<int> isolatedWhiteCells,
    required bool whiteConnected,
    required int satisfiedClueCount,
    required int totalClues,
    required int blackCount,
    required int whiteCount,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 48.0 : 42.0;
    final padPx = 16.0;
    final canvasPx = size * cellPx + padPx * 2;

    final gridCard = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF131B24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _onBoardTapUp(d, size, cellPx, padPx),
        onSecondaryTapUp: (d) => _onBoardSecondaryTapUp(d, size, cellPx, padPx),
        child: SizedBox(
          width: canvasPx,
          height: canvasPx,
          child: CustomPaint(
            painter: _CreekPainter(
              size: size,
              cellPx: cellPx,
              padPx: padPx,
              selectedIdx: _selectedIdx,
              vertexCluesFlat: vertexCluesFlat,
              board: board,
              vertexBlackCounts: vertexBlackCounts,
              satisfiedVertices: satisfiedVertices,
              violatedVertices: violatedVertices,
              isolatedWhiteCells: isolatedWhiteCells,
              whiteConnected: whiteConnected,
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
              A14Chip('交点 $satisfiedClueCount/$totalClues', const Color(0xFF00897B), size: 11),
              A14Chip('河岸 $blackCount · 溪流 $whiteCount', cs.primary, size: 11),
              A14Chip(
                whiteConnected && violatedVertices.isEmpty ? '✓ 溪流连通' : '⚠ 溪流断连或超额',
                whiteConnected && violatedVertices.isEmpty ? Colors.green : Colors.redAccent,
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
              SizedBox(
                height: 34,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF263238),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _canPlay ? () => _onSetVal(1, size) : null,
                  child: const Text('■ 涂黑河岸', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
              SizedBox(
                height: 34,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE0F7FA),
                    foregroundColor: const Color(0xFF006064),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _canPlay ? () => _onSetVal(2, size) : null,
                  child: const Text('● 标记溪流', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
              SizedBox(
                width: 44,
                height: 34,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _canPlay ? () => _onSetVal(0, size) : null,
                  child: const Icon(Icons.backspace_outlined, size: 16),
                ),
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
                label: const Text('重置', style: TextStyle(fontSize: 12)),
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

class _CreekPainter extends CustomPainter {
  final int size;
  final double cellPx;
  final double padPx;
  final int selectedIdx;
  final List<int> vertexCluesFlat;
  final List<int> board;
  final List<int> vertexBlackCounts;
  final Set<int> satisfiedVertices;
  final Set<int> violatedVertices;
  final Set<int> isolatedWhiteCells;
  final bool whiteConnected;

  const _CreekPainter({
    required this.size,
    required this.cellPx,
    required this.padPx,
    required this.selectedIdx,
    required this.vertexCluesFlat,
    required this.board,
    required this.vertexBlackCounts,
    required this.satisfiedVertices,
    required this.violatedVertices,
    required this.isolatedWhiteCells,
    required this.whiteConnected,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final borderPaint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // 1. Draw N x N cells
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final val = idx < board.length ? board[idx] : 0;
        final isIsoWhite = isolatedWhiteCells.contains(idx);
        final isSelected = selectedIdx == idx;

        final rect = Rect.fromLTWH(
          padPx + c * cellPx,
          padPx + r * cellPx,
          cellPx,
          cellPx,
        );

        Color bg;
        if (val == 1) {
          bg = const Color(0xFF1E293B);
        } else if (isIsoWhite) {
          bg = const Color(0xFFFFCDD2);
        } else if (isSelected) {
          bg = const Color(0xFFB2EBF2);
        } else {
          bg = const Color(0xFFE0F7FA);
        }

        canvas.drawRect(rect, Paint()..color = bg);
        canvas.drawRect(rect, borderPaint);

        if (val == 1) {
          final inner = Rect.fromCenter(
            center: rect.center,
            width: cellPx * 0.56,
            height: cellPx * 0.56,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(inner, const Radius.circular(5)),
            Paint()..color = const Color(0xFF334155),
          );
        } else if (val == 2) {
          canvas.drawCircle(
            rect.center,
            cellPx * 0.14,
            Paint()..color = const Color(0xFF00838F),
          );
        }
      }
    }

    // 2. Draw (N+1) x (N+1) Vertex Clues on intersections
    final vSize = size + 1;
    final radius = cellPx * 0.25;
    for (var vr = 0; vr <= size; vr++) {
      for (var vc = 0; vc <= size; vc++) {
        final vIdx = vr * vSize + vc;
        final clue = vIdx < vertexCluesFlat.length ? vertexCluesFlat[vIdx] : -1;
        if (clue < 0) continue;

        final isSat = satisfiedVertices.contains(vIdx);
        final isViol = violatedVertices.contains(vIdx);
        final center = Offset(padPx + vc * cellPx, padPx + vr * cellPx);

        final fill = isSat
            ? const Color(0xFFDCFCE7)
            : (isViol ? const Color(0xFFFFEBEE) : Colors.white);
        final ring = isSat
            ? const Color(0xFF2E7D32)
            : (isViol ? const Color(0xFFC62828) : const Color(0xFF0F172A));

        canvas.drawCircle(center, radius, Paint()..color = fill);
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = ring
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );

        final tp = TextPainter(
          text: TextSpan(
            text: '$clue',
            style: TextStyle(
              fontSize: cellPx * 0.28,
              fontWeight: FontWeight.w900,
              color: isSat
                  ? const Color(0xFF1B5E20)
                  : (isViol ? const Color(0xFFC62828) : const Color(0xFF0F172A)),
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
  bool shouldRepaint(covariant _CreekPainter old) => true;
}
