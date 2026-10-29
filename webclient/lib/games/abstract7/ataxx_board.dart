import 'dart:math';

import 'package:aurora_shared/games/abstract7/ataxx.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

class _AtaxxPainter extends CustomPainter {
  final List<int> board;
  final int selFrom;
  final Set<int> moveTargets;
  final int hover;
  final int lastFrom;
  final int lastTo;
  final Set<int> lastInfected;
  final Color accent;

  _AtaxxPainter({
    required this.board,
    required this.selFrom,
    required this.moveTargets,
    required this.hover,
    required this.lastFrom,
    required this.lastTo,
    required this.lastInfected,
    required this.accent,
  });

  static Rect cellRect(Size s, int cell) {
    final cw = s.width / ataxxSize;
    final x = cell % ataxxSize, y = cell ~/ ataxxSize;
    return Rect.fromLTWH(x * cw, y * cw, cw, cw);
  }

  static int hit(Size s, Offset o) {
    if (s.width <= 0 || s.height <= 0) return -1;
    final cw = s.width / ataxxSize;
    final x = (o.dx / cw).floor(), y = (o.dy / cw).floor();
    if (x < 0 || x >= ataxxSize || y < 0 || y >= ataxxSize) return -1;
    return y * ataxxSize + x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / ataxxSize;
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cw * 0.22));
    canvas.drawRRect(outer.shift(Offset(0, cw * 0.06)), a7Shadow(cw * 0.14, alpha: 0.45));

    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF263238), Color(0xFF141C20)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(outer.deflate(cw * 0.04));

    for (var cell = 0; cell < ataxxCells; cell++) {
      final r = cellRect(size, cell);
      final row = cell ~/ ataxxSize, col = cell % ataxxSize;
      final light = (row + col).isEven;
      final v = board[cell];

      if (v == -2) {
        // Blocked wall obstacle
        canvas.drawRect(r, Paint()..color = const Color(0xFF1A2226));
        final block = RRect.fromRectAndRadius(r.deflate(cw * 0.1), Radius.circular(cw * 0.14));
        canvas.drawRRect(
          block,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF546E7A), Color(0xFF37474F), Color(0xFF263238)],
            ).createShader(r),
        );
        canvas.drawRRect(
          block,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.2, cw * 0.035)
            ..color = const Color(0xFF90A4AE).withValues(alpha: 0.45),
        );
        a7PaintTextCentered(canvas, '❖', r.center, cw * 0.34, const Color(0x99CFD8DC));
        continue;
      }

      canvas.drawRect(
        r,
        Paint()..color = light ? const Color(0xFF2B3942) : const Color(0xFF212C33),
      );
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = const Color(0x3390A4AE),
      );

      if (cell == lastFrom || cell == lastTo) {
        canvas.drawRect(
          r,
          Paint()..color = cell == lastTo ? const Color(0x4442A5F5) : const Color(0x2842A5F5),
        );
      }

      if (col == 0) {
        a7PaintTextCentered(
          canvas,
          '${ataxxSize - row}',
          r.topLeft + Offset(cw * 0.14, cw * 0.15),
          cw * 0.17,
          const Color(0x8890A4AE),
          weight: FontWeight.w600,
        );
      }
      if (row == ataxxSize - 1) {
        a7PaintTextCentered(
          canvas,
          String.fromCharCode(65 + col),
          r.bottomRight - Offset(cw * 0.14, cw * 0.15),
          cw * 0.17,
          const Color(0x8890A4AE),
          weight: FontWeight.w600,
        );
      }
    }

    // Last move line
    if (lastFrom >= 0 && lastTo >= 0 && lastFrom < ataxxCells && lastTo < ataxxCells) {
      final p0 = cellRect(size, lastFrom).center;
      final p1 = cellRect(size, lastTo).center;
      final d = Ataxx.chebyshevDist(lastFrom, lastTo);
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = d == 1 ? const Color(0x9966BB6A) : const Color(0x9929B6F6)
          ..strokeWidth = max(1.8, cw * 0.065)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Selected cell highlight
    if (selFrom >= 0 && selFrom < ataxxCells) {
      final r = cellRect(size, selFrom).deflate(cw * 0.05);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cw * 0.15)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(2.2, cw * 0.075)
          ..color = const Color(0xFFFFD54F),
      );
    }

    // Draw pieces & infected rings
    for (var cell = 0; cell < ataxxCells; cell++) {
      final v = board[cell];
      if (v != 0 && v != 1) continue;
      final c = cellRect(size, cell).center;
      _paintOrb(canvas, c, cw, v, infected: lastInfected.contains(cell));
    }

    // Draw legal targets:
    // Distance 1 (Clone) = green circle with '+', Distance 2 (Jump) = cyan ring
    for (final t in moveTargets) {
      final r = cellRect(size, t);
      final isHover = t == hover;
      final dist = selFrom >= 0 ? Ataxx.chebyshevDist(selFrom, t) : 1;
      if (dist == 1) {
        final rad = cw * (isHover ? 0.23 : 0.18);
        canvas.drawCircle(
          r.center,
          rad,
          Paint()..color = const Color(0xDD43A047),
        );
        canvas.drawCircle(
          r.center,
          rad,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.2, cw * 0.03)
            ..color = Colors.white,
        );
        a7PaintTextCentered(canvas, '+', r.center, rad * 1.25, Colors.white);
      } else {
        final rad = cw * (isHover ? 0.25 : 0.20);
        canvas.drawCircle(
          r.center,
          rad,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.0, cw * 0.065)
            ..color = const Color(0xDD29B6F6),
        );
      }
    }

    canvas.restore();
  }

  void _paintOrb(Canvas canvas, Offset c, double cw, int seat, {bool infected = false}) {
    final r = cw * 0.36;
    canvas.drawCircle(c + Offset(r * 0.08, r * 0.16), r, a7Shadow(r * 0.22, alpha: 0.48));

    final colors = seat == 0
        ? const [Color(0xFFFFCDD2), Color(0xFFE53935), Color(0xFF8E0000)]
        : const [Color(0xFFB3E5FC), Color(0xFF039BE5), Color(0xFF01579B)];
    final rimColor = seat == 0 ? const Color(0xFFFF8A80) : const Color(0xFF80D8FF);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.38),
          colors: colors,
          stops: const [0.0, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.1, r * 0.10)
        ..color = rimColor.withValues(alpha: 0.75),
    );

    if (infected) {
      canvas.drawCircle(
        c,
        r * 1.08,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.8, cw * 0.055)
          ..color = const Color(0xFFFFB300),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AtaxxBoardView extends StatefulWidget {
  final GameContext g;
  const AtaxxBoardView(this.g, {super.key});
  @override
  State<AtaxxBoardView> createState() => _AtaxxBoardViewState();
}

class _AtaxxBoardViewState extends State<AtaxxBoardView> {
  int selFrom = -1;
  int hover = -1;
  Object? _lastPlies;

  GameContext get g => widget.g;

  List<int> _legalTargets(List<int> board, int from) {
    final out = <int>[];
    if (from < 0 || from >= ataxxCells) return out;
    final s = board[from];
    if (s != 0 && s != 1) return out;
    final r0 = from ~/ ataxxSize, c0 = from % ataxxSize;
    for (var dr = -2; dr <= 2; dr++) {
      final nr = r0 + dr;
      if (nr < 0 || nr >= ataxxSize) continue;
      for (var dc = -2; dc <= 2; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nc = c0 + dc;
        if (nc < 0 || nc >= ataxxSize) continue;
        final idx = nr * ataxxSize + nc;
        if (board[idx] == -1) out.add(idx);
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

    final board = (v['board'] as List).cast<int>();
    final turn = v['turn'] as int;
    final counts = ((v['counts'] as List?) ?? const [2, 2]).cast<int>();
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;

    final lastFrom = (last?['from'] as int?) ?? -1;
    final lastTo = (last?['to'] as int?) ?? -1;
    final lastInfected = ((last?['infected'] as List?) ?? const []).cast<int>().toSet();

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final moveTargets = <int>{};
    if (myTurn && selFrom >= 0 && selFrom < ataxxCells && board[selFrom] == turn) {
      moveTargets.addAll(_legalTargets(board, selFrom));
    }

    void tapCell(int c) {
      if (!myTurn || c < 0 || c >= ataxxCells) return;
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

    final sideName = turn == 0 ? '赤晶方' : '蓝珀方';
    String status;
    if (over) {
      status = result;
    } else if (myTurn) {
      if (selFrom < 0) {
        status = '轮到你（$sideName）：请点选一枚己方棋子进行分裂或跳跃';
      } else {
        status = '已选 ${ataxxCoord(selFrom)}：绿点(+)为1格分裂增殖，蓝圈为2格跳跃移位（落点8邻同化）';
      }
    } else {
      status = '等待 ${g.name(turn)}（$sideName）行动';
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

    final boardWidget = LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      final bSize = Size(side, side);
      return Center(
        child: MouseRegion(
          onHover: (e) {
            final p = _AtaxxPainter.hit(bSize, e.localPosition);
            if (p != hover) setState(() => hover = p);
          },
          onExit: (_) => setState(() => hover = -1),
          child: GestureDetector(
            onTapUp: (d) => tapCell(_AtaxxPainter.hit(bSize, d.localPosition)),
            child: CustomPaint(
              size: bSize,
              painter: _AtaxxPainter(
                board: board,
                selFrom: selFrom,
                moveTargets: moveTargets,
                hover: hover,
                lastFrom: lastFrom,
                lastTo: lastTo,
                lastInfected: lastInfected,
                accent: cs.primary,
              ),
            ),
          ),
        ),
      );
    });

    Widget tagFor(int s) {
      final sideLabel = s == 0 ? '赤晶' : '蓝珀';
      final cnt = counts[s];
      final stateLabel = over ? (winner == s ? ' · 胜($cnt子)' : (winner == 2 ? ' · 和($cnt子)' : ' · 负($cnt子)')) : ' · 领地 $cnt';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sideLabel$stateLabel',
        trailing: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: s == 0 ? const Color(0xFFE53935) : const Color(0xFF039BE5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 1.5),
          ),
        ),
      );
    }

    return A7Shell(
      tags: [for (var s = 0; s < g.players; s++) tagFor(s)],
      status: status,
      statusHighlight: myTurn,
      aspect: 1,
      board: boardWidget,
      actions: actions,
      info: [
        if (note.isNotEmpty) '动态：$note',
        '规则：向邻格移动（绿+）会分裂增殖新子，跨1格移动（蓝圈）会跳跃移位；落点周围8格内的敌子全部翻转同化！',
      ],
      result: a7Banner(g, over, winner, g.players),
      resultSub: over ? result : null,
    );
  }
}
