import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a16_common.dart';

class MagnetsBoard extends StatefulWidget {
  final GameContext g;
  const MagnetsBoard(this.g, {super.key});
  @override
  State<MagnetsBoard> createState() => _MagnetsBoardState();
}

class _MagnetsBoardState extends State<MagnetsBoard> {
  GameContext get g => widget.g;
  int _selectedIdx = 0;

  static const List<Color> _slotColors = [
    Color(0xFFF8FAFC),
    Color(0xFFF1F5F9),
    Color(0xFFFEFCE8),
    Color(0xFFF0FDF4),
    Color(0xFFEFF6FF),
    Color(0xFFFAF5FF),
  ];

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  int _slotAt(List<int> slotMap, int size, int r, int c) {
    if (r < 0 || r >= size || c < 0 || c >= size) return -99;
    final idx = r * size + c;
    return idx < slotMap.length ? slotMap[idx] : -99;
  }

  void _onCellTap(int r, int c, int size, int sid) {
    final idx = r * size + c;
    setState(() => _selectedIdx = idx);
    if (!_canPlay || sid < 0) return;
    g.act({'type': 'cycle', 'r': r, 'c': c});
  }

  void _onSetVal(int val, int size, List<int> slotMap) {
    if (!_canPlay) return;
    final idx = _selectedIdx.clamp(0, size * size - 1);
    if (idx < slotMap.length && slotMap[idx] < 0) return;
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
    final slotCount = math.max(1, aInt(v['slotCount'], (size * size) ~/ 2));
    final slotMap = aInts(v['slotMap']);
    final rowPlus = aInts(v['rowPlus']);
    final rowMinus = aInts(v['rowMinus']);
    final colPlus = aInts(v['colPlus']);
    final colMinus = aInts(v['colMinus']);
    final board = aInts(v['board']);
    final samePoleConflictCells = aInts(v['samePoleConflictCells']).toSet();
    final rowPlusCounts = aInts(v['rowPlusCounts']);
    final rowMinusCounts = aInts(v['rowMinusCounts']);
    final colPlusCounts = aInts(v['colPlusCounts']);
    final colMinusCounts = aInts(v['colMinusCounts']);
    final satisfiedRows = aInts(v['satisfiedRows']).toSet();
    final violatedRows = aInts(v['violatedRows']).toSet();
    final satisfiedCols = aInts(v['satisfiedCols']).toSet();
    final violatedCols = aInts(v['violatedCols']).toSet();
    final activeMagnetCount = aInt(v['activeMagnetCount'], 0);
    final ps = aMaps(v['ps']);

    if (_selectedIdx >= size * size) {
      _selectedIdx = 0;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';
    final satLines = satisfiedRows.length + satisfiedCols.length;

    String status;
    if (phase == 'over') {
      status = '磁铁正负极竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出磁铁正负极（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (samePoleConflictCells.isNotEmpty) '同极相邻冲突',
        if (violatedRows.isNotEmpty || violatedCols.isNotEmpty) '行列正负极超额',
      ];
      final warnStr = warnings.isEmpty ? '点击骨牌槽位循环切换 [+, -] / [-, +] / 中性' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 行列达标 $satLines/${size * 2} · 磁铁 $activeMagnetCount/$slotCount · $warnStr · ${left}s';
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
        slotCount: slotCount,
        slotMap: slotMap,
        rowPlus: rowPlus,
        rowMinus: rowMinus,
        colPlus: colPlus,
        colMinus: colMinus,
        board: board,
        samePoleConflictCells: samePoleConflictCells,
        rowPlusCounts: rowPlusCounts,
        rowMinusCounts: rowMinusCounts,
        colPlusCounts: colPlusCounts,
        colMinusCounts: colMinusCounts,
        satisfiedRows: satisfiedRows,
        violatedRows: violatedRows,
        satisfiedCols: satisfiedCols,
        violatedCols: violatedCols,
        activeMagnetCount: activeMagnetCount,
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
    final sat = aInt(p['satisfiedLines'], 0);
    final tot = math.max(1, aInt(p['totalLines'], 10));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot线', null),
    };
    return A16ProgressTile(
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
    required int slotCount,
    required List<int> slotMap,
    required List<int> rowPlus,
    required List<int> rowMinus,
    required List<int> colPlus,
    required List<int> colMinus,
    required List<int> board,
    required Set<int> samePoleConflictCells,
    required List<int> rowPlusCounts,
    required List<int> rowMinusCounts,
    required List<int> colPlusCounts,
    required List<int> colMinusCounts,
    required Set<int> satisfiedRows,
    required Set<int> violatedRows,
    required Set<int> satisfiedCols,
    required Set<int> violatedCols,
    required int activeMagnetCount,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 46.0 : 40.0;
    const headerPx = 38.0;

    final boardCard = Container(
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
          // Top column clues row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: headerPx,
                height: headerPx,
                child: Center(
                  child: Text('+/−', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w900)),
                ),
              ),
              for (var c = 0; c < size; c++)
                _buildDualClueHeader(
                  width: cellPx,
                  height: headerPx,
                  curPlus: c < colPlusCounts.length ? colPlusCounts[c] : 0,
                  targetPlus: c < colPlus.length ? colPlus[c] : 0,
                  curMinus: c < colMinusCounts.length ? colMinusCounts[c] : 0,
                  targetMinus: c < colMinus.length ? colMinus[c] : 0,
                  isSat: satisfiedCols.contains(c),
                  isViol: violatedCols.contains(c),
                ),
            ],
          ),
          // Left row clues + grid
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = 0; r < size; r++)
                    _buildDualClueHeader(
                      width: headerPx,
                      height: cellPx,
                      curPlus: r < rowPlusCounts.length ? rowPlusCounts[r] : 0,
                      targetPlus: r < rowPlus.length ? rowPlus[r] : 0,
                      curMinus: r < rowMinusCounts.length ? rowMinusCounts[r] : 0,
                      targetMinus: r < rowMinus.length ? rowMinus[r] : 0,
                      isSat: satisfiedRows.contains(r),
                      isViol: violatedRows.contains(r),
                    ),
                ],
              ),
              Column(
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
                            slotMap: slotMap,
                            board: board,
                            samePoleConflictCells: samePoleConflictCells,
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final noConflict = samePoleConflictCells.isEmpty && violatedRows.isEmpty && violatedCols.isEmpty;

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
              A16Chip(
                '行列达标 ${satisfiedRows.length + satisfiedCols.length}/${size * 2}',
                const Color(0xFF00897B),
                size: 11,
              ),
              A16Chip('磁铁 $activeMagnetCount/$slotCount', cs.primary, size: 11),
              A16Chip(
                noConflict
                    ? '✓ 无同极互斥冲突'
                    : (samePoleConflictCells.isNotEmpty ? '⚠ 同极正交冲突' : '⚠ 行列计数超标'),
                noConflict ? Colors.green : Colors.redAccent,
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
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _canPlay ? () => _onSetVal(1, size, slotMap) : null,
                  child: const Text('+ 设正极', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
              SizedBox(
                height: 34,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _canPlay ? () => _onSetVal(2, size, slotMap) : null,
                  child: const Text('− 设负极', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
              SizedBox(
                width: 44,
                height: 34,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _canPlay ? () => _onSetVal(0, size, slotMap) : null,
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
                boardCard,
                const SizedBox(width: 12),
                toolbar,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                boardCard,
                const SizedBox(height: 8),
                toolbar,
              ]),
      ),
    );
  }

  Widget _buildDualClueHeader({
    required double width,
    required double height,
    required int curPlus,
    required int targetPlus,
    required int curMinus,
    required int targetMinus,
    required bool isSat,
    required bool isViol,
  }) {
    final bg = isViol
        ? const Color(0x44D32F2F)
        : (isSat ? const Color(0x442E7D32) : const Color(0xFF1E293B));
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: const Color(0x3394A3B8), width: 0.5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+$targetPlus  −$targetMinus',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isViol ? const Color(0xFFFF8A80) : (isSat ? const Color(0xFF81C784) : Colors.white),
                height: 1.05,
              ),
            ),
            Text(
              '+$curPlus / −$curMinus',
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell({
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required List<int> slotMap,
    required List<int> board,
    required Set<int> samePoleConflictCells,
  }) {
    final idx = r * size + c;
    final sid = _slotAt(slotMap, size, r, c);
    final isBlocked = sid < 0;
    final val = idx < board.length ? board[idx] : 0;
    final isConflict = samePoleConflictCells.contains(idx);
    final isSelected = _selectedIdx == idx;

    const wallBorder = BorderSide(color: Color(0xFF0F172A), width: 2.8);
    const pairBorder = BorderSide(color: Color(0x5594A3B8), width: 0.8);

    Color bgColor;
    if (isBlocked) {
      bgColor = const Color(0xFF334155);
    } else if (val == 1) {
      bgColor = isConflict ? const Color(0xFF880E4F) : const Color(0xFFD32F2F);
    } else if (val == 2) {
      bgColor = isConflict ? const Color(0xFF4A148C) : const Color(0xFF1976D2);
    } else if (isSelected) {
      bgColor = const Color(0xFFE0F7FA);
    } else {
      bgColor = _slotColors[sid % _slotColors.length];
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, size, sid),
      onSecondaryTap: () {
        setState(() => _selectedIdx = idx);
        if (_canPlay && !isBlocked) {
          g.act({'type': 'set', 'r': r, 'c': c, 'val': 0});
        }
      },
      child: Container(
        width: cellPx,
        height: cellPx,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: _slotAt(slotMap, size, r - 1, c) != sid ? wallBorder : pairBorder,
            bottom: _slotAt(slotMap, size, r + 1, c) != sid ? wallBorder : pairBorder,
            left: _slotAt(slotMap, size, r, c - 1) != sid ? wallBorder : pairBorder,
            right: _slotAt(slotMap, size, r, c + 1) != sid ? wallBorder : pairBorder,
          ),
        ),
        child: Center(
          child: isBlocked
              ? Icon(Icons.close, size: cellPx * 0.42, color: Colors.white54)
              : (val == 1
                  ? Text(
                      '+',
                      style: TextStyle(
                        fontSize: cellPx * 0.48,
                        fontWeight: FontWeight.w900,
                        color: isConflict ? const Color(0xFFFFEB3B) : Colors.white,
                        height: 1.0,
                      ),
                    )
                  : (val == 2
                      ? Text(
                          '−',
                          style: TextStyle(
                            fontSize: cellPx * 0.48,
                            fontWeight: FontWeight.w900,
                            color: isConflict ? const Color(0xFFFFEB3B) : Colors.white,
                            height: 1.0,
                          ),
                        )
                      : Text(
                          '·',
                          style: TextStyle(
                            fontSize: cellPx * 0.36,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF94A3B8),
                          ),
                        ))),
        ),
      ),
    );
  }
}
