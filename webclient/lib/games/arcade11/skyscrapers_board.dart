import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a11_common.dart';

class SkyscrapersBoard extends StatefulWidget {
  final GameContext g;
  const SkyscrapersBoard(this.g, {super.key});
  @override
  State<SkyscrapersBoard> createState() => _SkyscrapersBoardState();
}

class _SkyscrapersBoardState extends State<SkyscrapersBoard> {
  GameContext get g => widget.g;
  int _selectedIdx = 0;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _onCellTap(int r, int c, int size, bool isClue) {
    final idx = r * size + c;
    setState(() => _selectedIdx = idx);
    if (!_canPlay || isClue) return;
    g.act({'type': 'toggle', 'r': r, 'c': c});
  }

  void _onSetDigit(int val, int size, List<int> cluesFlat) {
    if (!_canPlay) return;
    final idx = _selectedIdx.clamp(0, size * size - 1);
    if (idx < cluesFlat.length && cluesFlat[idx] > 0) return;
    g.act({'type': 'set', 'r': idx ~/ size, 'c': idx % size, 'val': val});
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = aStr(v['phase']);
    final round = aInt(v['round'], 1);
    final totalRounds = math.max(1, aInt(v['totalRounds'], 3));
    final size = math.max(4, aInt(v['size'], 4));
    final left = aInt(v['left'], 0);
    final cluesFlat = aInts(v['cluesFlat']);
    final topClues = aInts(v['topClues']);
    final bottomClues = aInts(v['bottomClues']);
    final leftClues = aInts(v['leftClues']);
    final rightClues = aInts(v['rightClues']);
    final board = aInts(v['board']);
    final duplicates = aInts(v['duplicates']).toSet();
    final violatedCells = aInts(v['violatedCells']).toSet();
    final satisfiedTop = aInts(v['satisfiedTop']).toSet();
    final satisfiedBottom = aInts(v['satisfiedBottom']).toSet();
    final satisfiedLeft = aInts(v['satisfiedLeft']).toSet();
    final satisfiedRight = aInts(v['satisfiedRight']).toSet();
    final violatedTop = aInts(v['violatedTop']).toSet();
    final violatedBottom = aInts(v['violatedBottom']).toSet();
    final violatedLeft = aInts(v['violatedLeft']).toSet();
    final violatedRight = aInts(v['violatedRight']).toSet();
    final satisfiedClues = aInt(v['satisfiedClues'], 0);
    final totalClues = math.max(1, aInt(v['totalClues'], 4 * size));
    final validLines = aInt(v['validLines'], 0);
    final totalLines = math.max(1, aInt(v['totalLines'], 2 * size));
    final ps = aMaps(v['ps']);

    if (_selectedIdx >= size * size) {
      _selectedIdx = 0;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '摩天楼可见数竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出摩天楼谜题（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (duplicates.isNotEmpty) '同行/列楼高重复',
        if (violatedCells.isNotEmpty) '视线可见数不符',
      ];
      final warnStr = warnings.isEmpty ? '无冲突' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 视线 $satisfiedClues/$totalClues · 行列 $validLines/$totalLines · $warnStr · ${left}s';
    }

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > box.maxHeight * 1.12;
      final sideW = wide ? math.min(200.0, box.maxWidth * 0.24) : 0.0;
      final topStripH = wide ? 0.0 : 58.0;

      final playerTiles = Wrap(
        direction: wide ? Axis.vertical : Axis.horizontal,
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final s in g.seatsFromMe())
            if (s < ps.length) _buildPlayerTile(s, ps[s], totalRounds, wide ? sideW - 12 : 140),
        ],
      );

      final workspace = _buildWorkspace(
        context,
        cs: cs,
        size: size,
        cluesFlat: cluesFlat,
        topClues: topClues,
        bottomClues: bottomClues,
        leftClues: leftClues,
        rightClues: rightClues,
        board: board,
        duplicates: duplicates,
        violatedCells: violatedCells,
        satisfiedTop: satisfiedTop,
        satisfiedBottom: satisfiedBottom,
        satisfiedLeft: satisfiedLeft,
        satisfiedRight: satisfiedRight,
        violatedTop: violatedTop,
        violatedBottom: violatedBottom,
        violatedLeft: violatedLeft,
        violatedRight: violatedRight,
        satisfiedClues: satisfiedClues,
        totalClues: totalClues,
        validLines: validLines,
        totalLines: totalLines,
        wide: wide,
      );

      Widget body;
      if (wide) {
        body = Row(children: [
          SizedBox(
            width: sideW,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(6),
                child: FittedBox(fit: BoxFit.scaleDown, child: playerTiles),
              ),
            ),
          ),
          Expanded(child: Center(child: workspace)),
        ]);
      } else {
        body = Column(children: [
          SizedBox(
            height: topStripH,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: playerTiles),
              ),
            ),
          ),
          Expanded(child: Center(child: workspace)),
        ]);
      }

      return Column(children: [
        SizedBox(height: 38, child: aStatus(status, highlight: _canPlay)),
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: body),
            if (phase == 'over')
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: aRanking(
                    g,
                    aMaps(v['final']),
                    (r) => '${r['score']} 分 · 解出 ${r['solved']}/$totalRounds 题',
                  ),
                ),
              ),
          ]),
        ),
      ]);
    });
  }

  Widget _buildPlayerTile(int s, Map<String, dynamic> p, int totalRounds, double width) {
    final st = aStr(p['status']);
    final score = aInt(p['score'], 0);
    final solved = aInt(p['solved'], 0);
    final filled = aInt(p['filled'], 0);
    final totalCells = math.max(1, aInt(p['totalCells'], 16));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$filled/$totalCells栋', null),
    };
    return A11ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (filled / totalCells),
      badge: badge,
      badgeColor: col,
      dim: st == 'resigned',
      sub: '积分 $score · 解出 $solved/$totalRounds',
    );
  }

  Widget _buildWorkspace(
    BuildContext context, {
    required ColorScheme cs,
    required int size,
    required List<int> cluesFlat,
    required List<int> topClues,
    required List<int> bottomClues,
    required List<int> leftClues,
    required List<int> rightClues,
    required List<int> board,
    required Set<int> duplicates,
    required Set<int> violatedCells,
    required Set<int> satisfiedTop,
    required Set<int> satisfiedBottom,
    required Set<int> satisfiedLeft,
    required Set<int> satisfiedRight,
    required Set<int> violatedTop,
    required Set<int> violatedBottom,
    required Set<int> violatedLeft,
    required Set<int> violatedRight,
    required int satisfiedClues,
    required int totalClues,
    required int validLines,
    required int totalLines,
    required bool wide,
  }) {
    final cellPx = size <= 4 ? 48.0 : 42.0;
    final cluePx = size <= 4 ? 32.0 : 28.0;

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141C26),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top visibility clues row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: cluePx, height: cluePx),
              for (var c = 0; c < size; c++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: _buildClueBadge(
                    clue: c < topClues.length ? topClues[c] : 0,
                    arrow: '▼',
                    width: cellPx,
                    height: cluePx,
                    satisfied: satisfiedTop.contains(c),
                    violated: violatedTop.contains(c),
                  ),
                ),
              SizedBox(width: cluePx, height: cluePx),
            ],
          ),
          // Interior rows with left & right visibility clues
          for (var r = 0; r < size; r++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: _buildClueBadge(
                    clue: r < leftClues.length ? leftClues[r] : 0,
                    arrow: '▶',
                    width: cluePx,
                    height: cellPx,
                    satisfied: satisfiedLeft.contains(r),
                    violated: violatedLeft.contains(r),
                  ),
                ),
                for (var c = 0; c < size; c++)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: _buildCell(
                      r: r,
                      c: c,
                      size: size,
                      cellPx: cellPx,
                      cluesFlat: cluesFlat,
                      board: board,
                      duplicates: duplicates,
                      violatedCells: violatedCells,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: _buildClueBadge(
                    clue: r < rightClues.length ? rightClues[r] : 0,
                    arrow: '◀',
                    width: cluePx,
                    height: cellPx,
                    satisfied: satisfiedRight.contains(r),
                    violated: violatedRight.contains(r),
                  ),
                ),
              ],
            ),
          // Bottom visibility clues row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: cluePx, height: cluePx),
              for (var c = 0; c < size; c++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: _buildClueBadge(
                    clue: c < bottomClues.length ? bottomClues[c] : 0,
                    arrow: '▲',
                    width: cellPx,
                    height: cluePx,
                    satisfied: satisfiedBottom.contains(c),
                    violated: violatedBottom.contains(c),
                  ),
                ),
              SizedBox(width: cluePx, height: cluePx),
            ],
          ),
        ],
      ),
    );

    final toolbar = Container(
      constraints: BoxConstraints(maxWidth: wide ? 230 : 340),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              A11Chip('视线 $satisfiedClues/$totalClues', const Color(0xFF00897B), size: 11),
              A11Chip('行列 $validLines/$totalLines', cs.primary, size: 11),
              A11Chip(
                duplicates.isEmpty && violatedCells.isEmpty ? '✓ 无冲突' : '⚠ 存在冲突',
                duplicates.isEmpty && violatedCells.isEmpty ? Colors.green : Colors.redAccent,
                size: 11,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (var d = 1; d <= size; d++)
                SizedBox(
                  width: 38,
                  height: 34,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: _canPlay ? () => _onSetDigit(d, size, cluesFlat) : null,
                    child: Text('$d层', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                ),
              SizedBox(
                width: 44,
                height: 34,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _canPlay ? () => _onSetDigit(0, size, cluesFlat) : null,
                  child: const Icon(Icons.backspace_outlined, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _canPlay ? () => g.act({'type': 'clear'}) : null,
                icon: const Icon(Icons.layers_clear, size: 15),
                label: const Text('重置', style: TextStyle(fontSize: 12)),
              ),
              FilledButton.tonalIcon(
                onPressed: _canPlay ? () => g.act({'type': 'pass'}) : null,
                icon: const Icon(Icons.flag_outlined, size: 15),
                label: const Text('放弃', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: wide
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                gridCard,
                const SizedBox(width: 12),
                toolbar,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                gridCard,
                const SizedBox(height: 8),
                toolbar,
              ]),
      ),
    );
  }

  Widget _buildClueBadge({
    required int clue,
    required String arrow,
    required double width,
    required double height,
    required bool satisfied,
    required bool violated,
  }) {
    if (clue <= 0) {
      return SizedBox(width: width, height: height);
    }
    final bgColor = violated
        ? const Color(0xFFC62828)
        : (satisfied ? const Color(0xFF2E7D32) : const Color(0xFF263238));
    final borderColor = violated
        ? const Color(0xFFFF8A80)
        : (satisfied ? const Color(0xFF81C784) : const Color(0xFF546E7A));

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          child: Text(
            '$arrow$clue',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCell({
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required List<int> cluesFlat,
    required List<int> board,
    required Set<int> duplicates,
    required Set<int> violatedCells,
  }) {
    final idx = r * size + c;
    final isClue = idx < cluesFlat.length && cluesFlat[idx] > 0;
    final val = idx < board.length ? board[idx] : 0;
    final isConflict = duplicates.contains(idx) || violatedCells.contains(idx);
    final isSelected = _selectedIdx == idx;

    Color bgColor;
    Color borderColor;
    Color textColor;
    final borderWidth = isSelected ? 2.4 : 1.4;

    if (isClue) {
      bgColor = isConflict ? const Color(0xFFFFEBEE) : const Color(0xFFCFD8DC);
      borderColor = isConflict
          ? const Color(0xFFD32F2F)
          : (isSelected ? const Color(0xFF0288D1) : const Color(0xFF607D8B));
      textColor = isConflict ? const Color(0xFFB71C1C) : const Color(0xFF1E293B);
    } else {
      bgColor = isConflict
          ? const Color(0xFFFFEBEE)
          : (isSelected ? const Color(0xFFE0F7FA) : const Color(0xFFF8FAFC));
      borderColor = isConflict
          ? const Color(0xFFE53935)
          : (isSelected ? const Color(0xFF00ACC1) : const Color(0xFF94A3B8));
      textColor = isConflict ? const Color(0xFFC62828) : const Color(0xFF0277BD);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, size, isClue),
      onSecondaryTap: () {
        setState(() => _selectedIdx = idx);
        if (_canPlay && !isClue) {
          g.act({'type': 'set', 'r': r, 'c': c, 'val': 0});
        }
      },
      child: Container(
        width: cellPx,
        height: cellPx,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (val > 0)
              Positioned(
                bottom: 3,
                left: 5,
                right: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var f = 0; f < val; f++)
                      Container(
                        width: 4,
                        height: 3.5,
                        margin: const EdgeInsets.symmetric(horizontal: 0.8),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                  ],
                ),
              ),
            if (val > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$val',
                  style: TextStyle(
                    fontSize: cellPx * 0.44,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
