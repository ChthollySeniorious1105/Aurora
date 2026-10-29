import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a17_common.dart';

class YinYangBoard extends StatefulWidget {
  final GameContext g;
  const YinYangBoard(this.g, {super.key});
  @override
  State<YinYangBoard> createState() => _YinYangBoardState();
}

class _YinYangBoardState extends State<YinYangBoard> {
  GameContext get g => widget.g;
  int _selectedIdx = 0;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _onCellTap(int r, int c, int size, List<int> clues) {
    final idx = r * size + c;
    setState(() => _selectedIdx = idx);
    if (!_canPlay) return;
    if (idx < clues.length && clues[idx] != 0) return;
    g.act({'type': 'cycle', 'r': r, 'c': c});
  }

  void _onSetVal(int val, int size, List<int> clues) {
    if (!_canPlay) return;
    final idx = _selectedIdx.clamp(0, size * size - 1);
    if (idx < clues.length && clues[idx] != 0) return;
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
    final clues = aInts(v['clues']);
    final board = aInts(v['board']);
    final whiteCount = aInt(v['whiteCount'], 0);
    final blackCount = aInt(v['blackCount'], 0);
    final filledCount = aInt(v['filledCount'], 0);
    final totalCells = math.max(1, aInt(v['totalCells'], size * size));
    final whiteComponentCount = aInt(v['whiteComponentCount'], 0);
    final blackComponentCount = aInt(v['blackComponentCount'], 0);
    final isWhiteConnected = v['isWhiteConnected'] == true;
    final isBlackConnected = v['isBlackConnected'] == true;
    final twoByTwoCells = aInts(v['twoByTwoCells']).toSet();
    final conflictCells = aInts(v['conflictCells']).toSet();
    final ps = aMaps(v['ps']);

    if (_selectedIdx >= size * size) {
      _selectedIdx = 0;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '阴阳连通竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出阴阳连通（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (twoByTwoCells.isNotEmpty) '禁 2×2 同色冲突',
        if (filledCount == totalCells && !isWhiteConnected) '白圆未单连通($whiteComponentCount群)',
        if (filledCount == totalCells && !isBlackConnected) '黑圆未单连通($blackComponentCount群)',
      ];
      final warnStr = warnings.isEmpty ? '点击空格切换 ⚪白圆 / ⚫黑圆' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 已填 $filledCount/$totalCells · ⚪$whiteCount ⚫$blackCount · $warnStr · ${left}s';
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
        clues: clues,
        board: board,
        whiteCount: whiteCount,
        blackCount: blackCount,
        filledCount: filledCount,
        totalCells: totalCells,
        whiteComponentCount: whiteComponentCount,
        blackComponentCount: blackComponentCount,
        isWhiteConnected: isWhiteConnected,
        isBlackConnected: isBlackConnected,
        twoByTwoCells: twoByTwoCells,
        conflictCells: conflictCells,
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
    final filled = aInt(p['filledCount'], 0);
    final tot = math.max(1, aInt(p['totalCells'], 25));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$filled/$tot格', null),
    };
    return A17ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (filled / tot),
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
    required List<int> clues,
    required List<int> board,
    required int whiteCount,
    required int blackCount,
    required int filledCount,
    required int totalCells,
    required int whiteComponentCount,
    required int blackComponentCount,
    required bool isWhiteConnected,
    required bool isBlackConnected,
    required Set<int> twoByTwoCells,
    required Set<int> conflictCells,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 50.0 : 44.0;

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
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
                  _buildCell(
                    r: r,
                    c: c,
                    size: size,
                    cellPx: cellPx,
                    clues: clues,
                    board: board,
                    conflictCells: conflictCells,
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
              A17Chip('填充 $filledCount/$totalCells', const Color(0xFF455A64), size: 11),
              A17Chip(
                isWhiteConnected ? '✓ ⚪连通($whiteCount)' : '⚪ $whiteComponentCount群',
                isWhiteConnected ? Colors.green : cs.primary,
                size: 11,
              ),
              A17Chip(
                isBlackConnected ? '✓ ⚫连通($blackCount)' : '⚫ $blackComponentCount群',
                isBlackConnected ? Colors.green : const Color(0xFF37474F),
                size: 11,
              ),
              A17Chip(
                twoByTwoCells.isEmpty ? '✓ 无 2×2 同色' : '⚠ 禁 2×2 同色',
                twoByTwoCells.isEmpty ? Colors.green : Colors.redAccent,
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
                    backgroundColor: const Color(0xFFECEFF1),
                    foregroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _canPlay ? () => _onSetVal(1, size, clues) : null,
                  child: const Text('⚪ 填白圆', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
              SizedBox(
                height: 34,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF263238),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _canPlay ? () => _onSetVal(2, size, clues) : null,
                  child: const Text('⚫ 填黑圆', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
              SizedBox(
                width: 44,
                height: 34,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _canPlay ? () => _onSetVal(0, size, clues) : null,
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
    required List<int> clues,
    required List<int> board,
    required Set<int> conflictCells,
  }) {
    final idx = r * size + c;
    final isClue = idx < clues.length && clues[idx] != 0;
    final val = idx < board.length ? board[idx] : 0;
    final isConflict = conflictCells.contains(idx);
    final isSelected = _selectedIdx == idx;

    Color bgColor;
    if (isConflict) {
      bgColor = const Color(0xFFFFCDD2);
    } else if (isSelected) {
      bgColor = const Color(0xFFB2DFDB);
    } else if (isClue) {
      bgColor = const Color(0xFFCFD8DC);
    } else {
      bgColor = const Color(0xFFF8FAFC);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, size, clues),
      onSecondaryTap: () {
        setState(() => _selectedIdx = idx);
        if (_canPlay && !isClue) {
          g.act({'type': 'set', 'r': r, 'c': c, 'val': val == 2 ? 0 : 2});
        }
      },
      child: Container(
        width: cellPx,
        height: cellPx,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: isSelected ? const Color(0xFF00796B) : const Color(0xFF94A3B8),
            width: isSelected ? 2.0 : 0.9,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (val == 1 || val == 2)
              Container(
                width: cellPx * 0.72,
                height: cellPx * 0.72,
                decoration: BoxDecoration(
                  color: val == 1 ? Colors.white : const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isConflict
                        ? const Color(0xFFD32F2F)
                        : (val == 1 ? const Color(0xFF1E293B) : Colors.white70),
                    width: isClue ? 2.8 : 2.0,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1.5)),
                  ],
                ),
                alignment: Alignment.center,
                child: isClue
                    ? Container(
                        width: cellPx * 0.16,
                        height: cellPx * 0.16,
                        decoration: BoxDecoration(
                          color: val == 1 ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
