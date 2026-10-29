import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class BoopBoard extends StatefulWidget {
  final GameContext g;
  const BoopBoard(this.g, {super.key});

  @override
  State<BoopBoard> createState() => _BoopBoardState();
}

class _BoopBoardState extends State<BoopBoard> {
  String _selectedKind = 'kitten';
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
    final kittens =
        (v['kittens'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [8, 8];
    final cats =
        (v['cats'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final lastMove = v['lastMove'] as Map?;

    final rawBoard = (v['board'] as List?) ?? const [];
    final board = List.generate(6, (r) {
      final row = r < rawBoard.length ? (rawBoard[r] as List) : const [];
      return List.generate(6, (c) => c < row.length ? (row[c] as Map?) : null);
    });

    final isMyTurn = !over && g.seat == turn;
    final myKittens = turn < kittens.length ? kittens[turn] : 0;
    final myCats = turn < cats.length ? cats[turn] : 0;

    if (_selectedKind == 'cat' && myCats <= 0 && myKittens > 0) {
      _selectedKind = 'kitten';
    } else if (_selectedKind == 'kitten' && myKittens <= 0 && myCats > 0) {
      _selectedKind = 'cat';
    }

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      final kLabel = _selectedKind == 'cat' ? '大猫🐈(可推大小猫)' : '小猫🐱(仅推小猫)';
      statusText = '轮到你：当前选择放置【$kLabel】，点击床垫空格落子并触发八向推挤！';
    } else {
      statusText = '等待 ${g.name(turn)} 在床垫上放置猫咪…';
    }

    Widget buildPlayerPanel(int s) {
      final isOrange = s == 0;
      final kCnt = s < kittens.length ? kittens[s] : 0;
      final cCnt = s < cats.length ? cats[s] : 0;
      final colorLabel = isOrange ? '橘猫方' : '蓝猫方';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$colorLabel · 池中小猫🐱$kCnt · 大猫🐈$cCnt',
        trailing: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOrange ? const Color(0xFFFF8F00) : const Color(0xFF1E88E5),
            border: Border.all(color: Colors.white70, width: 1.5),
          ),
          child: Text(
            cCnt > 0 ? '🐈' : '🐱',
            style: const TextStyle(fontSize: 11, fontFamilyFallback: kFontFallback),
          ),
        ),
      );
    }

    Widget? buildKindSelector() {
      if (!isMyTurn) return null;
      return Wrap(
        spacing: 8,
        alignment: WrapAlignment.center,
        children: [
          ChoiceChip(
            label: Text('🐱 放置小猫 (余 $myKittens)', style: const TextStyle(fontSize: 12)),
            selected: _selectedKind == 'kitten',
            onSelected: myKittens > 0 ? (_) => setState(() => _selectedKind = 'kitten') : null,
            visualDensity: VisualDensity.compact,
          ),
          ChoiceChip(
            label: Text('🐈 放置大猫 (余 $myCats)', style: const TextStyle(fontSize: 12)),
            selected: _selectedKind == 'cat',
            onSelected: myCats > 0 ? (_) => setState(() => _selectedKind = 'cat') : null,
            visualDensity: VisualDensity.compact,
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

          final boardSide = min(w, h) * 0.92;
          final cellSize = boardSide / 6.0;
          final origin = Offset((w - boardSide) / 2, (h - boardSide) / 2);

          (int, int)? hitCellAt(Offset pos) {
            final c = ((pos.dx - origin.dx) / cellSize).floor();
            final r = ((pos.dy - origin.dy) / cellSize).floor();
            if (r >= 0 && r < 6 && c >= 0 && c < 6) return (r, c);
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
                      if (hit == null) return;
                      final (r, c) = hit;
                      if (board[r][c] == null) {
                        g.act({
                          'type': 'place',
                          'r': r,
                          'c': c,
                          'kind': _selectedKind,
                        });
                      }
                    },
              child: CustomPaint(
                size: Size(w, h),
                painter: _BoopPainter(
                  board: board,
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
        final selector = buildKindSelector();

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
                                      if (selector != null) ...[
                                        const SizedBox(height: 6),
                                        FittedBox(fit: BoxFit.scaleDown, child: selector),
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
                        if (selector != null) ...[
                          const SizedBox(height: 4),
                          FittedBox(fit: BoxFit.scaleDown, child: selector),
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

class _BoopPainter extends CustomPainter {
  final List<List<Map?>> board;
  final (int, int)? hovered;
  final Map? lastMove;
  final bool isMyTurn;
  final Offset origin;
  final double boardSide;
  final double cellSize;
  final ColorScheme cs;

  _BoopPainter({
    required this.board,
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
    final bedRect = Rect.fromLTWH(origin.dx, origin.dy, boardSide, boardSide);
    final mattressFrame = bedRect.inflate(cellSize * 0.14);

    // Quilted bed outer border (soft indigo/lavender blanket rim)
    canvas.drawRRect(
      RRect.fromRectAndRadius(mattressFrame, Radius.circular(cellSize * 0.28)),
      Paint()..color = const Color(0xFF283593),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bedRect, Radius.circular(cellSize * 0.20)),
      Paint()..color = const Color(0xFF3949AB),
    );

    final lastR = (lastMove?['r'] as num?)?.toInt();
    final lastC = (lastMove?['c'] as num?)?.toInt();

    // Draw 6x6 quilted patches
    for (var r = 0; r < 6; r++) {
      for (var c = 0; c < 6; c++) {
        final rect = Rect.fromLTWH(
          origin.dx + c * cellSize,
          origin.dy + r * cellSize,
          cellSize,
          cellSize,
        ).deflate(cellSize * 0.04);

        final isEven = (r + c).isEven;
        Color patchColor = isEven ? const Color(0xFF5C6BC0) : const Color(0xFF49599A);
        if (lastR == r && lastC == c) {
          patchColor = Color.alphaBlend(Colors.amberAccent.withValues(alpha: 0.28), patchColor);
        } else if (isMyTurn && hovered == (r, c) && board[r][c] == null) {
          patchColor = Color.alphaBlend(Colors.greenAccent.withValues(alpha: 0.25), patchColor);
        }

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.16)),
          Paint()..color = patchColor,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.16)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withValues(alpha: 0.22),
        );

        final p = board[r][c];
        if (p != null) {
          final owner = (p['owner'] as num?)?.toInt() ?? 0;
          final kind = (p['kind'] as String?) ?? 'kitten';
          final isCat = kind == 'cat';
          final isOrange = owner == 0;
          final center = rect.center;
          final radius = cellSize * (isCat ? 0.39 : 0.30);

          // Shadow
          canvas.drawCircle(
            center + Offset(cellSize * 0.03, cellSize * 0.04),
            radius,
            Paint()..color = Colors.black45,
          );

          final fill = isOrange
              ? (isCat ? const Color(0xFFFF6F00) : const Color(0xFFFFB300))
              : (isCat ? const Color(0xFF1565C0) : const Color(0xFF42A5F5));
          final rim = isCat ? const Color(0xFFFFD740) : Colors.white;

          canvas.drawCircle(center, radius, Paint()..color = fill);
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = isCat ? 2.6 : 1.6
              ..color = rim,
          );

          final tp = TextPainter(
            text: TextSpan(
              text: isCat ? '🐈' : '🐱',
              style: TextStyle(
                fontSize: cellSize * (isCat ? 0.38 : 0.28),
                fontFamilyFallback: kFontFallback,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }

    // Draw push arrows from lastMove
    final pushed = (lastMove?['pushed'] as List?)?.cast<Map>() ?? const [];
    for (final p in pushed) {
      final fr = (p['fromR'] as num?)?.toInt();
      final fc = (p['fromC'] as num?)?.toInt();
      final tr = (p['toR'] as num?)?.toInt();
      final tc = (p['toC'] as num?)?.toInt();
      if (fr != null && fc != null && tr != null && tc != null) {
        final p1 = Offset(origin.dx + (fc + 0.5) * cellSize, origin.dy + (fr + 0.5) * cellSize);
        final clampedR = tr.clamp(-0.3, 5.3);
        final clampedC = tc.clamp(-0.3, 5.3);
        final p2 = Offset(
          origin.dx + (clampedC + 0.5) * cellSize,
          origin.dy + (clampedR + 0.5) * cellSize,
        );
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = Colors.amberAccent.withValues(alpha: 0.75)
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoopPainter oldDelegate) => true;
}
