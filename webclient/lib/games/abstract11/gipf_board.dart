import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class GipfBoard extends StatefulWidget {
  final GameContext g;
  const GipfBoard(this.g, {super.key});

  @override
  State<GipfBoard> createState() => _GipfBoardState();
}

class _GipfBoardState extends State<GipfBoard> {
  (int, int)? _selectedRim;

  Offset _axialToPixel(int q, int r, double radius) {
    // Flat-topped hex axial coordinates
    final x = radius * 1.5 * q;
    final y = radius * sqrt(3) * (r + q * 0.5);
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final reserve = (v['reserve'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [15, 15];
    final captured = (v['captured'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0];
    final lastMove = v['lastMove'] as Map?;
    final rimPoints = (v['rimPoints'] as List?)?.cast<Map>() ?? const [];
    final cellsList = (v['cells'] as List?)?.cast<Map>() ?? const [];

    final cellMap = <(int, int), int>{};
    for (final c in cellsList) {
      cellMap[((c['q'] as num).toInt(), (c['r'] as num).toInt())] = (c['color'] as num).toInt();
    }

    final isMyTurn = !over && g.seat == turn;

    // Validate _selectedRim still has legal directions
    Map? selectedRimData;
    if (_selectedRim != null) {
      for (final rp in rimPoints) {
        if ((rp['q'] as num).toInt() == _selectedRim!.$1 && (rp['r'] as num).toInt() == _selectedRim!.$2) {
          selectedRimData = rp;
          break;
        }
      }
    }

    final legalDirsForSelected = <Map>[];
    if (selectedRimData != null) {
      final dirs = (selectedRimData['dirs'] as List?)?.cast<Map>() ?? const [];
      for (final d in dirs) {
        if (d['legal'] == true) legalDirsForSelected.add(d);
      }
    }

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '双方和棋' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      statusText = _selectedRim == null
          ? '轮到你：点击外圈金色入口点推入棋子'
          : '已选外圈入口 ($_selectedRim)：点击绿色箭头目标格确认推入方向';
    } else {
      statusText = '等待 ${g.name(turn)} 推入棋子…';
    }

    Widget buildPlayerPanel(int s) {
      final colorLabel = s == 0 ? '白子' : '黑子';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$colorLabel · 储备 ${reserve[s]} · 俘获 ${captured[s]}',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: s == 0 ? const Color(0xFFFDFBF7) : const Color(0xFF22252A),
            border: Border.all(
              color: s == 0 ? Colors.brown.shade400 : Colors.grey.shade400,
              width: 1.5,
            ),
          ),
        ),
      );
    }

    Widget buildBoardCanvas() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final side = min(constraints.maxWidth, constraints.maxHeight);
          if (side <= 20) return const SizedBox.shrink();
          final hexStep = side / 15.2;
          final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: !isMyTurn
                ? null
                : (details) {
                    final tap = details.localPosition - center;
                    // First check if user tapped a target interior cell of the currently selected rim point
                    if (_selectedRim != null && legalDirsForSelected.isNotEmpty) {
                      for (final d in legalDirsForSelected) {
                        final toQ = (d['toQ'] as num).toInt();
                        final toR = (d['toR'] as num).toInt();
                        final pos = _axialToPixel(toQ, toR, hexStep);
                        if ((tap - pos).distance <= hexStep * 0.72) {
                          final (fq, fr) = _selectedRim!;
                          setState(() => _selectedRim = null);
                          g.act({
                            'type': 'push',
                            'fromQ': fq,
                            'fromR': fr,
                            'dq': (d['dq'] as num).toInt(),
                            'dr': (d['dr'] as num).toInt(),
                          });
                          return;
                        }
                      }
                    }

                    // Otherwise check if user tapped a rim entry point
                    (int, int)? hitRim;
                    var bestDist = hexStep * 0.78;
                    Map? hitRimData;
                    for (final rp in rimPoints) {
                      final q = (rp['q'] as num).toInt();
                      final r = (rp['r'] as num).toInt();
                      final dirs = (rp['dirs'] as List?)?.cast<Map>() ?? const [];
                      if (!dirs.any((d) => d['legal'] == true)) continue;
                      final pos = _axialToPixel(q, r, hexStep);
                      final dist = (tap - pos).distance;
                      if (dist < bestDist) {
                        bestDist = dist;
                        hitRim = (q, r);
                        hitRimData = rp;
                      }
                    }

                    if (hitRim != null && hitRimData != null) {
                      final legalDirs = ((hitRimData['dirs'] as List?)?.cast<Map>() ?? const [])
                          .where((d) => d['legal'] == true)
                          .toList();
                      // If only 1 legal inward direction and tapped again (or corner point), push directly!
                      if (legalDirs.length == 1 && _selectedRim == hitRim) {
                        final d = legalDirs.first;
                        setState(() => _selectedRim = null);
                        g.act({
                          'type': 'push',
                          'fromQ': hitRim.$1,
                          'fromR': hitRim.$2,
                          'dq': (d['dq'] as num).toInt(),
                          'dr': (d['dr'] as num).toInt(),
                        });
                        return;
                      }
                      setState(() => _selectedRim = hitRim);
                    } else {
                      setState(() => _selectedRim = null);
                    }
                  },
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _GipfPainter(
                cells: cellMap,
                rimPoints: rimPoints,
                selectedRim: _selectedRim,
                legalDirsForSelected: legalDirsForSelected,
                lastMove: lastMove,
                isMyTurn: isMyTurn,
                turn: turn,
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
                          width: min(230, outer.maxWidth * 0.28),
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
                                      FittedBox(fit: BoxFit.scaleDown, child: StatusBar(statusText, highlight: isMyTurn)),
                                      if (isMyTurn && _selectedRim != null && legalDirsForSelected.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          alignment: WrapAlignment.center,
                                          children: [
                                            for (final d in legalDirsForSelected)
                                              FilledButton.tonalIcon(
                                                style: FilledButton.styleFrom(
                                                  visualDensity: VisualDensity.compact,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                ),
                                                onPressed: () {
                                                  final (fq, fr) = _selectedRim!;
                                                  setState(() => _selectedRim = null);
                                                  g.act({
                                                    'type': 'push',
                                                    'fromQ': fq,
                                                    'fromR': fr,
                                                    'dq': (d['dq'] as num).toInt(),
                                                    'dr': (d['dr'] as num).toInt(),
                                                  });
                                                },
                                                icon: const Icon(Icons.play_arrow, size: 15),
                                                label: Text('推向 (${d['toQ']},${d['toR']})', style: const TextStyle(fontSize: 12)),
                                              ),
                                          ],
                                        ),
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
                        FittedBox(fit: BoxFit.scaleDown, child: StatusBar(statusText, highlight: isMyTurn)),
                        if (isMyTurn && _selectedRim != null && legalDirsForSelected.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final d in legalDirsForSelected)
                                  FilledButton.tonalIcon(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                    ),
                                    onPressed: () {
                                      final (fq, fr) = _selectedRim!;
                                      setState(() => _selectedRim = null);
                                      g.act({
                                        'type': 'push',
                                        'fromQ': fq,
                                        'fromR': fr,
                                        'dq': (d['dq'] as num).toInt(),
                                        'dr': (d['dr'] as num).toInt(),
                                      });
                                    },
                                    icon: const Icon(Icons.play_arrow, size: 14),
                                    label: Text('推向 (${d['toQ']},${d['toR']})', style: const TextStyle(fontSize: 12)),
                                  ),
                              ],
                            ),
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

class _GipfPainter extends CustomPainter {
  final Map<(int, int), int> cells;
  final List<Map> rimPoints;
  final (int, int)? selectedRim;
  final List<Map> legalDirsForSelected;
  final Map? lastMove;
  final bool isMyTurn;
  final int turn;
  final double hexStep;
  final ColorScheme cs;

  _GipfPainter({
    required this.cells,
    required this.rimPoints,
    required this.selectedRim,
    required this.legalDirsForSelected,
    required this.lastMove,
    required this.isMyTurn,
    required this.turn,
    required this.hexStep,
    required this.cs,
  });

  Offset _pos(int q, int r, Offset center) {
    final x = hexStep * 1.5 * q;
    final y = hexStep * sqrt(3) * (r + q * 0.5);
    return center + Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw outer hex board background (corners at radius 4)
    const rimCorners = [
      (4, 0),
      (0, 4),
      (-4, 4),
      (-4, 0),
      (0, -4),
      (4, -4),
    ];
    final boardPath = Path();
    for (var i = 0; i < rimCorners.length; i++) {
      final (q, r) = rimCorners[i];
      final p = _pos(q, r, center);
      if (i == 0) {
        boardPath.moveTo(p.dx, p.dy);
      } else {
        boardPath.lineTo(p.dx, p.dy);
      }
    }
    boardPath.close();

    canvas.drawShadow(boardPath, Colors.black54, 8, false);
    canvas.drawPath(
      boardPath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF2B3544),
            const Color(0xFF1A212C),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: hexStep * 7)),
    );
    canvas.drawPath(
      boardPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFFD4AF37).withValues(alpha: 0.65),
    );

    // Draw grid lines connecting adjacent cells (including rim to interior)
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.4;

    const dirs = [(1, 0), (0, 1), (-1, 1)];
    for (final (q, r) in cells.keys) {
      final p1 = _pos(q, r, center);
      for (final (dq, dr) in dirs) {
        final nq = q + dq;
        final nr = r + dr;
        if (cells.containsKey((nq, nr))) {
          canvas.drawLine(p1, _pos(nq, nr, center), linePaint);
        }
      }
    }
    // Draw rim entry connectors
    for (final rp in rimPoints) {
      final q0 = (rp['q'] as num).toInt();
      final r0 = (rp['r'] as num).toInt();
      final p0 = _pos(q0, r0, center);
      final rDirs = (rp['dirs'] as List?)?.cast<Map>() ?? const [];
      for (final d in rDirs) {
        final toQ = (d['toQ'] as num).toInt();
        final toR = (d['toR'] as num).toInt();
        canvas.drawLine(
          p0,
          _pos(toQ, toR, center),
          Paint()
            ..color = const Color(0xFFD4AF37).withValues(alpha: 0.35)
            ..strokeWidth = 1.3,
        );
      }
    }

    // Highlight last move shifted path
    final shiftedSet = <(int, int)>{};
    if (lastMove != null) {
      final shifted = (lastMove!['shifted'] as List?) ?? const [];
      for (final item in shifted) {
        if (item is List && item.length >= 2) {
          shiftedSet.add(((item[0] as num).toInt(), (item[1] as num).toInt()));
        }
      }
    }

    // Draw 37 interior nodes and pieces
    for (final entry in cells.entries) {
      final (q, r) = entry.key;
      final color = entry.value;
      final p = _pos(q, r, center);

      if (shiftedSet.contains((q, r))) {
        canvas.drawCircle(
          p,
          hexStep * 0.44,
          Paint()..color = Colors.amberAccent.withValues(alpha: 0.25),
        );
      }

      // Node socket
      canvas.drawCircle(
        p,
        hexStep * 0.14,
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );

      if (color == 1 || color == 2) {
        final isWhite = color == 1;
        final pieceRadius = hexStep * 0.37;
        canvas.drawCircle(
          p + const Offset(1.5, 2.5),
          pieceRadius,
          Paint()..color = Colors.black45,
        );
        canvas.drawCircle(
          p,
          pieceRadius,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: isWhite
                  ? [const Color(0xFFFFFFFF), const Color(0xFFD8D2C5)]
                  : [const Color(0xFF454B54), const Color(0xFF14171C)],
            ).createShader(Rect.fromCircle(center: p, radius: pieceRadius)),
        );
        canvas.drawCircle(
          p,
          pieceRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = isWhite ? const Color(0xFFB5AA96) : const Color(0xFF68707C),
        );
      }
    }

    // Draw 24 outer rim entry points
    for (final rp in rimPoints) {
      final q = (rp['q'] as num).toInt();
      final r = (rp['r'] as num).toInt();
      final rDirs = (rp['dirs'] as List?)?.cast<Map>() ?? const [];
      final hasLegal = rDirs.any((d) => d['legal'] == true);
      final isSelected = selectedRim == (q, r);
      final isLastRim = lastMove != null &&
          (lastMove!['fromQ'] as num?)?.toInt() == q &&
          (lastMove!['fromR'] as num?)?.toInt() == r;

      final p = _pos(q, r, center);
      final dotRadius = isSelected ? hexStep * 0.26 : hexStep * 0.19;

      if (isLastRim) {
        canvas.drawCircle(
          p,
          hexStep * 0.30,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.orangeAccent,
        );
      }

      canvas.drawCircle(
        p,
        dotRadius,
        Paint()
          ..color = isSelected
              ? Colors.greenAccent
              : (isMyTurn && hasLegal
                  ? const Color(0xFFFFD54F)
                  : Colors.white.withValues(alpha: 0.25)),
      );
    }

    // Draw target inward arrows when a rim point is selected
    if (selectedRim != null && legalDirsForSelected.isNotEmpty) {
      final p0 = _pos(selectedRim!.$1, selectedRim!.$2, center);
      for (final d in legalDirsForSelected) {
        final toQ = (d['toQ'] as num).toInt();
        final toR = (d['toR'] as num).toInt();
        final p1 = _pos(toQ, toR, center);
        canvas.drawLine(
          p0,
          p1,
          Paint()
            ..color = Colors.greenAccent
            ..strokeWidth = 3.0,
        );
        canvas.drawCircle(
          p1,
          hexStep * 0.42,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..color = Colors.greenAccent,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GipfPainter oldDelegate) => true;
}
