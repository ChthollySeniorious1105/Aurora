import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class TumbleweedBoard extends StatefulWidget {
  final GameContext g;
  const TumbleweedBoard(this.g, {super.key});

  @override
  State<TumbleweedBoard> createState() => _TumbleweedBoardState();
}

class _TumbleweedBoardState extends State<TumbleweedBoard> {
  (int, int)? _hoveredHex;

  static Offset _axialToPixel(int q, int r, double hexRadius, Offset center) {
    final x = hexRadius * sqrt(3) * (q + r * 0.5);
    final y = hexRadius * 1.5 * r;
    return Offset(center.dx + x, center.dy + y);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final radius = (v['radius'] as num?)?.toInt() ?? 4;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final rawCells = (v['cells'] as List?)?.cast<Map>() ?? const [];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [1, 1];
    final occupied = (v['occupied'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [1, 1];
    final controlled =
        (v['controlledEmpty'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final consecutivePasses = (v['consecutivePasses'] as num?)?.toInt() ?? 0;
    final lastMove = v['lastMove'] as Map?;

    final isMyTurn = !over && g.seat == turn;

    final cellMap = <(int, int), Map>{};
    final legalTargets = <(int, int), int>{};
    for (final c in rawCells) {
      final q = (c['q'] as num?)?.toInt() ?? 0;
      final r = (c['r'] as num?)?.toInt() ?? 0;
      final h = (c['height'] as num?)?.toInt() ?? 0;
      final myLos = ((turn == 0 ? c['los0'] : c['los1']) as num?)?.toInt() ?? 0;
      cellMap[(q, r)] = c;
      if (isMyTurn && myLos >= 1 && myLos > h) {
        legalTargets[(q, r)] = myLos;
      }
    }

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      statusText = '轮到你：点击带数字标记的六角格定居/吞并（数字为视线数=新棋堆高度），或跳过';
    } else {
      statusText = '等待 ${g.name(turn)} 定居或跳过…${consecutivePasses > 0 ? '（已连续跳过 $consecutivePasses 次）' : ''}';
    }

    Widget buildPlayerPanel(int s) {
      final isRed = s == 0;
      final sc = s < scores.length ? scores[s] : 0;
      final occ = s < occupied.length ? occupied[s] : 0;
      final emp = s < controlled.length ? controlled[s] : 0;
      final colorLabel = isRed ? '红方' : '白方';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$colorLabel · $sc分 (占$occ+领$emp)',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRed ? const Color(0xFFD32F2F) : const Color(0xFFF5F5F5),
            border: Border.all(
              color: isRed ? const Color(0xFFFFCA28) : const Color(0xFF26C6DA),
              width: 2.0,
            ),
          ),
        ),
      );
    }

    Widget? buildPassButton() {
      if (!isMyTurn) return null;
      return FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        onPressed: () => g.act({'type': 'pass'}),
        icon: const Icon(Icons.skip_next, size: 16),
        label: Text(consecutivePasses > 0 ? '跳过并结算 (Pass)' : '跳过回合 (Pass)'),
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          if (w <= 20 || h <= 20) return const SizedBox.shrink();

          final hexRadius = min(
            w / (sqrt(3) * (2 * radius + 1.5)),
            h / (3.0 * radius + 2.6),
          );
          final center = Offset(w / 2, h / 2);

          (int, int)? hitHexAt(Offset pos) {
            (int, int)? best;
            var bestDist = hexRadius * 0.92;
            for (final key in cellMap.keys) {
              final cPos = _axialToPixel(key.$1, key.$2, hexRadius, center);
              final d = (pos - cPos).distance;
              if (d < bestDist) {
                bestDist = d;
                best = key;
              }
            }
            return best;
          }

          return MouseRegion(
            onHover: !isMyTurn
                ? null
                : (e) {
                    final hit = hitHexAt(e.localPosition);
                    if (hit != _hoveredHex) {
                      setState(() => _hoveredHex = hit);
                    }
                  },
            onExit: (_) {
              if (_hoveredHex != null) setState(() => _hoveredHex = null);
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: !isMyTurn
                  ? null
                  : (details) {
                      final hit = hitHexAt(details.localPosition);
                      if (hit != null && legalTargets.containsKey(hit)) {
                        g.act({'type': 'settle', 'q': hit.$1, 'r': hit.$2});
                      }
                    },
              child: CustomPaint(
                size: Size(w, h),
                painter: _TumbleweedPainter(
                  radius: radius,
                  cellMap: cellMap,
                  legalTargets: legalTargets,
                  hoveredHex: _hoveredHex,
                  turn: turn,
                  isMyTurn: isMyTurn,
                  lastMove: lastMove,
                  hexRadius: hexRadius,
                  center: center,
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
        final passBtn = buildPassButton();

        return Stack(
          children: [
            Container(
              color: g.table,
              padding: const EdgeInsets.all(8),
              child: isWide
                  ? Row(
                      children: [
                        SizedBox(
                          width: min(240, outer.maxWidth * 0.28),
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
                                      if (passBtn != null) ...[
                                        const SizedBox(height: 6),
                                        FittedBox(fit: BoxFit.scaleDown, child: passBtn),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: StatusBar(statusText, highlight: isMyTurn),
                              ),
                            ),
                            if (passBtn != null) ...[
                              const SizedBox(width: 6),
                              FittedBox(fit: BoxFit.scaleDown, child: passBtn),
                            ],
                          ],
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

class _TumbleweedPainter extends CustomPainter {
  final int radius;
  final Map<(int, int), Map> cellMap;
  final Map<(int, int), int> legalTargets;
  final (int, int)? hoveredHex;
  final int turn;
  final bool isMyTurn;
  final Map? lastMove;
  final double hexRadius;
  final Offset center;
  final ColorScheme cs;

  _TumbleweedPainter({
    required this.radius,
    required this.cellMap,
    required this.legalTargets,
    required this.hoveredHex,
    required this.turn,
    required this.isMyTurn,
    required this.lastMove,
    required this.hexRadius,
    required this.center,
    required this.cs,
  });

  static Path _hexPath(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * pi / 180.0;
      final px = c.dx + r * cos(angle);
      final py = c.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lastQ = (lastMove?['q'] as num?)?.toInt();
    final lastR = (lastMove?['r'] as num?)?.toInt();

    for (final entry in cellMap.entries) {
      final (q, r) = entry.key;
      final data = entry.value;
      final owner = (data['owner'] as num?)?.toInt() ?? -2;
      final height = (data['height'] as num?)?.toInt() ?? 0;
      final territory = (data['territory'] as num?)?.toInt() ?? -1;

      final cPos = _TumbleweedBoardState._axialToPixel(q, r, hexRadius, center);
      final path = _hexPath(cPos, hexRadius * 0.94);

      Color fill = const Color(0xFF2D2620);
      if (height == 0) {
        if (territory == 0) {
          fill = Color.alphaBlend(const Color(0xFFD32F2F).withValues(alpha: 0.22), fill);
        } else if (territory == 1) {
          fill = Color.alphaBlend(const Color(0xFF4DD0E1).withValues(alpha: 0.22), fill);
        }
      }
      if (q == 0 && r == 0 && height == 0) {
        fill = Color.alphaBlend(Colors.amber.withValues(alpha: 0.14), fill);
      }
      if (q == lastQ && r == lastR) {
        fill = Color.alphaBlend(Colors.amberAccent.withValues(alpha: 0.28), fill);
      }
      if (hoveredHex == (q, r) && legalTargets.containsKey((q, r))) {
        fill = Color.alphaBlend(Colors.greenAccent.withValues(alpha: 0.28), fill);
      }

      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (q == lastQ && r == lastR) ? 2.2 : 1.1
          ..color = (q == lastQ && r == lastR)
              ? Colors.amberAccent
              : Colors.white.withValues(alpha: 0.18),
      );

      final targetH = legalTargets[(q, r)];

      if (height > 0) {
        // Draw stack discs
        final discRadius = hexRadius * 0.56;
        final List<Color> gradColors;
        final Color rimColor;
        final Color textColor;
        if (owner == 0) {
          gradColors = [const Color(0xFFEF5350), const Color(0xFFB71C1C)];
          rimColor = const Color(0xFFFFCA28);
          textColor = Colors.white;
        } else if (owner == 1) {
          gradColors = [const Color(0xFFFFFFFF), const Color(0xFFCFD8DC)];
          rimColor = const Color(0xFF00ACC1);
          textColor = const Color(0xFF1A2327);
        } else {
          // Neutral stack (-1)
          gradColors = [const Color(0xFFB0BEC5), const Color(0xFF546E7A)];
          rimColor = const Color(0xFFFFD54F);
          textColor = Colors.white;
        }

        final layers = min(height, 6);
        final stepY = hexRadius * 0.055;
        final baseOffset = Offset(0, (layers - 1) * stepY * 0.5);

        for (var l = 0; l < layers; l++) {
          final lCenter = cPos + baseOffset - Offset(0, l * stepY);
          if (l == 0) {
            canvas.drawCircle(
              lCenter + const Offset(1.0, 2.0),
              discRadius,
              Paint()..color = Colors.black54,
            );
          }
          canvas.drawCircle(
            lCenter,
            discRadius,
            Paint()
              ..shader = RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: gradColors,
              ).createShader(Rect.fromCircle(center: lCenter, radius: discRadius)),
          );
          canvas.drawCircle(
            lCenter,
            discRadius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = l == layers - 1 ? 1.8 : 1.0
              ..color = l == layers - 1 ? rimColor : Colors.black38,
          );
        }

        final topCenter = cPos + baseOffset - Offset(0, (layers - 1) * stepY);
        final label = targetH != null ? '$height→$targetH' : '$height';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: targetH != null ? Colors.greenAccent : textColor,
              fontWeight: FontWeight.w900,
              fontSize: hexRadius * (targetH != null ? 0.36 : 0.48),
              fontFamilyFallback: kFontFallback,
              shadows: targetH != null
                  ? const [Shadow(color: Colors.black, blurRadius: 3)]
                  : null,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, topCenter - Offset(tp.width / 2, tp.height / 2));
      } else if (targetH != null) {
        // Empty hex where active player can settle with height targetH
        final badgeRadius = hexRadius * 0.34;
        canvas.drawCircle(
          cPos,
          badgeRadius,
          Paint()..color = Colors.greenAccent.withValues(alpha: 0.22),
        );
        canvas.drawCircle(
          cPos,
          badgeRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = Colors.greenAccent.withValues(alpha: 0.8),
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '$targetH',
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: hexRadius * 0.38,
              fontFamilyFallback: kFontFallback,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, cPos - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TumbleweedPainter oldDelegate) => true;
}
