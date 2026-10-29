import 'dart:math';

import 'package:aurora_shared/games/abstract6/breakthrough.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

class _BreakthroughPainter extends CustomPainter {
  final int n;
  final List<int> board;
  final int selFrom;
  final Set<int> moveTargets;
  final int hover;
  final int lastFrom;
  final int lastTo;
  final bool lastCaptured;
  final Color accent;

  _BreakthroughPainter({
    required this.n,
    required this.board,
    required this.selFrom,
    required this.moveTargets,
    required this.hover,
    required this.lastFrom,
    required this.lastTo,
    required this.lastCaptured,
    required this.accent,
  });

  static Rect cellRect(Size s, int n, int cell) {
    final cw = s.width / n;
    final x = cell % n, y = cell ~/ n;
    return Rect.fromLTWH(x * cw, y * cw, cw, cw);
  }

  static int hit(Size s, int n, Offset o) {
    if (s.width <= 0 || s.height <= 0) return -1;
    final cw = s.width / n;
    final x = (o.dx / cw).floor(), y = (o.dy / cw).floor();
    if (x < 0 || x >= n || y < 0 || y >= n) return -1;
    return y * n + x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / n;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cw * 0.22));
    canvas.drawRRect(outer.shift(Offset(0, cw * 0.06)), a6Shadow(cw * 0.14, alpha: 0.45));

    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF37474F), Color(0xFF1C262B)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(outer.deflate(cw * 0.05));

    for (var cell = 0; cell < n * n; cell++) {
      final r = cellRect(size, n, cell);
      final row = cell ~/ n, col = cell % n;
      final light = (row + col).isEven;
      final isTopGoal = row == 0; // Goal row for Player 0 (Gold)
      final isBotGoal = row == n - 1; // Goal row for Player 1 (Dark)

      Color cellColor;
      if (isTopGoal) {
        cellColor = light ? const Color(0xFFF6E6B4) : const Color(0xFFDCC482);
      } else if (isBotGoal) {
        cellColor = light ? const Color(0xFFCFD8DC) : const Color(0xFF90A4AE);
      } else {
        cellColor = light ? const Color(0xFFEDE0C8) : const Color(0xFFC5B08B);
      }
      canvas.drawRect(r, Paint()..color = cellColor);

      // Subtle goal-rank banner stripe
      if (isTopGoal || isBotGoal) {
        final stripe = isTopGoal
            ? Rect.fromLTWH(r.left, r.top, r.width, cw * 0.08)
            : Rect.fromLTWH(r.left, r.bottom - cw * 0.08, r.width, cw * 0.08);
        canvas.drawRect(
          stripe,
          Paint()..color = isTopGoal ? const Color(0xCCFFB300) : const Color(0xCC546E7A),
        );
      }

      if (cell == lastFrom || cell == lastTo) {
        canvas.drawRect(
          r,
          Paint()..color = (cell == lastTo && lastCaptured) ? const Color(0x66EF5350) : const Color(0x5542A5F5),
        );
      }

      if (col == 0) {
        a6PaintTextCentered(
          canvas,
          '${n - row}',
          r.topLeft + Offset(cw * 0.14, cw * 0.16),
          cw * 0.18,
          const Color(0x9937474F),
          weight: FontWeight.w600,
        );
      }
      if (row == n - 1) {
        a6PaintTextCentered(
          canvas,
          String.fromCharCode(65 + col),
          r.bottomRight - Offset(cw * 0.14, cw * 0.15),
          cw * 0.18,
          const Color(0x9937474F),
          weight: FontWeight.w600,
        );
      }
    }

    // Last move line
    if (lastFrom >= 0 && lastTo >= 0 && lastFrom < n * n && lastTo < n * n) {
      final p0 = cellRect(size, n, lastFrom).center;
      final p1 = cellRect(size, n, lastTo).center;
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = lastCaptured ? const Color(0xAAE53935) : const Color(0x991E88E5)
          ..strokeWidth = max(1.8, cw * 0.065)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Selected square ring
    if (selFrom >= 0 && selFrom < n * n) {
      final r = cellRect(size, n, selFrom).deflate(cw * 0.05);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cw * 0.14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.2, cw * 0.075)
          ..color = accent,
      );
    }

    // Draw pieces
    for (var cell = 0; cell < n * n; cell++) {
      final v = board[cell];
      if (v != 0 && v != 1) continue;
      _paintSoldier(canvas, cellRect(size, n, cell).center, cw, v);
    }

    // Draw legal targets (green dot for empty advance, red target ring for diagonal capture!)
    for (final t in moveTargets) {
      final r = cellRect(size, n, t);
      final isHover = t == hover;
      final isCap = board[t] != -1;
      if (isCap) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(r.deflate(cw * 0.06), Radius.circular(cw * 0.16)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.2, cw * 0.08)
            ..color = const Color(0xFFE53935).withValues(alpha: isHover ? 1.0 : 0.85),
        );
      } else {
        canvas.drawCircle(
          r.center,
          cw * (isHover ? 0.21 : 0.15),
          Paint()..color = const Color(0xDD43A047),
        );
        canvas.drawCircle(
          r.center,
          cw * (isHover ? 0.21 : 0.15),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.2, cw * 0.03)
            ..color = Colors.white,
        );
      }
    }

    canvas.restore();
  }

  void _paintSoldier(Canvas canvas, Offset c, double cw, int seat) {
    final r = cw * 0.36;
    canvas.drawCircle(c + Offset(r * 0.08, r * 0.16), r, a6Shadow(r * 0.2, alpha: 0.45));

    final colors = seat == 0
        ? const [Color(0xFFFFF8E1), Color(0xFFFFD54F), Color(0xFFF57F17)]
        : const [Color(0xFF546E7A), Color(0xFF263238), Color(0xFF0F171A)];
    final rimColor = seat == 0 ? const Color(0xFF5D4037) : const Color(0xFFCFD8DC);
    final glyph = seat == 0 ? '▲' : '▼';
    final glyphColor = seat == 0 ? const Color(0xFF4E342E) : const Color(0xFFFFECB3);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: colors,
          stops: const [0.0, 0.68, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, r * 0.11)
        ..color = rimColor.withValues(alpha: 0.8),
    );
    a6PaintTextCentered(canvas, glyph, c, r * 0.88, glyphColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BreakthroughBoardView extends StatefulWidget {
  final GameContext g;
  const BreakthroughBoardView(this.g, {super.key});
  @override
  State<BreakthroughBoardView> createState() => _BreakthroughBoardViewState();
}

class _BreakthroughBoardViewState extends State<BreakthroughBoardView> {
  int selFrom = -1;
  int hover = -1;
  Object? _lastPlies;

  GameContext get g => widget.g;

  List<int> _legalTargets(List<int> board, int n, int from) {
    final out = <int>[];
    if (from < 0 || from >= n * n) return out;
    final seat = board[from];
    if (seat != 0 && seat != 1) return out;
    final r = from ~/ n, c = from % n;
    final nr = r + (seat == 0 ? -1 : 1);
    if (nr < 0 || nr >= n) return out;

    final straight = nr * n + c;
    if (board[straight] == -1) out.add(straight);

    for (final dc in const [-1, 1]) {
      final nc = c + dc;
      if (nc >= 0 && nc < n) {
        final diag = nr * n + nc;
        if (board[diag] != seat) out.add(diag);
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

    final n = (v['size'] as int?) ?? 8;
    final board = (v['board'] as List).cast<int>();
    final turn = v['turn'] as int;
    final counts = ((v['counts'] as List?) ?? const [16, 16]).cast<int>();
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;

    final lastFrom = (last?['from'] as int?) ?? -1;
    final lastTo = (last?['to'] as int?) ?? -1;
    final lastCap = last?['captured'] == true;

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final moveTargets = <int>{};
    if (myTurn && selFrom >= 0 && selFrom < n * n && board[selFrom] == turn) {
      moveTargets.addAll(_legalTargets(board, n, selFrom));
    }

    void tapCell(int c) {
      if (!myTurn || c < 0 || c >= n * n) return;
      if (selFrom >= 0 && moveTargets.contains(c)) {
        final f = selFrom;
        setState(() => selFrom = -1);
        g.act({'type': 'move', 'from': f, 'to': c});
        return;
      }
      if (board[c] == turn) {
        setState(() => selFrom = selFrom == c ? -1 : c);
      }
    }

    final sideName = turn == 0 ? '白金方（向上▲）' : '玄铁方（向下▼）';
    String status;
    if (over) {
      status = result;
    } else if (myTurn) {
      if (selFrom < 0) {
        status = '轮到你（$sideName）：请点选己方士兵向前推进';
      } else {
        status = '已选 ${breakthroughCoord(n, selFrom)}：直行入空格（绿点），斜前可入空格或吃敌子（红框）';
      }
    } else {
      status = '等待 ${g.name(turn)}（$sideName）推进部队';
    }

    final actions = <Widget>[];
    if (myTurn && selFrom >= 0) {
      actions.add(a6Button(
        context,
        '取消选择',
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
            final p = _BreakthroughPainter.hit(bSize, n, e.localPosition);
            if (p != hover) setState(() => hover = p);
          },
          onExit: (_) => setState(() => hover = -1),
          child: GestureDetector(
            onTapUp: (d) => tapCell(_BreakthroughPainter.hit(bSize, n, d.localPosition)),
            child: CustomPaint(
              size: bSize,
              painter: _BreakthroughPainter(
                n: n,
                board: board,
                selFrom: selFrom,
                moveTargets: moveTargets,
                hover: hover,
                lastFrom: lastFrom,
                lastTo: lastTo,
                lastCaptured: lastCap,
                accent: cs.primary,
              ),
            ),
          ),
        ),
      );
    });

    Widget tagFor(int s) {
      final sideLabel = s == 0 ? '白金军▲' : '玄铁军▼';
      final cnt = counts[s];
      final stateLabel = over ? (winner == s ? ' · 胜' : (winner == 2 ? ' · 和' : ' · 负')) : ' · 兵力 $cnt';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sideLabel$stateLabel',
        trailing: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: s == 0 ? const Color(0xFFFFD54F) : const Color(0xFF263238),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF5D4037), width: 1.5),
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
        '规则：士兵只能向前直走一格（须为空）或向斜前走一格（可入空或吃敌子）；率先将任意一兵冲入敌方底线即胜！',
      ],
      result: a6Banner(g, over, winner, g.players),
      resultSub: over ? result : null,
    );
  }
}
