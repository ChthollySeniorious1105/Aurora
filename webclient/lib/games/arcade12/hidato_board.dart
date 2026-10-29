import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a12_common.dart';

class HidatoBoard extends StatefulWidget {
  final GameContext g;
  const HidatoBoard(this.g, {super.key});
  @override
  State<HidatoBoard> createState() => _HidatoBoardState();
}

class _HidatoBoardState extends State<HidatoBoard> {
  GameContext get g => widget.g;
  int _selectedIdx = 0;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _onCellTap(int r, int c, int size, bool isClue, int nextMissing) {
    final idx = r * size + c;
    setState(() => _selectedIdx = idx);
    if (!_canPlay || isClue) return;
    if (nextMissing > 0) {
      g.act({'type': 'set', 'r': r, 'c': c, 'val': nextMissing});
    } else {
      g.act({'type': 'toggle', 'r': r, 'c': c});
    }
  }

  void _onSetVal(int val, int size, List<int> cluesFlat) {
    if (!_canPlay) return;
    final idx = _selectedIdx.clamp(0, size * size - 1);
    if (idx < cluesFlat.length && cluesFlat[idx] > 0) return;
    g.act({'type': 'set', 'r': idx ~/ size, 'c': idx % size, 'val': val});
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = aStr(v['phase']);
    final round = aInt(v['round'], 1);
    final totalRounds = math.max(1, aInt(v['totalRounds'], 3));
    final size = math.max(4, aInt(v['size'], 4));
    final left = aInt(v['left'], 0);
    final cluesFlat = aInts(v['cluesFlat']);
    final board = aInts(v['board']);
    final duplicates = aInts(v['duplicates']).toSet();
    final disconnectedCells = aInts(v['disconnectedCells']).toSet();
    final connectedLinks = aIntGrid(v['connectedLinks']);
    final validLinks = aInt(v['validLinks'], 0);
    final totalLinks = math.max(1, aInt(v['totalLinks'], size * size - 1));
    final filledCount = aInt(v['filledCount'], 0);
    final totalCells = math.max(1, aInt(v['totalCells'], size * size));
    final nextMissing = aInt(v['nextMissing'], 0);
    final ps = aMaps(v['ps']);

    if (_selectedIdx >= size * size) {
      _selectedIdx = 0;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '数链寻路竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出数链寻路（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (duplicates.isNotEmpty) '数字重复',
        if (disconnectedCells.isNotEmpty) '顺位未八向相邻',
      ];
      final warnStr = warnings.isEmpty ? '无冲突' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（1～$totalCells）· 连通段 $validLinks/$totalLinks · 已填 $filledCount/$totalCells · $warnStr · ${left}s';
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
        duplicates: duplicates,
        disconnectedCells: disconnectedCells,
        connectedLinks: connectedLinks,
        validLinks: validLinks,
        totalLinks: totalLinks,
        filledCount: filledCount,
        totalCells: totalCells,
        nextMissing: nextMissing,
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
    final validLinks = aInt(p['validLinks'], 0);
    final totalLinks = math.max(1, aInt(p['totalLinks'], 15));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$validLinks/$totalLinks链', null),
    };
    return A12ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (validLinks / totalLinks),
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
    required List<int> cluesFlat,
    required List<int> board,
    required Set<int> duplicates,
    required Set<int> disconnectedCells,
    required List<List<int>> connectedLinks,
    required int validLinks,
    required int totalLinks,
    required int filledCount,
    required int totalCells,
    required int nextMissing,
    required bool wide,
  }) {
    final cellPx = size <= 4 ? 54.0 : 46.0;
    const cellGap = 4.0;
    final stepPx = cellPx + cellGap;
    final gridSpan = size * stepPx;
    final conflictCells = {...duplicates, ...disconnectedCells};
    final placedVals = board.where((v) => v > 0).toSet();

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141C26),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: SizedBox(
        width: gridSpan,
        height: gridSpan,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _HidatoLinkPainter(
                    size: size,
                    stepPx: stepPx,
                    links: connectedLinks,
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < size; r++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var c = 0; c < size; c++)
                        Padding(
                          padding: const EdgeInsets.all(cellGap / 2),
                          child: _buildCell(
                            r: r,
                            c: c,
                            size: size,
                            cellPx: cellPx,
                            totalCells: totalCells,
                            cluesFlat: cluesFlat,
                            board: board,
                            conflictCells: conflictCells,
                            nextMissing: nextMissing,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    final toolbar = Container(
      constraints: BoxConstraints(maxWidth: wide ? 250 : 350),
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
              A12Chip('连通 $validLinks/$totalLinks', const Color(0xFF00897B), size: 11),
              A12Chip('已填 $filledCount/$totalCells', cs.primary, size: 11),
              A12Chip(
                conflictCells.isEmpty ? '✓ 八向连通正常' : '⚠ 存在断链/重数',
                conflictCells.isEmpty ? Colors.green : Colors.redAccent,
                size: 11,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (var d = 1; d <= totalCells; d++)
                SizedBox(
                  width: 34,
                  height: 30,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: placedVals.contains(d)
                          ? cs.surfaceContainerHighest.withValues(alpha: 0.55)
                          : (d == nextMissing ? cs.primaryContainer : null),
                    ),
                    onPressed: _canPlay ? () => _onSetVal(d, size, cluesFlat) : null,
                    child: Text(
                      '$d',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: placedVals.contains(d) ? cs.onSurface.withValues(alpha: 0.45) : null,
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: 38,
                height: 30,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _canPlay ? () => _onSetVal(0, size, cluesFlat) : null,
                  child: const Icon(Icons.backspace_outlined, size: 15),
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
    required int totalCells,
    required List<int> cluesFlat,
    required List<int> board,
    required Set<int> conflictCells,
    required int nextMissing,
  }) {
    final idx = r * size + c;
    final isClue = idx < cluesFlat.length && cluesFlat[idx] > 0;
    final val = idx < board.length ? board[idx] : 0;
    final isConflict = conflictCells.contains(idx);
    final isSelected = _selectedIdx == idx;
    final isEndpoint = val == 1 || val == totalCells;

    Color bgColor;
    if (isConflict) {
      bgColor = const Color(0xFFFFCDD2);
    } else if (isEndpoint) {
      bgColor = const Color(0xFFFFF8E1);
    } else if (isClue) {
      bgColor = const Color(0xFFCFD8DC);
    } else if (val > 0) {
      bgColor = const Color(0xFFE0F7FA);
    } else {
      bgColor = isSelected ? const Color(0xFF263238) : const Color(0xFF1E293B);
    }

    final borderColor = isConflict
        ? const Color(0xFFE53935)
        : (isSelected
            ? const Color(0xFF00E5FF)
            : (isEndpoint
                ? const Color(0xFFFFB300)
                : (isClue ? const Color(0xFF90A4AE) : const Color(0xFF475569))));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, size, isClue, nextMissing),
      onSecondaryTap: () {
        setState(() => _selectedIdx = idx);
        if (_canPlay && !isClue) {
          g.act({'type': 'set', 'r': r, 'c': c, 'val': 0});
        }
      },
      child: Container(
        width: cellPx,
        height: cellPx,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 2.5 : 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isClue)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isEndpoint ? const Color(0xFFE65100) : const Color(0xFF37474F),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (val > 0)
              Text(
                '$val',
                style: TextStyle(
                  fontSize: cellPx * 0.42,
                  fontWeight: FontWeight.w900,
                  color: isConflict
                      ? const Color(0xFFB71C1C)
                      : (isEndpoint
                          ? const Color(0xFFE65100)
                          : (isClue ? const Color(0xFF1E293B) : const Color(0xFF006064))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HidatoLinkPainter extends CustomPainter {
  final int size;
  final double stepPx;
  final List<List<int>> links;

  const _HidatoLinkPainter({
    required this.size,
    required this.stepPx,
    required this.links,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (links.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0x9900E676)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    for (final pair in links) {
      if (pair.length < 2) continue;
      final a = pair[0], b = pair[1];
      final r1 = a ~/ size, c1 = a % size;
      final r2 = b ~/ size, c2 = b % size;
      final p1 = Offset((c1 + 0.5) * stepPx, (r1 + 0.5) * stepPx);
      final p2 = Offset((c2 + 0.5) * stepPx, (r2 + 0.5) * stepPx);
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HidatoLinkPainter old) =>
      old.size != size || old.stepPx != stepPx || old.links.length != links.length;
}
