import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _goodNames = ['玉米', '靛蓝', '蔗糖', '烟草', '咖啡'];
const List<String> _goodIcons = ['🌽', '🟦', '🍬', '🍂', '☕'];
const List<Color> _goodColors = [
  Color(0xFFFBC02D), // 玉米
  Color(0xFF1E88E5), // 靛蓝
  Color(0xFF8E24AA), // 蔗糖
  Color(0xFF8D6E63), // 烟草
  Color(0xFF4E342E), // 咖啡
];

const List<String> _roleNames = ['开拓者', '市长', '建筑师', '工艺师', '商人', '船长'];
const List<String> _roleIcons = ['🌱', '🎩', '🏗️', '⚒️', '⚖️', '⚓'];
const List<String> _roleHints = [
  '选种植园/特权采石场',
  '分配拓荒者/特权+1人',
  '建建筑/特权费用-1',
  '产出货物/特权+1桶',
  '卖1桶货/特权售价+1',
  '装船得分/特权+1VP',
];

class PuertoRicoBoard extends StatefulWidget {
  final GameContext g;
  const PuertoRicoBoard(this.g, {super.key});

  @override
  State<PuertoRicoBoard> createState() => _PuertoRicoBoardState();
}

class _PuertoRicoBoardState extends State<PuertoRicoBoard> {
  int? _viewSeat;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 14;
    final governor = (v['governor'] as num?)?.toInt() ?? 0;
    final phase = (v['phase'] as String?) ?? 'pick_role';
    final currentRole = (v['currentRole'] as num?)?.toInt() ?? -1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final vpPool = (v['vpPool'] as num?)?.toInt() ?? 0;
    final colonistShip = (v['colonistShip'] as num?)?.toInt() ?? 0;
    final quarriesLeft = (v['quarriesLeft'] as num?)?.toInt() ?? 0;
    final lastAction = (v['lastAction'] as String?) ?? '';

    final roleCoins = (v['roleCoins'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List<int>.filled(6, 0);
    final usedRoles = ((v['usedRoles'] as List?)?.map((e) => (e as num).toInt()) ?? const <int>[]).toSet();
    final plantationMarket = (v['plantationMarket'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final tradingHouse = (v['tradingHouse'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final cargoShips = (v['cargoShips'] as List?)?.cast<Map>() ?? const [];
    final buildingShop = (v['buildingShop'] as List?)?.cast<Map>() ?? const [];
    final craftsmanBonusOptions =
        (v['craftsmanBonusOptions'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final playersData = (v['playersData'] as List?)?.cast<Map>() ?? const [];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List<int>.filled(g.players, 0);

    final isMyTurn = !over && g.seat >= 0 && g.seat == turn;
    final activeSeat = g.seat >= 0 ? g.seat : 0;
    final inspectedSeat = (_viewSeat != null && _viewSeat! < g.players) ? _viewSeat! : activeSeat;

    String phaseText() {
      if (over) return '波多黎各 已结束';
      final who = isMyTurn ? '你' : g.name(turn);
      switch (phase) {
        case 'pick_role':
          return '轮到 $who 选择本轮角色';
        case 'settler':
          return '【开拓者阶段】等待 $who 选取种植园或采石场';
        case 'builder':
          return '【建筑师阶段】等待 $who 建造城市建筑';
        case 'craftsman_bonus':
          return '【工艺师阶段】等待 $who 选择特权额外货物';
        case 'trader':
          return '【商人阶段】等待 $who 向交易所出售货物';
        case 'captain':
          return '【船长阶段】等待 $who 将货物装上货船';
        default:
          return '等待 $who 行动';
      }
    }

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBar(phaseText(), highlight: isMyTurn),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('第$round/$maxRounds轮 · 总督:${g.name(governor)} · ⭐池:$vpPool · 🚢移民:$colonistShip'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in g.seatsFromMe())
                      Builder(builder: (context) {
                        final pd = s < playersData.length ? playersData[s] : const {};
                        final d = (pd['doubloons'] as num?)?.toInt() ?? 0;
                        final sc = (pd['score'] as num?)?.toInt() ?? 0;
                        final city = (pd['citySpaces'] as num?)?.toInt() ?? 0;
                        return GestureDetector(
                          onTap: () => setState(() => _viewSeat = s),
                          child: g.tag(
                            s,
                            active: s == turn && !over,
                            sub: '${s == governor ? "👑 " : ""}💰$d · ⭐$sc · 🏛️$city/12',
                            size: 30,
                          ),
                        );
                      }),
                  ],
                ),
              ),
              if (lastAction.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: Text(
                    lastAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildRolesSection(cs, g, phase, currentRole, roleCoins, usedRoles, isMyTurn),
                      const SizedBox(height: 8),
                      if (isMyTurn && phase != 'pick_role')
                        _buildActiveActionCard(
                          cs,
                          g,
                          phase,
                          plantationMarket,
                          quarriesLeft,
                          buildingShop,
                          craftsmanBonusOptions,
                          tradingHouse,
                          cargoShips,
                          g.seat < playersData.length ? playersData[g.seat] : const {},
                        ),
                      const SizedBox(height: 8),
                      _buildShipsAndMarketSection(cs, cargoShips, tradingHouse, plantationMarket, quarriesLeft),
                      const SizedBox(height: 8),
                      if (inspectedSeat < playersData.length)
                        _buildPlayerEmpireCard(cs, g, inspectedSeat, playersData[inspectedSeat]),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (over && v['result'] != null)
            Align(
              alignment: Alignment.center,
              child: _buildResultBanner(g, scores),
            ),
        ],
      ),
    );
  }

  Widget _buildRolesSection(
    ColorScheme cs,
    GameContext g,
    String phase,
    int currentRole,
    List<int> roleCoins,
    Set<int> usedRoles,
    bool isMyTurn,
  ) {
    final canPick = isMyTurn && phase == 'pick_role';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            canPick ? '点击选择本轮角色（领取角色牌上的奖励金币）：' : '六大角色面板：',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var r = 0; r < 6; r++)
                Builder(builder: (context) {
                  final used = usedRoles.contains(r);
                  final active = currentRole == r && phase != 'pick_role';
                  final coins = r < roleCoins.length ? roleCoins[r] : 0;
                  return InkWell(
                    onTap: canPick && !used ? () => g.act({'type': 'pick_role', 'role': r}) : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 145,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: active
                            ? cs.primaryContainer
                            : (used
                                ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
                                : cs.surfaceContainerHighest.withValues(alpha: 0.85)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active ? cs.primary : (canPick && !used ? cs.primary.withValues(alpha: 0.6) : cs.outline.withValues(alpha: 0.3)),
                          width: active ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_roleIcons[r]} ${_roleNames[r]}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  decoration: used && !active ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (coins > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade700,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '+$coins💰',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(_roleHints[r], style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.75))),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveActionCard(
    ColorScheme cs,
    GameContext g,
    String phase,
    List<int> plantationMarket,
    int quarriesLeft,
    List<Map> buildingShop,
    List<int> craftsmanBonusOptions,
    List<int> tradingHouse,
    List<Map> cargoShips,
    Map myData,
  ) {
    final myGoods = (myData['goods'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List<int>.filled(5, 0);
    final myDoubloons = (myData['doubloons'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (phase == 'settler') ...[
            Text('🌱 开拓者阶段 — 请选择 1 块种植园或采石场：', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var i = 0; i < plantationMarket.length; i++)
                  FilledButton.tonal(
                    onPressed: () => g.act({'type': 'settler_pick', 'index': i}),
                    child: Text('${_goodIcons[plantationMarket[i]]} ${_goodNames[plantationMarket[i]]}田'),
                  ),
                if (quarriesLeft > 0)
                  FilledButton(
                    onPressed: () => g.act({'type': 'settler_quarry'}),
                    child: Text('🪨 拿取采石场 (余$quarriesLeft)'),
                  ),
                OutlinedButton(
                  onPressed: () => g.act({'type': 'pass'}),
                  child: const Text('跳过'),
                ),
              ],
            ),
          ],
          if (phase == 'builder') ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('🏗️ 建筑师阶段 — 选择要建造的建筑 (你的金币: 💰$myDoubloons)：',
                    style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                OutlinedButton(
                  onPressed: () => g.act({'type': 'pass'}),
                  child: const Text('跳过建造'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final b in buildingShop)
                  if (((b['stock'] as num?)?.toInt() ?? 0) > 0)
                    Builder(builder: (context) {
                      final id = (b['id'] as num).toInt();
                      final name = b['name'] as String;
                      final vp = (b['vp'] as num).toInt();
                      final effCost = (b['effectiveCost'] as num?)?.toInt() ?? (b['cost'] as num).toInt();
                      final desc = (b['desc'] as String?) ?? '';
                      final affordable = myDoubloons >= effCost;
                      return Tooltip(
                        message: desc,
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: CircleAvatar(
                            backgroundColor: affordable ? cs.primary : cs.outline,
                            child: Text('$effCost', style: TextStyle(fontSize: 10, color: cs.onPrimary)),
                          ),
                          label: Text('$name (${vp}VP)'),
                          onPressed: affordable ? () => g.act({'type': 'build', 'buildingId': id}) : null,
                        ),
                      );
                    }),
              ],
            ),
          ],
          if (phase == 'craftsman_bonus') ...[
            Text('⚒️ 工艺师特权 — 请选择额外生产的 1 桶货物：', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final good in craftsmanBonusOptions)
                  FilledButton(
                    onPressed: () => g.act({'type': 'craftsman_bonus', 'good': good}),
                    child: Text('${_goodIcons[good]} 额外获得 1 桶${_goodNames[good]}'),
                  ),
              ],
            ),
          ],
          if (phase == 'trader') ...[
            Text('⚖️ 商人阶段 — 选择向交易所出售 1 桶货物：', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var good = 0; good < 5; good++)
                  if (myGoods[good] > 0)
                    FilledButton.tonal(
                      onPressed: () => g.act({'type': 'trade', 'good': good}),
                      child: Text('出售 ${_goodIcons[good]}${_goodNames[good]} (库存${myGoods[good]})'),
                    ),
                OutlinedButton(
                  onPressed: () => g.act({'type': 'pass'}),
                  child: const Text('不出售 / 跳过'),
                ),
              ],
            ),
          ],
          if (phase == 'captain') ...[
            Text('⚓ 船长阶段 — 请选择货物与货船进行装船远航：', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var good = 0; good < 5; good++)
                  if (myGoods[good] > 0)
                    for (var sIdx = 0; sIdx < cargoShips.length; sIdx++)
                      Builder(builder: (context) {
                        final ship = cargoShips[sIdx];
                        final sGood = (ship['goodType'] as num?)?.toInt();
                        final space = (ship['spaceLeft'] as num?)?.toInt() ?? 0;
                        final otherHasGood = cargoShips.any((o) => (o['goodType'] as num?)?.toInt() == good);
                        final canLoad = space > 0 && (sGood == good || (sGood == null && !otherHasGood));
                        if (!canLoad) return const SizedBox.shrink();
                        return FilledButton(
                          onPressed: () => g.act({'type': 'load_ship', 'good': good, 'ship': sIdx}),
                          child: Text('装运 ${_goodIcons[good]}${_goodNames[good]} → ${sIdx + 1}号船(空位$space)'),
                        );
                      }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShipsAndMarketSection(
    ColorScheme cs,
    List<Map> cargoShips,
    List<int> tradingHouse,
    List<int> plantationMarket,
    int quarriesLeft,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        children: [
          // Cargo ships
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('⚓ 三艘远洋货船', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < cargoShips.length; i++)
                    Builder(builder: (context) {
                      final s = cargoShips[i];
                      final cap = (s['capacity'] as num?)?.toInt() ?? 4;
                      final cnt = (s['count'] as num?)?.toInt() ?? 0;
                      final gType = (s['goodType'] as num?)?.toInt();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${i + 1}号船[$cnt/$cap]: ${gType != null ? "${_goodIcons[gType]}${_goodNames[gType]}" : "空船"}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
          // Trading house
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('⚖️ 交易所 (${tradingHouse.length}/4)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  if (tradingHouse.isEmpty)
                    const Text('暂无货物', style: TextStyle(fontSize: 12))
                  else
                    for (final gType in tradingHouse)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('${_goodIcons[gType]} ${_goodNames[gType]}'),
                      ),
                ],
              ),
            ],
          ),
          // Plantations
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🌱 公开种植园 & 🪨采石场(余$quarriesLeft)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  for (final p in plantationMarket)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _goodColors[p % 5].withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_goodIcons[p % 5]}${_goodNames[p % 5]}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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

  Widget _buildPlayerEmpireCard(ColorScheme cs, GameContext g, int seat, Map pData) {
    final goods = (pData['goods'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List<int>.filled(5, 0);
    final plantations = (pData['plantations'] as List?)?.cast<Map>() ?? const [];
    final buildings = (pData['buildings'] as List?)?.cast<Map>() ?? const [];
    final colonists = (pData['colonists'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${g.name(seat)} 的总督府 (👷拓荒者: $colonists)',
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
              ),
              Wrap(
                spacing: 4,
                children: [
                  for (var s = 0; s < g.players; s++)
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(g.name(s), style: const TextStyle(fontSize: 11)),
                      selected: seat == s,
                      onSelected: (_) => setState(() => _viewSeat = s),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Goods barrels
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < 5; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _goodColors[i].withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _goodColors[i]),
                  ),
                  child: Text('${_goodIcons[i]} ${_goodNames[i]}: ${goods[i]}桶', style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('🌱 岛屿种植园与采石场 (${plantations.length}/12)：', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in plantations)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: p['manned'] == true ? Colors.green : cs.outline.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${p['name']} ${p['manned'] == true ? "👷" : "○"}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('🏛️ 城市建筑 (${buildings.length}座)：', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (buildings.isEmpty)
            Text('尚未建造城市建筑', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final b in buildings)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: b['isManned'] == true ? cs.primary : cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${b['name']} (${b['vp']}VP · 👷${b['mannedCount']}/${b['capacity']})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildResultBanner(GameContext g, List<int> scores) {
    final maxScore = scores.reduce(max);
    final winners = [for (var s = 0; s < g.players; s++) if (scores[s] == maxScore) g.name(s)];
    return ResultBanner(
      '${winners.join("、")} 获胜！($maxScore VP)',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var s = 0; s < g.players; s++)
            Text('${g.name(s)}: ${scores[s]} VP'),
        ],
      ),
    );
  }
}
