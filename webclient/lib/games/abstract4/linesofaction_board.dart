import 'dart:math';

import 'package:aurora_shared/games/abstract4/linesofaction.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

class _LoaPainter extends CustomPainter {
  final List<int> board;
  final int selFrom;
  final Map<int, (int, bool)> targets; // to -> (distance, isCapture)
  final int hover;
  final int lastFrom;
  final int lastTo;
  final Color accent;

  _LoaPainter({
    required this.board,
    required this.selFrom,
    required this.targets,
    required this.hover,
    required this.lastFrom,
    required this.lastTo,
    required this.accent,
  });

  static Rect cellRect(Size s, int cell) {
    final cw = s.width / 8;
    final x = cell % 8, y = cell ~/ 8;
    return Rect.fromLTWH(x * cw, y * cw, cw, cw);
  }

  static int hit(Size s, Offset o) {
    if (s.width <= 0 || s.height <= 0) return -1;
    final cw = s.width / 8;
    final x = (o.dx / cw).floor(), y = (o.dy / cw).floor();
    if (x < 0 || x >= 8 || y < 0 || y >= 8) return -1;
    return y * 8 + x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / 8;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cw * 0.22));
    canvas.drawRRect(outer.shift(Offset(0, cw * 0.06)), a4Shadow(cw * 0.14, alpha: 0.45));

    // Classic tournament green/slate felt board
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E4E3F), Color(0xFF1F382C)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(outer.deflate(cw * 0.05));

    for (var c = 0; c < 64; c++) {
      final r = cellRect(size, c);
      final row = c ~/ 8, col = c % 8;
      final light = (row + col).isEven;
      final cellColor = light ? const Color(0xFFDCE7DC) : const Color(0xFF7FA389);
      canvas.drawRect(r, Paint()..color = cellColor);

      if (c == lastFrom || c == lastTo) {
        canvas.drawRect(r, Paint()..color = const Color(0x55FFD54F));
      }

      if (col == 0) {
        a4PaintTextCentered(
          canvas,
          '${8 - row}',
          r.topLeft + Offset(cw * 0.14, cw * 0.16),
          cw * 0.18,
          light ? const Color(0x99263238) : const Color(0xBBFFFFFF),
          weight: FontWeight.w600,
        );
      }
      if (row == 7) {
        a4PaintTextCentered(
          canvas,
          String.fromCharCode(65 + col),
          r.bottomRight - Offset(cw * 0.14, cw * 0.15),
          cw * 0.18,
          light ? const Color(0x99263238) : const Color(0xBBFFFFFF),
          weight: FontWeight.w600,
        );
      }
    }

    // Draw subtle 8-directional connectivity links between adjacent same-color pieces
    for (var c = 0; c < 64; c++) {
      final seat = board[c];
      if (seat != 0 && seat != 1) continue;
      final r0 = c ~/ 8, c0 = c % 8;
      final p0 = cellRect(size, c).center;
      final linkColor = seat == 0 ? const Color(0x55263238) : const Color(0x77FFF8E1);
      for (final (dr, dc) in const [(0, 1), (1, 0), (1, 1), (1, -1)]) {
        final r1 = r0 + dr, c1 = c0 + dc;
        if (r1 >= 0 && r1 < 8 && c1 >= 0 && c1 < 8 && board[r1 * 8 + c1] == seat) {
          final p1 = cellRect(size, r1 * 8 + c1).center;
          canvas.drawLine(
            p0,
            p1,
            Paint()
              ..color = linkColor
              ..strokeWidth = max(2.0, cw * 0.08)
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    // Draw last move line
    if (lastFrom >= 0 && lastTo >= 0 && lastFrom < 64 && lastTo < 64) {
      canvas.drawLine(
        cellRect(size, lastFrom).center,
        cellRect(size, lastTo).center,
        Paint()
          ..color = const Color(0xAAFFB300)
          ..strokeWidth = max(2.0, cw * 0.07)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Draw lines of action from selected piece to legal destinations
    if (selFrom >= 0 && selFrom < 64) {
      final origin = cellRect(size, selFrom).center;
      for (final entry in targets.entries) {
        final dest = cellRect(size, entry.key).center;
        final isCap = entry.value.$2;
        canvas.drawLine(
          origin,
          dest,
          Paint()
            ..color = isCap ? const Color(0xAAEF5350) : const Color(0x9926A69A)
            ..strokeWidth = max(1.8, cw * 0.06)
            ..strokeCap = StrokeCap.round,
        );
      }

      final r = cellRect(size, selFrom).deflate(cw * 0.05);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cw * 0.14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.2, cw * 0.07)
          ..color = accent,
      );
    }

    // Draw pieces
    for (var c = 0; c < 64; c++) {
      final v = board[c];
      if (v == 0 || v == 1) {
        _paintPiece(canvas, cellRect(size, c).center, cw, v);
      }
    }

    // Draw legal target overlays with line-count badge
    for (final entry in targets.entries) {
      final t = entry.key;
      final (dist, isCap) = entry.value;
      final r = cellRect(size, t);
      final isHover = t == hover;
      final color = isCap ? const Color(0xFFE53935) : const Color(0xFF00897B);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(cw * 0.07), Radius.circular(cw * 0.14)),
        Paint()..color = color.withValues(alpha: isHover ? 0.45 : 0.24),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(cw * 0.07), Radius.circular(cw * 0.14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.8, cw * 0.055)
          ..color = color,
      );
      final badgeRadius = cw * (isHover ? 0.21 : 0.18);
      canvas.drawCircle(r.center, badgeRadius, Paint()..color = color.withValues(alpha: 0.92));
      a4PaintTextCentered(
        canvas,
        isCap ? '吃$dist' : '$dist',
        r.center,
        cw * (isCap ? 0.19 : 0.22),
        Colors.white,
      );
    }

    canvas.restore();
  }

  void _paintPiece(Canvas canvas, Offset c, double cw, int seat) {
    final r = cw * 0.36;
    canvas.drawCircle(c + Offset(r * 0.08, r * 0.16), r, a4Shadow(r * 0.2, alpha: 0.48));

    final isBlack = seat == 0;
    final colors = isBlack
        ? const [Color(0xFF546E7A), Color(0xFF263238), Color(0xFF0D1418)]
        : const [Color(0xFFFFFFFF), Color(0xFFF5F3EB), Color(0xFFCFD8DC)];

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: colors,
          stops: const [0.0, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    canvas.drawCircle(
      c,
      r * 0.76,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, r * 0.1)
        ..color = isBlack ? const Color(0x6690A4AE) : const Color(0x8878909C),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LinesOfActionBoardView extends StatefulWidget {
  final GameContext g;
  const LinesOfActionBoardView(this.g, {super.key});
  @override
  State<LinesOfActionBoardView> createState() => _LinesOfActionBoardViewState();
}

class _LinesOfActionBoardViewState extends State<LinesOfActionBoardView> {
  int selFrom = -1;
  int hover = -1;
  Object? _lastPlies;

  GameContext get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    if (_lastPlies != v['plies']) {
      _lastPlies = v['plies'];
      selFrom = -1;
    }

    final board = (v['board'] as List).cast<int>();
    final turn = v['turn'] as int;
    final plies = (v['plies'] as int?) ?? 0;
    final maxPlies = (v['maxPlies'] as int?) ?? 160;
    final components = (v['components'] as List).cast<int>();
    final counts = (v['counts'] as List).cast<int>();
    final legalMoves = [
      for (final m in v['legalMoves'] as List)
        ((m[0] as int), (m[1] as int), (m[2] as int), (m[3] as int) == 1)
    ];
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;

    final lastFrom = (last?['from'] as int?) ?? -1;
    final lastTo = (last?['to'] as int?) ?? -1;

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final targets = <int, (int, bool)>{};
    if (myTurn && selFrom >= 0) {
      for (final (f, t, dist, cap) in legalMoves) {
        if (f == selFrom) {
          targets[t] = (dist, cap);
        }
      }
    }

    void tapCell(int c) {
      if (!myTurn || c < 0 || c >= 64) return;
      if (selFrom >= 0 && targets.containsKey(c)) {
        final f = selFrom;
        setState(() => selFrom = -1);
        g.act({'type': 'move', 'from': f, 'to': c});
        return;
      }
      if (board[c] == turn) {
        setState(() {
          selFrom = selFrom == c ? -1 : c;
        });
      }
    }

    String status;
    if (over) {
      status = result;
    } else if (myTurn) {
      final sideName = turn == 0 ? '黑方' : '白方';
      if (selFrom < 0) {
        status = '轮到你（$sideName）：请点选己方棋子查看行动线落点（当前连通分块：${components[turn]}）';
      } else {
        status = '已选 ${loaCoord(selFrom)}：点选带步数标记的目标格移动（圆圈数字为该线总子数）';
      }
    } else {
      final sideName = turn == 0 ? '黑方' : '白方';
      status = '等待 ${g.name(turn)}（$sideName）行动';
    }

    final boardWidget = LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      final bSize = Size(side, side);
      return Center(
        child: MouseRegion(
          onHover: (e) {
            final p = _LoaPainter.hit(bSize, e.localPosition);
            if (p != hover) setState(() => hover = p);
          },
          onExit: (_) => setState(() => hover = -1),
          child: GestureDetector(
            onTapUp: (d) => tapCell(_LoaPainter.hit(bSize, d.localPosition)),
            child: CustomPaint(
              size: bSize,
              painter: _LoaPainter(
                board: board,
                selFrom: selFrom,
                targets: targets,
                hover: hover,
                lastFrom: lastFrom,
                lastTo: lastTo,
                accent: cs.primary,
              ),
            ),
          ),
        ),
      );
    });

    Widget tagFor(int s) {
      final sideLabel = s == 0 ? '黑方' : '白方';
      final compLabel = ' · 连通块 ${components[s]}（${counts[s]}子）';
      final stateLabel = over ? (winner == s ? ' · 胜' : (winner == 2 ? ' · 和' : ' · 负')) : compLabel;
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sideLabel$stateLabel',
        trailing: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: s == 0 ? const Color(0xFF263238) : const Color(0xFFF5F3EB),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF78909C), width: 1.5),
          ),
        ),
      );
    }

    return A4Shell(
      tags: [for (var s = 0; s < g.players; s++) tagFor(s)],
      status: status,
      statusHighlight: myTurn,
      aspect: 1,
      board: boardWidget,
      info: [
        if (note.isNotEmpty) '动态：$note',
        '手数：$plies/$maxPlies · 步数等于该直线上双方棋子总数（可越己子、不可越敌子），连成 1 块即胜！',
      ],
      result: a4Banner(g, over, winner, g.players),
      resultSub: over ? result : null,
    );
  }
}
