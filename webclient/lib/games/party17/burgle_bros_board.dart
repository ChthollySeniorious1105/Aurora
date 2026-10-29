import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _bbRoomNames = [
  '🚪大厅',
  '🔐金库',
  '🪜逃生梯',
  '🚨红外线',
  '📷监控室',
  '💻电脑室',
  '🤫暗室',
  '🧪实验室',
];

class BurgleBrosBoard extends StatefulWidget {
  final GameContext g;
  const BurgleBrosBoard(this.g, {super.key});

  @override
  State<BurgleBrosBoard> createState() => _BurgleBrosBoardState();
}

class _BurgleBrosBoardState extends State<BurgleBrosBoard> {
  bool _isConnected(List vWalls, List hWalls, int r1, int c1, int r2, int c2) {
    if ((r1 - r2).abs() + (c1 - c2).abs() != 1) return false;
    if (r1 == r2) {
      final minC = c1 < c2 ? c1 : c2;
      if (r1 < vWalls.length && minC < (vWalls[r1] as List).length) {
        return (vWalls[r1] as List)[minC] != true;
      }
      return true;
    } else {
      final minR = r1 < r2 ? r1 : r2;
      if (minR < hWalls.length && c1 < (hWalls[minR] as List).length) {
        return (hWalls[minR] as List)[c1] != true;
      }
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 11;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final apLeft = (v['apLeft'] as num?)?.toInt() ?? 4;
    final rooms = (v['rooms'] as List?) ?? const [];
    final roomNums = (v['roomNums'] as List?) ?? const [];
    final revealed = (v['revealed'] as List?) ?? const [];
    final vWalls = (v['vWalls'] as List?) ?? const [];
    final hWalls = (v['hWalls'] as List?) ?? const [];
    final playerPos = (v['playerPos'] as List?) ?? const [];
    final stealth = (v['stealth'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 3);
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final escaped = (v['escaped'] as List?)?.map((e) => e == true).toList() ??
        List<bool>.filled(g.players, false);
    final guardPos = (v['guardPos'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 3];
    final guardTarget = (v['guardTarget'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final guardSpeed = (v['guardSpeed'] as num?)?.toInt() ?? 2;
    final hackTokens = (v['hackTokens'] as num?)?.toInt() ?? 0;
    final safeDice = (v['safeDice'] as num?)?.toInt() ?? 1;
    final safeCracked = v['safeCracked'] == true;
    final safeDigits = (v['safeDigits'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final crackedDigits = (v['crackedDigits'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final lastRoll = (v['lastRoll'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canAct = v['canAct'] == true && !g.over;

    int myR = 3;
    int myC = 0;
    if (g.seat >= 0 && g.seat < playerPos.length) {
      final p = playerPos[g.seat] as List;
      if (p.length >= 2) {
        myR = (p[0] as num).toInt();
        myC = (p[1] as num).toInt();
      }
    }
    int myRoomType = 0;
    if (myR < rooms.length && myC < (rooms[myR] as List).length) {
      myRoomType = ((rooms[myR] as List)[myC] as num).toInt();
    }

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      g.over
                          ? '神偷小队 — 行动结束'
                          : '第 $round/$maxRounds 轮 · ${canAct ? "轮到你行动 (剩余 $apLeft AP)" : "等待 ${g.name(turn)} ($apLeft AP)"}',
                      highlight: canAct,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.88)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Status & Action Bar
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '👮保安: (${guardPos[0]},${guardPos[1]}) → 🎯(${guardTarget[0]},${guardTarget[1]}) 移速$guardSpeed · 💻骇客:$hackTokens · 🔐金库:${safeCracked ? "已破译！" : "密码 $crackedDigits/$safeDigits (🎲×$safeDice)"}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        if (lastRoll.isNotEmpty)
                          Text('上次掷骰: $lastRoll', style: const TextStyle(fontSize: 12)),
                        if (canAct)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (myRoomType == 5 && apLeft >= 1 && hackTokens < 3)
                                FilledButton.tonal(
                                  onPressed: () => g.act({'type': 'hack'}),
                                  child: const Text('💻 骇入电脑 (1 AP)'),
                                ),
                              if (myRoomType == 1 && !safeCracked && apLeft >= 1 && safeDice < 6)
                                FilledButton.tonal(
                                  onPressed: () => g.act({'type': 'add_die'}),
                                  child: Text('🎲 加装破译骰 (${apLeft >= 2 ? 2 : 1} AP)'),
                                ),
                              if (myRoomType == 1 && !safeCracked && apLeft >= 1)
                                FilledButton(
                                  onPressed: () => g.act({'type': 'crack'}),
                                  child: Text('🔐 掷骰破译 ($safeDice颗 · 1 AP)'),
                                ),
                              OutlinedButton(
                                onPressed: () => g.act({'type': 'end_turn'}),
                                child: const Text('⏭️ 结束回合 (保安巡逻)'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 4x4 Bank Grid
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var r = 0; r < 4; r++)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var c = 0; c < 4; c++)
                                  _buildBankCell(
                                    g: g,
                                    cs: cs,
                                    r: r,
                                    c: c,
                                    rooms: rooms,
                                    roomNums: roomNums,
                                    revealed: revealed,
                                    vWalls: vWalls,
                                    hWalls: hWalls,
                                    playerPos: playerPos,
                                    escaped: escaped,
                                    guardPos: guardPos,
                                    guardTarget: guardTarget,
                                    canAct: canAct && apLeft >= 1,
                                    myR: myR,
                                    myC: myC,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Player Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        g.tag(
                          s,
                          active: turn == s && !g.over,
                          sub: '❤️潜行:${s < stealth.length ? stealth[s] : 3} · ⭐${s < scores.length ? scores[s] : 0}分${s < escaped.length && escaped[s] ? " · 🚁已撤离" : ""}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '游戏结束'),
            ),
        ],
      ),
    );
  }

  Widget _buildBankCell({
    required GameContext g,
    required ColorScheme cs,
    required int r,
    required int c,
    required List rooms,
    required List roomNums,
    required List revealed,
    required List vWalls,
    required List hWalls,
    required List playerPos,
    required List<bool> escaped,
    required List<int> guardPos,
    required List<int> guardTarget,
    required bool canAct,
    required int myR,
    required int myC,
  }) {
    final isRev = r < revealed.length &&
        c < (revealed[r] as List).length &&
        (revealed[r] as List)[c] == true;
    final rType = (r < rooms.length && c < (rooms[r] as List).length)
        ? ((rooms[r] as List)[c] as num).toInt()
        : -1;
    final rNum = (r < roomNums.length && c < (roomNums[r] as List).length)
        ? ((roomNums[r] as List)[c] as num).toInt()
        : 0;

    final hasRightWall = c < 3 &&
        r < vWalls.length &&
        c < (vWalls[r] as List).length &&
        (vWalls[r] as List)[c] == true;
    final hasBottomWall = r < 3 &&
        r < hWalls.length &&
        c < (hWalls[r] as List).length &&
        (hWalls[r] as List)[c] == true;

    final connectedToMe = canAct && _isConnected(vWalls, hWalls, myR, myC, r, c);
    final isGuardHere = guardPos[0] == r && guardPos[1] == c;
    final isTargetHere = guardTarget[0] == r && guardTarget[1] == c;

    final seatsHere = <int>[];
    for (var s = 0; s < playerPos.length; s++) {
      if (s < escaped.length && escaped[s]) continue;
      final p = playerPos[s] as List;
      if (p.length >= 2 && (p[0] as num).toInt() == r && (p[1] as num).toInt() == c) {
        seatsHere.add(s);
      }
    }

    return Container(
      width: 78,
      height: 74,
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isRev
            ? cs.secondaryContainer.withValues(alpha: 0.72)
            : cs.surfaceContainerHighest.withValues(alpha: 0.65),
        border: Border(
          top: BorderSide(color: connectedToMe ? cs.primary : cs.outline.withValues(alpha: 0.3)),
          left: BorderSide(color: connectedToMe ? cs.primary : cs.outline.withValues(alpha: 0.3)),
          right: BorderSide(
            color: hasRightWall ? Colors.amber.shade700 : (connectedToMe ? cs.primary : cs.outline.withValues(alpha: 0.3)),
            width: hasRightWall ? 4.0 : 1.0,
          ),
          bottom: BorderSide(
            color: hasBottomWall ? Colors.amber.shade700 : (connectedToMe ? cs.primary : cs.outline.withValues(alpha: 0.3)),
            width: hasBottomWall ? 4.0 : 1.0,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isRev && rType >= 0 && rType < _bbRoomNames.length
                  ? '${_bbRoomNames[rType]} #$rNum'
                  : '❓未知 ($r,$c)',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isGuardHere) const Text('👮', style: TextStyle(fontSize: 13)),
                if (isTargetHere) const Text('🎯', style: TextStyle(fontSize: 11)),
                for (final s in seatsHere)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Text(
                      'P${s + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: s == g.seat ? cs.primary : cs.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (connectedToMe)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isRev)
                    InkWell(
                      onTap: () => g.act({'type': 'peek', 'r': r, 'c': c}),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.tertiaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('👁️侦察', style: TextStyle(fontSize: 9, color: cs.onTertiaryContainer)),
                      ),
                    ),
                  if (!isRev) const SizedBox(width: 3),
                  InkWell(
                    onTap: () => g.act({'type': 'move', 'r': r, 'c': c}),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('🏃移动', style: TextStyle(fontSize: 9, color: cs.onPrimary)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
