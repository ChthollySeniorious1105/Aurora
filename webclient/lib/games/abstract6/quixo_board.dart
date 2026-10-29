import 'dart:math';

import 'package:aurora_shared/games/abstract6/quixo.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

class _QuixoPainter extends CustomPainter {
  final List<int> board;
  final int selFrom;
  final Set<int> moveTargets;
  final int hover;
  final int lastFrom;
  final int lastTo;
  final Set<int> lastShifted;
  final Set<int> winningLine;
  final int turn;
  final bool myTurn;
  final Color accent;

  _QuixoPainter({
    required this.board,
    required this.selFrom,
    required this.moveTargets,
    required this.hover,
    required this.lastFrom,
    required this.lastTo,
    required this.lastShifted,
    required this.winningLine,
    required this.turn,
    required this.myTurn,
    required this.accent,
  });

  static const int n = 5;

  static Rect cellRect(Size s, int cell) {
    final pad = s.width * 0.055;
    final inner = s.width - pad * 2;
    final cw = inner / n;
    final x = cell % n, y = cell ~/ n;
    return Rect.fromLTWH(pad + x * cw, pad + y * cw, cw, cw);
  }

  static int hit(Size s, Offset o) {
    if (s.width <= 0 || s.height <= 0) return -1;
    final pad = s.width * 0.055;
    final inner = s.width - pad * 2;
    final cw = inner / n;
    final x = ((o.dx - pad) / cw).floor();
    final y = ((o.dy - pad) / cw).floor();
    if (x < 0 || x >= n || y < 0 || y >= n) return -1;
    return y * n + x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.width * 0.055;
    final inner = size.width - pad * 2;
    final cw = inner / n;

    // Warm rosewood outer tray
    final outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cw * 0.28));
    canvas.drawRRect(outer.shift(Offset(0, cw * 0.06)), a6Shadow(cw * 0.16, alpha: 0.45));
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5D4037), Color(0xFF3E2723), Color(0xFF271815)],
        ).createShader(Offset.zero & size),
    );

    // Recessed inner tray well
    final wellRect = Rect.fromLTWH(pad * 0.85, pad * 0.85, size.width - pad * 1.7, size.height - pad * 1.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(wellRect, Radius.circular(cw * 0.18)),
      Paint()..color = const Color(0xFF1F120E),
    );

    // Draw the 25 cubes
    for (var cell = 0; cell < 25; cell++) {
      final rawRect = cellRect(size, cell);
      final cubeRect = rawRect.deflate(cw * 0.055);
      final r = cell ~/ n, c = cell % n;
      final isOuter = Quixo.isOuter(cell);
      final v = board[cell];
      final isSel = cell == selFrom;
      final isTarget = moveTargets.contains(cell);
      final isWin = winningLine.contains(cell);
      final isShifted = lastShifted.contains(cell);

      // Cube shadow
      final cubeRRect = RRect.fromRectAndRadius(cubeRect, Radius.circular(cw * 0.16));
      canvas.drawRRect(cubeRRect.shift(Offset(0, cw * 0.04)), a6Shadow(cw * 0.08, alpha: 0.4));

      // Beechwood cube top face gradient
      List<Color> woodColors;
      if (isWin) {
        woodColors = const [Color(0xFFFFF59D), Color(0xFFFFD54F)];
      } else if (isSel) {
        woodColors = const [Color(0xFFFFE082), Color(0xFFFFB300)];
      } else if (isOuter) {
        woodColors = const [Color(0xFFF5E6CC), Color(0xFFE2C799)];
      } else {
        // Inner 3x3 slightly darker wood to distinguish from pickable border
        woodColors = const [Color(0xFFE6D2B5), Color(0xFFCDB28A)];
      }

      canvas.drawRRect(
        cubeRRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: woodColors,
          ).createShader(cubeRect),
      );

      // Highlight shifted cubes from last push
      if (isShifted && !isSel && !isWin) {
        canvas.drawRRect(
          cubeRRect,
          Paint()..color = const Color(0x3342A5F5),
        );
      }

      // Cube bevel border
      canvas.drawRRect(
        cubeRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSel || isWin ? max(2.2, cw * 0.06) : max(1.0, cw * 0.025)
          ..color = isSel
              ? accent
              : (isWin
                  ? const Color(0xFFF57F17)
                  : (cell == lastTo ? const Color(0xFF1E88E5) : const Color(0x885D4037))),
      );

      // Draw top face symbol: 0 = Blank (subtle wood grain dot on outer border), 1 = Cross ✕, 2 = Circle ◯
      final center = cubeRect.center;
      if (v == 1) {
        // Engraved crimson Cross (X)
        final arm = cw * 0.23;
        final xPaint = Paint()
          ..color = const Color(0xFFB71C1C)
          ..strokeWidth = max(2.8, cw * 0.10)
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(center + Offset(-arm, -arm), center + Offset(arm, arm), xPaint);
        canvas.drawLine(center + Offset(arm, -arm), center + Offset(-arm, arm), xPaint);
      } else if (v == 2) {
        // Engraved deep-navy Circle (O)
        canvas.drawCircle(
          center,
          cw * 0.25,
          Paint()
            ..color = const Color(0xFF0D47A1)
            ..strokeWidth = max(2.8, cw * 0.10)
            ..style = PaintingStyle.stroke,
        );
      } else if (isOuter && myTurn && selFrom < 0) {
        // Small dot indicating pickable blank border cube
        canvas.drawCircle(
          center,
          cw * 0.055,
          Paint()..color = const Color(0x555D4037),
        );
      }

      // Coordinate labels on border cubes
      if (c == 0) {
        a6PaintTextCentered(
          canvas,
          '${5 - r}',
          cubeRect.topLeft + Offset(cw * 0.13, cw * 0.14),
          cw * 0.15,
          const Color(0x884E342E),
        );
      }
      if (r == 4) {
        a6PaintTextCentered(
          canvas,
          String.fromCharCode(65 + c),
          cubeRect.bottomRight - Offset(cw * 0.13, cw * 0.13),
          cw * 0.15,
          const Color(0x884E342E),
        );
      }

      // Draw push target overlay
      if (isTarget) {
        final isHover = cell == hover;
        canvas.drawRRect(
          cubeRRect,
          Paint()..color = const Color(0xFF2E7D32).withValues(alpha: isHover ? 0.42 : 0.24),
        );
        final sr = selFrom ~/ n, sc = selFrom % n;
        String arrow = '●';
        if (r == sr) {
          arrow = c < sc ? '▶' : '◀';
        } else if (c == sc) {
          arrow = r < sr ? '▼' : '▲';
        }
        canvas.drawCircle(
          center,
          cw * (isHover ? 0.24 : 0.20),
          Paint()..color = const Color(0xEE2E7D32),
        );
        a6PaintTextCentered(canvas, arrow, center, cw * 0.22, Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class QuixoBoardView extends StatefulWidget {
  final GameContext g;
  const QuixoBoardView(this.g, {super.key});
  @override
  State<QuixoBoardView> createState() => _QuixoBoardViewState();
}

class _QuixoBoardViewState extends State<QuixoBoardView> {
  int selFrom = -1;
  int hover = -1;
  Object? _lastPlies;

  GameContext get g => widget.g;

  bool _canPick(List<int> board, int seat, int cell) {
    if (!Quixo.isOuter(cell)) return false;
    final v = board[cell];
    return v == 0 || v == seat + 1;
  }

  Set<int> _legalTargets(int from) {
    if (!Quixo.isOuter(from)) return const {};
    final r = from ~/ 5, c = from % 5;
    return {
      r * 5 + 0,
      r * 5 + 4,
      0 * 5 + c,
      4 * 5 + c,
    }..remove(from);
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
    final counts = ((v['counts'] as List?) ?? const [0, 0]).cast<int>();
    final winningLine = ((v['winningLine'] as List?) ?? const []).cast<int>().toSet();
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;

    final lastFrom = (last?['from'] as int?) ?? -1;
    final lastTo = (last?['to'] as int?) ?? -1;
    final lastShifted = ((last?['shifted'] as List?) ?? const []).cast<int>().toSet();

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final moveTargets = <int>{};
    if (myTurn && selFrom >= 0 && _canPick(board, turn, selFrom)) {
      moveTargets.addAll(_legalTargets(selFrom));
    }

    void tapCell(int c) {
      if (!myTurn || c < 0 || c >= 25) return;
      if (selFrom >= 0 && moveTargets.contains(c)) {
        final f = selFrom;
        setState(() => selFrom = -1);
        g.act({'type': 'push', 'from': f, 'to': c});
        return;
      }
      if (_canPick(board, turn, c)) {
        setState(() => selFrom = selFrom == c ? -1 : c);
      }
    }

    final sym = turn == 0 ? '✕' : '◯';
    String status;
    if (over) {
      status = result;
    } else if (myTurn) {
      if (selFrom < 0) {
        status = '轮到你（$sym 方）：请点选外圈 16 格中的空白或己方（$sym）方块';
      } else {
        status = '已拿起 ${quixoCoord(selFrom)}：请点击同行或同列带绿色箭头的端点推入！';
      }
    } else {
      status = '等待 ${g.name(turn)}（$sym 方）抽取并推入方块';
    }

    final actions = <Widget>[];
    if (myTurn && selFrom >= 0) {
      actions.add(a6Button(
        context,
        '放回方块',
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
            final p = _QuixoPainter.hit(bSize, e.localPosition);
            if (p != hover) setState(() => hover = p);
          },
          onExit: (_) => setState(() => hover = -1),
          child: GestureDetector(
            onTapUp: (d) => tapCell(_QuixoPainter.hit(bSize, d.localPosition)),
            child: CustomPaint(
              size: bSize,
              painter: _QuixoPainter(
                board: board,
                selFrom: selFrom,
                moveTargets: moveTargets,
                hover: hover,
                lastFrom: lastFrom,
                lastTo: lastTo,
                lastShifted: lastShifted,
                winningLine: winningLine,
                turn: turn,
                myTurn: myTurn,
                accent: cs.primary,
              ),
            ),
          ),
        ),
      );
    });

    Widget tagFor(int s) {
      final sSym = s == 0 ? '✕ 红叉' : '◯ 蓝圆';
      final cnt = counts[s];
      final stateLabel = over ? (winner == s ? ' · 胜' : (winner == 2 ? ' · 和' : ' · 负')) : ' · 盘面 $cnt 枚';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$sSym$stateLabel',
        trailing: Text(
          s == 0 ? '✕' : '◯',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: s == 0 ? const Color(0xFFB71C1C) : const Color(0xFF0D47A1),
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
        '规则：只能拿外圈空白或己方方块，翻转成己方符号后从同行/同列端点推入；横竖斜 5 连即胜（若推入促成对手 5 连则对手获胜）。',
      ],
      result: a6Banner(g, over, winner, g.players),
      resultSub: over ? result : null,
    );
  }
}
