import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class NeutreekoBoard extends StatefulWidget {
  final GameContext g;
  const NeutreekoBoard(this.g, {super.key});

  @override
  State<NeutreekoBoard> createState() => _NeutreekoBoardState();
}

class _NeutreekoBoardState extends State<NeutreekoBoard> {
  (int, int)? _selected;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  static const List<(int, int)> _dirs8 = [
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1),
  ];

  List<(int, int)> _destinationsFor(
    int r,
    int c,
    List<List<int>> board,
    int size,
  ) {
    final dests = <(int, int)>[];
    for (final (dr, dc) in _dirs8) {
      var cr = r;
      var cc = c;
      while (cr + dr >= 0 &&
          cr + dr < size &&
          cc + dc >= 0 &&
          cc + dc < size &&
          board[cr + dr][cc + dc] == 0) {
        cr += dr;
        cc += dc;
      }
      if (cr != r || cc != c) {
        dests.add((cr, cc));
      }
    }
    return dests;
  }

  void _onTapCell(
    int r,
    int c,
    List<List<int>> board,
    int size,
    int turn,
    bool over,
  ) {
    if (over || g.seat != turn) return;
    if (r < 0 || r >= size || c < 0 || c >= size) return;

    final me = turn + 1;
    if (_selected != null) {
      final (sr, sc) = _selected!;
      if (sr == r && sc == c) {
        setState(() => _selected = null);
        return;
      }
      final dests = _destinationsFor(sr, sc, board, size);
      if (dests.contains((r, c))) {
        setState(() => _selected = null);
        g.act({
          'type': 'slide',
          'from': [sr, sc],
          'to': [r, c],
          'fromR': sr,
          'fromC': sc,
          'toR': r,
          'toC': c,
        });
        return;
      }
    }

    if (board[r][c] == me) {
      setState(() => _selected = (r, c));
    } else {
      setState(() => _selected = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = (v['size'] as int?) ?? 5;
    final turn = (v['turn'] as int?) ?? 0;
    final over = v['over'] == true || g.over;

    final rawBoard = (v['board'] as List?) ?? const [];
    final board = <List<int>>[
      for (var r = 0; r < size; r++)
        r < rawBoard.length
            ? (rawBoard[r] as List).map((e) => (e as num).toInt()).toList()
            : List<int>.filled(size, 0),
    ];

    final winningLine = ((v['winningLine'] as List?) ?? const [])
        .map((e) => (e as List).map((x) => (x as num).toInt()).toList())
        .toList();
    final lastMove = v['lastMove'] as Map?;
    final resultText = v['result'] as String?;

    final activeSelected = (!over &&
            g.seat == turn &&
            _selected != null &&
            _selected!.$1 < size &&
            _selected!.$2 < size &&
            board[_selected!.$1][_selected!.$2] == turn + 1)
        ? _selected
        : null;

    final dests = activeSelected != null
        ? _destinationsFor(activeSelected.$1, activeSelected.$2, board, size)
        : const <(int, int)>[];

    String statusText;
    if (over) {
      statusText = resultText ?? '对局结束';
    } else if (g.seat == turn) {
      statusText = activeSelected == null
          ? '轮到你行动（${turn == 0 ? "黑子" : "白子"}）：点击己方棋子选择滑行方向'
          : '已选棋子：点击高亮终点一滑到底，连成紧邻三子获胜';
    } else {
      statusText = '等待 ${g.name(turn)}（${turn == 0 ? "黑子" : "白子"}）滑行棋子…';
    }

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 460;
          return Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      g.tag(
                        0,
                        active: !over && turn == 0,
                        sub: '⚫ 黑方 · 3 子滑冰连珠',
                        size: isCompact ? 28 : 34,
                      ),
                      StatusBar(statusText, highlight: !over && g.seat == turn),
                      g.tag(
                        1,
                        active: !over && turn == 1,
                        sub: '⚪ 白方 · 3 子滑冰连珠',
                        size: isCompact ? 28 : 34,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final side = math.min(box.maxWidth, box.maxHeight);
                            final cell = side / size;
                            return GestureDetector(
                              onTapUp: (d) {
                                final c = (d.localPosition.dx / cell).floor();
                                final r = (d.localPosition.dy / cell).floor();
                                _onTapCell(r, c, board, size, turn, over);
                              },
                              child: CustomPaint(
                                size: Size(side, side),
                                painter: _NeutreekoPainter(
                                  size: size,
                                  board: board,
                                  selected: activeSelected,
                                  destinations: dests,
                                  winningLine: winningLine,
                                  lastMove: lastMove,
                                  cs: cs,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (over && resultText != null) ResultBanner(resultText),
            ],
          );
        },
      ),
    );
  }
}

class _NeutreekoPainter extends CustomPainter {
  final int size;
  final List<List<int>> board;
  final (int, int)? selected;
  final List<(int, int)> destinations;
  final List<List<int>> winningLine;
  final Map? lastMove;
  final ColorScheme cs;

  _NeutreekoPainter({
    required this.size,
    required this.board,
    required this.selected,
    required this.destinations,
    required this.winningLine,
    required this.lastMove,
    required this.cs,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final side = math.min(canvasSize.width, canvasSize.height);
    final cell = side / size;
    final fullRect = Rect.fromLTWH(0, 0, side, side);

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(fullRect, const Radius.circular(14)),
    );

    // Ice-rink inspired board tiles
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final isEven = (r + c).isEven;
        final tileColor = isEven
            ? const Color(0xFFDCEEF8)
            : const Color(0xFFB8D8EB);
        canvas.drawRect(
          Rect.fromLTWH(c * cell, r * cell, cell, cell),
          Paint()..color = tileColor,
        );
      }
    }

    Offset cellCenter(int r, int c) =>
        Offset((c + 0.5) * cell, (r + 0.5) * cell);

    // Highlight last slide trajectory
    if (lastMove != null &&
        lastMove!['fromR'] is num &&
        lastMove!['fromC'] is num &&
        lastMove!['toR'] is num &&
        lastMove!['toC'] is num) {
      final fr = (lastMove!['fromR'] as num).toInt();
      final fc = (lastMove!['fromC'] as num).toInt();
      final tr = (lastMove!['toR'] as num).toInt();
      final tc = (lastMove!['toC'] as num).toInt();
      canvas.drawLine(
        cellCenter(fr, fc),
        cellCenter(tr, tc),
        Paint()
          ..color = Colors.amber.withValues(alpha: 0.65)
          ..strokeWidth = math.max(3.0, cell * 0.1)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        cellCenter(fr, fc),
        cell * 0.12,
        Paint()..color = Colors.amber.withValues(alpha: 0.7),
      );
    }

    // Highlight selected piece and slide rays to destinations
    if (selected != null) {
      final (sr, sc) = selected!;
      canvas.drawRect(
        Rect.fromLTWH(sc * cell, sr * cell, cell, cell),
        Paint()..color = const Color(0xFF00B8D4).withValues(alpha: 0.35),
      );
      final startOffset = cellCenter(sr, sc);
      for (final (dr, dc) in destinations) {
        final endOffset = cellCenter(dr, dc);
        canvas.drawLine(
          startOffset,
          endOffset,
          Paint()
            ..color = const Color(0xFF00ACC1).withValues(alpha: 0.55)
            ..strokeWidth = math.max(2.5, cell * 0.07)
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          endOffset,
          cell * 0.22,
          Paint()..color = const Color(0xFF00C853).withValues(alpha: 0.8),
        );
      }
    }

    // Draw pieces
    final radius = cell * 0.36;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = board[r][c];
        if (v == 0) continue;
        final center = cellCenter(r, c);

        canvas.drawCircle(
          center.translate(1.5, 2.2),
          radius,
          Paint()..color = Colors.black38,
        );

        final piecePaint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            radius: 0.85,
            colors: v == 1
                ? const [Color(0xFF546E7A), Color(0xFF1C262B)]
                : const [Color(0xFFFFFFFF), Color(0xFFCFD8DC)],
          ).createShader(Rect.fromCircle(center: center, radius: radius));
        canvas.drawCircle(center, radius, piecePaint);

        // Concentric puck ring
        canvas.drawCircle(
          center,
          radius * 0.62,
          Paint()
            ..color = v == 1 ? Colors.white24 : Colors.black26
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }

    // Highlight winning 3-in-a-row line
    if (winningLine.length >= 2) {
      final first = winningLine.first;
      final last = winningLine.last;
      canvas.drawLine(
        cellCenter(first[0], first[1]),
        cellCenter(last[0], last[1]),
        Paint()
          ..color = Colors.amberAccent
          ..strokeWidth = math.max(4.0, cell * 0.14)
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(fullRect, const Radius.circular(14)),
      Paint()
        ..color = const Color(0xFF37474F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _NeutreekoPainter oldDelegate) => true;
}
