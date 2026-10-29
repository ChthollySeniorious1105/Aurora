import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a12_common.dart';

class KuromasuBoard extends StatefulWidget {
  final GameContext g;
  const KuromasuBoard(this.g, {super.key});
  @override
  State<KuromasuBoard> createState() => _KuromasuBoardState();
}

class _KuromasuBoardState extends State<KuromasuBoard> {
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

  void _onSetVal(int val, int size, List<int> cluesFlat) {
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
    final size = math.max(5, aInt(v['size'], 5));
    final left = aInt(v['left'], 0);
    final cluesFlat = aInts(v['cluesFlat']);
    final board = aInts(v['board']);
    final visibleCounts = aInts(v['visibleCounts']);
    final satisfiedClues = aInts(v['satisfiedClues']).toSet();
    final violatedClues = aInts(v['violatedClues']).toSet();
    final adjacentBlacks = aInts(v['adjacentBlacks']).toSet();
    final isolatedWhites = aInts(v['isolatedWhites']).toSet();
    final satisfiedClueCount = aInt(v['satisfiedClueCount'], 0);
    final totalClues = math.max(1, aInt(v['totalClues'], 1));
    final blackCount = aInt(v['blackCount'], 0);
    final whiteConnected = v['whiteConnected'] != false;
    final ps = aMaps(v['ps']);

    if (_selectedIdx >= size * size) {
      _selectedIdx = 0;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '黑格视线竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出黑格视线（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (adjacentBlacks.isNotEmpty) '黑格正交相邻',
        if (!whiteConnected) '白格被隔断',
      ];
      final warnStr = warnings.isEmpty ? '黑白连通正常' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 视线达标 $satisfiedClueCount/$totalClues · 黑格 $blackCount · $warnStr · ${left}s';
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
        board: board,
        visibleCounts: visibleCounts,
        satisfiedClues: satisfiedClues,
        violatedClues: violatedClues,
        adjacentBlacks: adjacentBlacks,
        isolatedWhites: isolatedWhites,
        satisfiedClueCount: satisfiedClueCount,
        totalClues: totalClues,
        blackCount: blackCount,
        whiteConnected: whiteConnected,
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
    final sat = aInt(p['satisfiedClues'], 0);
    final tot = math.max(1, aInt(p['totalClues'], 6));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot视线', null),
    };
    return A12ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (sat / tot),
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
    required List<int> board,
    required List<int> visibleCounts,
    required Set<int> satisfiedClues,
    required Set<int> violatedClues,
    required Set<int> adjacentBlacks,
    required Set<int> isolatedWhites,
    required int satisfiedClueCount,
    required int totalClues,
    required int blackCount,
    required bool whiteConnected,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 48.0 : 42.0;

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
          for (var r = 0; r < size; r++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      visibleCounts: visibleCounts,
                      satisfiedClues: satisfiedClues,
                      violatedClues: violatedClues,
                      adjacentBlacks: adjacentBlacks,
                      isolatedWhites: isolatedWhites,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );

    final toolbar = Container(
      constraints: BoxConstraints(maxWidth: wide ? 235 : 340),
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
              A12Chip('视线 $satisfiedClueCount/$totalClues', const Color(0xFF00897B), size: 11),
              A12Chip('黑格 $blackCount', cs.primary, size: 11),
              A12Chip(
                adjacentBlacks.isEmpty && whiteConnected ? '✓ 禁邻/连通正常' : '⚠ 黑格相邻或隔断',
                adjacentBlacks.isEmpty && whiteConnected ? Colors.green : Colors.redAccent,
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
              SizedBox(
                height: 34,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF263238),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _canPlay ? () => _onSetVal(1, size, cluesFlat) : null,
                  child: const Text('■ 涂黑', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
              SizedBox(
                height: 34,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE0F2F1),
                    foregroundColor: const Color(0xFF00695C),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _canPlay ? () => _onSetVal(2, size, cluesFlat) : null,
                  child: const Text('● 标记白格', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
              SizedBox(
                width: 44,
                height: 34,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _canPlay ? () => _onSetVal(0, size, cluesFlat) : null,
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

  Widget _buildCell({
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required List<int> cluesFlat,
    required List<int> board,
    required List<int> visibleCounts,
    required Set<int> satisfiedClues,
    required Set<int> violatedClues,
    required Set<int> adjacentBlacks,
    required Set<int> isolatedWhites,
  }) {
    final idx = r * size + c;
    final clue = idx < cluesFlat.length ? cluesFlat[idx] : 0;
    final isClue = clue > 0;
    final val = idx < board.length ? board[idx] : 0;
    final vis = idx < visibleCounts.length ? visibleCounts[idx] : 0;
    final isSatClue = satisfiedClues.contains(idx);
    final isAdjBlack = adjacentBlacks.contains(idx);
    final isIsoWhite = isolatedWhites.contains(idx);
    final isSelected = _selectedIdx == idx;

    Color bgColor;
    if (val == 1) {
      bgColor = isAdjBlack ? const Color(0xFFB71C1C) : const Color(0xFF0F172A);
    } else if (isIsoWhite) {
      bgColor = const Color(0xFFFFCDD2);
    } else if (isClue) {
      bgColor = isSatClue ? const Color(0xFFE8F5E9) : const Color(0xFFFFFDE7);
    } else if (val == 2) {
      bgColor = const Color(0xFFE0F2F1);
    } else {
      bgColor = const Color(0xFFF8FAFC);
    }

    final borderColor = (isAdjBlack || isIsoWhite)
        ? const Color(0xFFE53935)
        : (isSelected
            ? const Color(0xFF00ACC1)
            : (isSatClue ? const Color(0xFF43A047) : const Color(0xFF64748B)));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, size, isClue),
      onSecondaryTap: () {
        setState(() => _selectedIdx = idx);
        if (_canPlay && !isClue) {
          g.act({'type': 'set', 'r': r, 'c': c, 'val': 2});
        }
      },
      child: Container(
        width: cellPx,
        height: cellPx,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isSelected ? 2.4 : 1.4),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isClue) ...[
              Container(
                width: cellPx * 0.68,
                height: cellPx * 0.68,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSatClue ? const Color(0xFF2E7D32) : const Color(0xFF334155),
                    width: 1.8,
                  ),
                ),
                child: Text(
                  '$clue',
                  style: TextStyle(
                    fontSize: cellPx * 0.36,
                    fontWeight: FontWeight.w900,
                    color: isSatClue ? const Color(0xFF1B5E20) : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 1,
                child: Text(
                  '$vis',
                  style: TextStyle(
                    fontSize: cellPx * 0.19,
                    fontWeight: FontWeight.w800,
                    color: vis == clue
                        ? const Color(0xFF2E7D32)
                        : (vis < clue ? const Color(0xFFC62828) : const Color(0xFFE65100)),
                  ),
                ),
              ),
            ] else if (val == 1)
              Icon(
                Icons.square_rounded,
                size: cellPx * 0.48,
                color: isAdjBlack ? const Color(0xFFFFCDD2) : const Color(0xFF334155),
              )
            else if (val == 2)
              Container(
                width: cellPx * 0.24,
                height: cellPx * 0.24,
                decoration: const BoxDecoration(
                  color: Color(0xFF00897B),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
