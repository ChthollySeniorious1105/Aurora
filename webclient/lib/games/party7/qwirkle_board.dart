import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<Color> _qwirkleColors = [
  Color(0xFFE53935), // 0 红
  Color(0xFFFB8C00), // 1 橙
  Color(0xFFFDD835), // 2 黄
  Color(0xFF43A047), // 3 绿
  Color(0xFF1E88E5), // 4 蓝
  Color(0xFF8E24AA), // 5 紫
];

const List<String> _qwirkleSymbols = [
  '●', // 0 圆形
  '✦', // 1 四角星
  '◆', // 2 菱形
  '■', // 3 方形
  '✸', // 4 八角星
  '♣', // 5 四叶草
];

class QwirkleBoard extends StatefulWidget {
  final GameContext g;
  const QwirkleBoard(this.g, {super.key});

  @override
  State<QwirkleBoard> createState() => _QwirkleBoardState();
}

class _QwirkleBoardState extends State<QwirkleBoard> {
  int? _selectedHandIdx;
  bool _swapMode = false;
  final Set<int> _swapIndices = {};
  final List<({int r, int c, int handIdx, int tile})> _staged = [];

  GameContext get g => widget.g;

  @override
  void didUpdateWidget(covariant QwirkleBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.g.view['turn'] != g.view['turn'] || oldWidget.g.view['bagCount'] != g.view['bagCount']) {
      _selectedHandIdx = null;
      _swapMode = false;
      _swapIndices.clear();
      _staged.clear();
    }
  }

  Widget _buildTileWidget(int tile, double size, {bool selected = false, bool staged = false, bool dim = false}) {
    final cIdx = (tile ~/ 6).clamp(0, 5);
    final sIdx = (tile % 6).clamp(0, 5);
    final color = _qwirkleColors[cIdx];
    final sym = _qwirkleSymbols[sIdx];

    return Opacity(
      opacity: dim ? 0.35 : 1.0,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF22252A),
          borderRadius: BorderRadius.circular(size * 0.18),
          border: Border.all(
            color: selected
                ? Colors.amberAccent
                : (staged ? Colors.greenAccent : Colors.white24),
            width: (selected || staged) ? 2.2 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(1, 1)),
          ],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.all(size * 0.08),
              child: Text(
                sym,
                style: TextStyle(
                  fontSize: size * 0.65,
                  color: color,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                  fontFamilyFallback: kFontFallback,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final bagCount = (v['bagCount'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final handCounts = (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final hand = (v['hand'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final logs = (v['log'] as List?)?.map((e) => '$e').toList() ?? const <String>[];

    final boardRaw = (v['board'] as Map?) ?? const {};
    final board = <(int, int), int>{};
    for (final e in boardRaw.entries) {
      final parts = '${e.key}'.split(',');
      if (parts.length == 2) {
        final r = int.tryParse(parts[0]);
        final c = int.tryParse(parts[1]);
        if (r != null && c != null) {
          board[(r, c)] = (e.value as num).toInt();
        }
      }
    }

    final lastMove = v['lastMove'] as Map?;
    final lastPlaced = <(int, int)>{};
    if (lastMove != null && lastMove['placements'] is List) {
      for (final p in lastMove['placements'] as List) {
        if (p is Map) {
          final r = (p['r'] as num?)?.toInt();
          final c = (p['c'] as num?)?.toInt();
          if (r != null && c != null) lastPlaced.add((r, c));
        }
      }
    }

    final isMyTurn = !over && g.seat == turn;
    final bounds = (v['bounds'] as Map?) ?? const {};
    var minR = ((bounds['minR'] as num?)?.toInt() ?? 0) - 1;
    var maxR = ((bounds['maxR'] as num?)?.toInt() ?? 0) + 1;
    var minC = ((bounds['minC'] as num?)?.toInt() ?? 0) - 1;
    var maxC = ((bounds['maxC'] as num?)?.toInt() ?? 0) + 1;
    for (final s in _staged) {
      minR = min(minR, s.r - 1);
      maxR = max(maxR, s.r + 1);
      minC = min(minC, s.c - 1);
      maxC = max(maxC, s.c + 1);
    }
    if (maxR - minR < 4) {
      minR = -2;
      maxR = 2;
    }
    if (maxC - minC < 4) {
      minC = -2;
      maxC = 2;
    }

    final rows = maxR - minR + 1;
    final cols = maxC - minC + 1;

    String statusText;
    if (over) {
      final best = scores.isEmpty ? 0 : scores.reduce(max);
      final winners = [for (var s = 0; s < g.players; s++) if (scores[s] == best) g.name(s)].join('、');
      statusText = '游戏结束：$winners 以 $best 分获胜！';
    } else if (isMyTurn) {
      statusText = _swapMode
          ? '轮到你：点选手牌进行交换（牌袋余 $bagCount 张）'
          : '轮到你：先点选手牌再点击棋盘空格放置（牌袋余 $bagCount 张）';
    } else {
      statusText = '等待 ${g.name(turn)} 行动（牌袋余 $bagCount 张）';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 460 || constraints.maxWidth < 460;
      final handTileSize = compact ? 34.0 : 44.0;

      return Stack(
        children: [
          Container(
            color: g.table,
            padding: EdgeInsets.all(compact ? 4 : 8),
            child: Column(
              children: [
                // Top bar
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
                        sub: '${scores[s]}分 · 手牌${handCounts[s]}',
                      ),
                  ],
                ),
                SizedBox(height: compact ? 4 : 6),

                // Center board
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
                    ),
                    padding: EdgeInsets.all(compact ? 4 : 8),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var r = minR; r <= maxR; r++)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var c = minC; c <= maxC; c++)
                                  Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: _buildGridCell(
                                      r: r,
                                      c: c,
                                      board: board,
                                      lastPlaced: lastPlaced,
                                      hand: hand,
                                      isMyTurn: isMyTurn,
                                      cs: cs,
                                      cellSize: max(28.0, min(48.0, 360.0 / max(rows, cols))),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 4 : 6),

                // Bottom hand & controls
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
                          // Hand tiles
                          for (var i = 0; i < hand.length; i++)
                            Builder(builder: (context) {
                              final alreadyStaged = _staged.any((s) => s.handIdx == i);
                              final isSelected = _swapMode
                                  ? _swapIndices.contains(i)
                                  : _selectedHandIdx == i;
                              return GestureDetector(
                                onTap: (!isMyTurn || alreadyStaged)
                                    ? null
                                    : () {
                                        setState(() {
                                          if (_swapMode) {
                                            if (_swapIndices.contains(i)) {
                                              _swapIndices.remove(i);
                                            } else {
                                              _swapIndices.add(i);
                                            }
                                          } else {
                                            _selectedHandIdx = _selectedHandIdx == i ? null : i;
                                          }
                                        });
                                      },
                                child: _buildTileWidget(
                                  hand[i],
                                  handTileSize,
                                  selected: isSelected,
                                  dim: alreadyStaged,
                                ),
                              );
                            }),
                          if (isMyTurn && !_swapMode && _staged.isNotEmpty) ...[
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                              ),
                              onPressed: () {
                                g.act({
                                  'type': 'place',
                                  'placements': [
                                    for (final s in _staged) {'r': s.r, 'c': s.c, 'tile': s.tile}
                                  ],
                                });
                                setState(() {
                                  _staged.clear();
                                  _selectedHandIdx = null;
                                });
                              },
                              icon: const Icon(Icons.check, size: 16),
                              label: Text('确认出牌(${_staged.length})'),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                              ),
                              onPressed: () => setState(() {
                                _staged.clear();
                                _selectedHandIdx = null;
                              }),
                              child: const Text('撤销'),
                            ),
                          ],
                          if (isMyTurn && bagCount > 0 && _staged.isEmpty) ...[
                            if (!_swapMode)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                                ),
                                onPressed: () => setState(() {
                                  _swapMode = true;
                                  _selectedHandIdx = null;
                                  _swapIndices.clear();
                                }),
                                icon: const Icon(Icons.swap_horiz, size: 16),
                                label: const Text('换牌'),
                              )
                            else ...[
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                                ),
                                onPressed: _swapIndices.isEmpty
                                    ? null
                                    : () {
                                        final idxList = _swapIndices.toList()..sort();
                                        g.act({'type': 'swap', 'indices': idxList});
                                        setState(() {
                                          _swapMode = false;
                                          _swapIndices.clear();
                                        });
                                      },
                                child: Text('确认交换(${_swapIndices.length})'),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  _swapMode = false;
                                  _swapIndices.clear();
                                }),
                                child: const Text('取消'),
                              ),
                            ],
                          ],
                          if (isMyTurn && bagCount == 0 && _staged.isEmpty)
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                              ),
                              onPressed: () => g.act({'type': 'pass'}),
                              child: const Text('跳过回合'),
                            ),
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
              child: ResultBanner(statusText),
            ),
        ],
      );
    });
  }

  Widget _buildGridCell({
    required int r,
    required int c,
    required Map<(int, int), int> board,
    required Set<(int, int)> lastPlaced,
    required List<int> hand,
    required bool isMyTurn,
    required ColorScheme cs,
    required double cellSize,
  }) {
    final placedTile = board[(r, c)];
    if (placedTile != null) {
      return _buildTileWidget(
        placedTile,
        cellSize,
        selected: lastPlaced.contains((r, c)),
      );
    }

    final stagedIdx = _staged.indexWhere((s) => s.r == r && s.c == c);
    if (stagedIdx >= 0) {
      final st = _staged[stagedIdx];
      return GestureDetector(
        onTap: () => setState(() => _staged.removeAt(stagedIdx)),
        child: _buildTileWidget(st.tile, cellSize, staged: true),
      );
    }

    final isCenter = r == 0 && c == 0 && board.isEmpty && _staged.isEmpty;
    final isAdjacent = board.containsKey((r - 1, c)) ||
        board.containsKey((r + 1, c)) ||
        board.containsKey((r, c - 1)) ||
        board.containsKey((r, c + 1)) ||
        _staged.any((s) => (s.r - r).abs() + (s.c - c).abs() == 1);
    final canTap = isMyTurn &&
        !_swapMode &&
        _selectedHandIdx != null &&
        _selectedHandIdx! < hand.length &&
        (isCenter || isAdjacent || board.isEmpty);

    return GestureDetector(
      onTap: canTap
          ? () {
              final hIdx = _selectedHandIdx!;
              setState(() {
                _staged.add((r: r, c: c, handIdx: hIdx, tile: hand[hIdx]));
                _selectedHandIdx = null;
              });
            }
          : null,
      child: Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: canTap
              ? cs.primary.withValues(alpha: 0.16)
              : cs.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(cellSize * 0.16),
          border: Border.all(
            color: canTap
                ? cs.primary.withValues(alpha: 0.55)
                : cs.outline.withValues(alpha: 0.18),
          ),
        ),
        child: isCenter
            ? Icon(Icons.star_border, size: cellSize * 0.45, color: cs.primary.withValues(alpha: 0.6))
            : null,
      ),
    );
  }
}
