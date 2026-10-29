import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

class MachiKoroBoard extends StatefulWidget {
  final GameContext g;
  const MachiKoroBoard(this.g, {super.key});

  @override
  State<MachiKoroBoard> createState() => _MachiKoroBoardState();
}

class _MachiKoroBoardState extends State<MachiKoroBoard> {
  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  static Color _cardColor(String c) {
    switch (c) {
      case 'blue':
        return const Color(0xFF1E88E5);
      case 'green':
        return const Color(0xFF43A047);
      case 'red':
        return const Color(0xFFE53935);
      case 'purple':
        return const Color(0xFF8E24AA);
      default:
        return const Color(0xFF546E7A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = '${v['phase'] ?? 'roll'}';
    final targetLandmarks = (v['targetLandmarks'] as num?)?.toInt() ?? 4;
    final dice = ((v['dice'] as List?) ?? const [1]).map((e) => (e as num).toInt()).toList();
    final diceSum = (v['diceSum'] as num?)?.toInt() ?? 1;
    final lastAction = '${v['lastAction'] ?? ''}';

    final supply = (v['supply'] as Map?)?.cast<String, dynamic>() ?? const {};
    final catalog = (v['catalog'] as List?) ?? const [];
    final landmarks = (v['landmarks'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    final isMyTurn = !g.over && g.seat >= 0 && g.seat == turn;

    int myCoins = 0;
    Set<String> myLandmarks = {};
    Map<String, dynamic> myCards = const {};
    if (g.seat >= 0 && g.seat < pList.length) {
      final mp = pList[g.seat] as Map;
      myCoins = (mp['coins'] as num?)?.toInt() ?? 0;
      myLandmarks = ((mp['landmarks'] as List?) ?? const []).map((e) => '$e').toSet();
      myCards = (mp['cards'] as Map?)?.cast<String, dynamic>() ?? const {};
    }

    String statusText;
    if (g.over) {
      statusText = '游戏结束';
    } else if (phase == 'roll') {
      statusText = isMyTurn ? '第 $round 轮：请投掷骰子' : '第 $round 轮：等待 ${g.name(turn)} 投掷骰子';
    } else if (phase == 'reroll') {
      statusText = isMyTurn ? '第 $round 轮：广播塔 — 选择保留点数或重掷' : '第 $round 轮：${g.name(turn)} 决定是否重掷';
    } else {
      statusText = isMyTurn ? '第 $round 轮：建设阶段（可买 1 张设施或建 1 座地标）' : '第 $round 轮：${g.name(turn)} 建设中';
    }

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar: Status + Dice + Action buttons
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBar(statusText, highlight: isMyTurn),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final d in dice) DieFace(d, size: 30),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '点数 $diceSum · 目标 $targetLandmarks 地标',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (lastAction.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    lastAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
                  ),
                ),
              const SizedBox(height: 6),

              if (isMyTurn)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildTurnActionBar(
                    cs,
                    phase: phase,
                    hasStation: myLandmarks.contains('station'),
                  ),
                ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Players panels
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in g.seatsFromMe())
                            if (s < pList.length)
                              _buildPlayerPanel(
                                cs,
                                pList[s] as Map,
                                catalog: catalog,
                                landmarks: landmarks,
                                active: !g.over && s == turn,
                                canBuildLandmark: isMyTurn && phase == 'build' && s == g.seat,
                                myCoins: myCoins,
                              ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Market Supply
                      Text(
                        '城市设施市场（建设阶段点击购买）',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final cObj in catalog)
                            _buildMarketTile(
                              cs,
                              cObj as Map,
                              supply: supply,
                              canBuy: isMyTurn && phase == 'build',
                              myCoins: myCoins,
                              myCards: myCards,
                              diceSum: diceSum,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (g.over && v['result'] != null)
            Align(
              alignment: Alignment.center,
              child: _buildResultBanner(v['result'] as Map),
            ),
        ],
      ),
    );
  }

  Widget _buildTurnActionBar(
    ColorScheme cs, {
    required String phase,
    required bool hasStation,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (phase == 'roll') ...[
            FilledButton.icon(
              onPressed: () => g.act({'type': 'roll', 'dice': 1}),
              icon: const Icon(Icons.casino, size: 16),
              label: const Text('掷 1 颗骰子'),
            ),
            if (hasStation)
              FilledButton.tonalIcon(
                onPressed: () => g.act({'type': 'roll', 'dice': 2}),
                icon: const Icon(Icons.casino_outlined, size: 16),
                label: const Text('掷 2 颗骰子'),
              ),
          ],
          if (phase == 'reroll') ...[
            FilledButton.icon(
              onPressed: () => g.act({'type': 'keep'}),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('保留当前点数'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => g.act({'type': 'reroll', 'dice': 1}),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重掷 1 颗'),
            ),
            if (hasStation)
              FilledButton.tonalIcon(
                onPressed: () => g.act({'type': 'reroll', 'dice': 2}),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重掷 2 颗'),
              ),
          ],
          if (phase == 'build') ...[
            const Text('点击下方【地标】或【市场设施】建造，或：', style: TextStyle(fontSize: 12)),
            FilledButton.tonalIcon(
              onPressed: () => g.act({'type': 'pass'}),
              icon: const Icon(Icons.skip_next, size: 16),
              label: const Text('跳过建设'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerPanel(
    ColorScheme cs,
    Map p, {
    required List catalog,
    required List landmarks,
    required bool active,
    required bool canBuildLandmark,
    required int myCoins,
  }) {
    final s = (p['seat'] as num).toInt();
    final coins = (p['coins'] as num?)?.toInt() ?? 0;
    final builtSet = ((p['landmarks'] as List?) ?? const []).map((e) => '$e').toSet();
    final cardsMap = (p['cards'] as Map?)?.cast<String, dynamic>() ?? const {};
    final targetLandmarks = (v['targetLandmarks'] as num?)?.toInt() ?? 4;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? cs.primary : cs.outline.withValues(alpha: 0.35),
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          g.tag(
            s,
            active: active,
            size: 30,
            sub: '💰 $coins 金币 · 🏛️ 地标 ${builtSet.length}/$targetLandmarks',
          ),
          const SizedBox(height: 6),
          // Landmarks row
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final lmObj in landmarks)
                Builder(builder: (context) {
                  final lm = lmObj as Map;
                  final id = '${lm['id']}';
                  final name = '${lm['name']}';
                  final cost = (lm['cost'] as num).toInt();
                  final isBuilt = builtSet.contains(id);
                  final buildable = canBuildLandmark && !isBuilt && myCoins >= cost;
                  final badge = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isBuilt
                          ? Colors.amber.withValues(alpha: 0.3)
                          : (buildable ? cs.primaryContainer : cs.surface),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isBuilt
                            ? Colors.amber.shade700
                            : (buildable ? cs.primary : cs.outline.withValues(alpha: 0.35)),
                        width: isBuilt || buildable ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      isBuilt ? '✓$name' : '$name($cost)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isBuilt || buildable ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                  if (!buildable) return badge;
                  return InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => g.act({'type': 'buy_landmark', 'id': id}),
                    child: badge,
                  );
                }),
            ],
          ),
          const SizedBox(height: 6),
          // Owned establishments
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final cObj in catalog)
                Builder(builder: (context) {
                  final c = cObj as Map;
                  final id = '${c['id']}';
                  final cnt = (cardsMap[id] as num?)?.toInt() ?? 0;
                  if (cnt <= 0) return const SizedBox();
                  final color = _cardColor('${c['color']}');
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: color, width: 1),
                    ),
                    child: Text(
                      '[${c['rollLabel']}]${c['name']}×$cnt',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketTile(
    ColorScheme cs,
    Map c, {
    required Map<String, dynamic> supply,
    required bool canBuy,
    required int myCoins,
    required Map<String, dynamic> myCards,
    required int diceSum,
  }) {
    final id = '${c['id']}';
    final name = '${c['name']}';
    final colorStr = '${c['color']}';
    final rollLabel = '${c['rollLabel']}';
    final cost = (c['cost'] as num).toInt();
    final desc = '${c['desc']}';
    final rem = (supply[id] as num?)?.toInt() ?? 0;
    final owned = (myCards[id] as num?)?.toInt() ?? 0;
    final rolls = ((c['rolls'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final matchedRoll = rolls.contains(diceSum);

    final affordable = canBuy &&
        rem > 0 &&
        myCoins >= cost &&
        !(colorStr == 'purple' && owned >= 1);
    final color = _cardColor(colorStr);

    final tile = Container(
      width: 155,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: rem > 0 ? 0.92 : 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: affordable ? color : (matchedRoll ? Colors.amber : color.withValues(alpha: 0.45)),
          width: affordable || matchedRoll ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '[$rollLabel]',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '💰$cost · 余$rem',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9.5, color: cs.onSurface.withValues(alpha: 0.78)),
          ),
        ],
      ),
    );

    if (!affordable) return tile;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => g.act({'type': 'buy_card', 'id': id}),
      child: tile,
    );
  }

  Widget _buildResultBanner(Map res) {
    final winSeat = (res['winner'] as num?)?.toInt() ?? 0;
    final built = ((res['landmarksBuilt'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final coins = ((res['coins'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    return ResultBanner(
      '🏆 ${g.name(winSeat)} 率先建成地标获胜！',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var s = 0; s < g.players && s < built.length; s++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${g.name(s)}：已建地标 ${built[s]} 座（剩余 ${coins[s]} 金币）',
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
