import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class OrbitoBoard extends StatefulWidget {
  final GameContext g;
  const OrbitoBoard(this.g, {super.key});

  @override
  State<OrbitoBoard> createState() => _OrbitoBoardState();
}

class _OrbitoBoardState extends State<OrbitoBoard> {
  (int, int)? _selectedShoveFrom;
  (int, int)? _hovered;

  static const Map<(int, int), String> _kOrbitArrows = {
    (0, 0): '↓',
    (1, 0): '↓',
    (2, 0): '↓',
    (3, 0): '→',
    (3, 1): '→',
    (3, 2): '→',
    (3, 3): '↑',
    (2, 3): '↑',
    (1, 3): '↑',
    (0, 3): '←',
    (0, 2): '←',
    (0, 1): '←',
    (1, 1): '↓',
    (2, 1): '→',
    (2, 2): '↑',
    (1, 2): '←',
  };

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final shovedThisTurn = v['shovedThisTurn'] == true;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final marbleCount = (v['marbleCount'] as num?)?.toInt() ?? 0;
    final lastMove = v['lastMove'] as Map?;

    final rawBoard = (v['board'] as List?) ?? const [];
    final board = List.generate(4, (r) {
      final row = r < rawBoard.length ? (rawBoard[r] as List) : const [];
      return List.generate(4, (c) => c < row.length ? (row[c] as num).toInt() : -1);
    });

    final isMyTurn = !over && g.seat == turn;

    final rawShoves = (v['legalShoves'] as List?)?.cast<Map>() ?? const [];
    final shoveTargetsByFrom = <(int, int), Set<(int, int)>>{};
    for (final s in rawShoves) {
      final fr = (s['fromR'] as num?)?.toInt() ?? -1;
      final fc = (s['fromC'] as num?)?.toInt() ?? -1;
      final tr = (s['toR'] as num?)?.toInt() ?? -1;
      final tc = (s['toC'] as num?)?.toInt() ?? -1;
      if (fr >= 0 && fc >= 0 && tr >= 0 && tc >= 0) {
        shoveTargetsByFrom.putIfAbsent((fr, fc), () => <(int, int)>{}).add((tr, tc));
      }
    }

    if (!isMyTurn || shovedThisTurn || !shoveTargetsByFrom.containsKey(_selectedShoveFrom)) {
      _selectedShoveFrom = null;
    }

    final activeShoveTargets = _selectedShoveFrom != null
        ? (shoveTargetsByFrom[_selectedShoveFrom] ?? const <(int, int)>{})
        : const <(int, int)>{};

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      if (_selectedShoveFrom != null) {
        statusText =
            '已选敌球 (${_selectedShoveFrom!.$1}, ${_selectedShoveFrom!.$2})：点击相邻高亮空格推开它，或再次点击取消';
      } else if (shovedThisTurn) {
        statusText = '已推开敌球：请点击任意空格放置己方弹珠并触发双环逆时针公转！';
      } else if (shoveTargetsByFrom.isNotEmpty) {
        statusText = '轮到你：可先点击带光圈的敌方弹珠推开 1 步，或直接点击空格落子并启动公转';
      } else {
        statusText = '轮到你：点击任意空格放置己方弹珠并启动双环逆时针公转！';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 行动…（场上弹珠 $marbleCount/16）';
    }

    Widget buildPlayerPanel(int s) {
      final isWhite = s == 0;
      var myCnt = 0;
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          if (board[r][c] == s) myCnt++;
        }
      }
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '${isWhite ? "白球方" : "黑球方"} · 场上 $myCnt 枚 · 逆时针公转四连',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isWhite ? const Color(0xFFF5F5F5) : const Color(0xFF212121),
            border: Border.all(
              color: isWhite ? const Color(0xFF00E5FF) : const Color(0xFFFFCA28),
              width: 2.0,
            ),
          ),
        ),
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          if (w <= 20 || h <= 20) return const SizedBox.shrink();

          final boardSide = min(w, h) * 0.90;
          final cellSize = boardSide / 4.0;
          final origin = Offset((w - boardSide) / 2, (h - boardSide) / 2);

          (int, int)? hitCellAt(Offset pos) {
            final c = ((pos.dx - origin.dx) / cellSize).floor();
            final r = ((pos.dy - origin.dy) / cellSize).floor();
            if (r >= 0 && r < 4 && c >= 0 && c < 4) return (r, c);
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
                        setState(() => _selectedShoveFrom = null);
                        return;
                      }
                      final (r, c) = hit;

                      if (_selectedShoveFrom != null) {
                        if (hit == _selectedShoveFrom) {
                          setState(() => _selectedShoveFrom = null);
                          return;
                        }
                        if (activeShoveTargets.contains(hit)) {
                          final (sfR, sfC) = _selectedShoveFrom!;
                          setState(() => _selectedShoveFrom = null);
                          g.act({
                            'type': 'shove',
                            'fromR': sfR,
                            'fromC': sfC,
                            'toR': r,
                            'toC': c,
                          });
                          return;
                        }
                      }

                      if (!shovedThisTurn && shoveTargetsByFrom.containsKey(hit)) {
                        setState(() => _selectedShoveFrom = hit);
                        return;
                      }

                      if (board[r][c] == -1) {
                        setState(() => _selectedShoveFrom = null);
                        g.act({'type': 'place', 'r': r, 'c': c});
                      }
                    },
              child: CustomPaint(
                size: Size(w, h),
                painter: _OrbitoPainter(
                  board: board,
                  shoveSources: shoveTargetsByFrom.keys.toSet(),
                  selectedShoveFrom: _selectedShoveFrom,
                  activeShoveTargets: activeShoveTargets,
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
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: StatusBar(statusText, highlight: isMyTurn),
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

class _OrbitoPainter extends CustomPainter {
  final List<List<int>> board;
  final Set<(int, int)> shoveSources;
  final (int, int)? selectedShoveFrom;
  final Set<(int, int)> activeShoveTargets;
  final (int, int)? hovered;
  final Map? lastMove;
  final bool isMyTurn;
  final Offset origin;
  final double boardSide;
  final double cellSize;
  final ColorScheme cs;

  _OrbitoPainter({
    required this.board,
    required this.shoveSources,
    required this.selectedShoveFrom,
    required this.activeShoveTargets,
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
    final trayRect = Rect.fromLTWH(origin.dx, origin.dy, boardSide, boardSide).inflate(cellSize * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(trayRect, Radius.circular(cellSize * 0.24)),
      Paint()..color = const Color(0xFF1A232C),
    );

    // Draw outer orbit track & inner orbit track outlines
    final outerTrack = Rect.fromLTRB(
      origin.dx + cellSize * 0.5,
      origin.dy + cellSize * 0.5,
      origin.dx + cellSize * 3.5,
      origin.dy + cellSize * 3.5,
    );
    final innerTrack = Rect.fromLTRB(
      origin.dx + cellSize * 1.5,
      origin.dy + cellSize * 1.5,
      origin.dx + cellSize * 2.5,
      origin.dy + cellSize * 2.5,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(outerTrack, Radius.circular(cellSize * 0.2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = const Color(0xFF4DD0E1).withValues(alpha: 0.35),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerTrack, Radius.circular(cellSize * 0.15)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = const Color(0xFFFF8A65).withValues(alpha: 0.45),
    );

    final rotR = (lastMove?['rotatedToR'] as num?)?.toInt();
    final rotC = (lastMove?['rotatedC'] as num?)?.toInt();

    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        final rect = Rect.fromLTWH(
          origin.dx + c * cellSize,
          origin.dy + r * cellSize,
          cellSize,
          cellSize,
        ).deflate(cellSize * 0.06);

        final isInner = r >= 1 && r <= 2 && c >= 1 && c <= 2;
        Color cellColor = isInner ? const Color(0xFF283542) : const Color(0xFF212B36);
        if (selectedShoveFrom == (r, c)) {
          cellColor = Color.alphaBlend(Colors.cyanAccent.withValues(alpha: 0.35), cellColor);
        } else if (activeShoveTargets.contains((r, c))) {
          cellColor = Color.alphaBlend(Colors.orangeAccent.withValues(alpha: 0.30), cellColor);
        } else if (rotR == r && rotC == c) {
          cellColor = Color.alphaBlend(Colors.amberAccent.withValues(alpha: 0.25), cellColor);
        } else if (isMyTurn && hovered == (r, c) && board[r][c] == -1) {
          cellColor = Color.alphaBlend(Colors.greenAccent.withValues(alpha: 0.22), cellColor);
        }

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.18)),
          Paint()..color = cellColor,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.18)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withValues(alpha: 0.16),
        );

        // Draw orbit arrow watermark inside each cell
        final arrow = _OrbitoBoardState._kOrbitArrows[(r, c)] ?? '↺';
        final arrowTp = TextPainter(
          text: TextSpan(
            text: arrow,
            style: TextStyle(
              color: (isInner ? const Color(0xFFFF8A65) : const Color(0xFF4DD0E1))
                  .withValues(alpha: 0.55),
              fontWeight: FontWeight.w900,
              fontSize: cellSize * 0.28,
              fontFamilyFallback: kFontFallback,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        arrowTp.paint(canvas, rect.center - Offset(arrowTp.width / 2, arrowTp.height / 2));

        // Draw marble if present
        final m = board[r][c];
        if (m >= 0) {
          final isWhite = m == 0;
          final center = rect.center;
          final radius = cellSize * 0.34;

          canvas.drawCircle(
            center + Offset(cellSize * 0.03, cellSize * 0.04),
            radius,
            Paint()..color = Colors.black54,
          );

          canvas.drawCircle(
            center,
            radius,
            Paint()..color = isWhite ? const Color(0xFFF5F5F5) : const Color(0xFF212121),
          );

          final canShoveThis = isMyTurn && shoveSources.contains((r, c));
          final isSel = selectedShoveFrom == (r, c);
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = isSel ? 3.0 : (canShoveThis ? 2.2 : 1.6)
              ..color = isSel
                  ? Colors.cyanAccent
                  : (canShoveThis
                      ? Colors.orangeAccent
                      : (isWhite ? const Color(0xFF00E5FF) : const Color(0xFFFFCA28))),
          );
        }
      }
    }

    // Central red Orbito rotation button emblem at center of board
    final hubCenter = Offset(origin.dx + boardSide / 2, origin.dy + boardSide / 2);
    final hubR = cellSize * 0.22;
    canvas.drawCircle(hubCenter, hubR, Paint()..color = const Color(0xFFD32F2F));
    canvas.drawCircle(
      hubCenter,
      hubR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white,
    );
    final hubTp = TextPainter(
      text: TextSpan(
        text: '↺',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: cellSize * 0.24,
          fontFamilyFallback: kFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hubTp.paint(canvas, hubCenter - Offset(hubTp.width / 2, hubTp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _OrbitoPainter oldDelegate) => true;
}
