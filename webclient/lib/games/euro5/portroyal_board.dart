import 'package:aurora_shared/aurora_shared.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class PortRoyalBoard extends StatelessWidget {
  final GameContext g;
  const PortRoyalBoard(this.g, {super.key});

  static const Map<String, Color> _shipColorMap = {
    'yellow': Color(0xFFF9A825),
    'blue': Color(0xFF1E88E5),
    'red': Color(0xFFE53935),
    'green': Color(0xFF43A047),
    'black': Color(0xFF37474F),
  };

  static const Map<String, String> _roleDesc = {
    'sailor': '⚔️武力+1',
    'pirate': '⚔️武力+2',
    'trader_yellow': '黄船+1金',
    'trader_blue': '蓝船+1金',
    'trader_red': '红船+1金',
    'trader_green': '绿船+1金',
    'trader_black': '黑船+1金',
    'settler': '🏠定居者',
    'priest': '✝️牧师',
    'captain': '⚓船长',
    'governor': '👑多拿1牌',
    'jester': '🃏爆港+1金',
    'admiral': '🎖️5牌+2金',
    'mademoiselle': '💃雇佣-1金',
  };

  static const Map<String, String> _reqIcon = {
    'settler': '🏠定居者',
    'priest': '✝️牧师',
    'captain': '⚓船长',
  };

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final round = asInt(v['round'], 1);
    final turn = asInt(v['turn'], 0);
    final phase = asStr(v['phase'], 'discover');
    final subPhase = asStr(v['subPhase'], 'flip');
    final tradeSeat = asInt(v['tradeSeat'], 0);
    final allowance = asInt(v['allowance'], 0);
    final targetVp = asInt(v['targetVp'], 12);
    final deckCount = asInt(v['deckCount'], 0);
    final distinctColors = asInt(v['distinctColors'], 0);
    final lastEvent = asStr(v['lastEvent']);

    final harbor = (v['harbor'] as List?)?.cast<Map>() ?? const [];
    final openExps = (v['openExpeditions'] as List?)?.cast<Map>() ?? const [];
    final coins = asIntList(v['coins']);
    final vp = asIntList(v['vp']);
    final swords = asIntList(v['swords']);
    final crewList = (v['crew'] as List?) ?? const [];
    final expList = (v['expeditions'] as List?) ?? const [];

    final activeSeat = phase == 'discover'
        ? turn
        : (subPhase == 'other_trade' ? tradeSeat : turn);
    final isMyTurn = !g.over && g.seat == activeSeat;

    String statusText;
    if (g.over) {
      statusText = '游戏结束！';
    } else if (phase == 'discover') {
      statusText = '第 $round 轮 · 探索阶段：轮到 ${g.name(turn)} 翻牌探索港口';
    } else if (subPhase == 'active_trade') {
      statusText = '第 $round 轮 · 贸易阶段：${g.name(turn)} 可拿取 $allowance 张牌';
    } else {
      statusText = '第 $round 轮 · 顺风贸易：${g.name(tradeSeat)} 可付 1 金给 ${g.name(turn)} 拿 1 张牌';
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      StatusBar(statusText, highlight: isMyTurn),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '目标 $targetVp 分 · 牌库 $deckCount 张 · 港口船色 $distinctColors/5',
                          style: TextStyle(fontSize: 12, color: cs.onSurface),
                        ),
                      ),
                    ],
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        lastEvent,
                        style: TextStyle(fontSize: 12.5, color: cs.onSecondaryContainer),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Action buttons bar
                  if (isMyTurn) _buildActionBar(context, phase, subPhase, harbor.isNotEmpty, allowance),

                  const SizedBox(height: 8),

                  // Open Expeditions section
                  _buildExpeditionsPanel(
                    context,
                    openExps,
                    canClaim: isMyTurn && phase == 'trade' && subPhase == 'active_trade',
                  ),

                  const SizedBox(height: 8),

                  // Harbor cards section
                  _buildHarborPanel(
                    context,
                    harbor,
                    canTake: isMyTurn && phase == 'trade' && (subPhase == 'other_trade' || allowance > 0),
                    isOtherTurn: subPhase == 'other_trade',
                  ),

                  const SizedBox(height: 10),

                  // Players overview
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        _buildPlayerCard(
                          context,
                          s,
                          active: !g.over && s == activeSeat,
                          coins: s < coins.length ? coins[s] : 0,
                          vp: s < vp.length ? vp[s] : 0,
                          swords: s < swords.length ? swords[s] : 0,
                          crew: s < crewList.length ? (crewList[s] as List).cast<Map>() : const [],
                          exps: s < expList.length ? (expList[s] as List).cast<Map>() : const [],
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
              child: _buildResultBanner(context, vp, coins),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    String phase,
    String subPhase,
    bool harborHasCards,
    int allowance,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (phase == 'discover') ...[
            FilledButton.icon(
              onPressed: () => g.act({'type': 'flip'}),
              icon: const Icon(Icons.style, size: 18),
              label: const Text('翻开下一张牌'),
            ),
            if (harborHasCards)
              ElevatedButton.icon(
                onPressed: () => g.act({'type': 'stop'}),
                icon: const Icon(Icons.anchor, size: 18),
                label: const Text('见好就收（进入贸易）'),
              ),
          ] else if (phase == 'trade' && subPhase == 'active_trade') ...[
            Text(
              '点击下方港口卡牌拿取（剩余 $allowance 次），或：',
              style: TextStyle(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
            ),
            FilledButton.tonalIcon(
              onPressed: () => g.act({'type': 'done'}),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('结束拿牌'),
            ),
          ] else if (phase == 'trade' && subPhase == 'other_trade') ...[
            Text(
              '可点击港口卡牌拿取 1 张（需付给当前船长 1 金），或：',
              style: TextStyle(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
            ),
            FilledButton.tonalIcon(
              onPressed: () => g.act({'type': 'pass'}),
              icon: const Icon(Icons.skip_next, size: 18),
              label: const Text('放弃顺风贸易'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpeditionsPanel(BuildContext context, List<Map> openExps, {required bool canClaim}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.explore, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                '王室远征任务区 (${openExps.length})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (openExps.isEmpty)
            Text('当前暂无未完成的远征任务', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final exp in openExps) _buildExpCard(context, exp, canClaim: canClaim),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildExpCard(BuildContext context, Map exp, {required bool canClaim}) {
    final cs = Theme.of(context).colorScheme;
    final reqs = (exp['reqs'] as List?)?.map((e) => _reqIcon['$e'] ?? '$e').join(' + ') ?? '';
    return Container(
      width: 190,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  asStr(exp['name']),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: cs.onTertiaryContainer),
                ),
              ),
              Text(
                '⭐${exp['vp']}分 💰+${exp['coins']}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: cs.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('需求: $reqs', style: TextStyle(fontSize: 11.5, color: cs.onTertiaryContainer)),
          if (canClaim) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 28,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: () => g.act({'type': 'claim_exp', 'id': exp['id']}),
                child: const FittedBox(fit: BoxFit.scaleDown, child: Text('宣称完成远征', style: TextStyle(fontSize: 11.5))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHarborPanel(
    BuildContext context,
    List<Map> harbor, {
    required bool canTake,
    required bool isOtherTurn,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_boat, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                '港口停泊区 (${harbor.length} 张)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (harbor.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  '港口空空如也，等待当前船长翻牌探索…',
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < harbor.length; i++)
                  _buildHarborCard(
                    context,
                    i,
                    harbor[i],
                    canTake: canTake,
                    isOtherTurn: isOtherTurn,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHarborCard(
    BuildContext context,
    int index,
    Map card, {
    required bool canTake,
    required bool isOtherTurn,
  }) {
    final cs = Theme.of(context).colorScheme;
    final type = asStr(card['type']);
    final isShip = type == 'ship';
    final colorKey = asStr(card['color']);
    final bannerColor = isShip ? (_shipColorMap[colorKey] ?? cs.primary) : cs.secondary;

    Widget detail;
    if (isShip) {
      final coins = asInt(card['coins'], 1);
      final skull = card['skull'] == true;
      final swords = asInt(card['swords'], 1);
      detail = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💰 贸易收益: +$coins 金', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          Text(
            skull ? '💀 骷髅战舰 (无法击退)' : '⚔️ 船只武力: $swords',
            style: TextStyle(fontSize: 11, color: skull ? Colors.redAccent : cs.onSurfaceVariant),
          ),
        ],
      );
    } else {
      final role = asStr(card['role']);
      final cost = asInt(card['cost'], 0);
      final vp = asInt(card['vp'], 0);
      detail = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💰 雇佣费: $cost 金 · ⭐ $vp 分', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          Text('技能: ${_roleDesc[role] ?? role}', style: TextStyle(fontSize: 11, color: cs.primary)),
        ],
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: canTake ? () => g.act({'type': 'take', 'index': index, 'id': card['id']}) : null,
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: canTake ? bannerColor : cs.outline.withValues(alpha: 0.35),
            width: canTake ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: bannerColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                asStr(card['name']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 6),
            detail,
            if (canTake) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  isShip ? (isOtherTurn ? '点击拿船(付1金)' : '点击拿船') : (isOtherTurn ? '点击雇佣(+1金)' : '点击雇佣'),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: cs.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(
    BuildContext context,
    int s, {
    required bool active,
    required int coins,
    required int vp,
    required int swords,
    required List<Map> crew,
    required List<Map> exps,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 245,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: active ? 0.92 : 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? cs.primary : cs.outline.withValues(alpha: 0.3), width: active ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          g.tag(
            s,
            active: active,
            size: 32,
            sub: '⭐ $vp 分 · 💰 $coins 金 · ⚔️ $swords',
          ),
          const SizedBox(height: 6),
          if (crew.isEmpty && exps.isEmpty)
            Text('暂无船员与远征', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final c in crew)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${c['name']}(${_roleDesc[asStr(c['role'])] ?? ''})',
                      style: TextStyle(fontSize: 10.5, color: cs.onSecondaryContainer),
                    ),
                  ),
                for (final e in exps)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '🏆${e['name']}(+${e['vp']}分)',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: cs.onTertiaryContainer),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildResultBanner(BuildContext context, List<int> vp, List<int> coins) {
    final placings = asIntList(g.view['placings']);
    final lines = <String>[];
    for (var s = 0; s < g.players; s++) {
      final rank = s < placings.length ? placings[s] : 1;
      lines.add('第 $rank 名：${g.name(s)} — ${s < vp.length ? vp[s] : 0} 分（${s < coins.length ? coins[s] : 0} 金）');
    }
    return ResultBanner(
      '皇家港 · 终局结算',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final l in lines) Text(l, style: const TextStyle(fontSize: 13))],
      ),
    );
  }
}
