import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro16/meadow.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class MeadowBoard extends StatefulWidget {
  final GameContext g;
  const MeadowBoard(this.g, {super.key});

  @override
  State<MeadowBoard> createState() => _MeadowBoardState();
}

class _MeadowBoardState extends State<MeadowBoard> {
  int _selectedHandIdx = -1;
  int? _inspectSeat;

  static const List<String> _tierLabels = [
    'R1 基础生境',
    'R2 低阶自然',
    'R3 中阶物种',
    'R4 顶级景观',
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = asInt(v['round'], 1);
    final maxRounds = asInt(v['maxRounds'], 6);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final market = (v['market'] as List?) ?? const [];
    final campfireGoals = (v['campfireGoals'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    final mySeat = g.seat >= 0 && g.seat < pList.length ? g.seat : turn;
    final viewSeat = (_inspectSeat != null && _inspectSeat! < pList.length)
        ? _inspectSeat!
        : mySeat;
    final isMyTurn = !over && g.seat == turn;

    final viewData = (pList.isNotEmpty && viewSeat < pList.length)
        ? (pList[viewSeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final myData = (pList.isNotEmpty && mySeat < pList.length)
        ? (pList[mySeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    final myHand = (myData['hand'] as List?) ?? const [];
    if (_selectedHandIdx >= myHand.length) _selectedHandIdx = -1;

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
                                ? '游戏结束 · $lastAction'
                                : (isMyTurn
                                    ? '轮到你！可先点选手牌再点选4×4芳原市场卡拿取并打出，或造访营火 · $lastAction'
                                    : '等待 ${g.name(turn)} 行动 · $lastAction'),
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
                          '🦌第 $round/$maxRounds 轮',
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
                        final evp = asInt(pd['ecosystemVp'], 0);
                        final cvp = asInt(pd['campfireVp'], 0);
                        final toks =
                            ((pd['tokensLeft'] as List?) ?? const []).join(',');
                        final selected = s == viewSeat;
                        return GestureDetector(
                          onTap: () => setState(() => _inspectSeat = s),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: selected
                                  ? Border.all(
                                      color: Colors.amberAccent, width: 2)
                                  : null,
                            ),
                            child: g.tag(
                              s,
                              active: s == turn,
                              sub: '⭐$sc分 (🌿$evp 🔥$cvp) · 标[$toks]',
                              size: 28,
                            ),
                          ),
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
                                flex: 6,
                                child: _buildMarketAndCampfire(
                                  market,
                                  campfireGoals,
                                  myData,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: _buildPlayerPanel(
                                  viewSeat,
                                  viewData,
                                  myHand,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 6,
                                child: _buildMarketAndCampfire(
                                  market,
                                  campfireGoals,
                                  myData,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 5,
                                child: _buildPlayerPanel(
                                  viewSeat,
                                  viewData,
                                  myHand,
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
                '翠屿芳原终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarketAndCampfire(
    List<dynamic> market,
    List<dynamic> campfireGoals,
    Map<String, dynamic> myData,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final myTokens = [
      for (final t in ((myData['tokensLeft'] as List?) ?? const []))
        asInt(t, 0),
    ];

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
                  '🧭 4×4 芳原市场 (路径标深度匹配行/列编号)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Text(
                '剩余路径标: ${myTokens.isEmpty ? "无" : myTokens.map((d) => "[$d]").join(" ")}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < 4; r++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _tierLabels[r],
                                style: const TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          for (var c = 0; c < 4; c++)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: _buildMarketCell(
                                  r,
                                  c,
                                  (r < market.length &&
                                          c < (market[r] as List).length)
                                      ? (market[r] as List)[c]
                                          as Map<String, dynamic>?
                                      : null,
                                  myTokens,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: campfireGoals.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final gMap =
                    (campfireGoals[idx] as Map).cast<String, dynamic>();
                final claimedBy = asInt(gMap['claimedBy'], -1);
                final claimed = claimedBy >= 0;
                return InkWell(
                  onTap: (!isMyTurn || claimed)
                      ? null
                      : () {
                          widget.g.act({
                            'type': 'campfire',
                            'goalIdx': idx,
                            'playCard': _selectedHandIdx,
                          });
                          setState(() => _selectedHandIdx = -1);
                        },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: claimed
                          ? cs.secondaryContainer.withValues(alpha: 0.6)
                          : Colors.deepOrange.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: claimed
                            ? cs.outline.withValues(alpha: 0.3)
                            : Colors.deepOrangeAccent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      claimed
                          ? '🔥${gMap['symAEmoji']}+${gMap['symBEmoji']} (${widget.g.name(claimedBy)} +${gMap['bonusVp']}分)'
                          : '🔥营火目标: ${gMap['symAEmoji']}+${gMap['symBEmoji']} (抢占+2/3/4分)',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketCell(
    int r,
    int c,
    Map<String, dynamic>? card,
    List<int> myTokens,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    if (card == null) {
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Text('空', style: TextStyle(fontSize: 10)),
      );
    }
    final reachable = myTokens.contains(r + 1) || myTokens.contains(c + 1);
    return GestureDetector(
      onTap: (!isMyTurn || !reachable)
          ? null
          : () {
              widget.g.act({
                'type': 'draft_play',
                'row': r,
                'col': c,
                'playCard': _selectedHandIdx,
              });
              setState(() => _selectedHandIdx = -1);
            },
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: reachable && isMyTurn
              ? cs.primaryContainer.withValues(alpha: 0.75)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: reachable && isMyTurn
                ? cs.primary
                : cs.outline.withValues(alpha: 0.3),
            width: reachable && isMyTurn ? 1.5 : 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${card['emoji']} ${card['name']}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              Text(
                '产:${card['providesEmoji']} · ⭐${card['vp']}分',
                style: const TextStyle(fontSize: 10),
              ),
              Text(
                '${card['reqsDesc']}',
                style: TextStyle(
                  fontSize: 9,
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    List<dynamic> myHand,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final eco = (viewData['ecosystem'] as List?) ?? const [];
    final symCounts = (viewData['symbolCounts'] as List?) ?? const [];

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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  '🌿 ${widget.g.name(viewSeat)} 的生态圈符号: ',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 11),
                ),
                for (var i = 0;
                    i < meadowSymbolEmojis.length && i < symCounts.length;
                    i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      '${meadowSymbolEmojis[i]}×${symCounts[i]}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '🃏 我的手牌（可点选 1 张在拿牌或造访营火时一并打出）:',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 54,
            child: myHand.isEmpty
                ? const Center(
                    child: Text('暂无手牌', style: TextStyle(fontSize: 10)),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: myHand.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final c = (myHand[idx] as Map).cast<String, dynamic>();
                      final sel = idx == _selectedHandIdx;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedHandIdx = sel ? -1 : idx;
                        }),
                        child: Container(
                          width: 110,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: sel
                                ? Colors.amber.withValues(alpha: 0.28)
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: sel
                                  ? Colors.amber
                                  : cs.outline.withValues(alpha: 0.3),
                              width: sel ? 2 : 1,
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${c['emoji']} ${c['name']} (+${c['vp']}分)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11),
                                ),
                                Text(
                                  '提供 ${c['providesEmoji']} · ${c['reqsDesc']}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            '🏞️ 已构筑生态圈 (${eco.length} 张 · ${viewData['ecosystemVp'] ?? 0} 分):',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: eco.isEmpty
                ? const Center(
                    child: Text('生态圈为空', style: TextStyle(fontSize: 10)),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 125,
                      mainAxisExtent: 46,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: eco.length,
                    itemBuilder: (context, idx) {
                      final c = (eco[idx] as Map).cast<String, dynamic>();
                      return Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${c['emoji']} ${c['name']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              Text(
                                '${c['providesEmoji']} · ⭐${c['vp']}分',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
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
