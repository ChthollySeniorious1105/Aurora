import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class KubaBoard extends StatefulWidget {
  final GameContext g;
  const KubaBoard(this.g, {super.key});

  @override
  State<KubaBoard> createState() => _KubaBoardState();
}

class _KubaBoardState extends State<KubaBoard> {
  (int, int)? _selected;
  (int, int)? _hovered;

  static const List<(int, int)> _kDirs = [
    (-1, 0),
    (0, 1),
    (1, 0),
    (0, -1),
  ];
  static const List<String> _kDirLabels = ['↑ 上推', '→ 右推', '↓ 下推', '← 左推'];
  static const List<String> _kDirArrows = ['↑', '→', '↓', '←'];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final targetRed = (v['targetRed'] as num?)?.toInt() ?? 7;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final bonusTurn = v['bonusTurn'] == true;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final redCaptured =
        (v['redCaptured'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final enemyCaptured =
        (v['enemyCaptured'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final redRemaining = (v['redRemaining'] as num?)?.toInt() ?? 13;
    final lastMove = v['lastMove'] as Map?;

    final rawBoard = (v['board'] as List?) ?? const [];
    final board = List.generate(7, (r) {
      final row = r < rawBoard.length ? (rawBoard[r] as List) : const [];
      return List.generate(7, (c) => c < row.length ? (row[c] as num).toInt() : 0);
    });

    final isMyTurn = !over && g.seat == turn;

    // Group legal moves by (r, c) -> list of legal directions
    final rawLegal = (v['legalMoves'] as List?)?.cast<Map>() ?? const [];
    final legalByCell = <(int, int), List<int>>{};
    for (final m in rawLegal) {
      final r = (m['r'] as num?)?.toInt() ?? -1;
      final c = (m['c'] as num?)?.toInt() ?? -1;
      final dir = (m['dir'] as num?)?.toInt() ?? -1;
      if (r >= 0 && c >= 0 && dir >= 0) {
        legalByCell.putIfAbsent((r, c), () => []).add(dir);
      }
    }

    if (_selected != null && (!isMyTurn || !legalByCell.containsKey(_selected))) {
      _selected = null;
    }

    final selectedDirs = _selected != null ? (legalByCell[_selected] ?? const <int>[]) : const <int>[];

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      final prefix = bonusTurn ? '【连击奖励回合】' : '轮到你：';
      if (_selected == null) {
        statusText = '$prefix点击带高亮光圈的己方弹球（后方留空方可推动）';
      } else {
        statusText = '$prefix已选 (${_selected!.$1}, ${_selected!.$2})，点击箭头方向格或下方方向按钮推球';
      }
    } else {
      statusText = '等待 ${g.name(turn)} ${bonusTurn ? '进行连击推球' : '推球'}…（场余红球 $redRemaining）';
    }

    Widget buildPlayerPanel(int s) {
      final isWhite = s == 0;
      final rc = s < redCaptured.length ? redCaptured[s] : 0;
      final ec = s < enemyCaptured.length ? enemyCaptured[s] : 0;
      final colorLabel = isWhite ? '白球' : '黑球';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$colorLabel · 红球 $rc/$targetRed · 歼敌 $ec/8',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isWhite ? const Color(0xFFF5F5F5) : const Color(0xFF212121),
            border: Border.all(
              color: isWhite ? const Color(0xFF26C6DA) : const Color(0xFFFFCA28),
              width: 2.0,
            ),
          ),
        ),
      );
    }

    Widget? buildDirectionButtons() {
      if (!isMyTurn || _selected == null || selectedDirs.isEmpty) return null;
      final (sr, sc) = _selected!;
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          for (final dir in selectedDirs)
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: () {
                setState(() => _selected = null);
                g.act({'type': 'push', 'r': sr, 'c': sc, 'dir': dir});
              },
              child: Text(_kDirLabels[dir], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ],
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          if (w <= 20 || h <= 20) return const SizedBox.shrink();

          final boardSide = min(w, h) * 0.94;
          final cellSize = boardSide / 7.0;
          final origin = Offset((w - boardSide) / 2, (h - boardSide) / 2);

          (int, int)? hitCellAt(Offset pos) {
            final c = ((pos.dx - origin.dx) / cellSize).floor();
            final r = ((pos.dy - origin.dy) / cellSize).floor();
            if (r >= 0 && r < 7 && c >= 0 && c < 7) return (r, c);
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
                      // If a marble is already selected and user taps adjacent cell in a legal push direction:
                      if (_selected != null) {
                        final (sr, sc) = _selected!;
                        for (final dir in selectedDirs) {
                          final (dr, dc) = _kDirs[dir];
                          if (hit == (sr + dr, sc + dc)) {
                            setState(() => _selected = null);
                            g.act({'type': 'push', 'r': sr, 'c': sc, 'dir': dir});
                            return;
                          }
                        }
                        // If tapping the same marble again and it only has 1 legal direction, push immediately
                        if (hit == _selected && selectedDirs.length == 1) {
                          final dir = selectedDirs.first;
                          setState(() => _selected = null);
                          g.act({'type': 'push', 'r': sr, 'c': sc, 'dir': dir});
                          return;
                        }
                      }
                      if (legalByCell.containsKey(hit)) {
                        setState(() => _selected = hit);
                      } else {
                        setState(() => _selected = null);
                      }
                    },
              child: CustomPaint(
                size: Size(w, h),
                painter: _KubaPainter(
                  board: board,
                  legalByCell: legalByCell,
                  selected: _selected,
                  hovered: _hovered,
                  lastMove: lastMove,
                  isMyTurn: isMyTurn,
                  origin: origin,
                  boardSide: boardSide,
                  cellSize: cellSize,
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
        final isWide = outer.maxWidth >= 680 && outer.maxWidth > outer.maxHeight * 1.15;
        final dirBtns = buildDirectionButtons();

        return Stack(
          children: [
            Container(
              color: g.table,
              padding: const EdgeInsets.all(8),
              child: isWide
                  ? Row(
                      children: [
                        SizedBox(
                          width: min(250, outer.maxWidth * 0.30),
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
                                      if (dirBtns != null) ...[
                                        const SizedBox(height: 6),
                                        FittedBox(fit: BoxFit.scaleDown, child: dirBtns),
                                      ],
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
                            Expanded(child: buildPlayerPanel(0)),
                            const SizedBox(width: 6),
                            Expanded(child: buildPlayerPanel(1)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: StatusBar(statusText, highlight: isMyTurn),
                        ),
                        if (dirBtns != null) ...[
                          const SizedBox(height: 4),
                          FittedBox(fit: BoxFit.scaleDown, child: dirBtns),
                        ],
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

class _KubaPainter extends CustomPainter {
  final List<List<int>> board;
  final Map<(int, int), List<int>> legalByCell;
  final (int, int)? selected;
  final (int, int)? hovered;
  final Map? lastMove;
  final bool isMyTurn;
  final Offset origin;
  final double boardSide;
  final double cellSize;
  final ColorScheme cs;

  _KubaPainter({
    required this.board,
    required this.legalByCell,
    required this.selected,
    required this.hovered,
    required this.lastMove,
    required this.isMyTurn,
    required this.origin,
    required this.boardSide,
    required this.cellSize,
    required this.cs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trayRect = Rect.fromLTWH(origin.dx, origin.dy, boardSide, boardSide);
    final outerRect = trayRect.inflate(cellSize * 0.14);

    // Outer wooden/slate rim with drop-off gutter
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, Radius.circular(cellSize * 0.24)),
      Paint()..color = const Color(0xFF3E2723),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(trayRect, Radius.circular(cellSize * 0.14)),
      Paint()..color = const Color(0xFF5D4037),
    );

    final lastR = (lastMove?['r'] as num?)?.toInt();
    final lastC = (lastMove?['c'] as num?)?.toInt();
    final lastDir = (lastMove?['dir'] as num?)?.toInt();

    // Draw 7x7 cells
    for (var r = 0; r < 7; r++) {
      for (var c = 0; c < 7; c++) {
        final rect = Rect.fromLTWH(
          origin.dx + c * cellSize,
          origin.dy + r * cellSize,
          cellSize,
          cellSize,
        ).deflate(cellSize * 0.04);

        final isCenterDiamond = (r - 3).abs() + (c - 3).abs() <= 2;
        Color cellColor = isCenterDiamond ? const Color(0xFF4E342E) : const Color(0xFF6D4C41);
        if (selected == (r, c)) {
          cellColor = Color.alphaBlend(Colors.cyanAccent.withValues(alpha: 0.35), cellColor);
        } else if (lastR == r && lastC == c) {
          cellColor = Color.alphaBlend(Colors.amberAccent.withValues(alpha: 0.25), cellColor);
        } else if (hovered == (r, c) && legalByCell.containsKey((r, c))) {
          cellColor = Color.alphaBlend(Colors.greenAccent.withValues(alpha: 0.22), cellColor);
        }

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.12)),
          Paint()..color = cellColor,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.12)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = Colors.white.withValues(alpha: 0.16),
        );

        // Subtle pocket indentation at cell center
        final center = rect.center;
        canvas.drawCircle(
          center,
          cellSize * 0.18,
          Paint()..color = Colors.black.withValues(alpha: 0.18),
        );
      }
    }

    // Draw marbles
    for (var r = 0; r < 7; r++) {
      for (var c = 0; c < 7; c++) {
        final m = board[r][c];
        if (m == 0) continue;
        final center = Offset(
          origin.dx + (c + 0.5) * cellSize,
          origin.dy + (r + 0.5) * cellSize,
        );
        final radius = cellSize * 0.36;

        // Shadow
        canvas.drawCircle(
          center + Offset(cellSize * 0.03, cellSize * 0.05),
          radius,
          Paint()..color = Colors.black54,
        );

        final List<Color> grad;
        final Color rim;
        if (m == 1) {
          // White marble (Player 0)
          grad = const [Color(0xFFFFFFFF), Color(0xFFCFD8DC), Color(0xFF90A4AE)];
          rim = const Color(0xFF26C6DA);
        } else if (m == 2) {
          // Black marble (Player 1)
          grad = const [Color(0xFF616161), Color(0xFF212121), Color(0xFF000000)];
          rim = const Color(0xFFFFCA28);
        } else {
          // Neutral Red marble (3)
          grad = const [Color(0xFFFF8A80), Color(0xFFD32F2F), Color(0xFF8E0000)];
          rim = const Color(0xFFFFD54F);
        }

        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.35),
              colors: grad,
              stops: const [0.0, 0.65, 1.0],
            ).createShader(Rect.fromCircle(center: center, radius: radius)),
        );

        final isMovable = isMyTurn && legalByCell.containsKey((r, c));
        final isSel = selected == (r, c);
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSel ? 2.8 : (isMovable ? 2.2 : 1.2)
            ..color = isSel
                ? Colors.cyanAccent
                : (isMovable ? Colors.greenAccent : rim.withValues(alpha: 0.75)),
        );
      }
    }

    // Draw last move direction indicator
    if (lastR != null && lastC != null && lastDir != null && lastDir >= 0 && lastDir < 4) {
      final (dr, dc) = _KubaBoardState._kDirs[lastDir];
      final p1 = Offset(origin.dx + (lastC + 0.5) * cellSize, origin.dy + (lastR + 0.5) * cellSize);
      final p2 = Offset(
        origin.dx + (lastC + dc + 0.5) * cellSize,
        origin.dy + (lastR + dr + 0.5) * cellSize,
      );
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = Colors.amberAccent.withValues(alpha: 0.7)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // Draw directional target badges when a marble is selected
    if (isMyTurn && selected != null) {
      final (sr, sc) = selected!;
      final dirs = legalByCell[selected] ?? const <int>[];
      for (final dir in dirs) {
        final (dr, dc) = _KubaBoardState._kDirs[dir];
        final tr = sr + dr;
        final tc = sc + dc;
        if (tr < 0 || tr >= 7 || tc < 0 || tc >= 7) continue;
        final tCenter = Offset(
          origin.dx + (tc + 0.5) * cellSize,
          origin.dy + (tr + 0.5) * cellSize,
        );
        final badgeR = cellSize * 0.24;
        canvas.drawCircle(
          tCenter,
          badgeR,
          Paint()..color = const Color(0xDD00E676),
        );
        canvas.drawCircle(
          tCenter,
          badgeR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = Colors.white,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: _KubaBoardState._kDirArrows[dir],
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: cellSize * 0.30,
              fontFamilyFallback: kFontFallback,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, tCenter - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KubaPainter oldDelegate) => true;
}
