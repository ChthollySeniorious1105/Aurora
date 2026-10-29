import 'dart:math';

import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/abstract3/abalone.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'common.dart';

Offset _hexOffset(AbHex h, double s) => Offset(sqrt(3) * s * (h.$1 + h.$2 * 0.5), 1.5 * s * h.$2);

class _AbalonePainter extends CustomPainter {
  final List<int> board;
  final Set<AbHex> selected;
  final List<AbaloneMove> activeMoves;
  final AbHex? hover;
  final Set<AbHex> lastFrom;
  final Set<AbHex> lastTo;
  final Set<AbHex> lastPushed;
  final Color accent;

  _AbalonePainter({
    required this.board,
    required this.selected,
    required this.activeMoves,
    required this.hover,
    required this.lastFrom,
    required this.lastTo,
    required this.lastPushed,
    required this.accent,
  });

  static double cellRadius(Size size) => min(size.width, size.height) / 16.4;

  static Offset cellCenter(Size size, AbHex h) {
    final s = cellRadius(size);
    return Offset(size.width / 2, size.height / 2) + _hexOffset(h, s);
  }

  static AbHex? hit(Size size, Offset pos) {
    final s = cellRadius(size);
    if (s <= 0) return null;
    final p = (pos - Offset(size.width / 2, size.height / 2)) / s;
    final qf = sqrt(3) / 3 * p.dx - p.dy / 3;
    final rf = 2 / 3 * p.dy;
    var x = qf, z = rf, y = -x - z;
    var rx = x.roundToDouble(), ry = y.roundToDouble(), rz = z.roundToDouble();
    final dx = (rx - x).abs(), dy = (ry - y).abs(), dz = (rz - z).abs();
    if (dx > dy && dx > dz) {
      rx = -ry - rz;
    } else if (dy > dz) {
      ry = -rx - rz;
    } else {
      rz = -rx - ry;
    }
    final h = (rx.toInt(), rz.toInt());
    return abOnBoard(h.$1, h.$2) ? h : null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = cellRadius(size);
    final center = Offset(size.width / 2, size.height / 2);

    // Draw outer hexagonal board frame (pointy-top outer rim around flat-row grid)
    final outerR = s * 8.1;
    final rimPath = Path();
    for (var i = 0; i < 6; i++) {
      final a = pi / 3 * i;
      final pt = center + Offset(cos(a) * outerR, sin(a) * outerR);
      i == 0 ? rimPath.moveTo(pt.dx, pt.dy) : rimPath.lineTo(pt.dx, pt.dy);
    }
    rimPath.close();

    canvas.drawPath(rimPath.shift(Offset(0, s * 0.18)), a3Shadow(s * 0.35, alpha: 0.5));
    canvas.drawPath(
      rimPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF37474F), Color(0xFF263238), Color(0xFF1C262B)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      rimPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.0, s * 0.16)
        ..color = const Color(0xFF546E7A),
    );

    // Draw all 61 sockets and marbles
    for (var i = 0; i < abaloneCells.length; i++) {
      final h = abaloneCells[i];
      final c = center + _hexOffset(h, s);
      final socketR = s * 0.72;

      // Sunken socket
      canvas.drawCircle(
        c,
        socketR,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.25, 0.25),
            colors: const [Color(0xFF303E45), Color(0xFF161F24)],
          ).createShader(Rect.fromCircle(center: c, radius: socketR)),
      );

      // Highlight last move origins
      if (lastFrom.contains(h) && board[i] == -1) {
        canvas.drawCircle(
          c,
          socketR * 0.85,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.2, s * 0.08)
            ..color = const Color(0x88FFD54F),
        );
      }

      final v = board[i];
      if (v == 0 || v == 1) {
        _paintMarble(canvas, c, s * 0.74, v == 0);
      }

      if (lastTo.contains(h)) {
        canvas.drawCircle(
          c,
          s * 0.78,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.5, s * 0.1)
            ..color = const Color(0xCCFFD54F),
        );
      }
      if (lastPushed.contains(h)) {
        canvas.drawCircle(
          c,
          s * 0.78,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.5, s * 0.1)
            ..color = const Color(0xCCFF7043),
        );
      }
      if (selected.contains(h)) {
        canvas.drawCircle(
          c,
          s * 0.80,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.2, s * 0.15)
            ..color = accent,
        );
      }
    }

    // Draw legal move destinations & directional indicators for the current selection
    final destCells = <AbHex, List<AbaloneMove>>{};
    for (final mv in activeMoves) {
      final (dq, dr) = abDirs[mv.dir];
      if (mv.inLine) {
        final head = mv.marbles.last;
        final target = (head.$1 + dq, head.$2 + dr);
        (destCells[target] ??= []).add(mv);
      } else {
        for (final m in mv.marbles) {
          final target = (m.$1 + dq, m.$2 + dr);
          (destCells[target] ??= []).add(mv);
        }
      }
    }

    for (final entry in destCells.entries) {
      final h = entry.key;
      final mvs = entry.value;
      final c = center + _hexOffset(h, s);
      final isHover = h == hover;
      final anyEject = mvs.any((m) => m.ejects);
      final anyPush = mvs.any((m) => m.pushed.isNotEmpty);
      final color = anyEject
          ? const Color(0xFFE53935)
          : (anyPush ? const Color(0xFFFF8F00) : const Color(0xFF43A047));

      canvas.drawCircle(
        c,
        s * (isHover ? 0.74 : 0.66),
        Paint()..color = color.withValues(alpha: isHover ? 0.52 : 0.34),
      );
      canvas.drawCircle(
        c,
        s * (isHover ? 0.74 : 0.66),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.6, s * 0.1)
          ..color = color,
      );
      if (anyEject) {
        a3PaintTextCentered(canvas, '击落', c, s * 0.42, Colors.white);
      } else if (anyPush) {
        a3PaintTextCentered(canvas, '推', c, s * 0.48, Colors.white);
      } else if (mvs.length == 1) {
        a3PaintTextCentered(canvas, abDirNames[mvs.first.dir], c, s * 0.38, Colors.white);
      }
    }
  }

  void _paintMarble(Canvas canvas, Offset c, double r, bool isBlack) {
    canvas.drawCircle(c + Offset(r * 0.12, r * 0.2), r, a3Shadow(r * 0.22, alpha: 0.55));
    final colors = isBlack
        ? const [Color(0xFF78909C), Color(0xFF263238), Color(0xFF0A0E11)]
        : const [Color(0xFFFFFFFF), Color(0xFFECEFF1), Color(0xFFB0BEC5)];
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.38, -0.42),
          radius: 0.95,
          colors: colors,
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Specular highlight dot
    canvas.drawCircle(
      c + Offset(-r * 0.28, -r * 0.3),
      r * 0.18,
      Paint()..color = Colors.white.withValues(alpha: isBlack ? 0.35 : 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AbaloneBoardView extends StatefulWidget {
  final GameContext g;
  const AbaloneBoardView(this.g, {super.key});
  @override
  State<AbaloneBoardView> createState() => _AbaloneBoardViewState();
}

class _AbaloneBoardViewState extends State<AbaloneBoardView> {
  final Set<AbHex> selected = {};
  AbHex? hover;
  Object? _lastPlies;

  GameContext get g => widget.g;

  static bool _isValidSelection(List<int> board, int color, Set<AbHex> cells) {
    if (cells.isEmpty || cells.length > 3) return false;
    for (final (q, r) in cells) {
      final idx = abIndex(q, r);
      if (idx < 0 || board[idx] != color) return false;
    }
    if (cells.length == 1) return true;
    for (var axis = 0; axis < 3; axis++) {
      final (aq, ar) = abDirs[axis];
      for (final start in cells) {
        final m1 = (start.$1 + aq, start.$2 + ar);
        if (!cells.contains(m1)) continue;
        if (cells.length == 2) return true;
        final m2 = (start.$1 + aq * 2, start.$2 + ar * 2);
        if (cells.contains(m2)) return true;
      }
    }
    return false;
  }

  static List<AbaloneMove> _movesForSelection(List<int> board, int color, Set<AbHex> sel) {
    if (sel.isEmpty) return const [];
    final engine = Abalone(GameSetup(
      players: 2,
      options: const {},
      names: const ['P0', 'P1'],
      bots: const [false, false],
    ));
    engine.board.setAll(0, board);
    final list = sel.toList();
    final out = <AbaloneMove>[];
    for (var d = 0; d < 6; d++) {
      final mv = engine.validateMove(color, list, d);
      if (mv != null) out.add(mv);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    if (_lastPlies != v['plies']) {
      _lastPlies = v['plies'];
      selected.clear();
    }

    final board = (v['board'] as List).cast<int>();
    final ejected = (v['ejected'] as List).cast<int>();
    final winEjected = (v['winEjected'] as int?) ?? 6;
    final turn = v['turn'] as int;
    final plies = v['plies'] as int;
    final maxPlies = (v['maxPlies'] as int?) ?? 200;
    final over = v['over'] == true;
    final winner = v['winner'] as int;
    final result = v['result'] as String;
    final note = v['note'] as String;
    final last = v['last'] as Map?;

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final lastFrom = <AbHex>{
      if (last?['from'] is List)
        for (final c in last!['from'] as List) ((c[0] as int), (c[1] as int)),
    };
    final lastTo = <AbHex>{
      if (last?['to'] is List)
        for (final c in last!['to'] as List) ((c[0] as int), (c[1] as int)),
    };
    final lastPushed = <AbHex>{
      if (last?['pushed'] is List)
        for (final c in last!['pushed'] as List) ((c[0] as int), (c[1] as int)),
    };

    final activeMoves = myTurn ? _movesForSelection(board, turn, selected) : const <AbaloneMove>[];

    void executeMove(AbaloneMove mv) {
      g.act(mv.toAction());
      setState(() => selected.clear());
    }

    void tapHex(AbHex h, Size boardSize, Offset localPos) {
      if (!myTurn) return;
      final idx = abIndex(h.$1, h.$2);
      if (idx < 0) return;

      // Check if tapping a destination cell of the currently selected marbles
      if (selected.isNotEmpty && board[idx] != turn) {
        final matching = <AbaloneMove>[];
        for (final mv in activeMoves) {
          final (dq, dr) = abDirs[mv.dir];
          if (mv.inLine) {
            final head = mv.marbles.last;
            if ((head.$1 + dq, head.$2 + dr) == h) matching.add(mv);
          } else {
            if (mv.marbles.any((m) => (m.$1 + dq, m.$2 + dr) == h)) {
              matching.add(mv);
            }
          }
        }
        if (matching.length == 1) {
          executeMove(matching.first);
          return;
        }
        if (matching.length > 1) {
          // Pick the move whose shifted group center is closest to the tap position
          AbaloneMove best = matching.first;
          var bestDist = double.infinity;
          for (final mv in matching) {
            final (dq, dr) = abDirs[mv.dir];
            var cx = 0.0, cy = 0.0;
            for (final m in mv.marbles) {
              final pt = _AbalonePainter.cellCenter(boardSize, (m.$1 + dq, m.$2 + dr));
              cx += pt.dx;
              cy += pt.dy;
            }
            cx /= mv.marbles.length;
            cy /= mv.marbles.length;
            final d2 = (Offset(cx, cy) - localPos).distanceSquared;
            if (d2 < bestDist) {
              bestDist = d2;
              best = mv;
            }
          }
          executeMove(best);
          return;
        }
      }

      // Tapping an own marble updates selection
      if (board[idx] == turn) {
        setState(() {
          if (selected.contains(h)) {
            final next = Set<AbHex>.of(selected)..remove(h);
            if (_isValidSelection(board, turn, next)) {
              selected
                ..clear()
                ..addAll(next);
            } else {
              // Tapped middle of 3 -> select just that marble
              selected
                ..clear()
                ..add(h);
            }
            return;
          }
          final added = <AbHex>{...selected, h};
          if (_isValidSelection(board, turn, added)) {
            selected
              ..clear()
              ..addAll(added);
            return;
          }
          // Check if `selected` has 1 marble and `h` is 2 steps away along a line with own marble in between
          if (selected.length == 1) {
            final s0 = selected.first;
            final dq = h.$1 - s0.$1, dr = h.$2 - s0.$2;
            if (dq.isEven && dr.isEven) {
              final mid = (s0.$1 + dq ~/ 2, s0.$2 + dr ~/ 2);
              final line3 = <AbHex>{s0, mid, h};
              if (_isValidSelection(board, turn, line3)) {
                selected
                  ..clear()
                  ..addAll(line3);
                return;
              }
            }
          }
          selected
            ..clear()
            ..add(h);
        });
      }
    }

    String status;
    if (over) {
      status = result;
    } else if (myTurn) {
      if (selected.isEmpty) {
        status = '轮到你（${turn == 0 ? '黑' : '白'}方）：请点选 1~3 枚同一直线相邻的己方棋子';
      } else if (activeMoves.isEmpty) {
        status = '已选 ${selected.length} 枚棋子（无合法移动方向，请重点其他棋子）';
      } else {
        status = '已选 ${selected.length} 枚棋子：点高亮目标格或下方方向按钮移动';
      }
    } else {
      status = '等待 ${g.name(turn)}（${turn == 0 ? '黑' : '白'}方）落子';
    }

    final actions = <Widget>[];
    if (myTurn && selected.isNotEmpty) {
      for (final mv in activeMoves) {
        final label = '${abDirNames[mv.dir]}${mv.ejects ? '(击落!)' : (mv.pushed.isNotEmpty ? '(推${mv.pushed.length})' : '')}';
        actions.add(a3Button(
          context,
          label,
          mv.ejects ? Icons.bolt : (mv.pushed.isNotEmpty ? Icons.double_arrow : Icons.arrow_forward),
          () => executeMove(mv),
          primary: mv.ejects || mv.pushed.isNotEmpty,
        ));
      }
      actions.add(a3Button(
        context,
        '重选',
        Icons.clear,
        () => setState(() => selected.clear()),
      ));
    }

    // Ejected marbles score bar tray
    Widget ejectedRow(int seat) {
      final count = ejected[seat];
      final oppIsBlack = seat == 1; // If seat 0 (Black) ejected opponent marbles, those marbles are White
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          '${seat == 0 ? '黑方' : '白方'}已推出 $count/$winEjected：',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        for (var i = 0; i < winEjected; i++)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < count
                  ? (oppIsBlack ? const Color(0xFF263238) : const Color(0xFFECEFF1))
                  : cs.onSurface.withValues(alpha: 0.12),
              border: Border.all(
                color: i < count ? cs.primary : cs.onSurface.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
          ),
      ]);
    }

    final tray = A3Panel(
      highlight: myTurn,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          ejectedRow(0),
          ejectedRow(1),
        ],
      ),
    );

    final boardWidget = LayoutBuilder(builder: (context, c) {
      final side = min(c.maxWidth, c.maxHeight);
      final bSize = Size(side, side);
      return Center(
        child: MouseRegion(
          onHover: (e) {
            final hh = _AbalonePainter.hit(bSize, e.localPosition);
            if (hh != hover) setState(() => hover = hh);
          },
          onExit: (_) => setState(() => hover = null),
          child: GestureDetector(
            onTapUp: (d) {
              final hh = _AbalonePainter.hit(bSize, d.localPosition);
              if (hh != null) tapHex(hh, bSize, d.localPosition);
            },
            child: CustomPaint(
              size: bSize,
              painter: _AbalonePainter(
                board: board,
                selected: selected,
                activeMoves: activeMoves,
                hover: hover,
                lastFrom: lastFrom,
                lastTo: lastTo,
                lastPushed: lastPushed,
                accent: cs.primary,
              ),
            ),
          ),
        ),
      );
    });

    Widget tagFor(int s) {
      final stateLabel = over ? (winner == s ? ' · 胜' : (winner == 2 ? ' · 和' : ' · 负')) : '';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '${s == 0 ? '黑' : '白'}方 · 推出 ${ejected[s]}/$winEjected$stateLabel',
        trailing: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: s == 0 ? const Color(0xFF263238) : const Color(0xFFECEFF1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black38),
          ),
        ),
      );
    }

    return A3Shell(
      tags: [tagFor(0), tagFor(1)],
      status: status,
      statusHighlight: myTurn,
      aspect: 1,
      board: boardWidget,
      tray: tray,
      trayFraction: 0.14,
      trayLandscapeHeight: 68,
      actions: actions,
      info: [
        if (note.isNotEmpty) '上一步：$note（手数 $plies/$maxPlies）',
        '规则：点选 1~3 枚同线相邻己方棋子推进或平移；2推1、3推1或2，先推落 6 子获胜！',
      ],
      result: a3Banner(g, over, winner, 2),
      resultSub: over ? result : null,
    );
  }
}
