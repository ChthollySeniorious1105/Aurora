import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class OtrioBoard extends StatefulWidget {
  final GameContext g;
  const OtrioBoard(this.g, {super.key});

  @override
  State<OtrioBoard> createState() => _OtrioBoardState();
}

class _OtrioBoardState extends State<OtrioBoard> {
  int _selectedSize = 0; // 0 = Small, 1 = Medium, 2 = Large

  static const List<Color> _ringColors = [
    Color(0xFFE53935), // Seat 0: Red
    Color(0xFF1E88E5), // Seat 1: Blue
    Color(0xFF43A047), // Seat 2: Green
    Color(0xFFAB47BC), // Seat 3: Purple
  ];

  static const List<String> _colorNames = ['红环', '蓝环', '绿环', '紫环'];
  static const List<String> _sizeNames = ['小环 (内)', '中环 (中)', '大环 (外)'];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    const boardSize = 3;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final rawRings = (v['rings'] as List?) ?? const [];
    final rawReserve = (v['reserve'] as List?) ?? const [];
    final winLineRaw = (v['winLine'] as List?)?.cast<Map>() ?? const [];
    final lastMove = v['lastMove'] as Map?;

    final rings = List.generate(boardSize, (r) {
      final row = r < rawRings.length && rawRings[r] is List ? rawRings[r] as List : const [];
      return List.generate(boardSize, (c) {
        final cell = c < row.length && row[c] is List ? row[c] as List : const [];
        return List.generate(3, (s) => s < cell.length ? (cell[s] as num).toInt() : 0);
      });
    });

    final reserve = List.generate(g.players, (p) {
      final row = p < rawReserve.length && rawReserve[p] is List ? rawReserve[p] as List : const [3, 3, 3];
      return List.generate(3, (s) => s < row.length ? (row[s] as num).toInt() : 3);
    });

    final isMyTurn = !over && g.seat == turn;
    final activeSeat = g.seat >= 0 && g.seat < g.players ? g.seat : turn;
    final myRes = activeSeat < reserve.length ? reserve[activeSeat] : const [0, 0, 0];

    // Auto-switch selected size if current size is depleted
    if (isMyTurn && myRes[_selectedSize] <= 0) {
      for (var s = 0; s < 3; s++) {
        if (myRes[s] > 0) {
          _selectedSize = s;
          break;
        }
      }
    }

    final winSlots = <(int, int, int)>{
      for (final m in winLineRaw)
        (
          (m['r'] as num?)?.toInt() ?? -1,
          (m['c'] as num?)?.toInt() ?? -1,
          (m['size'] as num?)?.toInt() ?? -1,
        ),
    };

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '双方平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      statusText = '轮到你：选择圆环尺寸（当前：${_sizeNames[_selectedSize]}），点击棋盘对应槽位落环';
    } else {
      statusText = '等待 ${g.name(turn)} 放置同心圆环…';
    }

    Widget buildPlayerPanel(int s) {
      final res = s < reserve.length ? reserve[s] : const [3, 3, 3];
      final color = _ringColors[s % _ringColors.length];
      final cName = _colorNames[s % _colorNames.length];
      return g.tag(
        s,
        active: !over && turn == s,
        size: g.players > 2 ? 30 : 34,
        sub: '$cName · 小${res[0]} 中${res[1]} 大${res[2]}',
        trailing: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 4),
          ),
        ),
      );
    }

    Widget buildSizeSelector() {
      final seatForSelector = isMyTurn ? g.seat : turn;
      final res = seatForSelector >= 0 && seatForSelector < reserve.length
          ? reserve[seatForSelector]
          : const [3, 3, 3];
      final baseColor = _ringColors[seatForSelector % _ringColors.length];

      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var s = 0; s < 3; s++) ...[
              if (s > 0) const SizedBox(width: 8),
              ChoiceChip(
                selected: _selectedSize == s,
                onSelected: res[s] > 0 ? (_) => setState(() => _selectedSize = s) : null,
                avatar: Container(
                  width: 12.0 + s * 4.0,
                  height: 12.0 + s * 4.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: res[s] > 0 ? baseColor : Colors.grey,
                      width: 2.8,
                    ),
                  ),
                ),
                label: Text(
                  '${_sizeNames[s]} ×${res[s]}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final side = min(constraints.maxWidth, constraints.maxHeight);
          if (side <= 20) return const SizedBox.shrink();
          final cellSize = side / 3.35;
          final boardPx = cellSize * boardSize;
          final origin = Offset(
            (constraints.maxWidth - boardPx) / 2,
            (constraints.maxHeight - boardPx) / 2,
          );

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: !isMyTurn
                ? null
                : (details) {
                    final local = details.localPosition - origin;
                    final c = (local.dx / cellSize).floor();
                    final r = (local.dy / cellSize).floor();
                    if (r < 0 || r >= boardSize || c < 0 || c >= boardSize) return;

                    final center = Offset((c + 0.5) * cellSize, (r + 0.5) * cellSize);
                    final distRatio = (local - center).distance / cellSize;

                    // Determine radial ring slot tapped, falling back to _selectedSize
                    int tappedRing;
                    if (distRatio < 0.17) {
                      tappedRing = 0;
                    } else if (distRatio < 0.30) {
                      tappedRing = 1;
                    } else {
                      tappedRing = 2;
                    }

                    int chosenSize = _selectedSize;
                    if (rings[r][c][chosenSize] != 0 || myRes[chosenSize] <= 0) {
                      if (rings[r][c][tappedRing] == 0 && myRes[tappedRing] > 0) {
                        chosenSize = tappedRing;
                      } else {
                        for (var s = 0; s < 3; s++) {
                          if (rings[r][c][s] == 0 && myRes[s] > 0) {
                            chosenSize = s;
                            break;
                          }
                        }
                      }
                    }

                    if (rings[r][c][chosenSize] == 0 && myRes[chosenSize] > 0) {
                      setState(() => _selectedSize = chosenSize);
                      g.act({
                        'type': 'place',
                        'r': r,
                        'c': c,
                        'size': chosenSize,
                      });
                    }
                  },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _OtrioPainter(
                rings: rings,
                selectedSize: _selectedSize,
                isMyTurn: isMyTurn,
                mySeat: isMyTurn ? g.seat : turn,
                myReserve: myRes,
                winSlots: winSlots,
                lastMove: lastMove,
                cellSize: cellSize,
                origin: origin,
                cs: cs,
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
                              Flexible(
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      for (var s = 0; s < g.players; s++)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: buildPlayerPanel(s),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: StatusBar(statusText, highlight: isMyTurn),
                                ),
                              ),
                              buildSizeSelector(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: buildBoardCanvas()),
                      ],
                    )
                  : Column(
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: [
                            for (var s = 0; s < g.players; s++)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: (outer.maxWidth - 28) / 2,
                                ),
                                child: buildPlayerPanel(s),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FittedBox(fit: BoxFit.scaleDown, child: StatusBar(statusText, highlight: isMyTurn)),
                        const SizedBox(height: 4),
                        buildSizeSelector(),
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

class _OtrioPainter extends CustomPainter {
  final List<List<List<int>>> rings;
  final int selectedSize;
  final bool isMyTurn;
  final int mySeat;
  final List<int> myReserve;
  final Set<(int, int, int)> winSlots;
  final Map? lastMove;
  final double cellSize;
  final Offset origin;
  final ColorScheme cs;

  _OtrioPainter({
    required this.rings,
    required this.selectedSize,
    required this.isMyTurn,
    required this.mySeat,
    required this.myReserve,
    required this.winSlots,
    required this.lastMove,
    required this.cellSize,
    required this.origin,
    required this.cs,
  });

  static const List<Color> _ringColors = [
    Color(0xFFEF5350), // 1: Red
    Color(0xFF42A5F5), // 2: Blue
    Color(0xFF66BB6A), // 3: Green
    Color(0xFFAB47BC), // 4: Purple
  ];

  static const List<double> _radiiFactors = [0.125, 0.245, 0.375];

  Offset _center(int r, int c) => Offset(
        origin.dx + (c + 0.5) * cellSize,
        origin.dy + (r + 0.5) * cellSize,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final boardPx = cellSize * 3;
    final outerRect = Rect.fromLTWH(
      origin.dx - cellSize * 0.14,
      origin.dy - cellSize * 0.14,
      boardPx + cellSize * 0.28,
      boardPx + cellSize * 0.28,
    );
    final rrect = RRect.fromRectAndRadius(outerRect, Radius.circular(cellSize * 0.22));
    canvas.drawShadow(Path()..addRRect(rrect), Colors.black54, 10, false);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2D23), Color(0xFF221A14)],
        ).createShader(outerRect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.65),
    );

    final lastR = (lastMove?['r'] as num?)?.toInt();
    final lastC = (lastMove?['c'] as num?)?.toInt();
    final lastSize = (lastMove?['size'] as num?)?.toInt();

    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final rect = Rect.fromLTWH(
          origin.dx + c * cellSize + cellSize * 0.04,
          origin.dy + r * cellSize + cellSize * 0.04,
          cellSize * 0.92,
          cellSize * 0.92,
        );
        final cellRRect = RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.14));
        canvas.drawRRect(
          cellRRect,
          Paint()..color = const Color(0xFF2D231B),
        );
        canvas.drawRRect(
          cellRRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withValues(alpha: 0.12),
        );

        final p = _center(r, c);
        final strokeW = cellSize * 0.072;

        for (var s = 2; s >= 0; s--) {
          final radius = cellSize * _radiiFactors[s];
          final val = rings[r][c][s];
          final isLast = lastR == r && lastC == c && lastSize == s;
          final isWinSlot = winSlots.contains((r, c, s));

          // Recessed track groove
          canvas.drawCircle(
            p,
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeW
              ..color = Colors.black.withValues(alpha: 0.42),
          );

          if (val == 0) {
            // Highlight available slot for selectedSize when it's player's turn
            if (isMyTurn && s == selectedSize && myReserve[s] > 0) {
              final hintColor = _ringColors[mySeat % _ringColors.length];
              canvas.drawCircle(
                p,
                radius,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = strokeW * 0.65
                  ..color = hintColor.withValues(alpha: 0.32),
              );
            }
          } else {
            final ringColor = _ringColors[(val - 1) % _ringColors.length];

            if (isWinSlot || isLast) {
              canvas.drawCircle(
                p,
                radius,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = strokeW + 5.0
                  ..color = (isWinSlot ? Colors.amberAccent : Colors.white)
                      .withValues(alpha: isWinSlot ? 0.85 : 0.55),
              );
            }

            // Ring drop shadow
            canvas.drawCircle(
              p + const Offset(1.2, 1.8),
              radius,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeW
                ..color = Colors.black54,
            );

            // Colored concentric ring
            canvas.drawCircle(
              p,
              radius,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeW
                ..color = ringColor,
            );

            // Inner specular rim highlight
            canvas.drawCircle(
              p,
              radius,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeW * 0.25
                ..color = Colors.white.withValues(alpha: 0.55),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OtrioPainter oldDelegate) => true;
}
