import 'dart:math';

import 'package:aurora_shared/games/abstract5/hnefatafl.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

class _HnefataflPainter extends CustomPainter {
  final int n;
  final List<int> board;
  final int selFrom;
  final Set<int> moveTargets;
  final int hover;
  final int lastFrom;
  final int lastTo;
  final Set<int> lastCaptured;
  final Color accent;

  _HnefataflPainter({
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

  bool _isCorner(int r, int c) => (r == 0 || r == n - 1) && (c == 0 || c == n - 1);

  bool _isCamp(int r, int c) {
    final m = n ~/ 2;
    if (n == 9) {
      if ((r == 0 || r == n - 1) && (c - m).abs() <= 1) return true;
      if ((c == 0 || c == n - 1) && (r - m).abs() <= 1) return true;
      if ((r == 1 || r == n - 2) && c == m) return true;
      if ((c == 1 || c == n - 2) && r == m) return true;
      return false;
    } else {
      if (r == m && (c - m).abs() >= 2) return true;
      if (c == m && (r - m).abs() >= 2) return true;
      return false;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / n;
    final m = n ~/ 2;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cw * 0.22));
    canvas.drawRRect(outer.shift(Offset(0, cw * 0.06)), a5Shadow(cw * 0.14, alpha: 0.45));

    // Nordic carved oak frame
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4E342E), Color(0xFF271815)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(outer.deflate(cw * 0.05));

    for (var cell = 0; cell < n * n; cell++) {
      final r = cellRect(size, n, cell);
      final row = cell ~/ n, col = cell % n;
      final isThrone = row == m && col == m;
      final isCorner = _isCorner(row, col);
      final isCamp = _isCamp(row, col);
      final light = (row + col).isEven;

      Color cellColor;
      if (isThrone) {
        cellColor = const Color(0xFFD4A359);
      } else if (isCorner) {
        cellColor = const Color(0xFF81A878);
      } else if (isCamp) {
        cellColor = light ? const Color(0xFFC5B49A) : const Color(0xFFB39F82);
      } else {
        cellColor = light ? const Color(0xFFEDE0C8) : const Color(0xFFD6C29F);
      }
      canvas.drawRect(r, Paint()..color = cellColor);

      // Subtle cell grid border
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0x443E2723),
      );

      // Special ornaments on Throne & Corners
      if (isThrone || isCorner) {
        final inner = r.deflate(cw * 0.12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(inner, Radius.circular(cw * 0.12)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.2, cw * 0.04)
            ..color = isThrone ? const Color(0xAA6D4C41) : const Color(0xAA1B5E20),
        );
        if (board[cell] == -1) {
          a5PaintTextCentered(
            canvas,
            isThrone ? '座' : '圣',
            r.center,
            cw * 0.34,
            isThrone ? const Color(0x884E342E) : const Color(0x991B5E20),
          );
        }
      }

      // Highlights for last move & captures
      if (cell == lastFrom || cell == lastTo) {
        canvas.drawRect(r, Paint()..color = const Color(0x5542A5F5));
      } else if (lastCaptured.contains(cell)) {
        canvas.drawRect(r, Paint()..color = const Color(0x66EF5350));
      }

      // Coordinate labels
      if (col == 0) {
        a5PaintTextCentered(
          canvas,
          '${n - row}',
          r.topLeft + Offset(cw * 0.14, cw * 0.16),
          cw * 0.18,
          const Color(0x993E2723),
          weight: FontWeight.w600,
        );
      }
      if (row == n - 1) {
        a5PaintTextCentered(
          canvas,
          String.fromCharCode(65 + col),
          r.bottomRight - Offset(cw * 0.14, cw * 0.15),
          cw * 0.18,
          const Color(0x993E2723),
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
          ..color = const Color(0x881E88E5)
          ..strokeWidth = max(1.5, cw * 0.06)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Selected piece ring
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

    // Draw pieces
    for (var cell = 0; cell < n * n; cell++) {
      final v = board[cell];
      if (v < 0) continue;
      _paintPiece(canvas, cellRect(size, n, cell).center, cw, v);
    }

    // Draw legal targets
    for (final t in moveTargets) {
      final r = cellRect(size, n, t);
      final isHover = t == hover;
      final row = t ~/ n, col = t % n;
      final cornerGoal = _isCorner(row, col);
      final color = cornerGoal ? const Color(0xFFFFB300) : const Color(0xFF2E7D32);
      if (isHover) {
        canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.28));
      }
      canvas.drawCircle(
        r.center,
        cw * (isHover ? 0.21 : 0.15),
        Paint()..color = cornerGoal ? const Color(0xEEFFA000) : const Color(0xDD43A047),
      );
      canvas.drawCircle(
        r.center,
        cw * (isHover ? 0.21 : 0.15),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.2, cw * 0.03)
          ..color = Colors.white.withValues(alpha: 0.9),
      );
    }

    canvas.restore();
  }

  void _paintPiece(Canvas canvas, Offset c, double cw, int kind) {
    final r = cw * (kind == 2 ? 0.39 : 0.35);
    canvas.drawCircle(c + Offset(r * 0.08, r * 0.16), r, a5Shadow(r * 0.2, alpha: 0.45));

    List<Color> colors;
    Color rimColor;
    String glyph;
    Color glyphColor;

    if (kind == 0) {
      // Attacker (Black Viking Raider)
      colors = const [Color(0xFF546E7A), Color(0xFF263238), Color(0xFF0F171A)];
      rimColor = const Color(0xFFD7CCC8);
      glyph = '⚔';
      glyphColor = const Color(0xFFFFECB3);
    } else if (kind == 1) {
      // Defender (White Royal Guard)
      colors = const [Color(0xFFFFFFFF), Color(0xFFF5EFE0), Color(0xFFC8BCA4)];
      rimColor = const Color(0xFF6D4C41);
      glyph = '🛡';
      glyphColor = const Color(0xFF3E2723);
    } else {
      // King (Golden Royal Piece)
      colors = const [Color(0xFFFFF8E1), Color(0xFFFFD54F), Color(0xFFF57F17)];
      rimColor = const Color(0xFF4E342E);
      glyph = '♚';
      glyphColor = const Color(0xFF3E2723);
    }

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
      r * 0.82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, r * 0.11)
        ..color = rimColor.withValues(alpha: 0.8),
    );

    a5PaintTextCentered(canvas, glyph, c, r * 1.0, glyphColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HnefataflBoardView extends StatefulWidget {
  final GameContext g;
  const HnefataflBoardView(this.g, {super.key});
  @override
  State<HnefataflBoardView> createState() => _HnefataflBoardViewState();
}

class _HnefataflBoardViewState extends State<HnefataflBoardView> {
  int selFrom = -1;
  int hover = -1;
  Object? _lastPlies;

  GameContext get g => widget.g;

  bool _belongsTo(int piece, int seat) => seat == 0 ? piece == 0 : (piece == 1 || piece == 2);

  bool _isRestricted(int n, int cell) {
    final m = n ~/ 2;
    if (cell == m * n + m) return true;
    final r = cell ~/ n, c = cell % n;
    return (r == 0 || r == n - 1) && (c == 0 || c == n - 1);
  }

  List<int> _legalTargets(List<int> board, int n, int from) {
    final out = <int>[];
    if (from < 0 || from >= n * n) return out;
    final piece = board[from];
    if (piece < 0) return out;
    final isKing = piece == 2;
    final r0 = from ~/ n, c0 = from % n;
    for (final (dr, dc) in hnefataflDirs) {
      var r = r0 + dr, c = c0 + dc;
      while (r >= 0 && r < n && c >= 0 && c < n) {
        final idx = r * n + c;
        if (board[idx] != -1) break;
        if (isKing || !_isRestricted(n, idx)) {
          out.add(idx);
        }
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
    }

    final n = (v['size'] as int?) ?? 9;
    final board = (v['board'] as List).cast<int>();
    final turn = v['turn'] as int;
    final attCount = (v['attackerCount'] as int?) ?? 0;
    final defCount = (v['defenderCount'] as int?) ?? 0;
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;

    final lastFrom = (last?['from'] as int?) ?? -1;
    final lastTo = (last?['to'] as int?) ?? -1;
    final lastCap = ((last?['captured'] as List?) ?? const []).cast<int>().toSet();

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final moveTargets = <int>{};
    if (myTurn && selFrom >= 0 && selFrom < n * n && _belongsTo(board[selFrom], turn)) {
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
      if (_belongsTo(board[c], turn)) {
        setState(() => selFrom = selFrom == c ? -1 : c);
      }
    }

    String status;
    if (over) {
      status = result;
    } else if (myTurn) {
      final sideName = turn == 0 ? '黑方劫掠者' : '白方近卫与国王';
      if (selFrom < 0) {
        status = '轮到你（$sideName）：请点选己方棋子沿横竖直线移动';
      } else {
        final pName = board[selFrom] == 2 ? '国王' : '士兵';
        status = '已选 ${hnefataflCoord(n, selFrom)}（$pName）：请点击高亮圆点移动（两面夹击可吃子）';
      }
    } else {
      final sideName = turn == 0 ? '黑方劫掠者' : '白方近卫与国王';
      status = '等待 ${g.name(turn)}（$sideName）落子';
    }

    final actions = <Widget>[];
    if (myTurn && selFrom >= 0) {
      actions.add(a5Button(
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
            final p = _HnefataflPainter.hit(bSize, n, e.localPosition);
            if (p != hover) setState(() => hover = p);
          },
          onExit: (_) => setState(() => hover = -1),
          child: GestureDetector(
            onTapUp: (d) => tapCell(_HnefataflPainter.hit(bSize, n, d.localPosition)),
            child: CustomPaint(
              size: bSize,
              painter: _HnefataflPainter(
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
      final sideLabel = s == 0 ? '黑方·劫掠者' : '白方·王室军';
      final cnt = s == 0 ? attCount : defCount;
      final stateLabel = over ? (winner == s ? ' · 胜' : (winner == 2 ? ' · 和' : ' · 负')) : ' · 兵力 $cnt';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sideLabel$stateLabel',
        trailing: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: s == 0 ? const Color(0xFF263238) : const Color(0xFFFFD54F),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF5D4037), width: 1.5),
          ),
        ),
      );
    }

    return A5Shell(
      tags: [for (var s = 0; s < g.players; s++) tagFor(s)],
      status: status,
      statusHighlight: myTurn,
      aspect: 1,
      board: boardWidget,
      actions: actions,
      info: [
        if (note.isNotEmpty) '动态：$note',
        '规则：所有棋子走直线（车走法），两面夹击吃兵；白方护送国王（♚）进入四角【圣】格即胜，黑方合围擒王即胜。',
      ],
      result: a5Banner(g, over, winner, g.players),
      resultSub: over ? result : null,
    );
  }
}
