import 'dart:math';

import 'package:aurora_shared/games/abstract7/dvonn.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

class _DvonnPainter extends CustomPainter {
  final String layout;
  final List<(int, int)> coords;
  final List<int> top;
  final List<int> height;
  final List<bool> hasDvonn;
  final String phase;
  final Set<int> mobileCells;
  final int selFrom;
  final Set<int> moveTargets;
  final int hover;
  final int lastFrom;
  final int lastTo;
  final Set<int> lastCollapsed;
  final Color accent;

  _DvonnPainter({
    required this.layout,
    required this.coords,
    required this.top,
    required this.height,
    required this.hasDvonn,
    required this.phase,
    required this.mobileCells,
    required this.selFrom,
    required this.moveTargets,
    required this.hover,
    required this.lastFrom,
    required this.lastTo,
    required this.lastCollapsed,
    required this.accent,
  });

  static double _spacing(Size s, String layout) {
    if (layout == 'compact') {
      return min(s.width, s.height) / 7.6;
    }
    return min(s.width / 11.4, s.height / 5.4);
  }

  static Offset cellCenter(Size s, String layout, List<(int, int)> coords, int idx) {
    final (q, r) = coords[idx];
    final sp = _spacing(s, layout);
    final cx = s.width / 2 + sp * (q + r * 0.5);
    final cy = s.height / 2 + sp * (r * 0.8660254);
    return Offset(cx, cy);
  }

  static int hit(Size s, String layout, List<(int, int)> coords, Offset o) {
    if (s.width <= 0 || s.height <= 0) return -1;
    final sp = _spacing(s, layout);
    final maxDist2 = (sp * 0.48) * (sp * 0.48);
    var bestIdx = -1;
    var bestD2 = maxDist2;
    for (var i = 0; i < coords.length; i++) {
      final c = cellCenter(s, layout, coords, i);
      final dx = o.dx - c.dx, dy = o.dy - c.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 <= bestD2) {
        bestD2 = d2;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sp = _spacing(size, layout);
    final center = Offset(size.width / 2, size.height / 2);

    // Draw board frame polygon
    final framePath = Path();
    if (layout == 'compact') {
      final outerR = sp * 3.72;
      for (var k = 0; k < 6; k++) {
        final angle = k * pi / 3;
        final pt = center + Offset(outerR * cos(angle), outerR * sin(angle));
        if (k == 0) {
          framePath.moveTo(pt.dx, pt.dy);
        } else {
          framePath.lineTo(pt.dx, pt.dy);
        }
      }
      framePath.close();
    } else {
      // Elongated 6-vertex hexagon around the 5x(9..11) grid
      final wHalf = sp * 5.65;
      final wShoulder = sp * 4.55;
      final hHalf = sp * 2.42;
      final pts = [
        center + Offset(-wShoulder, -hHalf),
        center + Offset(wShoulder, -hHalf),
        center + Offset(wHalf, 0),
        center + Offset(wShoulder, hHalf),
        center + Offset(-wShoulder, hHalf),
        center + Offset(-wHalf, 0),
      ];
      framePath.moveTo(pts.first.dx, pts.first.dy);
      for (var k = 1; k < pts.length; k++) {
        framePath.lineTo(pts[k].dx, pts[k].dy);
      }
      framePath.close();
    }

    canvas.drawPath(framePath.shift(Offset(0, sp * 0.08)), a7Shadow(sp * 0.2, alpha: 0.45));
    canvas.drawPath(
      framePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B2320), Color(0xFF1A1412), Color(0xFF110D0C)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      framePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.0, sp * 0.08)
        ..color = const Color(0xFFBCAAA4).withValues(alpha: 0.55),
    );

    // Draw grid edges between adjacent hexes
    final edgePaint = Paint()
      ..color = const Color(0xFF8D6E63).withValues(alpha: 0.36)
      ..strokeWidth = max(1.0, sp * 0.035);
    const halfDirs = [(1, 0), (0, 1), (1, -1)];
    for (var i = 0; i < coords.length; i++) {
      final (q, r) = coords[i];
      final p0 = cellCenter(size, layout, coords, i);
      for (final (dq, dr) in halfDirs) {
        final j = dvonnIndexFor(layout, q + dq, r + dr);
        if (j != -1) {
          final p1 = cellCenter(size, layout, coords, j);
          canvas.drawLine(p0, p1, edgePaint);
        }
      }
    }

    // Last move line
    if (lastFrom >= 0 && lastTo >= 0 && lastFrom < coords.length && lastTo < coords.length) {
      final p0 = cellCenter(size, layout, coords, lastFrom);
      final p1 = cellCenter(size, layout, coords, lastTo);
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = const Color(0xAA42A5F5)
          ..strokeWidth = max(2.0, sp * 0.095)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Draw board sockets & highlights
    for (var i = 0; i < coords.length; i++) {
      final c = cellCenter(size, layout, coords, i);
      canvas.drawCircle(c, sp * 0.10, Paint()..color = const Color(0xFF5D4037));
      canvas.drawCircle(c, sp * 0.05, Paint()..color = const Color(0xFFD7CCC8));

      if (i == lastFrom || i == lastTo) {
        canvas.drawCircle(c, sp * 0.43, Paint()..color = const Color(0x4442A5F5));
      }
      if (lastCollapsed.contains(i)) {
        canvas.drawCircle(
          c,
          sp * 0.38,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.6, sp * 0.06)
            ..color = const Color(0xCCEF5350),
        );
      }
    }

    // Draw stacks
    for (var i = 0; i < coords.length; i++) {
      final h = height[i];
      if (h <= 0) continue;
      final c = cellCenter(size, layout, coords, i);
      _paintStack(
        canvas,
        c,
        sp,
        owner: top[i],
        h: h,
        dvonnInside: hasDvonn[i],
        mobile: mobileCells.contains(i),
        selected: i == selFrom,
      );
    }

    // Draw legal targets or setup hover
    if (phase == 'place') {
      if (hover >= 0 && hover < coords.length && height[hover] == 0) {
        final c = cellCenter(size, layout, coords, hover);
        canvas.drawCircle(
          c,
          sp * 0.36,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.0, sp * 0.085)
            ..color = accent.withValues(alpha: 0.85),
        );
      }
    } else {
      for (final t in moveTargets) {
        final c = cellCenter(size, layout, coords, t);
        final isHover = t == hover;
        canvas.drawCircle(
          c,
          sp * (isHover ? 0.45 : 0.42),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.2, sp * (isHover ? 0.095 : 0.075))
            ..color = const Color(0xFF66BB6A),
        );
      }
    }
  }

  void _paintStack(
    Canvas canvas,
    Offset c,
    double sp, {
    required int owner,
    required int h,
    required bool dvonnInside,
    required bool mobile,
    required bool selected,
  }) {
    final outerR = sp * 0.39;
    canvas.drawCircle(c + Offset(sp * 0.03, sp * 0.05), outerR, a7Shadow(sp * 0.14, alpha: 0.48));

    List<Color> gradColors;
    Color rimColor;
    Color textColor;
    if (owner == 2) {
      // Unclaimed Red DVONN piece
      gradColors = const [Color(0xFFFF8A80), Color(0xFFE53935), Color(0xFF8E0000)];
      rimColor = const Color(0xFFFFCDD2);
      textColor = Colors.white;
    } else if (owner == 0) {
      // White stack
      gradColors = const [Color(0xFFFFFFFF), Color(0xFFECEFF1), Color(0xFFB0BEC5)];
      rimColor = const Color(0xFF546E7A);
      textColor = const Color(0xFF263238);
    } else {
      // Black stack
      gradColors = const [Color(0xFF546E7A), Color(0xFF263238), Color(0xFF0D1317)];
      rimColor = const Color(0xFFB0BEC5);
      textColor = const Color(0xFFECEFF1);
    }

    // Main piece body
    canvas.drawCircle(
      c,
      outerR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: gradColors,
          stops: const [0.0, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: outerR)),
    );

    // Outer border (gold if selected, cyan/amber glow if mobile, otherwise normal rim)
    canvas.drawCircle(
      c,
      outerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.4, sp * (selected ? 0.075 : (mobile ? 0.05 : 0.032)))
        ..color = selected
            ? const Color(0xFFFFD54F)
            : (mobile ? const Color(0xFF29B6F6) : rimColor.withValues(alpha: 0.75)),
    );

    // Inner ring: crimson ring if stack contains a Red DVONN lifeline piece!
    canvas.drawCircle(
      c,
      outerR * 0.64,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.3, sp * (dvonnInside ? 0.065 : 0.032))
        ..color = dvonnInside ? const Color(0xFFE53935) : rimColor.withValues(alpha: 0.45),
    );

    final label = owner == 2 ? (h > 1 ? 'D$h' : 'D') : '$h';
    a7PaintTextCentered(
      canvas,
      label,
      c,
      sp * (label.length > 1 ? 0.25 : 0.29),
      textColor,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DvonnBoardView extends StatefulWidget {
  final GameContext g;
  const DvonnBoardView(this.g, {super.key});
  @override
  State<DvonnBoardView> createState() => _DvonnBoardViewState();
}

class _DvonnBoardViewState extends State<DvonnBoardView> {
  int selFrom = -1;
  int hover = -1;
  Object? _lastPlies;

  GameContext get g => widget.g;

  int _occupiedNeighbors(List<(int, int)> coords, String layout, List<int> height, int idx) {
    final (q, r) = coords[idx];
    var cnt = 0;
    for (final (dq, dr) in dvonnDirs) {
      final nIdx = dvonnIndexFor(layout, q + dq, r + dr);
      if (nIdx != -1 && height[nIdx] > 0) cnt++;
    }
    return cnt;
  }

  List<int> _legalTargets(
    List<(int, int)> coords,
    String layout,
    List<int> top,
    List<int> height,
    int from,
  ) {
    if (from < 0 || from >= coords.length || height[from] <= 0) return const [];
    if (top[from] != 0 && top[from] != 1) return const [];
    if (_occupiedNeighbors(coords, layout, height, from) >= 6) return const [];
    final h = height[from];
    final (q0, r0) = coords[from];
    final out = <int>[];
    for (final (dq, dr) in dvonnDirs) {
      final tIdx = dvonnIndexFor(layout, q0 + dq * h, r0 + dr * h);
      if (tIdx != -1 && height[tIdx] > 0) out.add(tIdx);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    if (_lastPlies != v['plies']) {
      _lastPlies = v['plies'];
      selFrom = -1;
    }

    final layout = (v['layout'] as String?) ?? 'standard';
    final coords = dvonnCoordsFor(layout);
    final phase = (v['phase'] as String?) ?? 'stack';
    final placedCount = (v['placedCount'] as int?) ?? coords.length;
    final top = (v['top'] as List).cast<int>();
    final height = (v['height'] as List).cast<int>();
    final hasDvonn = (v['hasDvonn'] as List).cast<bool>();
    final turn = v['turn'] as int;
    final scores = ((v['scores'] as List?) ?? const [0, 0]).cast<int>();
    final stacks = ((v['stacks'] as List?) ?? const [0, 0]).cast<int>();
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;

    final lastFrom = (last?['from'] as int?) ?? (last?['cell'] as int?) ?? -1;
    final lastTo = (last?['to'] as int?) ?? -1;
    final lastCollapsed = ((last?['collapsed'] as List?) ?? const []).cast<int>().toSet();

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final mobileCells = <int>{};
    if (!over && phase == 'stack') {
      for (var i = 0; i < coords.length; i++) {
        if (top[i] == turn && height[i] > 0 && _legalTargets(coords, layout, top, height, i).isNotEmpty) {
          mobileCells.add(i);
        }
      }
    }

    final moveTargets = <int>{};
    if (myTurn && phase == 'stack' && selFrom >= 0 && selFrom < coords.length && top[selFrom] == turn) {
      moveTargets.addAll(_legalTargets(coords, layout, top, height, selFrom));
    }

    void tapCell(int c) {
      if (!myTurn || c < 0 || c >= coords.length) return;
      if (phase == 'place') {
        if (height[c] == 0) {
          g.act({'type': 'place', 'cell': c});
        }
        return;
      }
      if (selFrom >= 0 && moveTargets.contains(c)) {
        final f = selFrom;
        setState(() => selFrom = -1);
        g.act({'type': 'move', 'from': f, 'to': c});
        return;
      }
      if (top[c] == turn && height[c] > 0 && _occupiedNeighbors(coords, layout, height, c) < 6) {
        setState(() => selFrom = selFrom == c ? -1 : c);
      }
    }

    final sideName = turn == 0 ? '白方' : '黑方';
    String status;
    if (over) {
      status = result;
    } else if (myTurn) {
      if (phase == 'place') {
        final pLabel = placedCount < 3 ? '红源棋子(D)' : (turn == 0 ? '白子' : '黑子');
        status = '轮到你（$sideName）布子：请点击空位放置$pLabel（$placedCount/${coords.length}）';
      } else if (selFrom < 0) {
        status = '轮到你（$sideName）：请点选外围或未六面围死的己方棋垛（蓝圈高亮）';
      } else {
        status = '已选 ${dvonnCellLabel(layout, selFrom)}（高 ${height[selFrom]}）：点击绿圈目标沿直线跳 ${height[selFrom]} 步合并';
      }
    } else {
      status = '等待 ${g.name(turn)}（$sideName）${phase == 'place' ? '放置棋子' : '移动棋垛'}';
    }

    final actions = <Widget>[];
    if (myTurn && selFrom >= 0) {
      actions.add(a7Button(
        context,
        '取消选择',
        Icons.clear,
        () => setState(() => selFrom = -1),
      ));
    }

    final aspect = layout == 'compact' ? 1.0 : 1.75;
    final boardWidget = LayoutBuilder(builder: (context, c) {
      final bSize = Size(c.maxWidth, c.maxHeight);
      return Center(
        child: MouseRegion(
          onHover: (e) {
            final p = _DvonnPainter.hit(bSize, layout, coords, e.localPosition);
            if (p != hover) setState(() => hover = p);
          },
          onExit: (_) => setState(() => hover = -1),
          child: GestureDetector(
            onTapUp: (d) => tapCell(_DvonnPainter.hit(bSize, layout, coords, d.localPosition)),
            child: CustomPaint(
              size: bSize,
              painter: _DvonnPainter(
                layout: layout,
                coords: coords,
                top: top,
                height: height,
                hasDvonn: hasDvonn,
                phase: phase,
                mobileCells: mobileCells,
                selFrom: selFrom,
                moveTargets: moveTargets,
                hover: hover,
                lastFrom: lastFrom,
                lastTo: lastTo,
                lastCollapsed: lastCollapsed,
                accent: cs.primary,
              ),
            ),
          ),
        ),
      );
    });

    Widget tagFor(int s) {
      final sLabel = s == 0 ? '白方' : '黑方';
      final sc = scores[s];
      final st = stacks[s];
      final stateLabel = over
          ? (winner == s ? ' · 胜($sc子)' : (winner == 2 ? ' · 和($sc子)' : ' · 负($sc子)'))
          : ' · 控子 $sc · 棋垛 $st';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sLabel$stateLabel',
        trailing: Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: s == 0 ? const Color(0xFFECEFF1) : const Color(0xFF263238),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE53935),
              width: 2.2,
            ),
          ),
        ),
      );
    }

    return A7Shell(
      tags: [for (var s = 0; s < g.players; s++) tagFor(s)],
      status: status,
      statusHighlight: myTurn,
      aspect: aspect,
      board: boardWidget,
      actions: actions,
      info: [
        if (note.isNotEmpty) '动态：$note',
        '规则：未被六面围死的己方棋垛可沿直线精确跳跃【高度】步落入有子格；任何与红源(D/红内圈)断连的棋群将立即坍塌移除！',
      ],
      result: a7Banner(g, over, winner, g.players),
      resultSub: over ? result : null,
    );
  }
}
