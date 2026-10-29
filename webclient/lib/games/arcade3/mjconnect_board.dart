import 'dart:math' as math;

import 'package:aurora_shared/games/arcade3/mjconnect.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a3_common.dart';

class MjConnectBoard extends StatefulWidget {
  final GameContext g;
  const MjConnectBoard(this.g, {super.key});
  @override
  State<MjConnectBoard> createState() => _MjConnectBoardState();
}

class _MjConnectBoardState extends State<MjConnectBoard> {
  GameContext get g => widget.g;
  int _localSel = -1;
  bool _showHint = false;

  bool get _canPlay {
    final ps = aMaps(g.view['ps']);
    if (g.over || g.seat < 0 || g.seat >= ps.length) return false;
    final me = ps[g.seat];
    return me['out'] != true && me['done'] != true;
  }

  void _onTapCell(int idx, List<int> grid, int w, int h) {
    if (!_canPlay || idx < 0 || idx >= grid.length || grid[idx] == 0) return;
    setState(() => _showHint = false);
    final curSel = _localSel >= 0 && _localSel < grid.length && grid[_localSel] != 0
        ? _localSel
        : aInt(g.view['sel'], -1);
    if (curSel < 0 || curSel >= grid.length || grid[curSel] == 0) {
      setState(() => _localSel = idx);
      return;
    }
    if (curSel == idx) {
      setState(() => _localSel = -1);
      return;
    }
    if (grid[curSel] == grid[idx] && MjConnectSolver.findPath(grid, w, h, curSel, idx) != null) {
      setState(() => _localSel = -1);
      g.act({'type': 'pair', 'a': curSel, 'b': idx});
    } else {
      setState(() => _localSel = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = aStr(v['phase']);
    final w = math.max(1, aInt(v['w'], 6));
    final h = math.max(1, aInt(v['h'], 6));
    final sec = aInt(v['sec'], 0);
    final totalPairs = math.max(1, aInt(v['totalPairs'], 18));
    final grid = aInts(v['g']);
    final ps = aMaps(v['ps']);
    final shufflesLeft = aInt(v['shufflesLeft'], 0);
    final hint = aInts(v['hint']);
    final lastPair = aInts(v['lastPair']);
    final rawPath = v['lastPath'] is List ? v['lastPath'] as List : const [];
    final lastPath = <(int, int)>[
      for (final pt in rawPath)
        if (pt is List && pt.length >= 2) (aInt(pt[0]), aInt(pt[1])),
    ];

    if (_localSel >= grid.length || (_localSel >= 0 && grid[_localSel] == 0)) {
      _localSel = -1;
    }
    final activeSel = _localSel >= 0 ? _localSel : aInt(v['sel'], -1);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myCleared = me != null ? aInt(me['cleared'], 0) : 0;
    final myScore = me != null ? aInt(me['score'], 0) : 0;

    String status;
    if (phase == 'over') {
      status = '游戏结束';
    } else if (me == null) {
      status = '观战中 · 用时 ${mmss(sec)}';
    } else if (me['out'] == true) {
      status = '你已认输 · 用时 ${mmss(sec)}';
    } else if (me['done'] == true) {
      status = '你已清空棋盘！得分 $myScore';
    } else {
      status = '点击两张相同麻将牌（≤2次转弯连通即可消除）· 已消 $myCleared/$totalPairs 对 · 积分 $myScore · ${mmss(sec)}';
    }

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > box.maxHeight * 1.15;
      final sideW = wide ? math.min(185.0, box.maxWidth * 0.23) : 0.0;
      final ctrlW = wide ? math.min(150.0, box.maxWidth * 0.19) : 0.0;
      final topStripH = wide ? 0.0 : 58.0;
      final bottomBarH = wide ? 0.0 : 52.0;

      // Board includes a 1-cell border margin on all 4 sides -> (w + 1.2) x (h + 1.2) units
      final unitsW = w + 1.2;
      final unitsH = h + 1.2;
      final availW = box.maxWidth - sideW - ctrlW - 16;
      final availH = box.maxHeight - 44 - topStripH - bottomBarH - 8;
      final cellSize = math.max(12.0, math.min(availW / unitsW, availH / unitsH));
      final boardW = cellSize * unitsW;
      final boardH = cellSize * unitsH;
      final pad = cellSize * 0.6;

      final progressList = Wrap(
        direction: wide ? Axis.vertical : Axis.horizontal,
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final s in g.seatsFromMe())
            if (s < ps.length)
              A3ProgressTile(
                g,
                s,
                width: wide ? sideW - 12 : 140,
                pct: aInt(ps[s]['cleared'], 0) / totalPairs,
                badge: ps[s]['done'] == true
                    ? '清空'
                    : (ps[s]['out'] == true ? '认输' : '${ps[s]['cleared']}/$totalPairs'),
                badgeColor: ps[s]['done'] == true
                    ? Colors.green
                    : (ps[s]['out'] == true ? Colors.redAccent : cs.primary),
                dim: ps[s]['out'] == true,
                sub: '积分 ${ps[s]['score']} · 已消 ${ps[s]['cleared']} 对',
              ),
        ],
      );

      final boardWidget = SizedBox(
        width: boardW,
        height: boardH,
        child: GestureDetector(
          onTapUp: (d) {
            final gx = ((d.localPosition.dx - pad) / cellSize).floor();
            final gy = ((d.localPosition.dy - pad) / cellSize).floor();
            if (gx >= 0 && gx < w && gy >= 0 && gy < h) {
              _onTapCell(gy * w + gx, grid, w, h);
            }
          },
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _MjConnectPainter(
                w: w,
                h: h,
                pad: pad,
                cellSize: cellSize,
                grid: grid,
                sel: activeSel,
                hint: _showHint ? hint : const [],
                lastPair: lastPair,
                lastPath: lastPath,
                accent: cs.primary,
              ),
            ),
          ),
        ),
      );

      final controls = FittedBox(
        fit: BoxFit.scaleDown,
        child: Flex(
          direction: wide ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonalIcon(
              onPressed: _canPlay && shufflesLeft > 0
                  ? () {
                      setState(() {
                        _localSel = -1;
                        _showHint = false;
                      });
                      g.act({'type': 'shuffle'});
                    }
                  : null,
              icon: const Icon(Icons.shuffle, size: 18),
              label: Text('洗牌 ($shufflesLeft)'),
            ),
            SizedBox(width: wide ? 0 : 12, height: wide ? 12 : 0),
            OutlinedButton.icon(
              onPressed: _canPlay && hint.length >= 2
                  ? () => setState(() => _showHint = !_showHint)
                  : null,
              icon: const Icon(Icons.lightbulb_outline, size: 18),
              label: const Text('提示'),
            ),
          ],
        ),
      );

      Widget body;
      if (wide) {
        body = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            width: sideW,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(4),
                child: FittedBox(fit: BoxFit.scaleDown, child: progressList),
              ),
            ),
          ),
          Expanded(child: Center(child: boardWidget)),
          SizedBox(width: ctrlW, child: Center(child: controls)),
        ]);
      } else {
        body = Column(children: [
          SizedBox(
            height: topStripH,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: progressList),
              ),
            ),
          ),
          Expanded(child: Center(child: boardWidget)),
          SizedBox(height: bottomBarH, child: Center(child: controls)),
        ]);
      }

      return Column(children: [
        SizedBox(height: 40, child: aStatus(status, highlight: _canPlay)),
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
                    (r) => '消除 ${r['cleared']}/${r['total']} 对 · 积分 ${r['score']}',
                  ),
                ),
              ),
          ]),
        ),
      ]);
    });
  }
}

class _MjConnectPainter extends CustomPainter {
  final int w, h, sel;
  final double pad, cellSize;
  final List<int> grid;
  final List<int> hint;
  final List<int> lastPair;
  final List<(int, int)> lastPath;
  final Color accent;

  _MjConnectPainter({
    required this.w,
    required this.h,
    required this.pad,
    required this.cellSize,
    required this.grid,
    required this.sel,
    required this.hint,
    required this.lastPair,
    required this.lastPath,
    required this.accent,
  });

  static const _tileColors = [
    Colors.black87,
    Color(0xFFC62828), // 1 一万
    Color(0xFFC62828), // 2 二万
    Color(0xFFC62828), // 3 三万
    Color(0xFFC62828), // 4 四万
    Color(0xFFC62828), // 5 五万
    Color(0xFFC62828), // 6 六万
    Color(0xFFC62828), // 7 七万
    Color(0xFFC62828), // 8 八万
    Color(0xFF1565C0), // 9 东
    Color(0xFF1565C0), // 10 南
    Color(0xFF1565C0), // 11 西
    Color(0xFF1565C0), // 12 北
    Color(0xFFD32F2F), // 13 中
    Color(0xFF2E7D32), // 14 发
    Color(0xFF37474F), // 15 白
    Color(0xFF6A1B9A), // 16 春
  ];

  static const _tileSub = [
    '',
    '萬', '萬', '萬', '萬', '萬', '萬', '萬', '萬',
    '風', '風', '風', '風', '箭', '箭', '箭', '花',
  ];

  Offset _cellCenter(int gx, int gy) {
    final x = gx < 0
        ? pad * 0.45
        : (gx >= w ? pad + w * cellSize + pad * 0.55 : pad + (gx + 0.5) * cellSize);
    final y = gy < 0
        ? pad * 0.45
        : (gy >= h ? pad + h * cellSize + pad * 0.55 : pad + (gy + 0.5) * cellSize);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Felt board container
    final boardRect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    canvas.drawRRect(boardRect, Paint()..color = const Color(0xFF143D30).withValues(alpha: 0.85));
    canvas.drawRRect(
      boardRect,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 2. Empty slot dots
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.12);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        canvas.drawCircle(_cellCenter(x, y), cellSize * 0.06, dotPaint);
      }
    }

    // 3. Last eliminated connection path
    if (lastPath.length >= 2) {
      final path = Path();
      final p0 = _cellCenter(lastPath[0].$1, lastPath[0].$2);
      path.moveTo(p0.dx, p0.dy);
      for (var i = 1; i < lastPath.length; i++) {
        final pi = _cellCenter(lastPath[i].$1, lastPath[i].$2);
        path.lineTo(pi.dx, pi.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = math.max(3, cellSize * 0.14),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFEE58)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = math.max(1.5, cellSize * 0.06),
      );
    }

    // 4. Mahjong tiles
    for (var i = 0; i < grid.length && i < w * h; i++) {
      final v = grid[i];
      if (v <= 0) continue;
      final gx = i % w, gy = i ~/ w;
      final rect = Rect.fromLTWH(pad + gx * cellSize, pad + gy * cellSize, cellSize, cellSize).deflate(cellSize * 0.06);
      final isSelected = i == sel;
      final isHinted = hint.contains(i);

      final tileRect = isSelected ? rect.shift(Offset(0, -cellSize * 0.06)) : rect;
      final rrect = RRect.fromRectAndRadius(tileRect, Radius.circular(cellSize * 0.14));

      // 3D bamboo/green backing shadow
      canvas.drawRRect(
        rrect.shift(Offset(0, cellSize * 0.06)),
        Paint()..color = const Color(0xFF1B5E20),
      );

      // Ivory tile face
      canvas.drawRRect(
        rrect,
        Paint()..color = isSelected ? const Color(0xFFFFF8E1) : const Color(0xFFFFFDF7),
      );

      // Border highlight for selected or hinted tile
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (isSelected || isHinted) ? math.max(2, cellSize * 0.07) : 1
          ..color = isSelected
              ? const Color(0xFFFF8F00)
              : (isHinted ? const Color(0xFF00E676) : const Color(0xFFB0BEC5)),
      );

      final sym = v < MjConnectSolver.symbols.length ? MjConnectSolver.symbols[v] : '$v';
      final col = v < _tileColors.length ? _tileColors[v] : Colors.black87;
      final sub = v < _tileSub.length ? _tileSub[v] : '';

      // Top-left mini category badge
      if (sub.isNotEmpty) {
        _drawText(
          canvas,
          sub,
          tileRect.topLeft + Offset(cellSize * 0.16, cellSize * 0.15),
          cellSize * 0.16,
          col.withValues(alpha: 0.65),
          false,
        );
      }

      // Main glyph
      _drawText(
        canvas,
        sym,
        tileRect.center + Offset(0, cellSize * 0.04),
        sym.length >= 2 ? cellSize * 0.32 : cellSize * 0.42,
        col,
        true,
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, double fontSize, Color color, bool bold) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
          fontFamilyFallback: kFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_MjConnectPainter oldDelegate) => true;
}
