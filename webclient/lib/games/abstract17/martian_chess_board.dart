import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class MartianChessBoard extends StatefulWidget {
  final GameContext g;
  const MartianChessBoard(this.g, {super.key});

  @override
  State<MartianChessBoard> createState() => _MartianChessBoardState();
}

class _MartianChessBoardState extends State<MartianChessBoard> {
  (int, int)? _selected;
  (int, int)? _hovered;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final score =
        (v['score'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final zoneCounts =
        (v['zoneCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [9, 9];
    final zoneQueens =
        (v['zoneQueens'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [3, 3];
    final lastMove = v['lastMove'] as Map?;

    final rawBoard = (v['board'] as List?) ?? const [];
    final board = List.generate(8, (r) {
      final row = r < rawBoard.length ? (rawBoard[r] as List) : const [];
      return List.generate(4, (c) => c < row.length ? (row[c] as num).toInt() : 0);
    });

    final isMyTurn = !over && g.seat == turn;

    // Group legalMoves by (fromR, fromC) -> Map<(toR, toC), Map>
    final rawMoves = (v['legalMoves'] as List?)?.cast<Map>() ?? const [];
    final movesBySource = <(int, int), Map<(int, int), Map>>{};
    for (final m in rawMoves) {
      final fr = (m['fromR'] as num?)?.toInt() ?? -1;
      final fc = (m['fromC'] as num?)?.toInt() ?? -1;
      final tr = (m['toR'] as num?)?.toInt() ?? -1;
      final tc = (m['toC'] as num?)?.toInt() ?? -1;
      if (fr >= 0 && fc >= 0 && tr >= 0 && tc >= 0) {
        movesBySource.putIfAbsent((fr, fc), () => {})[(tr, tc)] = m;
      }
    }

    if (_selected != null && (!isMyTurn || !movesBySource.containsKey(_selected))) {
      _selected = null;
    }

    final activeTargets =
        _selected != null ? (movesBySource[_selected] ?? const <(int, int), Map>{}) : const <(int, int), Map>{};

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      final zoneLabel = turn == 0 ? '南区(4~7行)' : '北区(0~3行)';
      if (_selected == null) {
        statusText = '轮到你（控制$zoneLabel）：点击己方半区金字塔棋子，跨过运河即可吃子得分！';
      } else {
        final p = board[_selected!.$1][_selected!.$2];
        final pName = p == 3 ? '女王(3分·八向直线)' : (p == 2 ? '中卫(2分·正交1~2格)' : '小兵(1分·斜向1格)');
        statusText = '已选$pName：点击高亮目标格移动或跨河吃子';
      }
    } else {
      final zoneLabel = turn == 0 ? '南区(4~7行)' : '北区(0~3行)';
      statusText = '等待 ${g.name(turn)} 调遣$zoneLabel棋子…';
    }

    Widget buildPlayerPanel(int s) {
      final isSouth = s == 0;
      final sc = s < score.length ? score[s] : 0;
      final zc = s < zoneCounts.length ? zoneCounts[s] : 0;
      final zq = s < zoneQueens.length ? zoneQueens[s] : 0;
      final zoneLabel = isSouth ? '南区(4~7行)' : '北区(0~3行)';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$zoneLabel · $sc分 · 辖区$zc子${zq == 0 ? "(可合体女王)" : ""}',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isSouth ? const Color(0xFF00838F) : const Color(0xFFAD1457),
            border: Border.all(
              color: isSouth ? const Color(0xFF80DEEA) : const Color(0xFFF48FB1),
              width: 1.5,
            ),
          ),
          child: Text(
            '$sc分',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      );
    }

    Widget buildLegendBar() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
        ),
        child: Text(
          '▲1 小兵(斜1格) · ▲▲2 中卫(正交1~2格) · ▲▲▲3 女王(八向任意格) · 跨过运河即移交控制权！',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.85)),
        ),
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          if (w <= 20 || h <= 20) return const SizedBox.shrink();

          // 8 rows + 0.45 row canal gap = 8.45 units tall, 4 cols wide
          final cellSize = min((w * 0.92) / 4.0, (h * 0.94) / 8.45);
          final canalGap = cellSize * 0.45;
          final boardW = cellSize * 4.0;
          final boardH = cellSize * 8.0 + canalGap;
          final origin = Offset((w - boardW) / 2, (h - boardH) / 2);

          Rect cellRect(int r, int c) {
            final dy = r * cellSize + (r >= 4 ? canalGap : 0.0);
            return Rect.fromLTWH(origin.dx + c * cellSize, origin.dy + dy, cellSize, cellSize);
          }

          (int, int)? hitCellAt(Offset pos) {
            for (var r = 0; r < 8; r++) {
              for (var c = 0; c < 4; c++) {
                if (cellRect(r, c).contains(pos)) return (r, c);
              }
            }
            return null;
          }

          return MouseRegion(
            onHover: !isMyTurn
                ? null
                : (e) {
                    final hit = hitCellAt(e.localPosition);
                    if (hit != _hovered) setState(() => _hovered = hit);
                  },
            onExit: (_) {
              if (_hovered != null) setState(() => _hovered = null);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: !isMyTurn
                  ? null
                  : (details) {
                      final hit = hitCellAt(details.localPosition);
                      if (hit == null) {
                        setState(() => _selected = null);
                        return;
                      }
                      if (_selected != null && activeTargets.containsKey(hit)) {
                        final (fr, fc) = _selected!;
                        setState(() => _selected = null);
                        g.act({
                          'type': 'move',
                          'fromR': fr,
                          'fromC': fc,
                          'toR': hit.$1,
                          'toC': hit.$2,
                        });
                        return;
                      }
                      if (movesBySource.containsKey(hit)) {
                        setState(() => _selected = hit);
                      } else {
                        setState(() => _selected = null);
                      }
                    },
              child: CustomPaint(
                size: Size(w, h),
                painter: _MartianChessPainter(
                  board: board,
                  movesBySource: movesBySource,
                  selected: _selected,
                  activeTargets: activeTargets,
                  hovered: _hovered,
                  lastMove: lastMove,
                  turn: turn,
                  isMyTurn: isMyTurn,
                  origin: origin,
                  boardW: boardW,
                  boardH: boardH,
                  cellSize: cellSize,
                  canalGap: canalGap,
                  cs: cs,
                ),
              ),
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, outer) {
        final isWide = outer.maxWidth >= 660 && outer.maxWidth > outer.maxHeight * 1.1;

        return Stack(
          children: [
            Container(
              color: g.table,
              padding: const EdgeInsets.all(8),
              child: isWide
                  ? Row(
                      children: [
                        SizedBox(
                          width: min(260, outer.maxWidth * 0.32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buildPlayerPanel(1),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: StatusBar(statusText, highlight: isMyTurn),
                                      ),
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: buildLegendBar(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              buildPlayerPanel(0),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: buildBoardCanvas()),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: buildPlayerPanel(1)),
                            const SizedBox(width: 6),
                            Expanded(child: buildPlayerPanel(0)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: StatusBar(statusText, highlight: isMyTurn),
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: buildLegendBar(),
                        ),
                        Expanded(child: buildBoardCanvas()),
                      ],
                    ),
            ),
            if (over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(
                  winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MartianChessPainter extends CustomPainter {
  final List<List<int>> board;
  final Map<(int, int), Map<(int, int), Map>> movesBySource;
  final (int, int)? selected;
  final Map<(int, int), Map> activeTargets;
  final (int, int)? hovered;
  final Map? lastMove;
  final int turn;
  final bool isMyTurn;
  final Offset origin;
  final double boardW;
  final double boardH;
  final double cellSize;
  final double canalGap;
  final ColorScheme cs;

  _MartianChessPainter({
    required this.board,
    required this.movesBySource,
    required this.selected,
    required this.activeTargets,
    required this.hovered,
    required this.lastMove,
    required this.turn,
    required this.isMyTurn,
    required this.origin,
    required this.boardW,
    required this.boardH,
    required this.cellSize,
    required this.canalGap,
    required this.cs,
  });

  Rect _cellRect(int r, int c) {
    final dy = r * cellSize + (r >= 4 ? canalGap : 0.0);
    return Rect.fromLTWH(origin.dx + c * cellSize, origin.dy + dy, cellSize, cellSize);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outerRect = Rect.fromLTWH(origin.dx, origin.dy, boardW, boardH).inflate(cellSize * 0.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, Radius.circular(cellSize * 0.2)),
      Paint()..color = const Color(0xFF1C1924),
    );

    // Draw North Zone (rows 0..3) and South Zone (rows 4..7) background frames
    final northZoneRect = Rect.fromLTWH(origin.dx, origin.dy, boardW, cellSize * 4).inflate(cellSize * 0.04);
    final southZoneRect =
        Rect.fromLTWH(origin.dx, origin.dy + cellSize * 4 + canalGap, boardW, cellSize * 4).inflate(cellSize * 0.04);

    canvas.drawRRect(
      RRect.fromRectAndRadius(northZoneRect, Radius.circular(cellSize * 0.1)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = turn == 1 ? 2.4 : 1.2
        ..color = const Color(0xFFF48FB1).withValues(alpha: turn == 1 ? 0.85 : 0.35),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(southZoneRect, Radius.circular(cellSize * 0.1)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = turn == 0 ? 2.4 : 1.2
        ..color = const Color(0xFF80DEEA).withValues(alpha: turn == 0 ? 0.85 : 0.35),
    );

    // Draw the Martian Canal between Row 3 and Row 4
    final canalRect = Rect.fromLTWH(
      origin.dx - cellSize * 0.04,
      origin.dy + cellSize * 4 + canalGap * 0.12,
      boardW + cellSize * 0.08,
      canalGap * 0.76,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(canalRect, Radius.circular(canalGap * 0.35)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFAD1457), Color(0xFFFF6F00), Color(0xFF00838F)],
        ).createShader(canalRect),
    );
    final canalTp = TextPainter(
      text: TextSpan(
        text: '▲ 北区(P2) ══ 火星运河 CANAL ══ 南区(P1) ▼',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: max(8.5, canalGap * 0.44),
          fontFamilyFallback: kFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canalTp.paint(
      canvas,
      canalRect.center - Offset(canalTp.width / 2, canalTp.height / 2),
    );

    final lastFromR = (lastMove?['fromR'] as num?)?.toInt();
    final lastFromC = (lastMove?['fromC'] as num?)?.toInt();
    final lastToR = (lastMove?['toR'] as num?)?.toInt();
    final lastToC = (lastMove?['toC'] as num?)?.toInt();

    // Draw 8x4 squares
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 4; c++) {
        final rect = _cellRect(r, c).deflate(cellSize * 0.03);
        final isDark = (r + c).isOdd;
        final isSouth = r >= 4;
        Color bg;
        if (isSouth) {
          bg = isDark ? const Color(0xFF22333B) : const Color(0xFF2F4550);
        } else {
          bg = isDark ? const Color(0xFF382230) : const Color(0xFF4C2E41);
        }

        if (selected == (r, c)) {
          bg = Color.alphaBlend(Colors.cyanAccent.withValues(alpha: 0.35), bg);
        } else if ((lastFromR == r && lastFromC == c) || (lastToR == r && lastToC == c)) {
          bg = Color.alphaBlend(Colors.amberAccent.withValues(alpha: 0.25), bg);
        } else if (hovered == (r, c) &&
            (movesBySource.containsKey((r, c)) || activeTargets.containsKey((r, c)))) {
          bg = Color.alphaBlend(Colors.greenAccent.withValues(alpha: 0.22), bg);
        }

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.1)),
          Paint()..color = bg,
        );

        // Draw piece if present
        final piece = board[r][c];
        if (piece > 0) {
          _drawPyramidPiece(
            canvas,
            rect.center,
            piece,
            isSouth: isSouth,
            isMovable: isMyTurn && movesBySource.containsKey((r, c)),
            isSelected: selected == (r, c),
          );
        }

        // Draw target indicator if (r, c) is a legal destination for the selected piece
        final targetInfo = activeTargets[(r, c)];
        if (targetInfo != null) {
          final isCapture = ((targetInfo['captured'] as num?)?.toInt() ?? 0) > 0;
          final isPromote = ((targetInfo['promote'] as num?)?.toInt() ?? 0) == 1;
          final tColor = isCapture
              ? const Color(0xFFFF5252)
              : (isPromote ? const Color(0xFFFFD740) : const Color(0xFF00E676));

          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.1)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6
              ..color = tColor,
          );
          if (piece == 0) {
            canvas.drawCircle(
              rect.center,
              cellSize * 0.18,
              Paint()..color = tColor.withValues(alpha: 0.78),
            );
          }
        }
      }
    }
  }

  void _drawPyramidPiece(
    Canvas canvas,
    Offset center,
    int tier, {
    required bool isSouth,
    required bool isMovable,
    required bool isSelected,
  }) {
    // Looney Pyramids have no player color (neutral ivory/gold crystal), tinted subtly by current zone control
    final baseRadius = cellSize * (tier == 3 ? 0.39 : (tier == 2 ? 0.34 : 0.28));
    final zoneAccent = isSouth ? const Color(0xFF26C6DA) : const Color(0xFFEC407A);

    // Shadow
    canvas.drawCircle(
      center + Offset(cellSize * 0.03, cellSize * 0.04),
      baseRadius,
      Paint()..color = Colors.black54,
    );

    // Draw concentric stepped pyramid rings (1 for Pawn, 2 for Drone, 3 for Queen)
    for (var l = tier; l >= 1; l--) {
      final frac = l / tier;
      final r = baseRadius * (0.42 + 0.58 * frac);
      final rect = Rect.fromCircle(center: center, radius: r);
      final fill = l == 3
          ? const Color(0xFFFFD54F)
          : (l == 2 ? const Color(0xFFFFECB3) : const Color(0xFFFFF8E1));
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(r * 0.28)),
        Paint()..color = fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(r * 0.28)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = l == tier ? (isSelected ? 2.6 : (isMovable ? 2.0 : 1.4)) : 1.1
          ..color = l == tier
              ? (isSelected
                  ? Colors.cyanAccent
                  : (isMovable ? Colors.greenAccent : zoneAccent))
              : const Color(0xFF5D4037),
      );
    }

    // Draw tier value label ('1', '2', '3') in center
    final tp = TextPainter(
      text: TextSpan(
        text: '$tier',
        style: TextStyle(
          color: const Color(0xFF263238),
          fontWeight: FontWeight.w900,
          fontSize: cellSize * 0.26,
          fontFamilyFallback: kFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MartianChessPainter oldDelegate) => true;
}
