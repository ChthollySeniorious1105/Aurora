import 'dart:math';

import 'package:aurora_shared/games/abstract5/fanorona.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

class _FanoronaPainter extends CustomPainter {
  final int cols;
  final int rows;
  final List<int> board;
  final int activeFrom;
  final int pendingTo;
  final Set<int> moveTargets;
  final Set<int> approachCells;
  final Set<int> withdrawCells;
  final List<int> visited;
  final int hover;
  final int lastFrom;
  final int lastTo;
  final Set<int> lastCaptured;
  final Color accent;

  _FanoronaPainter({
    required this.cols,
    required this.rows,
    required this.board,
    required this.activeFrom,
    required this.pendingTo,
    required this.moveTargets,
    required this.approachCells,
    required this.withdrawCells,
    required this.visited,
    required this.hover,
    required this.lastFrom,
    required this.lastTo,
    required this.lastCaptured,
    required this.accent,
  });

  static Offset cellCenter(Size s, int cols, int rows, int cell) {
    final cw = s.width / cols;
    final ch = s.height / rows;
    final c = cell % cols, r = cell ~/ cols;
    return Offset((c + 0.5) * cw, (r + 0.5) * ch);
  }

  static int hit(Size s, int cols, int rows, Offset o) {
    if (s.width <= 0 || s.height <= 0) return -1;
    final cw = s.width / cols;
    final ch = s.height / rows;
    final c = (o.dx / cw).floor(), r = (o.dy / ch).floor();
    if (c < 0 || c >= cols || r < 0 || r >= rows) return -1;
    return r * cols + c;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cw = min(size.width / cols, size.height / rows);
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cw * 0.24));
    canvas.drawRRect(outer.shift(Offset(0, cw * 0.06)), a5Shadow(cw * 0.14, alpha: 0.45));

    // Malagasy carved rosewood / warm sandstone board
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5D4037), Color(0xFF3E2723)],
        ).createShader(Offset.zero & size),
    );

    final inner = outer.deflate(cw * 0.07);
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEBD9B4), Color(0xFFD7BC8D)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(inner);

    final linePaint = Paint()
      ..color = const Color(0xAA4E342E)
      ..strokeWidth = max(1.4, cw * 0.045)
      ..strokeCap = StrokeCap.round;

    // 1. Draw horizontal & vertical grid lines
    for (var r = 0; r < rows; r++) {
      final p0 = cellCenter(size, cols, rows, r * cols + 0);
      final p1 = cellCenter(size, cols, rows, r * cols + (cols - 1));
      canvas.drawLine(p0, p1, linePaint);
    }
    for (var c = 0; c < cols; c++) {
      final p0 = cellCenter(size, cols, rows, c);
      final p1 = cellCenter(size, cols, rows, (rows - 1) * cols + c);
      canvas.drawLine(p0, p1, linePaint);
    }

    // 2. Draw diagonal lines connecting strong points ((r + c).isEven)
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        if ((r + c).isEven) {
          final p0 = cellCenter(size, cols, rows, r * cols + c);
          final p1 = cellCenter(size, cols, rows, (r + 1) * cols + (c + 1));
          canvas.drawLine(p0, p1, linePaint);
        } else {
          final p0 = cellCenter(size, cols, rows, r * cols + (c + 1));
          final p1 = cellCenter(size, cols, rows, (r + 1) * cols + c);
          canvas.drawLine(p0, p1, linePaint);
        }
      }
    }

    // 3. Draw intersection hubs & coordinate labels
    for (var cell = 0; cell < cols * rows; cell++) {
      final r = cell ~/ cols, c = cell % cols;
      final pt = cellCenter(size, cols, rows, cell);
      final strong = (r + c).isEven;
      if (strong) {
        canvas.drawCircle(
          pt,
          cw * 0.085,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.1, cw * 0.03)
            ..color = const Color(0x995D4037),
        );
      }
      canvas.drawCircle(pt, cw * 0.045, Paint()..color = const Color(0xFF4E342E));

      if (c == 0) {
        a5PaintTextCentered(
          canvas,
          '${rows - r}',
          pt + Offset(-cw * 0.34, -cw * 0.28),
          cw * 0.16,
          const Color(0xAA4E342E),
          weight: FontWeight.w600,
        );
      }
      if (r == rows - 1) {
        a5PaintTextCentered(
          canvas,
          String.fromCharCode(65 + c),
          pt + Offset(cw * 0.28, cw * 0.34),
          cw * 0.16,
          const Color(0xAA4E342E),
          weight: FontWeight.w600,
        );
      }
    }

    // 4. Draw multi-capture chain visited trail
    if (visited.length >= 2) {
      final trailPaint = Paint()
        ..color = const Color(0xCCFFA000)
        ..strokeWidth = max(2.2, cw * 0.075)
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i + 1 < visited.length; i++) {
        final p0 = cellCenter(size, cols, rows, visited[i]);
        final p1 = cellCenter(size, cols, rows, visited[i + 1]);
        canvas.drawLine(p0, p1, trailPaint);
      }
    }

    // 5. Draw last action highlights
    if (lastFrom >= 0 && lastTo >= 0 && lastFrom < cols * rows && lastTo < cols * rows) {
      final p0 = cellCenter(size, cols, rows, lastFrom);
      final p1 = cellCenter(size, cols, rows, lastTo);
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = const Color(0x991E88E5)
          ..strokeWidth = max(2.0, cw * 0.07)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(p0, cw * 0.12, Paint()..color = const Color(0x661E88E5));
    }
    for (final capCell in lastCaptured) {
      if (capCell < 0 || capCell >= cols * rows) continue;
      final pt = cellCenter(size, cols, rows, capCell);
      canvas.drawCircle(pt, cw * 0.20, Paint()..color = const Color(0x55E53935));
    }

    // 6. Draw pieces
    for (var cell = 0; cell < cols * rows; cell++) {
      final v = board[cell];
      if (v < 0) continue;
      final pt = cellCenter(size, cols, rows, cell);
      _paintStone(canvas, pt, cw, v);

      // Highlight capturable enemy lines when disambiguating Approach vs Withdrawal
      if (approachCells.contains(cell)) {
        canvas.drawCircle(
          pt,
          cw * 0.38,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.2, cw * 0.075)
            ..color = const Color(0xFFFF5722),
        );
        a5PaintTextCentered(canvas, '撞', pt, cw * 0.23, const Color(0xFFFF5722));
      } else if (withdrawCells.contains(cell)) {
        canvas.drawCircle(
          pt,
          cw * 0.38,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.2, cw * 0.075)
            ..color = const Color(0xFFAB47BC),
        );
        a5PaintTextCentered(canvas, '撤', pt, cw * 0.23, const Color(0xFFCE93D8));
      }
    }

    // 7. Highlight activeFrom piece
    if (activeFrom >= 0 && activeFrom < cols * rows) {
      final pt = cellCenter(size, cols, rows, activeFrom);
      canvas.drawCircle(
        pt,
        cw * 0.40,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.4, cw * 0.08)
          ..color = accent,
      );
    }

    // 8. Draw legal target indicators
    for (final t in moveTargets) {
      final pt = cellCenter(size, cols, rows, t);
      final isHover = t == hover || t == pendingTo;
      canvas.drawCircle(
        pt,
        cw * (isHover ? 0.22 : 0.16),
        Paint()..color = t == pendingTo ? const Color(0xEEFFB300) : const Color(0xDD43A047),
      );
      canvas.drawCircle(
        pt,
        cw * (isHover ? 0.22 : 0.16),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.2, cw * 0.035)
          ..color = Colors.white,
      );
    }

    canvas.restore();
  }

  void _paintStone(Canvas canvas, Offset c, double cw, int seat) {
    final r = cw * 0.33;
    canvas.drawCircle(c + Offset(r * 0.08, r * 0.16), r, a5Shadow(r * 0.2, alpha: 0.45));

    final isWhite = seat == 0;
    final colors = isWhite
        ? const [Color(0xFFFFFFFF), Color(0xFFF5EFE0), Color(0xFFC5B89E)]
        : const [Color(0xFF546E7A), Color(0xFF263238), Color(0xFF0E1518)];
    final rimColor = isWhite ? const Color(0xFF8D6E63) : const Color(0xFFFFD54F);

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
      r * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.1, r * 0.10)
        ..color = rimColor.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FanoronaBoardView extends StatefulWidget {
  final GameContext g;
  const FanoronaBoardView(this.g, {super.key});
  @override
  State<FanoronaBoardView> createState() => _FanoronaBoardViewState();
}

class _FanoronaBoardViewState extends State<FanoronaBoardView> {
  int selFrom = -1;
  int pendingTo = -1;
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
      pendingTo = -1;
    }

    final cols = (v['cols'] as int?) ?? 9;
    final rows = (v['rows'] as int?) ?? 5;
    final board = (v['board'] as List).cast<int>();
    final turn = v['turn'] as int;
    final chainPos = (v['chainPos'] as int?) ?? -1;
    final visited = ((v['visited'] as List?) ?? const []).cast<int>();
    final mustCapture = v['mustCapture'] == true;
    final rawMoves = (v['legalMoves'] as List?) ?? const [];
    final counts = (v['counts'] as List).cast<int>();
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;

    final lastFrom = (last?['from'] as int?) ?? -1;
    final lastTo = (last?['to'] as int?) ?? -1;
    final lastCaptured = ((last?['captured'] as List?) ?? const []).cast<int>().toSet();

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final activeFrom = chainPos >= 0 ? chainPos : selFrom;
    final legalMoves = [
      for (final m in rawMoves)
        FanoronaMove(
          from: (m as Map)['from'] as int,
          to: m['to'] as int,
          capture: m['capture'] as String?,
          capturedCells: ((m['capturedCells'] as List?) ?? const []).cast<int>(),
        ),
    ];

    final legalFromCells = {for (final m in legalMoves) m.from};
    final movesFromActive = [
      for (final m in legalMoves)
        if (m.from == activeFrom) m,
    ];
    final moveTargets = {for (final m in movesFromActive) m.to};

    final pendingMoves = [
      for (final m in movesFromActive)
        if (m.to == pendingTo) m,
    ];
    final approachCells = <int>{};
    final withdrawCells = <int>{};
    for (final m in pendingMoves) {
      if (m.capture == 'approach') approachCells.addAll(m.capturedCells);
      if (m.capture == 'withdraw') withdrawCells.addAll(m.capturedCells);
    }

    void tapCell(int c) {
      if (!myTurn || c < 0 || c >= cols * rows) return;

      // If disambiguating between Approach and Withdrawal, allow tapping a highlighted enemy piece
      if (pendingTo >= 0) {
        if (approachCells.contains(c)) {
          final f = activeFrom, t = pendingTo;
          setState(() {
            selFrom = -1;
            pendingTo = -1;
          });
          g.act({'type': 'move', 'from': f, 'to': t, 'capture': 'approach'});
          return;
        }
        if (withdrawCells.contains(c)) {
          final f = activeFrom, t = pendingTo;
          setState(() {
            selFrom = -1;
            pendingTo = -1;
          });
          g.act({'type': 'move', 'from': f, 'to': t, 'capture': 'withdraw'});
          return;
        }
      }

      if (activeFrom >= 0 && moveTargets.contains(c)) {
        final matching = [
          for (final m in movesFromActive)
            if (m.to == c) m,
        ];
        if (matching.length == 1) {
          final m = matching.single;
          setState(() {
            selFrom = -1;
            pendingTo = -1;
          });
          g.act(m.toAction());
          return;
        } else if (matching.length >= 2) {
          setState(() => pendingTo = c);
          return;
        }
      }

      if (chainPos < 0 && board[c] == turn) {
        if (legalFromCells.contains(c)) {
          setState(() {
            selFrom = selFrom == c ? -1 : c;
            pendingTo = -1;
          });
        }
      }
    }

    String status;
    if (over) {
      status = result;
    } else if (myTurn) {
      final sideName = turn == 0 ? '白方' : '黑方';
      if (pendingTo >= 0) {
        status = '移动 ${fanoronaCoord(cols, rows, activeFrom)}→${fanoronaCoord(cols, rows, pendingTo)} 可前后双吃：请选择【撞击吃】或【后撤吃】！';
      } else if (chainPos >= 0) {
        status = '连续追击中（当前位于 ${fanoronaCoord(cols, rows, chainPos)}）：点击绿点继续吃子，或点“结束追击”';
      } else if (activeFrom >= 0) {
        status = '已选 ${fanoronaCoord(cols, rows, activeFrom)}：请点击相邻绿点移动${mustCapture ? '吃子' : ''}';
      } else {
        final capHint = mustCapture ? '（有吃必吃！）' : '（当前无吃子，可走普通步）';
        status = '轮到你（$sideName）：请点选己方棋子沿实线移动$capHint';
      }
    } else {
      final sideName = turn == 0 ? '白方' : '黑方';
      status = '等待 ${g.name(turn)}（$sideName）行动';
    }

    final actions = <Widget>[];
    if (myTurn) {
      if (pendingTo >= 0) {
        actions.add(a5Button(
          context,
          '撞击吃 (${approachCells.length}子)',
          Icons.arrow_forward,
          () {
            final f = activeFrom, t = pendingTo;
            setState(() {
              selFrom = -1;
              pendingTo = -1;
            });
            g.act({'type': 'move', 'from': f, 'to': t, 'capture': 'approach'});
          },
          primary: true,
        ));
        actions.add(a5Button(
          context,
          '后撤吃 (${withdrawCells.length}子)',
          Icons.arrow_back,
          () {
            final f = activeFrom, t = pendingTo;
            setState(() {
              selFrom = -1;
              pendingTo = -1;
            });
            g.act({'type': 'move', 'from': f, 'to': t, 'capture': 'withdraw'});
          },
          primary: true,
        ));
        actions.add(a5Button(
          context,
          '重选落点',
          Icons.undo,
          () => setState(() => pendingTo = -1),
        ));
      } else if (chainPos >= 0) {
        actions.add(a5Button(
          context,
          '结束追击',
          Icons.check_circle_outline,
          () => g.act({'type': 'end_turn'}),
          primary: true,
        ));
      } else if (selFrom >= 0) {
        actions.add(a5Button(
          context,
          '取消选择',
          Icons.clear,
          () => setState(() {
            selFrom = -1;
            pendingTo = -1;
          }),
        ));
      }
    }

    final boardWidget = LayoutBuilder(builder: (context, c) {
      final cw = min(c.maxWidth / cols, c.maxHeight / rows);
      final bSize = Size(cw * cols, cw * rows);
      return Center(
        child: MouseRegion(
          onHover: (e) {
            final p = _FanoronaPainter.hit(bSize, cols, rows, e.localPosition);
            if (p != hover) setState(() => hover = p);
          },
          onExit: (_) => setState(() => hover = -1),
          child: GestureDetector(
            onTapUp: (d) => tapCell(_FanoronaPainter.hit(bSize, cols, rows, d.localPosition)),
            child: CustomPaint(
              size: bSize,
              painter: _FanoronaPainter(
                cols: cols,
                rows: rows,
                board: board,
                activeFrom: activeFrom,
                pendingTo: pendingTo,
                moveTargets: moveTargets,
                approachCells: approachCells,
                withdrawCells: withdrawCells,
                visited: visited,
                hover: hover,
                lastFrom: lastFrom,
                lastTo: lastTo,
                lastCaptured: lastCaptured,
                accent: cs.primary,
              ),
            ),
          ),
        ),
      );
    });

    Widget tagFor(int s) {
      final sideLabel = s == 0 ? '白方' : '黑方';
      final stateLabel = over ? (winner == s ? ' · 胜' : (winner == 2 ? ' · 和' : ' · 负')) : ' · 剩余 ${counts[s]} 子';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sideLabel$stateLabel',
        trailing: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: s == 0 ? const Color(0xFFF5EFE0) : const Color(0xFF263238),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF6D4C41), width: 1.5),
          ),
        ),
      );
    }

    return A5Shell(
      tags: [for (var s = 0; s < g.players; s++) tagFor(s)],
      status: status,
      statusHighlight: myTurn,
      aspect: cols / rows,
      board: boardWidget,
      actions: actions,
      info: [
        if (note.isNotEmpty) '动态：$note',
        '规则：强交点可走 8 方向，弱交点仅走 4 正交方向；撞击吃或后撤吃将消灭该方向线上连续紧邻的全部敌子！',
      ],
      result: a5Banner(g, over, winner, g.players),
      resultSub: over ? result : null,
    );
  }
}
