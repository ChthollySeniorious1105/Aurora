import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro14/dorfromantik.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class DorfromantikBoard extends StatefulWidget {
  final GameContext g;
  const DorfromantikBoard(this.g, {super.key});

  @override
  State<DorfromantikBoard> createState() => _DorfromantikBoardState();
}

class _DorfromantikBoardState extends State<DorfromantikBoard> {
  int _rot = 0;

  Color _terrainColor(int t) {
    return switch (t) {
      0 => const Color(0xFFFBC02D), // Wheat
      1 => const Color(0xFF2E7D32), // Forest
      2 => const Color(0xFFD84315), // Village
      3 => const Color(0xFF546E7A), // Railway
      4 => const Color(0xFF0288D1), // River
      _ => Colors.blueGrey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final deckCount = asInt(v['deckCount'], 0);
    final lastAction = asStr(v['lastAction']);
    final totalScore = asInt(v['totalScore'], 0);
    final fulfilledTaskScore = asInt(v['fulfilledTaskScore'], 0);
    final fulfilledTasksCount = asInt(v['fulfilledTasksCount'], 0);
    final cancelledTasksCount = asInt(v['cancelledTasksCount'], 0);
    final closedFlagScore = asInt(v['closedFlagScore'], 0);
    final longestRiver = asInt(v['longestRiver'], 0);
    final longestRailway = asInt(v['longestRailway'], 0);

    final curTile = (v['currentTile'] as Map?)?.cast<String, dynamic>();
    final validMoves = (v['validMoves'] as List?) ?? const [];
    final tiles = (v['tiles'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    final isMyTurn = !over && g.seat == turn;

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(6),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: StatusBar(
                            over
                                ? '画卷完成 · $lastAction'
                                : (isMyTurn
                                    ? '轮到你！旋转并放置当前田园板块 · $lastAction'
                                    : '等待 ${g.name(turn)} 铺设田园 · $lastAction'),
                            highlight: isMyTurn,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🏞️余 $deckCount 块 · ⭐$totalScore 分',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pList.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, s) {
                        final pd = (pList[s] as Map).cast<String, dynamic>();
                        final sc = asInt(pd['score'], 0);
                        final cb = asInt(pd['contribution'], 0);
                        return g.tag(
                          s,
                          active: s == turn,
                          sub: '⭐$sc分 · 贡献+$cb',
                          size: 28,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildControlPanel(
                                  curTile,
                                  validMoves,
                                  fulfilledTaskScore,
                                  fulfilledTasksCount,
                                  cancelledTasksCount,
                                  closedFlagScore,
                                  longestRiver,
                                  longestRailway,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildHexMapPanel(
                                  tiles,
                                  validMoves,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildControlPanel(
                                  curTile,
                                  validMoves,
                                  fulfilledTaskScore,
                                  fulfilledTasksCount,
                                  cancelledTasksCount,
                                  closedFlagScore,
                                  longestRiver,
                                  longestRailway,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildHexMapPanel(
                                  tiles,
                                  validMoves,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
          if (over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(
                '筑梦颂歌画卷终局 · 总分 $totalScore 分 (任务+$fulfilledTaskScore · 🚩+$closedFlagScore · 🌊+$longestRiver · 🚂+$longestRailway)',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(
    Map<String, dynamic>? curTile,
    List<dynamic> validMoves,
    int fulfilledTaskScore,
    int fulfilledTasksCount,
    int cancelledTasksCount,
    int closedFlagScore,
    int longestRiver,
    int longestRailway,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final tType = curTile != null ? asInt(curTile['type'], 0) : 0;
    final hasFlag = curTile != null && asBool(curTile['hasFlag']);
    final taskType = curTile != null ? asInt(curTile['taskType'], -1) : -1;
    final taskTarget = curTile != null ? asInt(curTile['taskTarget'], 0) : 0;
    final edges = (curTile?['edges'] as List?) ?? const [];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '🧭 当前田园六角板块与旋转',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              if (isMyTurn && validMoves.isNotEmpty)
                InkWell(
                  onTap: () {
                    final m =
                        (validMoves.first as Map).cast<String, dynamic>();
                    widget.g.act({
                      'type': 'place',
                      'q': asInt(m['q'], 0),
                      'r': asInt(m['r'], 0),
                      'rot': asInt(m['rot'], 0),
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚡快捷放置',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (curTile != null)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _terrainColor(tType).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  children: [
                    Text(
                      '${dorfTerrainEmojis[tType]} ${dorfTerrainNames[tType]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (hasFlag)
                      const Text(
                        '  🚩含领地旗帜',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    if (taskType >= 0 && taskTarget > 0)
                      Text(
                        '  🎯任务气泡: 恰好 $taskTarget 块${dorfTerrainNames[taskType]}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    if (edges.isNotEmpty)
                      Text(
                        '  六边:${[
                          for (var d = 0; d < edges.length; d++)
                            dorfTerrainEmojis[asInt(edges[(d - _rot + 6) % 6], 0)]
                        ].join()}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          SizedBox(
            height: 28,
            child: Row(
              children: [
                const Text(
                  '旋转方向: ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                for (var r = 0; r < 6; r++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _rot = r),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: _rot == r
                              ? cs.primary
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${r * 60}°',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color:
                                  _rot == r ? cs.onPrimary : cs.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              children: [
                Text(
                  '📊 田园计分总览：任务达成 $fulfilledTasksCount 个 (+$fulfilledTaskScore分) · 任务超额取消 $cancelledTasksCount 个 · 🚩封闭旗帜 +$closedFlagScore分 · 🌊最长河流 +$longestRiver分 · 🚂最长铁路 +$longestRailway分',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  '📍 可选空位与合法旋转角度（点击直接放置）：',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final m in validMoves.take(18))
                      Builder(builder: (context) {
                        final mm = (m as Map).cast<String, dynamic>();
                        final q = asInt(mm['q'], 0);
                        final r = asInt(mm['r'], 0);
                        final rot = asInt(mm['rot'], 0);
                        return InkWell(
                          onTap: isMyTurn
                              ? () => widget.g.act({
                                    'type': 'place',
                                    'q': q,
                                    'r': r,
                                    'rot': rot,
                                  })
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer
                                  .withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '($q,$r) · ${rot * 60}°',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHexMapPanel(
    List<dynamic> tiles,
    List<dynamic> validMoves,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '🗺️ 田园六角版图 (${tiles.length} 块已铺设)',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              itemCount: tiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 3),
              itemBuilder: (context, idx) {
                final tm = (tiles[idx] as Map).cast<String, dynamic>();
                final q = asInt(tm['q'], 0);
                final r = asInt(tm['r'], 0);
                final t = asInt(tm['type'], 0);
                final hasFlag = asBool(tm['hasFlag']);
                final taskType = asInt(tm['taskType'], -1);
                final taskTarget = asInt(tm['taskTarget'], 0);
                final taskState = asInt(tm['taskState'], 0);

                final stateLabel = switch (taskState) {
                  1 => '🎯进行中(目标$taskTarget)',
                  2 => '✅已完成(+$taskTarget分)',
                  3 => '❌超额取消(0分)',
                  _ => '',
                };

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _terrainColor(t).withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '($q,$r) ${dorfTerrainEmojis[t]}${dorfTerrainNames[t]}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (hasFlag)
                        const Text(
                          '🚩旗帜 ',
                          style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      if (taskType >= 0 && taskState > 0)
                        Expanded(
                          child: Text(
                            stateLabel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
