import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

const List<Color> _playerColors = [
  Color(0xFFE53935), // Red
  Color(0xFF1E88E5), // Blue
  Color(0xFF43A047), // Green
  Color(0xFFFB8C00), // Orange
];

class CanStopBoard extends StatefulWidget {
  final GameContext g;
  const CanStopBoard(this.g, {super.key});

  @override
  State<CanStopBoard> createState() => _CanStopBoardState();
}

class _CanStopBoardState extends State<CanStopBoard> {
  GameContext get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = '${v['phase'] ?? 'choose_pair'}';
    final targetCols = (v['targetCols'] as num?)?.toInt() ?? 3;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt() ?? -1;
    final dice = (v['dice'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [1, 1, 1, 1];
    final legalChoices = (v['legalChoices'] as List?)
            ?.map((c) => (c as List).map((x) => (x as num).toInt()).toList())
            .toList() ??
        const <List<int>>[];
    final claimedCounts =
        (v['claimedCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final logs = (v['log'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final isMyTurn = !over && g.seat == turn;

    String statusText;
    if (over) {
      statusText = winner >= 0 ? '游戏结束：${g.name(winner)} 登顶 $targetCols 列获胜！' : '游戏结束';
    } else if (isMyTurn) {
      statusText = phase == 'choose_pair'
          ? '轮到你：请选择一组骰子点数推进登山者'
          : '轮到你：继续掷骰冲击山顶，还是见好就收扎营？';
    } else {
      statusText = '等待 ${g.name(turn)} ${phase == 'choose_pair' ? '选择骰子组合' : '决定是否继续掷骰'}…';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 460 || constraints.maxWidth < 460;

      return Stack(
        children: [
          Container(
            color: g.table,
            padding: EdgeInsets.all(compact ? 4 : 8),
            child: Column(
              children: [
                // Top bar: status + player tags
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBar(statusText, highlight: isMyTurn),
                    for (var s = 0; s < g.players; s++)
                      g.tag(
                        s,
                        active: !over && turn == s,
                        size: compact ? 26 : 32,
                        sub: '占领 ${claimedCounts[s]}/$targetCols 列',
                        trailing: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _playerColors[s % _playerColors.length],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Center: Mountain climbing board
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
                    ),
                    padding: EdgeInsets.all(compact ? 4 : 8),
                    child: CustomPaint(
                      painter: _CanStopMountainPainter(
                        view: v,
                        players: g.players,
                        colorScheme: cs,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
                SizedBox(height: compact ? 4 : 6),

                // Bottom panel: Dice + Controls
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 12,
                    vertical: compact ? 4 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isMyTurn ? cs.primary : cs.outline.withValues(alpha: 0.3),
                      width: isMyTurn ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < dice.length; i++) ...[
                                if (i > 0) const SizedBox(width: 4),
                                DieFace(dice[i], size: compact ? 28 : 36),
                              ],
                            ],
                          ),
                          if (!over && phase == 'choose_pair')
                            for (final choice in legalChoices)
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: compact ? 8 : 12,
                                    vertical: compact ? 4 : 6,
                                  ),
                                ),
                                onPressed: isMyTurn
                                    ? () => g.act({'type': 'choose_pair', 'cols': choice})
                                    : null,
                                child: Text(
                                  choice.length == 2 && choice[0] == choice[1]
                                      ? '推进 ${choice[0]} 列 ×2'
                                      : '推进 ${choice.join(" + ")} 列',
                                  style: TextStyle(
                                    fontSize: compact ? 12 : 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          if (!over && phase == 'decide') ...[
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                              ),
                              onPressed: isMyTurn ? () => g.act({'type': 'roll'}) : null,
                              icon: const Icon(Icons.casino, size: 16),
                              label: const Text('继续掷骰'),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                              ),
                              onPressed: isMyTurn ? () => g.act({'type': 'stop'}) : null,
                              icon: const Icon(Icons.flag, size: 16),
                              label: const Text('扎营保存'),
                            ),
                          ],
                        ],
                      ),
                      if (logs.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          logs.last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            color: cs.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(
                winner >= 0 ? '${g.name(winner)} 率先登顶 $targetCols 列获胜！' : '对局结束',
              ),
            ),
        ],
      );
    });
  }
}

class _CanStopMountainPainter extends CustomPainter {
  final Map<String, dynamic> view;
  final int players;
  final ColorScheme colorScheme;

  _CanStopMountainPainter({
    required this.view,
    required this.players,
    required this.colorScheme,
  });

  static const Map<int, int> _heights = {
    2: 3,
    3: 5,
    4: 7,
    5: 9,
    6: 11,
    7: 13,
    8: 11,
    9: 9,
    10: 7,
    11: 5,
    12: 3,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 10 || size.height <= 10) return;

    final runnersRaw = (view['runners'] as Map?) ?? const {};
    final runners = <int, int>{
      for (final e in runnersRaw.entries) int.tryParse('${e.key}') ?? 0: (e.value as num).toInt()
    };
    final claimedRaw = (view['claimed'] as Map?) ?? const {};
    final claimed = <int, int>{
      for (final e in claimedRaw.entries) int.tryParse('${e.key}') ?? 0: (e.value as num).toInt()
    };
    final campsList = (view['camps'] as List?) ?? const [];

    final colWidth = size.width / 11.0;
    final headerH = min(22.0, size.height * 0.12);
    final usableH = max(20.0, size.height - headerH - 6);
    final stepH = usableH / 13.0;
    final radius = min(colWidth * 0.34, stepH * 0.42).clamp(3.0, 14.0);

    for (var idx = 0; idx < 11; idx++) {
      final col = idx + 2;
      final h = _heights[col]!;
      final cx = (idx + 0.5) * colWidth;
      final owner = claimed[col];
      final hasRunner = runners.containsKey(col);

      // Column track background
      final colTopY = headerH + (13 - h) * stepH;
      final colBottomY = headerH + 13 * stepH;
      final trackRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - colWidth * 0.4, colTopY, cx + colWidth * 0.4, colBottomY),
        const Radius.circular(8),
      );
      final trackPaint = Paint()
        ..color = owner != null
            ? _playerColors[owner % _playerColors.length].withValues(alpha: 0.25)
            : (hasRunner
                ? colorScheme.primary.withValues(alpha: 0.16)
                : colorScheme.onSurface.withValues(alpha: 0.06));
      canvas.drawRRect(trackRect, trackPaint);

      // Column number label at top
      final tp = TextPainter(
        text: TextSpan(
          text: '$col',
          style: TextStyle(
            fontSize: min(13.0, headerH * 0.72),
            fontWeight: FontWeight.bold,
            color: owner != null
                ? _playerColors[owner % _playerColors.length]
                : colorScheme.onSurface,
            fontFamilyFallback: kFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, (headerH - tp.height) / 2));

      // Draw each step 1..h (from bottom to top)
      for (var step = 1; step <= h; step++) {
        final cy = colBottomY - (step - 0.5) * stepH;
        final isSummit = step == h;

        final circlePaint = Paint()
          ..color = isSummit
              ? colorScheme.primaryContainer.withValues(alpha: 0.65)
              : colorScheme.surface;
        final borderPaint = Paint()
          ..color = colorScheme.outline.withValues(alpha: isSummit ? 0.6 : 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSummit ? 1.5 : 1.0;

        canvas.drawCircle(Offset(cx, cy), radius, circlePaint);
        canvas.drawCircle(Offset(cx, cy), radius, borderPaint);

        // Draw player camps on this step
        final campedSeats = <int>[];
        for (var s = 0; s < players && s < campsList.length; s++) {
          final seatCamps = campsList[s] as Map?;
          final pos = (seatCamps?['$col'] as num?)?.toInt() ?? 0;
          if (pos == step) campedSeats.add(s);
        }
        if (campedSeats.isNotEmpty) {
          for (var i = 0; i < campedSeats.length; i++) {
            final s = campedSeats[i];
            final offsetX = (i - (campedSeats.length - 1) / 2.0) * (radius * 0.55);
            final campPaint = Paint()..color = _playerColors[s % _playerColors.length];
            canvas.drawCircle(Offset(cx + offsetX, cy), radius * 0.65, campPaint);
          }
        }

        // Draw active white runner on this step
        if (runners[col] == step) {
          final runnerPaint = Paint()..color = Colors.white;
          final runnerBorder = Paint()
            ..color = Colors.amber.shade700
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
          canvas.drawCircle(Offset(cx, cy), radius * 0.8, runnerPaint);
          canvas.drawCircle(Offset(cx, cy), radius * 0.8, runnerBorder);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanStopMountainPainter oldDelegate) => true;
}
