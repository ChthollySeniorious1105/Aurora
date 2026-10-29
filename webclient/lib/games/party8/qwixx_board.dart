import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class QwixxBoard extends StatefulWidget {
  final GameContext g;
  const QwixxBoard(this.g, {super.key});

  @override
  State<QwixxBoard> createState() => _QwixxBoardState();
}

class _QwixxBoardState extends State<QwixxBoard> {
  int? _inspectSeat;

  static const List<Color> _rowColors = [
    Color(0xFFD32F2F), // Red
    Color(0xFFFBC02D), // Yellow
    Color(0xFF388E3C), // Green
    Color(0xFF1976D2), // Blue
  ];

  static const List<String> _rowNames = ['红', '黄', '绿', '蓝'];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final step = '${v['step'] ?? 'white'}';
    final w1 = (v['w1'] as num?)?.toInt() ?? 1;
    final w2 = (v['w2'] as num?)?.toInt() ?? 1;
    final whiteSum = (v['whiteSum'] as num?)?.toInt() ?? (w1 + w2);
    final colorDice =
        (v['colorDice'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            const [1, 1, 1, 1];
    final locked =
        (v['locked'] as List?)?.map((e) => e == true).toList() ??
            const [false, false, false, false];
    final lockedCount = (v['lockedCount'] as num?)?.toInt() ?? 0;
    final lockTarget = (v['lockTarget'] as num?)?.toInt() ?? 2;
    final sheetsRaw = (v['sheets'] as List?) ?? const [];
    final lockBonusRaw = (v['lockBonus'] as List?) ?? const [];
    final penalties =
        (v['penalties'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final rowScoresRaw = (v['rowScores'] as List?) ?? const [];
    final whiteDone =
        (v['whiteDone'] as List?)?.map((e) => e == true).toList() ??
            List.filled(g.players, false);
    final turnCrossedInWhite = v['turnCrossedInWhite'] == true;
    final legalWhiteRows =
        (v['legalWhiteRows'] as List?)?.map((e) => (e as num).toInt()).toSet() ??
            const <int>{};
    final legalColorMoves = (v['legalColorMoves'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        const <Map<String, dynamic>>[];

    final mySeat = g.seat;
    final viewSeat = (_inspectSeat != null &&
            _inspectSeat! >= 0 &&
            _inspectSeat! < g.players)
        ? _inspectSeat!
        : (mySeat >= 0 && mySeat < g.players ? mySeat : 0);

    final canActWhite =
        !g.over && step == 'white' && mySeat >= 0 && !whiteDone[mySeat];
    final canActColor = !g.over && step == 'color' && mySeat == turn;
    final myTurn = canActWhite || canActColor;

    final statusText = g.over
        ? '游戏结束！'
        : step == 'white'
            ? '第 $round 轮 · ${g.name(turn)} 掷骰 · 白骰阶段（全员可选白骰和 $whiteSum）'
            : '第 $round 轮 · 彩骰阶段（等待 ${g.name(turn)} 组合白骰+彩骰）';

    return Stack(
      children: [
        Container(
          color: g.table,
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              // Top bar: status + players
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBar(statusText, highlight: myTurn),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '已锁行: $lockedCount/$lockTarget',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in g.seatsFromMe())
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _inspectSeat = s),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: viewSeat == s
                                  ? Border.all(color: Colors.amber, width: 2)
                                  : null,
                            ),
                            child: g.tag(
                              s,
                              active: (step == 'white' && !whiteDone[s]) ||
                                  (step == 'color' && s == turn),
                              sub:
                                  '${scores[s]}分 · 罚${penalties[s]}/4${s == turn ? " [掷骰]" : ""}',
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Main scrollable area: Dice + Actions + Score Sheet
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildDiceAndActions(
                        context,
                        w1: w1,
                        w2: w2,
                        whiteSum: whiteSum,
                        colorDice: colorDice,
                        locked: locked,
                        canActWhite: canActWhite,
                        canActColor: canActColor,
                        legalWhiteRows: legalWhiteRows,
                        legalColorMoves: legalColorMoves,
                        turnCrossedInWhite: turnCrossedInWhite,
                      ),
                      const SizedBox(height: 8),
                      _buildSheet(
                        context,
                        viewSeat: viewSeat,
                        mySeat: mySeat,
                        sheetsRaw: sheetsRaw,
                        lockBonusRaw: lockBonusRaw,
                        rowScoresRaw: rowScoresRaw,
                        locked: locked,
                        penalties: penalties,
                        scores: scores,
                        whiteSum: whiteSum,
                        canActWhite: canActWhite,
                        canActColor: canActColor,
                        legalWhiteRows: legalWhiteRows,
                        legalColorMoves: legalColorMoves,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (g.over)
          Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              child: ResultBanner(
                _winnerText(g, scores),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < g.players; s++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${g.name(s)}: ${scores[s]} 分（罚分 ${penalties[s]} 次）',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _winnerText(GameContext g, List<int> scores) {
    if (scores.isEmpty) return '游戏结束';
    var best = scores.first;
    for (final s in scores) {
      if (s > best) best = s;
    }
    final winners = <String>[
      for (var i = 0; i < g.players; i++)
        if (scores[i] == best) g.name(i),
    ];
    return '${winners.join("、")} 获胜！（$best 分）';
  }

  Widget _buildDiceAndActions(
    BuildContext context, {
    required int w1,
    required int w2,
    required int whiteSum,
    required List<int> colorDice,
    required List<bool> locked,
    required bool canActWhite,
    required bool canActColor,
    required Set<int> legalWhiteRows,
    required List<Map<String, dynamic>> legalColorMoves,
    required bool turnCrossedInWhite,
  }) {
    final cs = Theme.of(context).colorScheme;
    final g = widget.g;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DieFace(w1, size: 36),
              DieFace(w2, size: 36),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '白骰和: $whiteSum',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              for (var r = 0; r < 4; r++)
                _buildColoredDie(r, colorDice[r], locked[r]),
            ],
          ),
          if (canActWhite) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final r in legalWhiteRows)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _rowColors[r],
                      foregroundColor: r == 1 ? Colors.black87 : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => g.act({'type': 'white', 'row': r}),
                    icon: const Icon(Icons.edit, size: 15),
                    label: Text('划${_rowNames[r]}行 $whiteSum'),
                  ),
                OutlinedButton(
                  onPressed: () => g.act({'type': 'white', 'row': -1}),
                  child: const Text('跳过白骰'),
                ),
              ],
            ),
          ],
          if (canActColor) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final m in legalColorMoves)
                  Builder(builder: (context) {
                    final r = (m['row'] as num).toInt();
                    final numVal = (m['num'] as num).toInt();
                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _rowColors[r],
                        foregroundColor: r == 1 ? Colors.black87 : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      onPressed: () =>
                          g.act({'type': 'color', 'row': r, 'num': numVal}),
                      icon: const Icon(Icons.add_task, size: 15),
                      label: Text('划${_rowNames[r]}行 $numVal'),
                    );
                  }),
                OutlinedButton(
                  onPressed: () => g.act({'type': 'color', 'row': -1}),
                  child: Text(
                    turnCrossedInWhite ? '跳过彩骰' : '跳过彩骰 (罚分-5)',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColoredDie(int r, int val, bool isLocked) {
    final bg = _rowColors[r];
    final fg = r == 1 ? Colors.black87 : Colors.white;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isLocked ? bg.withValues(alpha: 0.35) : bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26),
      ),
      child: Center(
        child: isLocked
            ? Icon(Icons.lock, size: 18, color: fg)
            : Text(
                '$val',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
      ),
    );
  }

  Widget _buildSheet(
    BuildContext context, {
    required int viewSeat,
    required int mySeat,
    required List sheetsRaw,
    required List lockBonusRaw,
    required List rowScoresRaw,
    required List<bool> locked,
    required List<int> penalties,
    required List<int> scores,
    required int whiteSum,
    required bool canActWhite,
    required bool canActColor,
    required Set<int> legalWhiteRows,
    required List<Map<String, dynamic>> legalColorMoves,
  }) {
    final cs = Theme.of(context).colorScheme;
    final g = widget.g;
    final isMySheet = viewSeat == mySeat;

    final seatSheet = viewSeat < sheetsRaw.length
        ? (sheetsRaw[viewSeat] as List)
        : const [];
    final seatBonus = viewSeat < lockBonusRaw.length
        ? (lockBonusRaw[viewSeat] as List).map((e) => e == true).toList()
        : const [false, false, false, false];
    final seatRowScores = viewSeat < rowScoresRaw.length
        ? (rowScoresRaw[viewSeat] as List)
            .map((e) => (e as num).toInt())
            .toList()
        : const [0, 0, 0, 0];

    return Container(
      constraints: const BoxConstraints(maxWidth: 760),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${g.name(viewSeat)} 的记分纸${isMySheet ? "（我）" : "（点击上方玩家头像可切换查看）"}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '总分: ${scores[viewSeat]} 分',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < 4; r++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: _buildSheetRow(
                r: r,
                crossed: r < seatSheet.length
                    ? (seatSheet[r] as List)
                        .map((e) => (e as num).toInt())
                        .toList()
                    : const <int>[],
                hasLockBonus: r < seatBonus.length && seatBonus[r],
                rowLocked: r < locked.length && locked[r],
                rowScore: r < seatRowScores.length ? seatRowScores[r] : 0,
                isMySheet: isMySheet,
                whiteSum: whiteSum,
                canActWhite: canActWhite,
                canActColor: canActColor,
                legalWhiteRows: legalWhiteRows,
                legalColorMoves: legalColorMoves,
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '计分表: 1勾=1, 2=3, 3=6, 4=10, 5=15, 6=21, 7=28, 8=36, 9=45, 10=55, 11=66, 12=78',
                style: TextStyle(fontSize: 11),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '罚分(-5/格): ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  for (var i = 0; i < 4; i++)
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i < penalties[viewSeat]
                            ? Colors.redAccent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Center(
                        child: Text(
                          i < penalties[viewSeat] ? '✕' : '',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSheetRow({
    required int r,
    required List<int> crossed,
    required bool hasLockBonus,
    required bool rowLocked,
    required int rowScore,
    required bool isMySheet,
    required int whiteSum,
    required bool canActWhite,
    required bool canActColor,
    required Set<int> legalWhiteRows,
    required List<Map<String, dynamic>> legalColorMoves,
  }) {
    final g = widget.g;
    final asc = r == 0 || r == 1;
    final nums = [
      for (var i = 0; i < 11; i++) asc ? (2 + i) : (12 - i),
    ];
    final crossedSet = crossed.toSet();
    final lastCrossed = crossed.isEmpty ? null : crossed.last;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: _rowColors[r].withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _rowColors[r], width: 1.5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              alignment: Alignment.center,
              child: Text(
                _rowNames[r],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _rowColors[r],
                  fontSize: 14,
                ),
              ),
            ),
            for (final n in nums)
              Builder(builder: (context) {
                final isCrossed = crossedSet.contains(n);
                final isSkipped = !isCrossed &&
                    lastCrossed != null &&
                    (asc ? n < lastCrossed : n > lastCrossed);
                final canTapWhite = isMySheet &&
                    canActWhite &&
                    n == whiteSum &&
                    legalWhiteRows.contains(r);
                final canTapColor = isMySheet &&
                    canActColor &&
                    legalColorMoves
                        .any((m) => m['row'] == r && m['num'] == n);
                final clickable = canTapWhite || canTapColor;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: clickable
                        ? () {
                            if (canTapWhite) {
                              g.act({'type': 'white', 'row': r});
                            } else if (canTapColor) {
                              g.act({'type': 'color', 'row': r, 'num': n});
                            }
                          }
                        : null,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isCrossed
                            ? _rowColors[r]
                            : clickable
                                ? Colors.amber.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: clickable
                              ? Colors.amber.shade800
                              : _rowColors[r].withValues(alpha: 0.6),
                          width: clickable ? 2.5 : 1,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$n',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isCrossed
                                  ? (r == 1 ? Colors.black87 : Colors.white)
                                  : isSkipped
                                      ? Colors.black26
                                      : Colors.black87,
                            ),
                          ),
                          if (isCrossed)
                            Icon(
                              Icons.close,
                              size: 26,
                              color: (r == 1 ? Colors.black : Colors.white)
                                  .withValues(alpha: 0.75),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(width: 4),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: hasLockBonus
                    ? _rowColors[r]
                    : rowLocked
                        ? Colors.black26
                        : Colors.white70,
                shape: BoxShape.circle,
                border: Border.all(color: _rowColors[r]),
              ),
              child: Icon(
                rowLocked ? Icons.lock : Icons.lock_open,
                size: 16,
                color: hasLockBonus
                    ? (r == 1 ? Colors.black87 : Colors.white)
                    : Colors.black54,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: Text(
                '$rowScore分',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
