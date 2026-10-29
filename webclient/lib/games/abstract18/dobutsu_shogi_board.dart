import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class DobutsuShogiBoard extends StatefulWidget {
  final GameContext g;
  const DobutsuShogiBoard(this.g, {super.key});

  @override
  State<DobutsuShogiBoard> createState() => _DobutsuShogiBoardState();
}

class _DobutsuShogiBoardState extends State<DobutsuShogiBoard> {
  (int, int)? _selectedCell;
  String? _selectedHandKind;
  (int, int)? _hovered;

  static const Map<String, String> _kEmojis = {
    'L': '🦁',
    'E': '🐘',
    'G': '🦒',
    'C': '🐥',
    'H': '🐔',
  };

  static const Map<String, String> _kNames = {
    'L': '狮子',
    'E': '大象',
    'G': '长颈鹿',
    'C': '小鸡',
    'H': '母鸡',
  };

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
      return List.generate(3, (c) => c < row.length ? (row[c] as Map?) : null);
    });

    final rawHands = (v['hands'] as List?) ?? const [];
    final hands = List.generate(2, (s) {
      final h = s < rawHands.length ? (rawHands[s] as List) : const [];
      return h.map((e) => e.toString()).toList();
    });

    final isMyTurn = !over && g.seat == turn;

    final rawLegal = (v['legalMoves'] as List?)?.cast<Map>() ?? const [];
    final movesByCell = <(int, int), Set<(int, int)>>{};
    final dropsByKind = <String, Set<(int, int)>>{};
    for (final m in rawLegal) {
      if (m['type'] == 'move') {
        final fr = (m['fromR'] as num?)?.toInt() ?? -1;
        final fc = (m['fromC'] as num?)?.toInt() ?? -1;
        final tr = (m['toR'] as num?)?.toInt() ?? -1;
        final tc = (m['toC'] as num?)?.toInt() ?? -1;
        if (fr >= 0 && fc >= 0 && tr >= 0 && tc >= 0) {
          movesByCell.putIfAbsent((fr, fc), () => <(int, int)>{}).add((tr, tc));
        }
      } else if (m['type'] == 'drop') {
        final k = m['kind'] as String? ?? '';
        final r = (m['r'] as num?)?.toInt() ?? -1;
        final c = (m['c'] as num?)?.toInt() ?? -1;
        if (k.isNotEmpty && r >= 0 && c >= 0) {
          dropsByKind.putIfAbsent(k, () => <(int, int)>{}).add((r, c));
        }
      }
    }

    if (!isMyTurn) {
      _selectedCell = null;
      _selectedHandKind = null;
    } else {
      if (_selectedCell != null && !movesByCell.containsKey(_selectedCell)) {
        _selectedCell = null;
      }
      if (_selectedHandKind != null && !dropsByKind.containsKey(_selectedHandKind)) {
        _selectedHandKind = null;
      }
    }

    final activeTargets = _selectedHandKind != null
        ? (dropsByKind[_selectedHandKind] ?? const <(int, int)>{})
        : (_selectedCell != null
            ? (movesByCell[_selectedCell] ?? const <(int, int)>{})
            : const <(int, int)>{});

    String statusText;
    if (over) {
      statusText = winReason ?? (winner == -1 ? '平局！' : '${g.name(winner ?? 0)} 获胜！');
    } else if (isMyTurn) {
      if (_selectedHandKind != null) {
        statusText =
            '已选手牌【${_kEmojis[_selectedHandKind]}${_kNames[_selectedHandKind]}】：点击任意空森林格直接打入！';
      } else if (_selectedCell != null) {
        final p = board[_selectedCell!.$1][_selectedCell!.$2];
        final k = p?['kind'] as String? ?? 'L';
        statusText = '已选盘面【${_kEmojis[k]}${_kNames[k]}】：点击高亮目标格移动或吃子';
      } else {
        statusText = '轮到你：点击场上己方动物移动，或点击手牌俘虏打入空格（捕狮或狮王底线达阵即胜）';
      }
    } else {
      statusText = '等待 ${g.name(turn)} 行动…';
    }

    Widget buildPlayerPanel(int s) {
      final isSouth = s == 0;
      final h = hands[s];
      final handSummary = h.isEmpty
          ? '无'
          : [for (final k in h) '${_kEmojis[k] ?? k}${_kNames[k] ?? k}'].join(' ');
      return g.tag(
        s,
        active: !over && turn == s,
        sub: '${isSouth ? "南方森林(向上)" : "北方森林(向下)"} · 持驹: $handSummary',
        trailing: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSouth ? const Color(0xFF43A047) : const Color(0xFFE53935),
            border: Border.all(color: Colors.white70, width: 1.5),
          ),
          child: const Text('🦁', style: TextStyle(fontSize: 11, fontFamilyFallback: kFontFallback)),
        ),
      );
    }

    Widget? buildHandDropBar() {
      if (!isMyTurn || hands[turn].isEmpty) return null;
      final counts = <String, int>{};
      for (final k in hands[turn]) {
        counts[k] = (counts[k] ?? 0) + 1;
      }
      return Wrap(
        spacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final entry in counts.entries)
            ChoiceChip(
              label: Text(
                '打入 ${_kEmojis[entry.key]}${_kNames[entry.key]} ×${entry.value}',
                style: const TextStyle(fontSize: 11),
              ),
              selected: _selectedHandKind == entry.key,
              onSelected: dropsByKind.containsKey(entry.key)
                  ? (sel) {
                      setState(() {
                        _selectedHandKind = sel ? entry.key : null;
                        _selectedCell = null;
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

          final cellSize = min((w * 0.88) / 3.0, (h * 0.90) / 4.0);
          final boardW = cellSize * 3.0;
          final boardH = cellSize * 4.0;
          final origin = Offset((w - boardW) / 2, (h - boardH) / 2);

          (int, int)? hitCellAt(Offset pos) {
            final c = ((pos.dx - origin.dx) / cellSize).floor();
            final r = ((pos.dy - origin.dy) / cellSize).floor();
            if (r >= 0 && r < 4 && c >= 0 && c < 3) return (r, c);
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
                        setState(() {
                          _selectedCell = null;
                          _selectedHandKind = null;
                        });
                        return;
                      }
                      final (r, c) = hit;

                      if (_selectedHandKind != null && activeTargets.contains(hit)) {
                        final k = _selectedHandKind!;
                        setState(() => _selectedHandKind = null);
                        g.act({'type': 'drop', 'kind': k, 'r': r, 'c': c});
                        return;
                      }

                      if (_selectedCell != null && activeTargets.contains(hit)) {
                        final (fr, fc) = _selectedCell!;
                        setState(() => _selectedCell = null);
                        g.act({
                          'type': 'move',
                          'fromR': fr,
                          'fromC': fc,
                          'toR': r,
                          'toC': c,
                        });
                        return;
                      }

                      if (movesByCell.containsKey(hit)) {
                        setState(() {
                          _selectedCell = hit;
                          _selectedHandKind = null;
                        });
                      } else {
                        setState(() => _selectedCell = null);
                      }
                    },
              child: CustomPaint(
                size: Size(w, h),
                painter: _DobutsuShogiPainter(
                  board: board,
                  movableSources: movesByCell.keys.toSet(),
                  selectedCell: _selectedCell,
                  activeTargets: activeTargets,
                  hovered: _hovered,
                  lastMove: lastMove,
                  isMyTurn: isMyTurn,
                  origin: origin,
                  boardW: boardW,
                  boardH: boardH,
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
        final isWide = outer.maxWidth >= 660 && outer.maxWidth > outer.maxHeight * 1.1;
        final handChips = buildHandDropBar();

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
                                      if (handChips != null) ...[
                                        const SizedBox(height: 6),
                                        FittedBox(fit: BoxFit.scaleDown, child: handChips),
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
                            Expanded(child: buildPlayerPanel(1)),
                            const SizedBox(width: 6),
                            Expanded(child: buildPlayerPanel(0)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: StatusBar(statusText, highlight: isMyTurn),
                        ),
                        if (handChips != null) ...[
                          const SizedBox(height: 4),
                          FittedBox(fit: BoxFit.scaleDown, child: handChips),
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

class _DobutsuShogiPainter extends CustomPainter {
  final List<List<Map?>> board;
  final Set<(int, int)> movableSources;
  final (int, int)? selectedCell;
  final Set<(int, int)> activeTargets;
  final (int, int)? hovered;
  final Map? lastMove;
  final bool isMyTurn;
  final Offset origin;
  final double boardW;
  final double boardH;
  final double cellSize;
  final ColorScheme cs;

  _DobutsuShogiPainter({
    required this.board,
    required this.movableSources,
    required this.selectedCell,
    required this.activeTargets,
    required this.hovered,
    required this.lastMove,
    required this.isMyTurn,
    required this.origin,
    required this.boardW,
    required this.boardH,
    required this.cellSize,
    required this.cs,
  });

  static List<(int, int)> _dirsFor(int owner, String kind) {
    final fwd = owner == 0 ? -1 : 1;
    switch (kind) {
      case 'L':
        return const [
          (-1, -1),
          (-1, 0),
          (-1, 1),
          (0, -1),
          (0, 1),
          (1, -1),
          (1, 0),
          (1, 1),
        ];
      case 'E':
        return const [(-1, -1), (-1, 1), (1, -1), (1, 1)];
      case 'G':
        return const [(-1, 0), (1, 0), (0, -1), (0, 1)];
      case 'C':
        return [(fwd, 0)];
      case 'H':
        return [(-1, 0), (1, 0), (0, -1), (0, 1), (fwd, -1), (fwd, 1)];
      default:
        return const [];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outerRect = Rect.fromLTWH(origin.dx, origin.dy, boardW, boardH).inflate(cellSize * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, Radius.circular(cellSize * 0.22)),
      Paint()..color = const Color(0xFF4E342E),
    );

    final lastToR = (lastMove?['toR'] ?? lastMove?['r'] as num?)?.toInt();
    final lastToC = (lastMove?['toC'] ?? lastMove?['c'] as num?)?.toInt();

    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 3; c++) {
        final rect = Rect.fromLTWH(
          origin.dx + c * cellSize,
          origin.dy + r * cellSize,
          cellSize,
          cellSize,
        ).deflate(cellSize * 0.04);

        // Sky zone (row 0) vs Meadow vs Forest (row 3)
        Color bg = r == 0
            ? const Color(0xFFE3F2FD)
            : (r == 3 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1));
        if (selectedCell == (r, c)) {
          bg = Color.alphaBlend(Colors.cyanAccent.withValues(alpha: 0.45), bg);
        } else if (lastToR == r && lastToC == c) {
          bg = Color.alphaBlend(Colors.amberAccent.withValues(alpha: 0.40), bg);
        } else if (isMyTurn && hovered == (r, c) && activeTargets.contains((r, c))) {
          bg = Color.alphaBlend(Colors.greenAccent.withValues(alpha: 0.35), bg);
        }

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.12)),
          Paint()..color = bg,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.12)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = const Color(0xFF8D6E63),
        );

        if (isMyTurn && activeTargets.contains((r, c))) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(cellSize * 0.12)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.8
              ..color = const Color(0xFF00C853),
          );
        }

        final p = board[r][c];
        if (p != null) {
          final owner = (p['owner'] as num?)?.toInt() ?? 0;
          final kind = (p['kind'] as String?) ?? 'C';
          final isSouth = owner == 0;
          final tileRect = rect.deflate(cellSize * 0.09);

          // Wooden block shadow
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              tileRect.shift(Offset(cellSize * 0.02, cellSize * 0.03)),
              Radius.circular(cellSize * 0.12),
            ),
            Paint()..color = Colors.black38,
          );

          final tileColor = isSouth ? const Color(0xFFFFECB3) : const Color(0xFFFFCDD2);
          final borderColor = selectedCell == (r, c)
              ? Colors.cyanAccent
              : (isMyTurn && movableSources.contains((r, c))
                  ? const Color(0xFF00C853)
                  : (isSouth ? const Color(0xFF2E7D32) : const Color(0xFFC62828)));

          canvas.drawRRect(
            RRect.fromRectAndRadius(tileRect, Radius.circular(cellSize * 0.12)),
            Paint()..color = tileColor,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(tileRect, Radius.circular(cellSize * 0.12)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2
              ..color = borderColor,
          );

          // Draw directional movement dots around the edges of the tile
          for (final (dr, dc) in _dirsFor(owner, kind)) {
            final dotPos = Offset(
              tileRect.center.dx + dc * tileRect.width * 0.36,
              tileRect.center.dy + dr * tileRect.height * 0.36,
            );
            canvas.drawCircle(
              dotPos,
              cellSize * 0.038,
              Paint()..color = const Color(0xFFD32F2F),
            );
          }

          final emoji = _DobutsuShogiBoardState._kEmojis[kind] ?? kind;
          final name = _DobutsuShogiBoardState._kNames[kind] ?? kind;
          final tp = TextPainter(
            text: TextSpan(
              text: '$emoji\n$name',
              style: TextStyle(
                color: const Color(0xFF3E2723),
                fontWeight: FontWeight.w900,
                fontSize: cellSize * 0.19,
                height: 1.05,
                fontFamilyFallback: kFontFallback,
              ),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, tileRect.center - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DobutsuShogiPainter oldDelegate) => true;
}
