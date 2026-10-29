import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class EntropyBoard extends StatefulWidget {
  final GameContext g;
  const EntropyBoard(this.g, {super.key});

  @override
  State<EntropyBoard> createState() => _EntropyBoardState();
}

class _EntropyBoardState extends State<EntropyBoard> {
  (int, int)? _selectedFrom;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  static const List<Color> _tileColors = [
    Colors.transparent,
    Color(0xFFE53935), // 1 Red
    Color(0xFF1E88E5), // 2 Blue
    Color(0xFF43A047), // 3 Green
    Color(0xFFFDD835), // 4 Yellow
    Color(0xFF8E24AA), // 5 Purple
    Color(0xFFFB8C00), // 6 Orange
    Color(0xFF00ACC1), // 7 Cyan
  ];

  static const List<String> _tileNames = [
    '',
    '红1',
    '蓝2',
    '绿3',
    '黄4',
    '紫5',
    '橙6',
    '青7',
  ];

  List<(int, int)> _legalSlideTargets(int fromR, int fromC, List<List<int>> board) {
    final size = board.length;
    if (fromR < 0 || fromR >= size || fromC < 0 || fromC >= size) return const [];
    if (board[fromR][fromC] <= 0) return const [];
    final res = <(int, int)>[];
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    for (final (dr, dc) in dirs) {
      var nr = fromR + dr;
      var nc = fromC + dc;
      while (nr >= 0 && nr < size && nc >= 0 && nc < size && board[nr][nc] == 0) {
        res.add((nr, nc));
        nr += dr;
        nc += dc;
      }
    }
    return res;
  }

  void _onCellTap(int r, int c, List<List<int>> board, String phase, int turn, bool over) {
    if (over || g.seat != turn) return;
    final size = board.length;
    if (r < 0 || r >= size || c < 0 || c >= size) return;

    if (phase == 'chaos') {
      if (board[r][c] == 0) {
        g.act({'type': 'place', 'r': r, 'c': c});
      }
      return;
    }

    if (phase == 'order') {
      if (_selectedFrom != null) {
        final (sr, sc) = _selectedFrom!;
        if (sr == r && sc == c) {
          setState(() => _selectedFrom = null);
          return;
        }
        final targets = _legalSlideTargets(sr, sc, board);
        if (targets.contains((r, c))) {
          setState(() => _selectedFrom = null);
          g.act({
            'type': 'slide',
            'fromR': sr,
            'fromC': sc,
            'toR': r,
            'toC': c,
          });
          return;
        }
      }
      if (board[r][c] > 0) {
        setState(() => _selectedFrom = (r, c));
      } else {
        setState(() => _selectedFrom = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = (v['size'] as int?) ?? 5;
    final halves = (v['halves'] as int?) ?? 2;
    final half = (v['half'] as int?) ?? 1;
    final targetScore = (v['targetScore'] as int?) ?? 30;
    final chaosSeat = (v['chaosSeat'] as int?) ?? 0;
    final phase = (v['phase'] as String?) ?? 'chaos';
    final turn = (v['turn'] as int?) ?? 0;
    final over = v['over'] == true || g.over;
    final currentTile = (v['currentTile'] as int?) ?? 0;
    final bagCount = (v['bagCount'] as int?) ?? 0;

    final rawBoard = (v['board'] as List?) ?? const [];
    final board = <List<int>>[
      for (var r = 0; r < size; r++)
        r < rawBoard.length
            ? (rawBoard[r] as List).map((e) => (e as num).toInt()).toList()
            : List<int>.filled(size, 0),
    ];

    if (_selectedFrom != null) {
      final (sr, sc) = _selectedFrom!;
      if (phase != 'order' || sr >= size || sc >= size || board[sr][sc] <= 0) {
        _selectedFrom = null;
      }
    }

    final halfScores = ((v['halfScores'] as List?) ?? const [0, 0])
        .map((e) => (e as num).toInt())
        .toList();
    final s0 = halfScores.isNotEmpty ? halfScores[0] : 0;
    final s1 = halfScores.length > 1 ? halfScores[1] : 0;

    final rowScores = ((v['rowScores'] as List?) ?? List.filled(size, 0))
        .map((e) => (e as num).toInt())
        .toList();
    final colScores = ((v['colScores'] as List?) ?? List.filled(size, 0))
        .map((e) => (e as num).toInt())
        .toList();

    final lastAction = v['lastAction'] as Map?;
    final resultText = v['result'] as String?;

    final legalTargets = (_selectedFrom != null && phase == 'order' && !over && g.seat == turn)
        ? _legalSlideTargets(_selectedFrom!.$1, _selectedFrom!.$2, board).toSet()
        : const <(int, int)>{};

    String statusText;
    if (over) {
      statusText = resultText ?? '对局结束';
    } else if (phase == 'chaos') {
      final tName = (currentTile >= 1 && currentTile < _tileNames.length)
          ? _tileNames[currentTile]
          : '$currentTile';
      statusText = g.seat == turn
          ? '第$half/$halves局 · 混沌回合：请将【$tName】放入任意空格（袋余 $bagCount）'
          : '第$half/$halves局 · 等待混沌方 ${g.name(turn)} 放置【$tName】…';
    } else {
      statusText = g.seat == turn
          ? '第$half/$halves局 · 秩序回合：点击棋子正交滑移构筑回文串，或点“跳过”'
          : '第$half/$halves局 · 等待秩序方 ${g.name(turn)} 滑移棋子…';
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
                        sub: '${chaosSeat == 0 ? "混沌方" : "秩序方"} · 秩序分 $s0',
                        size: isCompact ? 28 : 34,
                      ),
                      StatusBar(statusText, highlight: !over && g.seat == turn),
                      if (!over && phase == 'chaos' && currentTile > 0)
                        _CurrentTileBadge(
                          color: _tileColors[currentTile.clamp(1, 7)],
                          label: '当前抽子: $currentTile',
                        ),
                      if (!over && phase == 'order' && g.seat == turn)
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          onPressed: () {
                            setState(() => _selectedFrom = null);
                            g.act({'type': 'pass'});
                          },
                          icon: const Icon(Icons.skip_next, size: 16),
                          label: const Text('跳过不滑移'),
                        ),
                      g.tag(
                        1,
                        active: !over && turn == 1,
                        sub: '${chaosSeat == 1 ? "混沌方" : "秩序方"} · 秩序分 $s1${halves == 1 ? "/$targetScore" : ""}',
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
                            // Grid has size cells + 1 score margin column/row
                            final pad = side * 0.04;
                            final cellSpan = (side - pad * 2) / (size + 0.75);

                            return GestureDetector(
                              onTapUp: (d) {
                                final pos = d.localPosition;
                                final c = ((pos.dx - pad) / cellSpan).floor();
                                final r = ((pos.dy - pad) / cellSpan).floor();
                                if (r >= 0 && r < size && c >= 0 && c < size) {
                                  _onCellTap(r, c, board, phase, turn, over);
                                }
                              },
                              child: CustomPaint(
                                size: Size(side, side),
                                painter: _EntropyPainter(
                                  size: size,
                                  board: board,
                                  rowScores: rowScores,
                                  colScores: colScores,
                                  selectedFrom: _selectedFrom,
                                  legalTargets: legalTargets,
                                  lastAction: lastAction,
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

class _CurrentTileBadge extends StatelessWidget {
  final Color color;
  final String label;
  const _CurrentTileBadge({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white70, width: 1.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
        ),
      ),
    );
  }
}

class _EntropyPainter extends CustomPainter {
  final int size;
  final List<List<int>> board;
  final List<int> rowScores;
  final List<int> colScores;
  final (int, int)? selectedFrom;
  final Set<(int, int)> legalTargets;
  final Map? lastAction;
  final ColorScheme cs;

  _EntropyPainter({
    required this.size,
    required this.board,
    required this.rowScores,
    required this.colScores,
    required this.selectedFrom,
    required this.legalTargets,
    required this.lastAction,
    required this.cs,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final side = math.min(canvasSize.width, canvasSize.height);
    final pad = side * 0.04;
    final cell = (side - pad * 2) / (size + 0.75);
    final boardExtent = cell * size;

    final boardRect = Rect.fromLTWH(pad, pad, boardExtent, boardExtent);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect.inflate(4), const Radius.circular(12)),
      Paint()..color = const Color(0xFF1F2633),
    );

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final rect = Rect.fromLTWH(
          pad + c * cell + 2,
          pad + r * cell + 2,
          cell - 4,
          cell - 4,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
        canvas.drawRRect(
          rrect,
          Paint()..color = const Color(0xFF2D3748),
        );

        final val = board[r][c];
        if (val > 0) {
          final color = _EntropyBoardState._tileColors[val.clamp(1, 7)];
          final tileRect = rect.deflate(cell * 0.07);
          final tileRRect = RRect.fromRectAndRadius(tileRect, const Radius.circular(8));
          canvas.drawRRect(
            tileRRect,
            Paint()..color = color,
          );
          canvas.drawRRect(
            tileRRect,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );

          final tp = TextPainter(
            text: TextSpan(
              text: '$val',
              style: TextStyle(
                fontSize: cell * 0.42,
                fontWeight: FontWeight.w900,
                color: val == 4 ? Colors.black87 : Colors.white,
                fontFamilyFallback: kFontFallback,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
            canvas,
            rect.center - Offset(tp.width / 2, tp.height / 2),
          );
        }

        // Highlight legal slide target
        if (legalTargets.contains((r, c))) {
          canvas.drawCircle(
            rect.center,
            cell * 0.16,
            Paint()..color = Colors.greenAccent.withValues(alpha: 0.85),
          );
        }

        // Highlight selected tile
        if (selectedFrom == (r, c)) {
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = Colors.amberAccent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0,
          );
        }
      }
    }

    // Highlight last action
    if (lastAction != null) {
      final type = lastAction!['type'];
      if (type == 'place' && lastAction!['r'] is num && lastAction!['c'] is num) {
        final lr = (lastAction!['r'] as num).toInt();
        final lc = (lastAction!['c'] as num).toInt();
        if (lr >= 0 && lr < size && lc >= 0 && lc < size) {
          final rect = Rect.fromLTWH(pad + lc * cell + 3, pad + lr * cell + 3, cell - 6, cell - 6);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(8)),
            Paint()
              ..color = Colors.cyanAccent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2,
          );
        }
      } else if (type == 'slide' &&
          lastAction!['toR'] is num &&
          lastAction!['toC'] is num) {
        final tr = (lastAction!['toR'] as num).toInt();
        final tc = (lastAction!['toC'] as num).toInt();
        if (tr >= 0 && tr < size && tc >= 0 && tc < size) {
          final rect = Rect.fromLTWH(pad + tc * cell + 3, pad + tr * cell + 3, cell - 6, cell - 6);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(8)),
            Paint()
              ..color = Colors.amberAccent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2,
          );
        }
      }
    }

    // Draw row palindrome scores on the right and column palindrome scores on the bottom
    for (var i = 0; i < size; i++) {
      final rScore = i < rowScores.length ? rowScores[i] : 0;
      final rTp = TextPainter(
        text: TextSpan(
          text: '+$rScore',
          style: TextStyle(
            fontSize: math.max(10, cell * 0.26),
            fontWeight: FontWeight.bold,
            color: rScore > 0 ? Colors.amberAccent : Colors.white54,
            fontFamilyFallback: kFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final rx = pad + boardExtent + cell * 0.38 - rTp.width / 2;
      final ry = pad + (i + 0.5) * cell - rTp.height / 2;
      rTp.paint(canvas, Offset(rx, ry));

      final cScore = i < colScores.length ? colScores[i] : 0;
      final cTp = TextPainter(
        text: TextSpan(
          text: '+$cScore',
          style: TextStyle(
            fontSize: math.max(10, cell * 0.26),
            fontWeight: FontWeight.bold,
            color: cScore > 0 ? Colors.amberAccent : Colors.white54,
            fontFamilyFallback: kFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = pad + (i + 0.5) * cell - cTp.width / 2;
      final cy = pad + boardExtent + cell * 0.38 - cTp.height / 2;
      cTp.paint(canvas, Offset(cx, cy));
    }
  }

  @override
  bool shouldRepaint(covariant _EntropyPainter oldDelegate) => true;
}
