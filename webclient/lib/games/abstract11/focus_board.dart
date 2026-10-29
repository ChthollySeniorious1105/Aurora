import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class FocusBoard extends StatefulWidget {
  final GameContext g;
  const FocusBoard(this.g, {super.key});

  @override
  State<FocusBoard> createState() => _FocusBoardState();
}

class _FocusBoardState extends State<FocusBoard> {
  (int, int)? _selectedCell;
  bool _dropMode = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final boardSize = (v['boardSize'] as num?)?.toInt() ?? 8;
    final targetCaptures = (v['targetCaptures'] as num?)?.toInt() ?? 6;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = (v['winner'] as num?)?.toInt();
    final winReason = v['winReason'] as String?;
    final reserve = (v['reserve'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0];
    final captured = (v['captured'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0];
    final controlled = (v['controlled'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [18, 18];
    final lastMove = v['lastMove'] as Map?;
    final rawBoard = (v['board'] as List?) ?? const [];

    List<int>? stackAt(int r, int c) {
      if (r < 0 || r >= rawBoard.length) return null;
      final row = rawBoard[r] as List?;
      if (row == null || c < 0 || c >= row.length) return null;
      final cell = row[c];
      if (cell == null) return null;
      return (cell as List).map((e) => (e as num).toInt()).toList();
    }

    final isMyTurn = !over && g.seat == turn;
    final myReserve = (g.seat >= 0 && g.seat < 2) ? reserve[g.seat] : 0;

    if (!isMyTurn || myReserve <= 0) {
      _dropMode = false;
    }

    List<int>? selectedStack;
    if (_selectedCell != null) {
      final st = stackAt(_selectedCell!.$1, _selectedCell!.$2);
      if (st != null && st.isNotEmpty && st.last == turn) {
        selectedStack = st;
      } else {
        _selectedCell = null;
      }
    }

    // Compute valid destination map (r, c) -> count k for selectedStack
    final validDests = <(int, int), int>{};
    if (isMyTurn && !_dropMode && _selectedCell != null && selectedStack != null) {
      final (sr, sc) = _selectedCell!;
      const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
      for (var k = 1; k <= selectedStack.length; k++) {
        for (final (dr, dc) in dirs) {
          final tr = sr + dr * k;
          final tc = sc + dc * k;
          if (stackAt(tr, tc) != null) {
            validDests[(tr, tc)] = k;
          }
        }
      }
    }

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      if (_dropMode) {
        statusText = '投放模式：点击任意有效格投放 1 枚储备子';
      } else if (_selectedCell != null && selectedStack != null) {
        statusText = '已选 (${_selectedCell!.$1 + 1},${_selectedCell!.$2 + 1}) 塔高 ${selectedStack.length}：点绿框格移动对应步数';
      } else {
        statusText = '轮到你：选择己方控顶叠塔移动，或投放储备子（先俘获 $targetCaptures 枚胜）';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 行动（目标俘获 $targetCaptures 枚）…';
    }

    Widget buildPlayerPanel(int s) {
      final colorName = s == 0 ? '白方' : '黑方';
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '$colorName · 俘获 ${captured[s]}/$targetCaptures · 储备 ${reserve[s]} · 控塔 ${controlled[s]}',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: s == 0 ? const Color(0xFFF5F2EB) : const Color(0xFF23272E),
            border: Border.all(color: Colors.amber.shade600, width: 1.5),
          ),
        ),
      );
    }

    Widget buildReserveButton() {
      if (!isMyTurn || myReserve <= 0) return const SizedBox.shrink();
      return FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          backgroundColor: _dropMode ? cs.primaryContainer : null,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        onPressed: () {
          setState(() {
            _dropMode = !_dropMode;
            if (_dropMode) _selectedCell = null;
          });
        },
        icon: Icon(_dropMode ? Icons.close : Icons.add_circle_outline, size: 15),
        label: Text(
          _dropMode ? '取消投放（返回移塔）' : '投放储备子 ($myReserve)',
          style: const TextStyle(fontSize: 12),
        ),
      );
    }

    Widget buildGrid() {
      return LayoutBuilder(
        builder: (context, constraints) {
          final side = min(constraints.maxWidth, constraints.maxHeight);
          if (side <= 20) return const SizedBox.shrink();

          return Center(
            child: SizedBox(
              width: side,
              height: side,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C221E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFB8925A), width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    for (var r = 0; r < boardSize; r++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var c = 0; c < boardSize; c++)
                              Expanded(
                                child: _buildCell(
                                  r: r,
                                  c: c,
                                  st: stackAt(r, c),
                                  isMyTurn: isMyTurn,
                                  turn: turn,
                                  validDestStep: validDests[(r, c)],
                                  lastMove: lastMove,
                                  cs: cs,
                                  g: g,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
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
                          width: min(240, outer.maxWidth * 0.30),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              buildPlayerPanel(1),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(fit: BoxFit.scaleDown, child: StatusBar(statusText, highlight: isMyTurn)),
                                    const SizedBox(height: 6),
                                    buildReserveButton(),
                                  ],
                                ),
                              ),
                              buildPlayerPanel(0),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: buildGrid()),
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
                            if (isMyTurn && myReserve > 0) ...[
                              const SizedBox(width: 6),
                              buildReserveButton(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Expanded(child: buildGrid()),
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

  Widget _buildCell({
    required int r,
    required int c,
    required List<int>? st,
    required bool isMyTurn,
    required int turn,
    required int? validDestStep,
    required Map? lastMove,
    required ColorScheme cs,
    required GameContext g,
  }) {
    if (st == null) {
      // Clipped corner cell
      return const SizedBox.expand();
    }

    final isSelected = _selectedCell == (r, c);
    final isDest = validDestStep != null;
    final isLastFrom = lastMove != null &&
        (lastMove['fromR'] as num?)?.toInt() == r &&
        (lastMove['fromC'] as num?)?.toInt() == c;
    final isLastTo = lastMove != null &&
        (((lastMove['toR'] as num?)?.toInt() == r && (lastMove['toC'] as num?)?.toInt() == c) ||
            ((lastMove['r'] as num?)?.toInt() == r && (lastMove['c'] as num?)?.toInt() == c));

    final canSelectStack = isMyTurn && !_dropMode && st.isNotEmpty && st.last == turn;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: !isMyTurn
          ? null
          : () {
              if (_dropMode) {
                setState(() {
                  _dropMode = false;
                  _selectedCell = null;
                });
                g.act({'type': 'drop', 'r': r, 'c': c});
                return;
              }
              if (isDest && _selectedCell != null) {
                final (fr, fc) = _selectedCell!;
                setState(() => _selectedCell = null);
                g.act({
                  'type': 'move',
                  'fromR': fr,
                  'fromC': fc,
                  'toR': r,
                  'toC': c,
                  'count': validDestStep,
                });
                return;
              }
              if (canSelectStack) {
                setState(() {
                  _selectedCell = isSelected ? null : (r, c);
                });
              } else {
                setState(() => _selectedCell = null);
              }
            },
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: (r + c).isEven ? const Color(0xFFD9C39E) : const Color(0xFFC4A77D),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? Colors.cyanAccent
                : isDest
                    ? Colors.greenAccent.shade400
                    : (_dropMode
                        ? Colors.amberAccent
                        : (isLastTo
                            ? Colors.orangeAccent
                            : (isLastFrom ? Colors.orange.withValues(alpha: 0.6) : Colors.black26))),
            width: (isSelected || isDest || _dropMode || isLastTo) ? 2.2 : 0.8,
          ),
        ),
        child: CustomPaint(
          painter: _FocusStackPainter(
            stack: st,
            stepBadge: validDestStep,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _FocusStackPainter extends CustomPainter {
  final List<int> stack;
  final int? stepBadge;

  _FocusStackPainter({
    required this.stack,
    required this.stepBadge,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minDim = min(size.width, size.height);

    if (stack.isNotEmpty) {
      final radius = minDim * 0.34;
      final total = stack.length;
      final stepDy = minDim * 0.055;
      final baseOffsetY = (total - 1) * stepDy * 0.5;

      // Draw stacked discs from bottom (0) to top (total - 1)
      for (var i = 0; i < total; i++) {
        final isWhite = stack[i] == 0;
        final c = Offset(center.dx, center.dy + baseOffsetY - i * stepDy);
        canvas.drawCircle(
          c + const Offset(0.8, 1.5),
          radius,
          Paint()..color = Colors.black38,
        );
        canvas.drawCircle(
          c,
          radius,
          Paint()
            ..color = isWhite ? const Color(0xFFFDFBF7) : const Color(0xFF20242B),
        );
        canvas.drawCircle(
          c,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = isWhite ? const Color(0xFF8C7A60) : const Color(0xFF7B8492),
        );
      }

      // Draw stack height label on top disc if height > 1
      if (total > 1) {
        final topIsWhite = stack.last == 0;
        final topCenter = Offset(center.dx, center.dy + baseOffsetY - (total - 1) * stepDy);
        final tp = TextPainter(
          text: TextSpan(
            text: '$total',
            style: TextStyle(
              color: topIsWhite ? const Color(0xFF20242B) : const Color(0xFFFDFBF7),
              fontSize: minDim * 0.28,
              fontWeight: FontWeight.bold,
              fontFamilyFallback: kFontFallback,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, topCenter - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // Draw step badge in corner if valid destination
    if (stepBadge != null) {
      final badgeRadius = minDim * 0.19;
      final badgeCenter = Offset(size.width - badgeRadius - 2, badgeRadius + 2);
      canvas.drawCircle(
        badgeCenter,
        badgeRadius,
        Paint()..color = const Color(0xFF00C853),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '$stepBadge',
          style: TextStyle(
            color: Colors.white,
            fontSize: minDim * 0.22,
            fontWeight: FontWeight.bold,
            fontFamilyFallback: kFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, badgeCenter - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _FocusStackPainter oldDelegate) =>
      oldDelegate.stack != stack || oldDelegate.stepBadge != stepBadge;
}
