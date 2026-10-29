import 'dart:math';

import 'package:aurora_shared/games/abstract4/amazons.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

class _AmazonsPainter extends CustomPainter {
  final int n;
  final List<int> board;
  final int turn;
  final int selFrom;
  final int selTo;
  final Set<int> moveTargets;
  final Set<int> arrowTargets;
  final int hover;
  final int lastFrom;
  final int lastTo;
  final int lastArrow;
  final Color accent;

  _AmazonsPainter({
    required this.n,
    required this.board,
    required this.turn,
    required this.selFrom,
    required this.selTo,
    required this.moveTargets,
    required this.arrowTargets,
    required this.hover,
    required this.lastFrom,
    required this.lastTo,
    required this.lastArrow,
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
    canvas.drawRRect(outer.shift(Offset(0, cw * 0.06)), a4Shadow(cw * 0.14, alpha: 0.45));

    // Warm rosewood / maple chessboard frame
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(outer.deflate(cw * 0.05));

    for (var c = 0; c < n * n; c++) {
      final r = cellRect(size, n, c);
      final row = c ~/ n, col = c % n;
      final light = (row + col).isEven;
      final cellColor = light ? const Color(0xFFF3E5AB) : const Color(0xFFC89D66);
      canvas.drawRect(r, Paint()..color = cellColor);

      // Last action highlights
      if (c == lastFrom || c == lastTo) {
        canvas.drawRect(r, Paint()..color = const Color(0x5542A5F5));
      } else if (c == lastArrow) {
        canvas.drawRect(r, Paint()..color = const Color(0x66EF5350));
      }

      // Coordinate labels along left col and bottom row
      if (col == 0) {
        a4PaintTextCentered(
          canvas,
          '${n - row}',
          r.topLeft + Offset(cw * 0.14, cw * 0.16),
          cw * 0.18,
          light ? const Color(0x994E342E) : const Color(0xBBFFF8E1),
          weight: FontWeight.w600,
        );
      }
      if (row == n - 1) {
        a4PaintTextCentered(
          canvas,
          String.fromCharCode(65 + col),
          r.bottomRight - Offset(cw * 0.14, cw * 0.15),
          cw * 0.18,
          light ? const Color(0x994E342E) : const Color(0xBBFFF8E1),
          weight: FontWeight.w600,
        );
      }

      final v = board[c];
      if (v == 2) {
        _paintBurnedArrow(canvas, r.center, cw, c == lastArrow);
      }
    }

    // Draw last move & arrow trajectory lines
    if (lastFrom >= 0 && lastTo >= 0 && lastFrom < n * n && lastTo < n * n) {
      final p0 = cellRect(size, n, lastFrom).center;
      final p1 = cellRect(size, n, lastTo).center;
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = const Color(0x881E88E5)
          ..strokeWidth = max(1.5, cw * 0.06)
          ..strokeCap = StrokeCap.round,
      );
      if (lastArrow >= 0 && lastArrow < n * n) {
        final p2 = cellRect(size, n, lastArrow).center;
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = const Color(0x99E53935)
            ..strokeWidth = max(1.5, cw * 0.05)
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Draw selected piece ring
    if (selFrom >= 0 && selFrom < n * n) {
      final r = cellRect(size, n, selFrom).deflate(cw * 0.05);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cw * 0.14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.0, cw * 0.07)
          ..color = accent,
      );
    }

    // Draw Amazons pieces
    for (var c = 0; c < n * n; c++) {
      final v = board[c];
      if (v != 0 && v != 1) continue;
      final isMovingOrigin = (c == selFrom && selTo >= 0);
      _paintAmazon(canvas, cellRect(size, n, c).center, cw, v, ghost: isMovingOrigin);
    }

    // Draw preview Amazon at selTo when choosing arrow shot
    if (selFrom >= 0 && selTo >= 0 && selTo < n * n) {
      final p0 = cellRect(size, n, selFrom).center;
      final p1 = cellRect(size, n, selTo).center;
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = const Color(0xCC43A047)
          ..strokeWidth = max(2.0, cw * 0.07)
          ..strokeCap = StrokeCap.round,
      );
      _paintAmazon(canvas, p1, cw, turn, preview: true);
    }

    // Draw move targets (Step 1)
    for (final t in moveTargets) {
      final r = cellRect(size, n, t);
      final isHover = t == hover;
      const color = Color(0xFF2E7D32);
      if (isHover) {
        canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.28));
      }
      canvas.drawCircle(
        r.center,
        cw * (isHover ? 0.20 : 0.14),
        Paint()..color = const Color(0xDD43A047),
      );
      canvas.drawCircle(
        r.center,
        cw * (isHover ? 0.20 : 0.14),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.2, cw * 0.03)
          ..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    // Draw arrow targets (Step 2)
    for (final a in arrowTargets) {
      final r = cellRect(size, n, a);
      final isHover = a == hover;
      const color = Color(0xFFD84315);
      canvas.drawRect(r, Paint()..color = color.withValues(alpha: isHover ? 0.38 : 0.18));
      canvas.drawCircle(
        r.center,
        cw * (isHover ? 0.22 : 0.15),
        Paint()..color = const Color(0xEEFF5722),
      );
      a4PaintTextCentered(canvas, '箭', r.center, cw * 0.22, Colors.white);
    }

    canvas.restore();
  }

  void _paintAmazon(Canvas canvas, Offset c, double cw, int seat, {bool ghost = false, bool preview = false}) {
    final alpha = ghost ? 0.35 : (preview ? 0.90 : 1.0);
    final r = cw * 0.36;
    if (!ghost) {
      canvas.drawCircle(c + Offset(r * 0.08, r * 0.16), r, a4Shadow(r * 0.2, alpha: 0.45 * alpha));
    }

    final isWhite = seat == 0;
    final colors = isWhite
        ? [
            const Color(0xFFFFFFFF).withValues(alpha: alpha),
            const Color(0xFFF5F0E1).withValues(alpha: alpha),
            const Color(0xFFBDB399).withValues(alpha: alpha),
          ]
        : [
            const Color(0xFF546E7A).withValues(alpha: alpha),
            const Color(0xFF263238).withValues(alpha: alpha),
            const Color(0xFF0D1317).withValues(alpha: alpha),
          ];

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

    final rimColor = isWhite
        ? const Color(0xFF8D6E63).withValues(alpha: 0.85 * alpha)
        : const Color(0xFFFFD54F).withValues(alpha: 0.75 * alpha);
    canvas.drawCircle(
      c,
      r * 0.82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, r * 0.11)
        ..color = rimColor,
    );

    if (preview) {
      canvas.drawCircle(
        c,
        r * 1.04,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.8, r * 0.14)
          ..color = const Color(0xFF43A047),
      );
    }

    a4PaintTextCentered(
      canvas,
      '♛',
      c,
      r * 1.05,
      isWhite ? const Color(0xFF4E342E).withValues(alpha: alpha) : const Color(0xFFFFF8E1).withValues(alpha: alpha),
    );
  }

  void _paintBurnedArrow(Canvas canvas, Offset c, double cw, bool isLast) {
    final r = cw * 0.34;
    // Scorched dark crater
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF3E2723), Color(0xFF1B0F0D)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, cw * 0.04)
        ..color = isLast ? const Color(0xFFFF7043) : const Color(0xFF8D6E63),
    );
    // Crossed flame/arrow X mark
    final p = Paint()
      ..color = isLast ? const Color(0xFFFFAB40) : const Color(0xFFE65100)
      ..strokeWidth = max(1.6, cw * 0.065)
      ..strokeCap = StrokeCap.round;
    final d = r * 0.52;
    canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), p);
    canvas.drawLine(c + Offset(d, -d), c + Offset(-d, d), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AmazonsBoardView extends StatefulWidget {
  final GameContext g;
  const AmazonsBoardView(this.g, {super.key});
  @override
  State<AmazonsBoardView> createState() => _AmazonsBoardViewState();
}

class _AmazonsBoardViewState extends State<AmazonsBoardView> {
  int selFrom = -1;
  int selTo = -1;
  int hover = -1;
  Object? _lastPlies;

  GameContext get g => widget.g;

  List<int> _queenRays(List<int> board, int n, int origin, {int ignoreCell = -1}) {
    final out = <int>[];
    if (origin < 0 || origin >= n * n) return out;
    final r0 = origin ~/ n, c0 = origin % n;
    for (final (dr, dc) in amazonsDirs) {
      var r = r0 + dr, c = c0 + dc;
      while (r >= 0 && r < n && c >= 0 && c < n) {
        final idx = r * n + c;
        if (board[idx] != -1 && idx != ignoreCell) break;
        out.add(idx);
        r += dr;
        c += dc;
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
      selTo = -1;
    }

    final n = (v['size'] as int?) ?? 8;
    final board = (v['board'] as List).cast<int>();
    final turn = v['turn'] as int;
    final arrowCount = (v['arrowCount'] as int?) ?? 0;
    final myMob = (v['myMobility'] as int?) ?? 0;
    final oppMob = (v['oppMobility'] as int?) ?? 0;
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;

    final lastFrom = (last?['from'] as int?) ?? -1;
    final lastTo = (last?['to'] as int?) ?? -1;
    final lastArrow = (last?['arrow'] as int?) ?? -1;

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final moveTargets = <int>{};
    final arrowTargets = <int>{};
    if (myTurn && selFrom >= 0 && selFrom < n * n && board[selFrom] == turn) {
      if (selTo < 0) {
        moveTargets.addAll(_queenRays(board, n, selFrom));
      } else {
        arrowTargets.addAll(_queenRays(board, n, selTo, ignoreCell: selFrom));
      }
    }

    void tapCell(int c) {
      if (!myTurn || c < 0 || c >= n * n) return;
      if (selFrom >= 0 && selTo >= 0) {
        if (arrowTargets.contains(c)) {
          final f = selFrom, t = selTo;
          setState(() {
            selFrom = -1;
            selTo = -1;
          });
          g.act({'type': 'move', 'from': f, 'to': t, 'arrow': c});
          return;
        }
        if (c == selTo) {
          setState(() => selTo = -1);
          return;
        }
        if (board[c] == turn) {
          setState(() {
            selFrom = c;
            selTo = -1;
          });
          return;
        }
        return;
      }

      if (selFrom >= 0 && moveTargets.contains(c)) {
        setState(() => selTo = c);
        return;
      }

      if (board[c] == turn) {
        setState(() {
          selFrom = selFrom == c ? -1 : c;
          selTo = -1;
        });
      }
    }

    String status;
    if (over) {
      status = result;
    } else if (myTurn) {
      final sideName = turn == 0 ? '白方' : '黑方';
      if (selFrom < 0) {
        status = '轮到你（$sideName）：第 1 步，请点选己方 1 枚亚马逊女战士（♛）';
      } else if (selTo < 0) {
        status = '已选 ${amazonsCoord(n, selFrom)}：第 1 步，请点绿色圆点移动女战士';
      } else {
        status = '已移至 ${amazonsCoord(n, selTo)}：第 2 步，请点橙色“箭”格发射火焰箭封锁！';
      }
    } else {
      final sideName = turn == 0 ? '白方' : '黑方';
      status = '等待 ${g.name(turn)}（$sideName）移动并射箭';
    }

    final actions = <Widget>[];
    if (myTurn && selFrom >= 0) {
      if (selTo >= 0) {
        actions.add(a4Button(
          context,
          '重选移动落点',
          Icons.undo,
          () => setState(() => selTo = -1),
        ));
      }
      actions.add(a4Button(
        context,
        '取消选择',
        Icons.clear,
        () => setState(() {
          selFrom = -1;
          selTo = -1;
        }),
      ));
    }

    final boardWidget = LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      final bSize = Size(side, side);
      return Center(
        child: MouseRegion(
          onHover: (e) {
            final p = _AmazonsPainter.hit(bSize, n, e.localPosition);
            if (p != hover) setState(() => hover = p);
          },
          onExit: (_) => setState(() => hover = -1),
          child: GestureDetector(
            onTapUp: (d) => tapCell(_AmazonsPainter.hit(bSize, n, d.localPosition)),
            child: CustomPaint(
              size: bSize,
              painter: _AmazonsPainter(
                n: n,
                board: board,
                turn: turn,
                selFrom: selFrom,
                selTo: selTo,
                moveTargets: moveTargets,
                arrowTargets: arrowTargets,
                hover: hover,
                lastFrom: lastFrom,
                lastTo: lastTo,
                lastArrow: lastArrow,
                accent: cs.primary,
              ),
            ),
          ),
        ),
      );
    });

    Widget tagFor(int s) {
      final sideLabel = s == 0 ? '白方' : '黑方';
      final mob = s == turn ? myMob : oppMob;
      final stateLabel = over ? (winner == s ? ' · 胜' : (winner == 2 ? ' · 和' : ' · 负')) : ' · 路线 $mob';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sideLabel$stateLabel',
        trailing: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: s == 0 ? const Color(0xFFF5F0E1) : const Color(0xFF263238),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF8D6E63), width: 1.5),
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
      actions: actions,
      info: [
        if (note.isNotEmpty) '动态：$note',
        '规格：$n×$n 棋盘 · 已封锁箭矢格：$arrowCount 处 · 困毙对手全部 4 枚女战士即胜！',
      ],
      result: a4Banner(g, over, winner, g.players),
      resultSub: over ? result : null,
    );
  }
}
