import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class KonaneBoard extends StatefulWidget {
  final GameContext g;
  const KonaneBoard(this.g, {super.key});

  @override
  State<KonaneBoard> createState() => _KonaneBoardState();
}

class _KonaneBoardState extends State<KonaneBoard> {
  (int, int)? _selectedFrom;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  void _onCellTap(
    int r,
    int c,
    String phase,
    int turn,
    bool over,
    Set<(int, int)> legalRemovals,
    List<Map> legalJumps,
  ) {
    if (over || g.seat != turn) return;

    if (phase == 'remove_black' || phase == 'remove_white') {
      if (legalRemovals.contains((r, c))) {
        g.act({'type': 'remove', 'r': r, 'c': c});
      }
      return;
    }

    if (phase == 'jump') {
      if (_selectedFrom != null) {
        final (sr, sc) = _selectedFrom!;
        if (sr == r && sc == c) {
          setState(() => _selectedFrom = null);
          return;
        }
        final matchingJump = legalJumps.any(
          (j) =>
              (j['fromR'] as num).toInt() == sr &&
              (j['fromC'] as num).toInt() == sc &&
              (j['toR'] as num).toInt() == r &&
              (j['toC'] as num).toInt() == c,
        );
        if (matchingJump) {
          setState(() => _selectedFrom = null);
          g.act({
            'type': 'jump',
            'fromR': sr,
            'fromC': sc,
            'toR': r,
            'toC': c,
          });
          return;
        }
      }

      final canJumpFromHere = legalJumps.any(
        (j) => (j['fromR'] as num).toInt() == r && (j['fromC'] as num).toInt() == c,
      );
      if (canJumpFromHere) {
        setState(() => _selectedFrom = (r, c));
      } else {
        setState(() => _selectedFrom = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = (v['size'] as int?) ?? 6;
    final phase = (v['phase'] as String?) ?? 'remove_black';
    final turn = (v['turn'] as int?) ?? 0;
    final over = v['over'] == true || g.over;

    final rawBoard = (v['board'] as List?) ?? const [];
    final board = <List<int>>[
      for (var r = 0; r < size; r++)
        r < rawBoard.length
            ? (rawBoard[r] as List).map((e) => (e as num).toInt()).toList()
            : List<int>.filled(size, 0),
    ];

    final capList = ((v['captured'] as List?) ?? const [0, 0])
        .map((e) => (e as num).toInt())
        .toList();
    final cap0 = capList.isNotEmpty ? capList[0] : 0;
    final cap1 = capList.length > 1 ? capList[1] : 0;

    final legalRemovals = <(int, int)>{
      for (final p in ((v['legalRemovals'] as List?) ?? const []))
        if (p is List && p.length >= 2) ((p[0] as num).toInt(), (p[1] as num).toInt()),
    };
    final legalJumps = ((v['legalJumps'] as List?) ?? const []).cast<Map>();

    if (_selectedFrom != null) {
      final (sr, sc) = _selectedFrom!;
      final stillValid = phase == 'jump' &&
          !over &&
          g.seat == turn &&
          legalJumps.any(
            (j) => (j['fromR'] as num).toInt() == sr && (j['fromC'] as num).toInt() == sc,
          );
      if (!stillValid) _selectedFrom = null;
    }

    final jumpableFrom = <(int, int)>{
      if (!over && g.seat == turn && phase == 'jump')
        for (final j in legalJumps)
          ((j['fromR'] as num).toInt(), (j['fromC'] as num).toInt()),
    };

    final targetSteps = <(int, int), int>{};
    if (_selectedFrom != null && !over && g.seat == turn && phase == 'jump') {
      final (sr, sc) = _selectedFrom!;
      for (final j in legalJumps) {
        if ((j['fromR'] as num).toInt() == sr && (j['fromC'] as num).toInt() == sc) {
          final tr = (j['toR'] as num).toInt();
          final tc = (j['toC'] as num).toInt();
          final caps = (j['captured'] as List?) ?? const [];
          targetSteps[(tr, tc)] = caps.length;
        }
      }
    }

    final lastMove = v['lastMove'] as Map?;
    final resultText = v['result'] as String?;

    String statusText;
    if (over) {
      statusText = resultText ?? '对局结束';
    } else if (phase == 'remove_black') {
      statusText = g.seat == turn
          ? '开局取子：请黑方点击中心或四角高亮黑子将其移除'
          : '等待黑方 ${g.name(0)} 移除开局黑子…';
    } else if (phase == 'remove_white') {
      statusText = g.seat == turn
          ? '开局取子：请白方点击空位旁高亮白子将其移除'
          : '等待白方 ${g.name(1)} 移除相邻白子…';
    } else {
      statusText = g.seat == turn
          ? '轮到你跳吃（${turn == 0 ? "黑子" : "白子"}）：点击己方棋子正交单跳或直线连跳（可跳 ${legalJumps.length} 步）'
          : '等待 ${g.name(turn)}（${turn == 0 ? "黑子" : "白子"}）跳吃…';
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
                        sub: '● 黑石 · 捕获 $cap0 子',
                        size: isCompact ? 28 : 34,
                      ),
                      StatusBar(statusText, highlight: !over && g.seat == turn),
                      g.tag(
                        1,
                        active: !over && turn == 1,
                        sub: '○ 白珊瑚 · 捕获 $cap1 子',
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
                            final pad = side * 0.055;
                            final cell = (side - pad * 2) / size;

                            return GestureDetector(
                              onTapUp: (d) {
                                final pos = d.localPosition;
                                final c = ((pos.dx - pad) / cell).floor();
                                final r = ((pos.dy - pad) / cell).floor();
                                if (r >= 0 && r < size && c >= 0 && c < size) {
                                  _onCellTap(
                                    r,
                                    c,
                                    phase,
                                    turn,
                                    over,
                                    legalRemovals,
                                    legalJumps,
                                  );
                                }
                              },
                              child: CustomPaint(
                                size: Size(side, side),
                                painter: _KonanePainter(
                                  size: size,
                                  board: board,
                                  legalRemovals: (!over && g.seat == turn) ? legalRemovals : const {},
                                  jumpableFrom: jumpableFrom,
                                  selectedFrom: _selectedFrom,
                                  targetSteps: targetSteps,
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

class _KonanePainter extends CustomPainter {
  final int size;
  final List<List<int>> board;
  final Set<(int, int)> legalRemovals;
  final Set<(int, int)> jumpableFrom;
  final (int, int)? selectedFrom;
  final Map<(int, int), int> targetSteps;
  final Map? lastMove;
  final ColorScheme cs;

  _KonanePainter({
    required this.size,
    required this.board,
    required this.legalRemovals,
    required this.jumpableFrom,
    required this.selectedFrom,
    required this.targetSteps,
    required this.lastMove,
    required this.cs,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final side = math.min(canvasSize.width, canvasSize.height);
    final rect = Rect.fromLTWH(0, 0, side, side);

    // Carved Hawaiian Koa wood / volcanic stone board
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6D4C3D), Color(0xFF4A3228)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF2E1E17)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    final pad = side * 0.055;
    final cell = (side - pad * 2) / size;

    // Subtle orthogonal grid lines connecting pits
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 1.2;
    for (var i = 0; i < size; i++) {
      final p = pad + (i + 0.5) * cell;
      canvas.drawLine(
        Offset(pad + 0.5 * cell, p),
        Offset(side - pad - 0.5 * cell, p),
        gridPaint,
      );
      canvas.drawLine(
        Offset(p, pad + 0.5 * cell),
        Offset(p, side - pad - 0.5 * cell),
        gridPaint,
      );
    }

    // Draw last move trail
    if (lastMove != null && lastMove!['type'] == 'jump') {
      final fr = (lastMove!['fromR'] as num).toInt();
      final fc = (lastMove!['fromC'] as num).toInt();
      final tr = (lastMove!['toR'] as num).toInt();
      final tc = (lastMove!['toC'] as num).toInt();
      final pFrom = Offset(pad + (fc + 0.5) * cell, pad + (fr + 0.5) * cell);
      final pTo = Offset(pad + (tc + 0.5) * cell, pad + (tr + 0.5) * cell);
      canvas.drawLine(
        pFrom,
        pTo,
        Paint()
          ..color = Colors.amberAccent.withValues(alpha: 0.55)
          ..strokeWidth = cell * 0.14
          ..strokeCap = StrokeCap.round,
      );
    }

    final stoneRadius = cell * 0.37;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final center = Offset(pad + (c + 0.5) * cell, pad + (r + 0.5) * cell);

        // Carved pit indentation
        canvas.drawCircle(
          center,
          stoneRadius * 0.92,
          Paint()..color = const Color(0xFF33211A),
        );

        final val = board[r][c];
        if (val > 0) {
          canvas.drawCircle(
            center.translate(1.5, 2.0),
            stoneRadius,
            Paint()..color = Colors.black45,
          );
          final stonePaint = Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.35),
              radius: 0.85,
              colors: val == 1
                  ? const [Color(0xFF4D4D4D), Color(0xFF121212)]
                  : const [Color(0xFFFFFAF0), Color(0xFFD7CCC8)],
            ).createShader(Rect.fromCircle(center: center, radius: stoneRadius));
          canvas.drawCircle(center, stoneRadius, stonePaint);

          // Highlight removable stones in opening
          if (legalRemovals.contains((r, c))) {
            canvas.drawCircle(
              center,
              stoneRadius + 2.5,
              Paint()
                ..color = Colors.amberAccent
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.8,
            );
          }

          // Highlight jumpable stones
          if (jumpableFrom.contains((r, c)) && selectedFrom != (r, c)) {
            canvas.drawCircle(
              center,
              stoneRadius + 2.0,
              Paint()
                ..color = Colors.cyanAccent.withValues(alpha: 0.75)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0,
            );
          }

          // Highlight selected stone
          if (selectedFrom == (r, c)) {
            canvas.drawCircle(
              center,
              stoneRadius + 3.0,
              Paint()
                ..color = Colors.amberAccent
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.2,
            );
          }
        }

        // Highlight legal landing cells with jump step count
        if (targetSteps.containsKey((r, c))) {
          final steps = targetSteps[(r, c)]!;
          canvas.drawCircle(
            center,
            stoneRadius * 0.62,
            Paint()..color = Colors.greenAccent.withValues(alpha: 0.85),
          );
          final tp = TextPainter(
            text: TextSpan(
              text: '×$steps',
              style: TextStyle(
                fontSize: math.max(10, cell * 0.25),
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                fontFamilyFallback: kFontFallback,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KonanePainter oldDelegate) => true;
}
