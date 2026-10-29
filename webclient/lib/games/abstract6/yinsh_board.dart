import 'dart:math';

import 'package:aurora_shared/games/abstract6/yinsh.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

class _YinshPainter extends CustomPainter {
  final List<int> board;
  final String phase;
  final int selFrom;
  final Set<int> moveTargets;
  final int hover;
  final int lastFrom;
  final int lastTo;
  final Set<int> lastFlipped;
  final Set<int> lastScored;
  final Color accent;

  _YinshPainter({
    required this.board,
    required this.phase,
    required this.selFrom,
    required this.moveTargets,
    required this.hover,
    required this.lastFrom,
    required this.lastTo,
    required this.lastFlipped,
    required this.lastScored,
    required this.accent,
  });

  static double _spacing(Size s) => min(s.width, s.height) / 9.8;

  static Offset cellCenter(Size s, int idx) {
    final (q, r) = yinshCoords[idx];
    final sp = _spacing(s);
    final cx = s.width / 2 + sp * (q + r * 0.5);
    final cy = s.height / 2 + sp * (r * 0.8660254);
    return Offset(cx, cy);
  }

  static int hit(Size s, Offset o) {
    if (s.width <= 0 || s.height <= 0) return -1;
    final sp = _spacing(s);
    final maxDist2 = (sp * 0.48) * (sp * 0.48);
    var bestIdx = -1;
    var bestD2 = maxDist2;
    for (var i = 0; i < yinshCoords.length; i++) {
      final c = cellCenter(s, i);
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
    final sp = _spacing(size);
    final center = Offset(size.width / 2, size.height / 2);

    // Outer hexagonal star-board medallion
    final outerPath = Path();
    final outerR = sp * 4.72;
    for (var k = 0; k < 6; k++) {
      final angle = k * pi / 3;
      final pt = center + Offset(outerR * cos(angle), outerR * sin(angle));
      if (k == 0) {
        outerPath.moveTo(pt.dx, pt.dy);
      } else {
        outerPath.lineTo(pt.dx, pt.dy);
      }
    }
    outerPath.close();

    canvas.drawPath(outerPath.shift(Offset(0, sp * 0.08)), a6Shadow(sp * 0.2, alpha: 0.45));
    canvas.drawPath(
      outerPath,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF28354A), Color(0xFF162030), Color(0xFF0D131D)],
          stops: [0.0, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: outerR)),
    );
    canvas.drawPath(
      outerPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.0, sp * 0.08)
        ..color = const Color(0xFF90A4AE).withValues(alpha: 0.55),
    );

    // Draw grid lines along the 3 hex axes
    final linePaint = Paint()
      ..color = const Color(0xFF90A4AE).withValues(alpha: 0.35)
      ..strokeWidth = max(1.1, sp * 0.035);
    for (final line in yinshLines) {
      final p0 = cellCenter(size, line.first);
      final p1 = cellCenter(size, line.last);
      canvas.drawLine(p0, p1, linePaint);
    }
    // Also draw the corner edge lines of length 5 (included in yinshLines)

    // Last move line
    if (lastFrom >= 0 && lastTo >= 0 && lastFrom < board.length && lastTo < board.length) {
      final p0 = cellCenter(size, lastFrom);
      final p1 = cellCenter(size, lastTo);
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = const Color(0x9942A5F5)
          ..strokeWidth = max(2.0, sp * 0.09)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Draw intersection nodes & highlights
    for (var i = 0; i < board.length; i++) {
      final c = cellCenter(size, i);
      // Node socket
      canvas.drawCircle(c, sp * 0.11, Paint()..color = const Color(0xFF546E7A));
      canvas.drawCircle(c, sp * 0.06, Paint()..color = const Color(0xFFCFD8DC));

      if (i == lastFrom || i == lastTo) {
        canvas.drawCircle(c, sp * 0.42, Paint()..color = const Color(0x4442A5F5));
      }
      if (lastFlipped.contains(i)) {
        canvas.drawCircle(
          c,
          sp * 0.43,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.6, sp * 0.055)
            ..color = const Color(0xFFFFB300),
        );
      }
      if (lastScored.contains(i)) {
        canvas.drawCircle(c, sp * 0.40, Paint()..color = const Color(0x5566BB6A));
      }
    }

    // Draw Markers & Rings
    for (var i = 0; i < board.length; i++) {
      final v = board[i];
      if (v < 0) continue;
      final c = cellCenter(size, i);
      if (Yinsh.isMarker(v)) {
        _paintMarker(canvas, c, sp, v);
      } else if (Yinsh.isRing(v)) {
        _paintRing(canvas, c, sp, v - 2, selected: i == selFrom);
      }
    }

    // Draw legal targets / setup hover
    if (phase == 'setup') {
      if (hover >= 0 && hover < board.length && board[hover] == -1) {
        final c = cellCenter(size, hover);
        canvas.drawCircle(
          c,
          sp * 0.36,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.2, sp * 0.09)
            ..color = accent.withValues(alpha: 0.8),
        );
      }
    } else {
      for (final t in moveTargets) {
        final c = cellCenter(size, t);
        final isHover = t == hover;
        canvas.drawCircle(
          c,
          sp * (isHover ? 0.24 : 0.17),
          Paint()..color = const Color(0xDD43A047),
        );
        canvas.drawCircle(
          c,
          sp * (isHover ? 0.24 : 0.17),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.2, sp * 0.035)
            ..color = Colors.white,
        );
      }
    }
  }

  void _paintMarker(Canvas canvas, Offset c, double sp, int owner) {
    final r = sp * 0.26;
    canvas.drawCircle(c + Offset(r * 0.08, r * 0.15), r, a6Shadow(r * 0.2, alpha: 0.45));
    final colors = owner == 0
        ? const [Color(0xFFFFFFFF), Color(0xFFECEFF1), Color(0xFFB0BEC5)]
        : const [Color(0xFF546E7A), Color(0xFF263238), Color(0xFF0D1317)];
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: colors,
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.85,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, r * 0.1)
        ..color = owner == 0 ? const Color(0xFF78909C) : const Color(0xFF90A4AE),
    );
  }

  void _paintRing(Canvas canvas, Offset c, double sp, int owner, {bool selected = false}) {
    final outerR = sp * 0.40;
    final strokeW = sp * 0.125;
    final midR = outerR - strokeW / 2;

    canvas.drawCircle(
      c + Offset(sp * 0.02, sp * 0.04),
      midR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(0.5, sp * 0.05)),
    );

    final ringColor = owner == 0 ? const Color(0xFFF5F7FA) : const Color(0xFF263238);
    final rimColor = owner == 0 ? const Color(0xFF42A5F5) : const Color(0xFFFF7043);

    canvas.drawCircle(
      c,
      midR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..color = ringColor,
    );

    canvas.drawCircle(
      c,
      outerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.4, sp * 0.038)
        ..color = selected ? const Color(0xFFFFD54F) : rimColor,
    );
    canvas.drawCircle(
      c,
      outerR - strokeW,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, sp * 0.032)
        ..color = selected ? const Color(0xFFFFD54F) : rimColor.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class YinshBoardView extends StatefulWidget {
  final GameContext g;
  const YinshBoardView(this.g, {super.key});
  @override
  State<YinshBoardView> createState() => _YinshBoardViewState();
}

class _YinshBoardViewState extends State<YinshBoardView> {
  int selFrom = -1;
  int hover = -1;
  Object? _lastPlies;

  GameContext get g => widget.g;

  List<int> _legalTargets(List<int> board, int from) {
    final out = <int>[];
    if (from < 0 || from >= board.length || !Yinsh.isRing(board[from])) return out;
    final (q0, r0) = yinshCoords[from];
    for (final (dq, dr) in yinshDirs) {
      var cq = q0 + dq, cr = r0 + dr;
      var jumped = false;
      while (true) {
        final idx = yinshIndex(cq, cr);
        if (idx == -1) break;
        final v = board[idx];
        if (Yinsh.isRing(v)) break;
        if (!jumped) {
          if (v == -1) {
            out.add(idx);
          } else {
            jumped = true;
          }
        } else {
          if (v == -1) {
            out.add(idx);
            break;
          }
        }
        cq += dq;
        cr += dr;
      }
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

    final phase = (v['phase'] as String?) ?? 'play';
    final targetRings = (v['targetRings'] as int?) ?? 3;
    final ringsPlaced = (v['ringsPlaced'] as int?) ?? 0;
    final board = (v['board'] as List).cast<int>();
    final turn = v['turn'] as int;
    final scores = ((v['scores'] as List?) ?? const [0, 0]).cast<int>();
    final markers = ((v['markers'] as List?) ?? const [0, 0]).cast<int>();
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;

    final lastFrom = (last?['from'] as int?) ?? (last?['cell'] as int?) ?? -1;
    final lastTo = (last?['to'] as int?) ?? -1;
    final lastFlipped = ((last?['flipped'] as List?) ?? const []).cast<int>().toSet();
    final lastScored = <int>{};
    for (final line in ((last?['scoredLines'] as List?) ?? const [])) {
      if (line is List) lastScored.addAll(line.cast<int>());
    }

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final moveTargets = <int>{};
    if (myTurn && phase == 'play' && selFrom >= 0 && selFrom < board.length && board[selFrom] == 2 + turn) {
      moveTargets.addAll(_legalTargets(board, selFrom));
    }

    void tapCell(int c) {
      if (!myTurn || c < 0 || c >= board.length) return;
      if (phase == 'setup') {
        if (board[c] == -1) {
          g.act({'type': 'place_ring', 'cell': c});
        }
        return;
      }
      if (selFrom >= 0 && moveTargets.contains(c)) {
        final f = selFrom;
        setState(() => selFrom = -1);
        g.act({'type': 'move_ring', 'from': f, 'to': c});
        return;
      }
      if (board[c] == 2 + turn) {
        setState(() => selFrom = selFrom == c ? -1 : c);
      }
    }

    String status;
    final sideName = turn == 0 ? '白方' : '黑方';
    if (over) {
      status = result;
    } else if (myTurn) {
      if (phase == 'setup') {
        status = '轮到你（$sideName）布环：请点击星盘任意空交点放置星环（$ringsPlaced/10）';
      } else if (selFrom < 0) {
        status = '轮到你（$sideName）：请点选一枚己方星环沿六角直线移动';
      } else {
        status = '已选星环 ${yinshCellLabel(selFrom)}：点击绿色圆点移环留子（跳过标记将翻面）';
      }
    } else {
      status = '等待 ${g.name(turn)}（$sideName）${phase == 'setup' ? '放置星环' : '移动星环'}';
    }

    final actions = <Widget>[];
    if (myTurn && selFrom >= 0) {
      actions.add(a6Button(
        context,
        '取消选环',
        Icons.clear,
        () => setState(() => selFrom = -1),
      ));
    }

    final boardWidget = LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      final bSize = Size(side, side);
      return Center(
        child: MouseRegion(
          onHover: (e) {
            final p = _YinshPainter.hit(bSize, e.localPosition);
            if (p != hover) setState(() => hover = p);
          },
          onExit: (_) => setState(() => hover = -1),
          child: GestureDetector(
            onTapUp: (d) => tapCell(_YinshPainter.hit(bSize, d.localPosition)),
            child: CustomPaint(
              size: bSize,
              painter: _YinshPainter(
                board: board,
                phase: phase,
                selFrom: selFrom,
                moveTargets: moveTargets,
                hover: hover,
                lastFrom: lastFrom,
                lastTo: lastTo,
                lastFlipped: lastFlipped,
                lastScored: lastScored,
                accent: cs.primary,
              ),
            ),
          ),
        ),
      );
    });

    Widget tagFor(int s) {
      final sLabel = s == 0 ? '白环' : '黑环';
      final sc = scores[s];
      final mk = markers[s];
      final stateLabel = over
          ? (winner == s ? ' · 胜' : (winner == 2 ? ' · 和' : ' · 负'))
          : ' · 战利环 $sc/$targetRings · 标记 $mk';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sLabel$stateLabel',
        trailing: Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: s == 0 ? const Color(0xFF42A5F5) : const Color(0xFFFF7043),
              width: 3.2,
            ),
          ),
        ),
      );
    }

    return A6Shell(
      tags: [for (var s = 0; s < g.players; s++) tagFor(s)],
      status: status,
      statusHighlight: myTurn,
      aspect: 1,
      board: boardWidget,
      actions: actions,
      info: [
        if (note.isNotEmpty) '动态：$note',
        '规则：移环时在原位留下己方标记，跳过的连续标记全部翻面且必须停在紧邻空位；同色 5 连得分并收回 1 环，先集齐 $targetRings 环胜。',
      ],
      result: a6Banner(g, over, winner, g.players),
      resultSub: over ? result : null,
    );
  }
}
