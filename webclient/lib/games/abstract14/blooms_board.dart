import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class BloomsBoard extends StatefulWidget {
  final GameContext g;
  const BloomsBoard(this.g, {super.key});

  @override
  State<BloomsBoard> createState() => _BloomsBoardState();
}

class _BloomsBoardState extends State<BloomsBoard> {
  int? _selectedColor;

  static Color _fillForColor(int c) {
    switch (c) {
      case 1:
        return const Color(0xFFFF80AB); // 🌸 樱粉
      case 2:
        return const Color(0xFFE53935); // 🌺 赤红
      case 3:
        return const Color(0xFF29B6F6); // 💠 冰蓝
      case 4:
        return const Color(0xFF7E57C2); // 🔮 靛紫
      default:
        return Colors.grey;
    }
  }

  static String _nameForColor(int c) {
    switch (c) {
      case 1:
        return '🌸 樱粉';
      case 2:
        return '🌺 赤红';
      case 3:
        return '💠 冰蓝';
      case 4:
        return '🔮 靛紫';
      default:
        return '';
    }
  }

  Offset _axialToPixel(int q, int r, double step) {
    final x = step * 1.5 * q;
    final y = step * sqrt(3) * (r + q * 0.5);
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final radius = (v['radius'] as num?)?.toInt() ?? 4;
    final targetCaptures = (v['targetCaptures'] as num?)?.toInt() ?? 15;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final turnNumber = (v['turnNumber'] as num?)?.toInt() ?? 0;
    final maxPlacements = (v['maxPlacementsThisTurn'] as num?)?.toInt() ?? 1;
    final availColors = (v['availableColors'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final placedThisTurn = (v['placedColorsThisTurn'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final canEndTurn = v['canEndTurn'] == true;
    final captured = (v['captured'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final lastCapturedRaw = (v['lastCapturedCells'] as List?) ?? const [];
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final cellsList = (v['cells'] as List?)?.cast<Map>() ?? const [];
    final lastMove = v['lastMove'] as Map?;

    final cellMap = <(int, int), Map>{};
    for (final c in cellsList) {
      final q = (c['q'] as num).toInt();
      final r = (c['r'] as num).toInt();
      cellMap[(q, r)] = c;
    }

    final lastCapSet = <(int, int)>{
      for (final item in lastCapturedRaw)
        if (item is List && item.length >= 2)
          ((item[0] as num).toInt(), (item[1] as num).toInt()),
    };

    final isMyTurn = !over && g.seat == turn;
    if (availColors.isNotEmpty) {
      if (_selectedColor == null || !availColors.contains(_selectedColor)) {
        _selectedColor = availColors.first;
      }
    } else {
      _selectedColor = null;
    }

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '双方平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      if (turnNumber == 0) {
        statusText = '首回合平衡：请选择一种花色在任意空格放置 1 颗花子';
      } else if (placedThisTurn.isEmpty) {
        statusText = '轮到你（第 1/$maxPlacements 子）：选择花色落子，本回合可下两颗异色花子';
      } else {
        final remColor = availColors.isNotEmpty ? _nameForColor(availColors.first) : '';
        statusText = '已落 1 子：请继续放置 $remColor（第 2/2 子），或点击「结束回合」';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 落子（已落 ${placedThisTurn.length}/$maxPlacements 子）…';
    }

    Widget buildPlayerPanel(int s) {
      final cap = s < captured.length ? captured[s] : 0;
      final c1 = s == 0 ? 1 : 3;
      final c2 = s == 0 ? 2 : 4;
      final title = s == 0 ? '春花方' : '寒晶方';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$title · 俘获 $cap/$targetCaptures',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _fillForColor(c1),
                border: Border.all(color: Colors.white70, width: 1.2),
              ),
            ),
            const SizedBox(width: 3),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _fillForColor(c2),
                border: Border.all(color: Colors.white70, width: 1.2),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildActionBar() {
      final myColors = turn == 0 ? const [1, 2] : const [3, 4];
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in myColors) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  selected: _selectedColor == c,
                  label: Text(
                    _nameForColor(c),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  avatar: CircleAvatar(backgroundColor: _fillForColor(c), radius: 7),
                  onSelected: isMyTurn && availColors.contains(c)
                      ? (_) => setState(() => _selectedColor = c)
                      : null,
                ),
              ),
            ],
            if (isMyTurn && canEndTurn)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: FilledButton.tonalIcon(
                  onPressed: () => g.act({'type': 'end_turn'}),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('结束回合', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final side = min(constraints.maxWidth, constraints.maxHeight);
          if (side <= 20) return const SizedBox.shrink();
          final hexStep = side / (radius == 3 ? 12.2 : 15.2);
          final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: !isMyTurn || _selectedColor == null
                ? null
                : (details) {
                    final tap = details.localPosition - center;
                    (int, int)? hit;
                    var bestDist = hexStep * 0.85;
                    for (final pos in cellMap.keys) {
                      final d = (tap - _axialToPixel(pos.$1, pos.$2, hexStep)).distance;
                      if (d < bestDist) {
                        bestDist = d;
                        hit = pos;
                      }
                    }
                    if (hit == null) return;
                    final c = cellMap[hit]!;
                    if ((c['color'] as num).toInt() != 0) return;
                    g.act({
                      'type': 'place',
                      'q': hit.$1,
                      'r': hit.$2,
                      'color': _selectedColor!,
                    });
                  },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _BloomsPainter(
                cellMap: cellMap,
                radius: radius,
                lastCapSet: lastCapSet,
                lastMove: lastMove,
                selectedColor: _selectedColor,
                isMyTurn: isMyTurn,
                hexStep: hexStep,
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
                          width: min(245, outer.maxWidth * 0.29),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buildPlayerPanel(1),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: StatusBar(statusText, highlight: isMyTurn),
                                    ),
                                    const SizedBox(height: 6),
                                    buildActionBar(),
                                  ],
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
                        FittedBox(fit: BoxFit.scaleDown, child: StatusBar(statusText, highlight: isMyTurn)),
                        const SizedBox(height: 2),
                        buildActionBar(),
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

class _BloomsPainter extends CustomPainter {
  final Map<(int, int), Map> cellMap;
  final int radius;
  final Set<(int, int)> lastCapSet;
  final Map? lastMove;
  final int? selectedColor;
  final bool isMyTurn;
  final double hexStep;
  final ColorScheme cs;

  _BloomsPainter({
    required this.cellMap,
    required this.radius,
    required this.lastCapSet,
    required this.lastMove,
    required this.selectedColor,
    required this.isMyTurn,
    required this.hexStep,
    required this.cs,
  });

  Offset _pos(int q, int r, Offset center) {
    final x = hexStep * 1.5 * q;
    final y = hexStep * sqrt(3) * (r + q * 0.5);
    return center + Offset(x, y);
  }

  Path _hexPolygon(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3;
      final pt = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    return path;
  }

  static (Color, Color, Color) _paletteFor(int color) {
    switch (color) {
      case 1: // 🌸 樱粉
        return (const Color(0xFFFFB2C9), const Color(0xFFD81B60), const Color(0xFFFFE4EC));
      case 2: // 🌺 赤红
        return (const Color(0xFFFF6E40), const Color(0xFFB71C1C), const Color(0xFFFFCCBC));
      case 3: // 💠 冰蓝
        return (const Color(0xFF80D8FF), const Color(0xFF0277BD), const Color(0xFFE1F5FE));
      case 4: // 🔮 靛紫
        return (const Color(0xFFB388FF), const Color(0xFF4527A0), const Color(0xFFEDE7F6));
      default:
        return (Colors.grey, Colors.black, Colors.white);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bgRadius = hexStep * (radius == 3 ? 5.6 : 7.3);

    final bgPath = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * pi / 3 + pi / 6;
      final pt = Offset(center.dx + bgRadius * cos(a), center.dy + bgRadius * sin(a));
      if (i == 0) {
        bgPath.moveTo(pt.dx, pt.dy);
      } else {
        bgPath.lineTo(pt.dx, pt.dy);
      }
    }
     bgPath.close();

    canvas.drawShadow(bgPath, Colors.black54, 8, false);
    canvas.drawPath(
      bgPath,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF28352C), Color(0xFF161F19)],
        ).createShader(Rect.fromCircle(center: center, radius: bgRadius)),
    );
    canvas.drawPath(
      bgPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.6),
    );

    final lastQ = (lastMove?['q'] as num?)?.toInt();
    final lastR = (lastMove?['r'] as num?)?.toInt();

    for (final entry in cellMap.entries) {
      final (q, r) = entry.key;
      final c = entry.value;
      final color = (c['color'] as num).toInt();
      final libs = (c['liberties'] as num?)?.toInt() ?? 0;
      final isLast = lastQ == q && lastR == r;
      final wasCaptured = lastCapSet.contains((q, r));
      final p = _pos(q, r, center);
      final hexPath = _hexPolygon(p, hexStep * 0.54);

      Color cellFill = Colors.white.withValues(alpha: 0.06);
      if (wasCaptured) {
        cellFill = Colors.amberAccent.withValues(alpha: 0.22);
      }
      canvas.drawPath(hexPath, Paint()..color = cellFill);
      canvas.drawPath(
        hexPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = wasCaptured ? 1.8 : 1.0
          ..color = wasCaptured
              ? Colors.amberAccent.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.18),
      );

      if (color == 0) {
        canvas.drawCircle(
          p,
          hexStep * 0.08,
          Paint()..color = Colors.white.withValues(alpha: 0.20),
        );
      } else {
        final stoneRadius = hexStep * 0.41;
        final (lightCol, darkCol, rimCol) = _paletteFor(color);

        if (isLast || libs == 1) {
          canvas.drawCircle(
            p,
            stoneRadius + 3.2,
            Paint()
              ..color = isLast
                  ? Colors.amberAccent.withValues(alpha: 0.85)
                  : Colors.redAccent.withValues(alpha: 0.65),
          );
        }

        canvas.drawCircle(
          p + const Offset(1.3, 2.0),
          stoneRadius,
          Paint()..color = Colors.black45,
        );
        canvas.drawCircle(
          p,
          stoneRadius,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [lightCol, darkCol],
            ).createShader(Rect.fromCircle(center: p, radius: stoneRadius)),
        );
        canvas.drawCircle(
          p,
          stoneRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = rimCol.withValues(alpha: 0.85),
        );

        // Draw subtle inner blossom ring + liberty count
        final label = libs > 0 ? '$libs' : '';
        if (label.isNotEmpty) {
          final tp = TextPainter(
            text: TextSpan(
              text: label,
              style: TextStyle(
                fontSize: hexStep * 0.34,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.92),
                fontFamilyFallback: kFontFallback,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BloomsPainter oldDelegate) => true;
}
