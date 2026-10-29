import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a17_common.dart';

class Match3BattleBoard extends StatefulWidget {
  final GameContext g;
  const Match3BattleBoard(this.g, {super.key});
  @override
  State<Match3BattleBoard> createState() => _Match3BattleBoardState();
}

class _Match3BattleBoardState extends State<Match3BattleBoard> {
  GameContext get g => widget.g;
  int? _selectedIdx;

  static const List<Color> _gemColors = [
    Color(0xFF37474F), // 0 placeholder
    Color(0xFFE53935), // 1 Ruby Red
    Color(0xFF1E88E5), // 2 Sapphire Blue
    Color(0xFF43A047), // 3 Emerald Green
    Color(0xFFFFB300), // 4 Topaz Amber
    Color(0xFF8E24AA), // 5 Amethyst Purple
    Color(0xFF00ACC1), // 6 Diamond Cyan
  ];

  static const List<String> _gemIcons = [
    '·',
    '♦',
    '💧',
    '🍀',
    '⭐',
    '🔮',
    '💠',
  ];

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play' && aInt(ps[g.seat]['movesLeft'], 0) > 0;
  }

  void _onGemTap(int r, int c, int size) {
    final idx = r * size + c;
    if (_selectedIdx == null) {
      setState(() => _selectedIdx = idx);
      return;
    }
    if (_selectedIdx == idx) {
      setState(() => _selectedIdx = null);
      return;
    }
    final prev = _selectedIdx!;
    final pr = prev ~/ size, pc = prev % size;
    if ((pr - r).abs() + (pc - c).abs() == 1) {
      setState(() => _selectedIdx = null);
      if (_canPlay) {
        g.act({'type': 'swap', 'r1': pr, 'c1': pc, 'r2': r, 'c2': c});
      }
    } else {
      setState(() => _selectedIdx = idx);
    }
  }

  void _onUseHint(List<int> hintSwap, int size) {
    if (!_canPlay || hintSwap.length < 2) return;
    final i1 = hintSwap[0], i2 = hintSwap[1];
    setState(() => _selectedIdx = null);
    g.act({
      'type': 'swap',
      'r1': i1 ~/ size,
      'c1': i1 % size,
      'r2': i2 ~/ size,
      'c2': i2 % size,
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = aStr(v['phase']);
    final size = math.max(7, aInt(v['size'], 7));
    final colors = math.max(5, aInt(v['colors'], 5));
    final maxMoves = math.max(1, aInt(v['maxMoves'], 15));
    final movesLeft = aInt(v['movesLeft'], 0);
    final board = aInts(v['board']);
    final special = aInts(v['special']);
    final frozen = aInts(v['frozen']);
    final frozenCount = aInt(v['frozenCount'], 0);
    final specialCount = aInt(v['specialCount'], 0);
    final validSwapCount = aInt(v['validSwapCount'], 0);
    final hintSwap = aInts(v['hintSwap']);
    final lastSwap = aInts(v['lastSwap']).toSet();
    final lastCombo = aInt(v['lastCombo'], 0);
    final lastCleared = aInt(v['lastCleared'], 0);
    final lastPoints = aInt(v['lastPoints'], 0);
    final lastIceAttack = aInt(v['lastIceAttack'], 0);
    final ps = aMaps(v['ps']);

    if (_selectedIdx != null && _selectedIdx! >= size * size) {
      _selectedIdx = null;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '宝石消消乐对战 · 对局结束';
    } else if (me == null) {
      status = '7×7 宝石消消乐（$colors色）· 观战中';
    } else if (myStatus == 'done') {
      status = '已完成全部 $maxMoves 步（总分 ${me['score']} 分）· 等待其他玩家完成';
    } else {
      final lastMsg = lastCleared > 0
          ? '上步消除 $lastCleared 颗${lastCombo >= 2 ? " ($lastCombo连击!)" : ""} +$lastPoints分'
          : '点击两颗正交相邻宝石交换消除';
      status = '剩余步数 $movesLeft/$maxMoves · 特效 $specialCount · 冰封 $frozenCount · $lastMsg';
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
            if (s < ps.length) _buildPlayerTile(s, ps[s], maxMoves, wide ? sideW - 12 : 140),
        ],
      );

      final workspace = _buildWorkspace(
        context,
        cs: cs,
        size: size,
        maxMoves: maxMoves,
        movesLeft: movesLeft,
        board: board,
        special: special,
        frozen: frozen,
        frozenCount: frozenCount,
        specialCount: specialCount,
        validSwapCount: validSwapCount,
        hintSwap: hintSwap,
        lastSwap: lastSwap,
        lastCombo: lastCombo,
        lastIceAttack: lastIceAttack,
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
                    (r) => '${r['score']} 分 · 最高 ${r['maxCombo']} 连击 · 消除 ${r['cleared']}',
                  ),
                ),
              ),
          ]),
        ),
      ]);
    });
  }

  Widget _buildPlayerTile(int s, Map<String, dynamic> p, int maxMoves, double width) {
    final st = aStr(p['status']);
    final score = aInt(p['score'], 0);
    final movesLeft = aInt(p['movesLeft'], 0);
    final movesUsed = aInt(p['movesUsed'], 0);
    final maxCombo = aInt(p['maxCombo'], 0);
    final frozenCnt = aInt(p['frozenCount'], 0);
    final (badge, col) = switch (st) {
      'done' => ('完成', Colors.green),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('剩$movesLeft步', frozenCnt > 0 ? Colors.lightBlue : null),
    };
    return A17ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'done' ? 1.0 : (movesUsed / maxMoves),
      badge: badge,
      badgeColor: col,
      dim: st == 'resigned',
      sub: '$score分 · 连击×$maxCombo${frozenCnt > 0 ? " · ❄️$frozenCnt" : ""}',
    );
  }

  Widget _buildWorkspace(
    BuildContext context, {
    required ColorScheme cs,
    required int size,
    required int maxMoves,
    required int movesLeft,
    required List<int> board,
    required List<int> special,
    required List<int> frozen,
    required int frozenCount,
    required int specialCount,
    required int validSwapCount,
    required List<int> hintSwap,
    required Set<int> lastSwap,
    required int lastCombo,
    required int lastIceAttack,
    required bool wide,
  }) {
    const cellPx = 42.0;

    final gridCard = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
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
                  _buildGemCell(
                    r: r,
                    c: c,
                    size: size,
                    cellPx: cellPx,
                    board: board,
                    special: special,
                    frozen: frozen,
                    lastSwap: lastSwap,
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
              A17Chip('剩余 $movesLeft/$maxMoves 步', cs.primary, size: 11),
              A17Chip('⚡🌈 特效 $specialCount', const Color(0xFF8E24AA), size: 11),
              A17Chip(
                frozenCount > 0 ? '❄️ 冰封 $frozenCount' : '✓ 无冰封阻碍',
                frozenCount > 0 ? const Color(0xFF0288D1) : Colors.green,
                size: 11,
              ),
              if (lastCombo >= 2) A17Chip('🔥 Combo ×$lastCombo', Colors.deepOrange, size: 11),
              if (lastIceAttack > 0) A17Chip('发射 ❄️×$lastIceAttack', Colors.indigo, size: 11),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '4 连合成 ⚡激光炸弹（清行+列） · 5 连合成 🌈彩虹棱镜（清同色） · 连击发射 ❄️冰封',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: _canPlay && hintSwap.length >= 2 ? () => _onUseHint(hintSwap, size) : null,
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: Text('推荐消除 ($validSwapCount)', style: const TextStyle(fontSize: 12)),
              ),
              OutlinedButton.icon(
                onPressed: _selectedIdx != null ? () => setState(() => _selectedIdx = null) : null,
                icon: const Icon(Icons.deselect, size: 15),
                label: const Text('取消选中', style: TextStyle(fontSize: 12)),
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

  Widget _buildGemCell({
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required List<int> board,
    required List<int> special,
    required List<int> frozen,
    required Set<int> lastSwap,
  }) {
    final idx = r * size + c;
    final gem = (idx < board.length ? board[idx] : 1).clamp(1, _gemColors.length - 1);
    final spec = idx < special.length ? special[idx] : 0;
    final isFrozen = idx < frozen.length && frozen[idx] > 0;
    final isSelected = _selectedIdx == idx;
    final isLastSwap = lastSwap.contains(idx);
    final isAdjacentToSelected = _selectedIdx != null &&
        ((_selectedIdx! ~/ size - r).abs() + (_selectedIdx! % size - c).abs() == 1);

    final baseColor = _gemColors[gem];
    final icon = _gemIcons[gem];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onGemTap(r, c, size),
      child: Container(
        width: cellPx,
        height: cellPx,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFF59D)
              : (isAdjacentToSelected ? const Color(0xFF1E293B) : const Color(0xFF1F2937)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.amberAccent
                : (isFrozen
                    ? const Color(0xFF4FC3F7)
                    : (isLastSwap ? Colors.white70 : Colors.white12)),
            width: isSelected || isFrozen ? 2.2 : 1.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: cellPx * 0.76,
              height: cellPx * 0.76,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color.lerp(baseColor, Colors.white, 0.35)!,
                    baseColor,
                    Color.lerp(baseColor, Colors.black, 0.25)!,
                  ],
                ),
                shape: spec == 2 ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: spec == 2 ? null : BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.45),
                    blurRadius: 4,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  spec == 2 ? '🌈' : (spec == 1 ? '⚡' : icon),
                  style: TextStyle(
                    fontSize: cellPx * 0.38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamilyFallback: kFontFallback,
                  ),
                ),
              ),
            ),
            if (isFrozen)
              Positioned(
                right: 1,
                top: 1,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: const Color(0xDD0277BD),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '❄️',
                    style: TextStyle(fontSize: 9, height: 1.0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
