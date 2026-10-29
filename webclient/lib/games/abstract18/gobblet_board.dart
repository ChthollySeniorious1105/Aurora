import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class GobbletBoard extends StatefulWidget {
  final GameContext g;
  const GobbletBoard(this.g, {super.key});

  @override
  State<GobbletBoard> createState() => _GobbletBoardState();
}

class _GobbletBoardState extends State<GobbletBoard> {
  int? _selectedStackIdx;
  (int, int)? _selectedBoardCell;
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
    final lastMove = v['lastMove'] as Map?;

    final rawBoard = (v['board'] as List?) ?? const [];
    final board = List.generate(4, (r) {
      final row = r < rawBoard.length ? (rawBoard[r] as List) : const [];
      return List.generate(4, (c) {
        final cell = c < row.length ? (row[c] as List) : const [];
        return cell.cast<Map>();
      });
    });

    final rawStacks = (v['externalStacks'] as List?) ?? const [];
    final externalStacks = List.generate(2, (s) {
      final playerStacks = s < rawStacks.length ? (rawStacks[s] as List) : const [];
      return List.generate(3, (idx) {
        final st = idx < playerStacks.length ? (playerStacks[idx] as List) : const [];
        return st.map((e) => (e as num).toInt()).toList();
      });
    });

    final isMyTurn = !over && g.seat == turn;

    final rawLegal = (v['legalMoves'] as List?)?.cast<Map>() ?? const [];
    final placeTargetsByStack = <int, Set<(int, int)>>{};
    final moveTargetsByCell = <(int, int), Set<(int, int)>>{};
    for (final m in rawLegal) {
      final type = m['type'] as String?;
      final tr = (m['toR'] as num?)?.toInt() ?? -1;
      final tc = (m['toC'] as num?)?.toInt() ?? -1;
      if (type == 'place') {
        final sIdx = (m['stackIdx'] as num?)?.toInt() ?? -1;
        if (sIdx >= 0 && tr >= 0 && tc >= 0) {
          placeTargetsByStack.putIfAbsent(sIdx, () => <(int, int)>{}).add((tr, tc));
        }
      } else if (type == 'move') {
        final fr = (m['fromR'] as num?)?.toInt() ?? -1;
        final fc = (m['fromC'] as num?)?.toInt() ?? -1;
        if (fr >= 0 && fc >= 0 && tr >= 0 && tc >= 0) {
          moveTargetsByCell.putIfAbsent((fr, fc), () => <(int, int)>{}).add((tr, tc));
        }
      }
    }

    if (!isMyTurn) {
      _selectedStackIdx = null;
      _selectedBoardCell = null;
    } else {
      if (_selectedStackIdx != null && !placeTargetsByStack.containsKey(_selectedStackIdx)) {
        _selectedStackIdx = null;
      }
      if (_selectedBoardCell != null && !moveTargetsByCell.containsKey(_selectedBoardCell)) {
        _selectedBoardCell = null;
      }
      // Default to first available external stack if nothing is selected yet
      if (_selectedStackIdx == null &&
          _selectedBoardCell == null &&
          placeTargetsByStack.isNotEmpty) {
        _selectedStackIdx = placeTargetsByStack.keys.first;
      }
    }

    final activeTargets = _selectedStackIdx != null
        ? (placeTargetsByStack[_selectedStackIdx] ?? const <(int, int)>{})
        : (_selectedBoardCell != null
            ? (moveTargetsByCell[_selectedBoardCell] ?? const <(int, int)>{})
            : const <(int, int)>{});

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      if (_selectedStackIdx != null) {
        final topSz = externalStacks[turn][_selectedStackIdx!].last;
        statusText = '轮到你：已选场外第 ${_selectedStackIdx! + 1} 栈（$topSz号杯），点击高亮格放入或点击盘面己方套杯移动';
      } else if (_selectedBoardCell != null) {
        statusText = '轮到你：已选盘面 (${_selectedBoardCell!.$1}, ${_selectedBoardCell!.$2}) 套杯，点击高亮格移动或吞套小杯';
      } else {
        statusText = '轮到你：选择场外套杯栈或盘面顶层己方套杯进行移动';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 移动或放置套杯…';
    }

    Widget buildPlayerPanel(int s) {
      final isGold = s == 0;
      final st = externalStacks[s];
      final topStr = [
        for (var i = 0; i < 3; i++) st[i].isEmpty ? '空' : '${st[i].last}号',
      ].join('/');
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '${isGold ? "金杯方" : "紫杯方"} · 场外三栈顶: [$topStr]',
        trailing: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isGold ? const Color(0xFFFFB300) : const Color(0xFF8E24AA),
            border: Border.all(color: Colors.white70, width: 1.5),
          ),
        ),
      );
    }

    Widget? buildStackSelector() {
      if (!isMyTurn) return null;
      final myStacks = externalStacks[turn];
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            ChoiceChip(
              label: Text(
                myStacks[i].isEmpty
                    ? '栈${i + 1}: 空'
                    : '栈${i + 1}: 顶${myStacks[i].last}号 (余${myStacks[i].length})',
                style: const TextStyle(fontSize: 11),
              ),
              selected: _selectedStackIdx == i,
              onSelected: placeTargetsByStack.containsKey(i)
                  ? (_) {
                      setState(() {
                        _selectedStackIdx = i;
                        _selectedBoardCell = null;
                      });
                    }
                  : null,
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
                      if (hit == null) return;

                      // If tapping an own movable piece on the board and it's not a gobble target of another board piece:
                      if (_selectedStackIdx != null && moveTargetsByCell.containsKey(hit)) {
                        setState(() {
                          _selectedStackIdx = null;
                          _selectedBoardCell = hit;
                        });
                        return;
                      }

                      if (_selectedBoardCell != null) {
                        if (activeTargets.contains(hit)) {
                          final (fr, fc) = _selectedBoardCell!;
                          setState(() => _selectedBoardCell = null);
                          g.act({
                            'type': 'move',
                            'fromR': fr,
                            'fromC': fc,
                            'toR': hit.$1,
                            'toC': hit.$2,
                          });
                          return;
                        }
                        if (moveTargetsByCell.containsKey(hit)) {
                          setState(() => _selectedBoardCell = hit);
                          return;
                        }
                      }

                      if (_selectedStackIdx != null && activeTargets.contains(hit)) {
                        final sIdx = _selectedStackIdx!;
                        g.act({
                          'type': 'place',
                          'stackIdx': sIdx,
                          'toR': hit.$1,
                          'toC': hit.$2,
                        });
                        return;
                      }

                      if (moveTargetsByCell.containsKey(hit)) {
                        setState(() {
                          _selectedStackIdx = null;
                          _selectedBoardCell = hit;
                        });
                      }
                    },
              child: CustomPaint(
                size: Size(w, h),
                painter: _GobbletPainter(
                  board: board,
                  selectedBoardCell: _selectedBoardCell,
                  activeTargets: activeTargets,
                  movableSources: moveTargetsByCell.keys.toSet(),
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
        final stackChips = buildStackSelector();

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
                                      if (stackChips != null) ...[
                                        const SizedBox(height: 6),
                                        FittedBox(fit: BoxFit.scaleDown, child: stackChips),
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
                        if (stackChips != null) ...[
                          const SizedBox(height: 4),
                          FittedBox(fit: BoxFit.scaleDown, child: stackChips),
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

class _GobbletPainter extends CustomPainter {
  final List<List<List<Map>>> board;
  final (int, int)? selectedBoardCell;
  final Set<(int, int)> activeTargets;
  final Set<(int, int)> movableSources;
  final (int, int)? hovered;
  final Map? lastMove;
  final bool isMyTurn;
  final Offset origin;
  final double boardSide;
  final double cellSize;
  final ColorScheme cs;

  _GobbletPainter({
    required this.board,
    required this.selectedBoardCell,
    required this.activeTargets,
    required this.movableSources,
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
    final frameRect = Rect.fromLTWH(origin.dx, origin.dy, boardSide, boardSide).inflate(cellSize * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, Radius.circular(cellSize * 0.22)),
      Paint()..color = const Color(0xFF3E2723),
    );

    final lastToR = (lastMove?['toR'] as num?)?.toInt();
    final lastToC = (lastMove?['toC'] as num?)?.toInt();

    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        final rect = Rect.fromLTWH(
          origin.dx + c * cellSize,
          origin.dy + r * cellSize,
          cellSize,
          cellSize,
        ).deflate(cellSize * 0.04);

        final isDark = (r + c).isOdd;
        Color cellColor = isDark ? const Color(0xFF5D4037) : const Color(0xFF6D4C41);
        if (selectedBoardCell == (r, c)) {
          cellColor = Color.alphaBlend(Colors.cyanAccent.withValues(alpha: 0.35), cellColor);
        } else if (lastToR == r && lastToC == c) {
          cellColor = Color.alphaBlend(Colors.amberAccent.withValues(alpha: 0.25), cellColor);
        } else if (isMyTurn && hovered == (r, c) && activeTargets.contains((r, c))) {
          cellColor = Color.alphaBlend(Colors.greenAccent.withValues(alpha: 0.25), cellColor);
        }

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.14)),
          Paint()..color = cellColor,
        );

        final isTarget = isMyTurn && activeTargets.contains((r, c));
        if (isTarget) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.14)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..color = Colors.greenAccent.withValues(alpha: 0.75),
          );
        }

        final st = board[r][c];
        if (st.isNotEmpty) {
          final top = st.last;
          final owner = (top['owner'] as num?)?.toInt() ?? 0;
          final sz = (top['size'] as num?)?.toInt() ?? 1;
          final isGold = owner == 0;
          final center = rect.center;
          final radius = cellSize * (0.16 + sz * 0.065);

          canvas.drawCircle(
            center + Offset(cellSize * 0.03, cellSize * 0.04),
            radius,
            Paint()..color = Colors.black54,
          );

          final fill = isGold ? const Color(0xFFFFB300) : const Color(0xFF8E24AA);
          final isSel = selectedBoardCell == (r, c);
          final isMovable = isMyTurn && movableSources.contains((r, c));

          canvas.drawCircle(center, radius, Paint()..color = fill);
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = isSel ? 3.0 : (isMovable ? 2.2 : 1.6)
              ..color = isSel
                  ? Colors.cyanAccent
                  : (isMovable ? Colors.greenAccent : Colors.white70),
          );

          final tp = TextPainter(
            text: TextSpan(
              text: '$sz${st.length > 1 ? " (${st.length}层)" : ""}',
              style: TextStyle(
                color: isGold ? Colors.black : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: cellSize * 0.18,
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
  bool shouldRepaint(covariant _GobbletPainter oldDelegate) => true;
}
