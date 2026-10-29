import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a17_common.dart';

class ShakashakaBoard extends StatefulWidget {
  final GameContext g;
  const ShakashakaBoard(this.g, {super.key});
  @override
  State<ShakashakaBoard> createState() => _ShakashakaBoardState();
}

class _ShakashakaBoardState extends State<ShakashakaBoard> {
  GameContext get g => widget.g;
  int _selectedIdx = 0;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  bool _isBlackClue(List<int> clues, int idx) => idx >= 0 && idx < clues.length && clues[idx] >= -1;

  void _onCellTap(int r, int c, int size, List<int> clues) {
    final idx = r * size + c;
    setState(() => _selectedIdx = idx);
    if (!_canPlay) return;
    if (_isBlackClue(clues, idx)) return;
    g.act({'type': 'cycle', 'r': r, 'c': c});
  }

  void _onSetVal(int val, int size, List<int> clues) {
    if (!_canPlay) return;
    final idx = _selectedIdx.clamp(0, size * size - 1);
    if (_isBlackClue(clues, idx)) return;
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
    final clues = aInts(v['clues']);
    final board = aInts(v['board']);
    final satisfiedClueCells = aInts(v['satisfiedClueCells']).toSet();
    final violatedClueCells = aInts(v['violatedClueCells']).toSet();
    final satisfiedClueCount = aInt(v['satisfiedClueCount'], 0);
    final totalNumberedClues = math.max(1, aInt(v['totalNumberedClues'], 1));
    final whiteRegionCount = aInt(v['whiteRegionCount'], 0);
    final validRectRegionCount = aInt(v['validRectRegionCount'], 0);
    final nonRectCells = aInts(v['nonRectCells']).toSet();
    final triangleCount = aInt(v['triangleCount'], 0);
    final ps = aMaps(v['ps']);

    if (_selectedIdx >= size * size) {
      _selectedIdx = 0;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '数间直角三角竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出直角三角（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (violatedClueCells.isNotEmpty) '黑格邻接三角超额',
        if (nonRectCells.isNotEmpty) '存在非矩形白色区域',
      ];
      final warnStr = warnings.isEmpty ? '点击白格切换 ◤ ◥ ◣ ◢ 直角三角形' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 线索 $satisfiedClueCount/$totalNumberedClues · 矩形白区 $validRectRegionCount/$whiteRegionCount · $warnStr · ${left}s';
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
        clues: clues,
        board: board,
        satisfiedClueCells: satisfiedClueCells,
        violatedClueCells: violatedClueCells,
        satisfiedClueCount: satisfiedClueCount,
        totalNumberedClues: totalNumberedClues,
        whiteRegionCount: whiteRegionCount,
        validRectRegionCount: validRectRegionCount,
        nonRectCells: nonRectCells,
        triangleCount: triangleCount,
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
    final sat = aInt(p['satisfiedClueCount'], 0);
    final tot = math.max(1, aInt(p['totalNumberedClues'], 1));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot线索', null),
    };
    return A17ProgressTile(
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
    required List<int> clues,
    required List<int> board,
    required Set<int> satisfiedClueCells,
    required Set<int> violatedClueCells,
    required int satisfiedClueCount,
    required int totalNumberedClues,
    required int whiteRegionCount,
    required int validRectRegionCount,
    required Set<int> nonRectCells,
    required int triangleCount,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 50.0 : 44.0;
    final allRectOk = whiteRegionCount > 0 && validRectRegionCount == whiteRegionCount && nonRectCells.isEmpty;

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < size; r++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < size; c++)
                  _buildCell(
                    r: r,
                    c: c,
                    size: size,
                    cellPx: cellPx,
                    clues: clues,
                    board: board,
                    satisfiedClueCells: satisfiedClueCells,
                    violatedClueCells: violatedClueCells,
                    nonRectCells: nonRectCells,
                  ),
              ],
            ),
        ],
      ),
    );

    final toolbar = Container(
      constraints: BoxConstraints(maxWidth: wide ? 245 : 345),
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
              A17Chip('线索 $satisfiedClueCount/$totalNumberedClues', const Color(0xFF37474F), size: 11),
              A17Chip('三角 $triangleCount', cs.primary, size: 11),
              A17Chip(
                allRectOk ? '✓ 全为正交/斜矩形' : '白区矩形 $validRectRegionCount/$whiteRegionCount',
                allRectOk ? Colors.green : Colors.orange.shade800,
                size: 11,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            alignment: WrapAlignment.center,
            children: [
              for (final (val, label) in const [
                (1, '◤ 左上'),
                (2, '◥ 右上'),
                (3, '◣ 左下'),
                (4, '◢ 右下'),
                (0, '□ 留白'),
              ])
                SizedBox(
                  height: 32,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: val == 0 ? const Color(0xFFECEFF1) : const Color(0xFF1E293B),
                      foregroundColor: val == 0 ? const Color(0xFF1E293B) : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: _canPlay ? () => _onSetVal(val, size, clues) : null,
                    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
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

  Widget _buildCell({
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required List<int> clues,
    required List<int> board,
    required Set<int> satisfiedClueCells,
    required Set<int> violatedClueCells,
    required Set<int> nonRectCells,
  }) {
    final idx = r * size + c;
    final clue = idx < clues.length ? clues[idx] : -2;
    final isBlack = clue >= -1;
    final val = idx < board.length ? board[idx] : 0;
    final isSelected = _selectedIdx == idx;
    final isNonRect = nonRectCells.contains(idx);

    if (isBlack) {
      final isSat = satisfiedClueCells.contains(idx);
      final isViol = violatedClueCells.contains(idx);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selectedIdx = idx),
        child: Container(
          width: cellPx,
          height: cellPx,
          decoration: BoxDecoration(
            color: isViol ? const Color(0xFF7F1D1D) : const Color(0xFF0F172A),
            border: Border.all(color: const Color(0xFF334155), width: 0.9),
          ),
          alignment: Alignment.center,
          child: clue >= 0
              ? Text(
                  '$clue',
                  style: TextStyle(
                    fontSize: cellPx * 0.44,
                    fontWeight: FontWeight.w900,
                    color: isViol
                        ? const Color(0xFFFCA5A5)
                        : (isSat ? const Color(0xFF4ADE80) : Colors.white),
                  ),
                )
              : null,
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, size, clues),
      onSecondaryTap: () {
        setState(() => _selectedIdx = idx);
        if (_canPlay) {
          g.act({'type': 'set', 'r': r, 'c': c, 'val': 0});
        }
      },
      child: Container(
        width: cellPx,
        height: cellPx,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE0F2FE)
              : (isNonRect ? const Color(0xFFFFF1F2) : Colors.white),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.8 : 0.7,
          ),
        ),
        child: CustomPaint(
          painter: _ShakashakaTrianglePainter(
            val: val,
            triangleColor: isNonRect ? const Color(0xFFBE123C) : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}

class _ShakashakaTrianglePainter extends CustomPainter {
  final int val;
  final Color triangleColor;

  const _ShakashakaTrianglePainter({
    required this.val,
    required this.triangleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (val < 1 || val > 4) return;
    final paint = Paint()
      ..color = triangleColor
      ..style = PaintingStyle.fill;

    final w = size.width, h = size.height;
    final path = Path();
    switch (val) {
      case 1: // ◤ Top-Left black triangle
        path
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(0, h)
          ..close();
      case 2: // ◥ Top-Right black triangle
        path
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h)
          ..close();
      case 3: // ◣ Bottom-Left black triangle
        path
          ..moveTo(0, 0)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
      case 4: // ◢ Bottom-Right black triangle
        path
          ..moveTo(w, 0)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ShakashakaTrianglePainter oldDelegate) =>
      oldDelegate.val != val || oldDelegate.triangleColor != triangleColor;
}
