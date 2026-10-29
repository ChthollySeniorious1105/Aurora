import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class CitadelsBoard extends StatefulWidget {
  final GameContext g;
  const CitadelsBoard(this.g, {super.key});

  @override
  State<CitadelsBoard> createState() => _CitadelsBoardState();
}

class _CitadelsBoardState extends State<CitadelsBoard> {
  final Set<int> _exchangeSelected = {};

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  static Color _districtColor(String c) {
    switch (c) {
      case 'yellow':
        return const Color(0xFFF9A825);
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

  static String _colorLabel(String c) {
    switch (c) {
      case 'yellow':
        return '贵族';
      case 'blue':
        return '宗教';
      case 'green':
        return '商业';
      case 'red':
        return '军事';
      case 'purple':
        return '特殊';
      default:
        return '';
    }
  }

  String _roleName(int id, List roles) {
    if (id <= 0 || id > roles.length) return '未知';
    return '${roles[id - 1]['name']}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final phase = '${v['phase'] ?? 'draft'}';
    final subphase = '${v['subphase'] ?? 'income'}';
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final crown = (v['crown'] as num?)?.toInt() ?? 0;
    final targetDistricts = (v['targetDistricts'] as num?)?.toInt() ?? 7;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final draftSeat = (v['draftSeat'] as num?)?.toInt() ?? -1;
    final activeSeat = (v['activeSeat'] as num?)?.toInt() ?? -1;
    final currentRole = (v['currentRole'] as num?)?.toInt() ?? 0;
    final killedRole = (v['killedRole'] as num?)?.toInt() ?? 0;
    final robbedRole = (v['robbedRole'] as num?)?.toInt() ?? 0;
    final skillUsed = v['skillUsed'] == true;
    final taxTaken = v['taxTaken'] == true;
    final taxAvailable = (v['taxAvailable'] as num?)?.toInt() ?? 0;
    final buildsRemaining = (v['buildsRemaining'] as num?)?.toInt() ?? 0;
    final lastAction = '${v['lastAction'] ?? ''}';

    final roles = (v['roles'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];
    final myHand = (v['myHand'] as List?) ?? const [];
    final drawnCards = (v['drawnCards'] as List?) ?? const [];
    final availableRoles = ((v['availableRoles'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toList();
    final faceUpDiscards = ((v['faceUpDiscards'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toList();
    final faceDownCount = (v['faceDownDiscardCount'] as num?)?.toInt() ?? 0;
    final warlordTargets = (v['warlordTargets'] as List?) ?? const [];

    final isMyDraft = phase == 'draft' && g.seat >= 0 && g.seat == draftSeat;
    final isMyTurn = phase == 'turn' && g.seat >= 0 && g.seat == activeSeat;

    String statusText;
    if (g.over) {
      statusText = '游戏结束';
    } else if (phase == 'draft') {
      statusText = isMyDraft
          ? '第 $round 轮：请选择你的本轮角色'
          : '第 $round 轮：等待 ${g.name(draftSeat)} 选角';
    } else {
      final rName = _roleName(currentRole, roles);
      statusText = isMyTurn
          ? '第 $round 轮：你是【$currentRole号 $rName】，请执行行动'
          : '第 $round 轮：【$currentRole号 $rName】${g.name(activeSeat)} 行动中';
    }

    final myCityIds = <String>{};
    int myGold = 0;
    if (g.seat >= 0 && g.seat < pList.length) {
      final mp = pList[g.seat] as Map;
      myGold = (mp['gold'] as num?)?.toInt() ?? 0;
      for (final d in (mp['city'] as List? ?? const [])) {
        myCityIds.add('${(d as Map)['id']}');
      }
    }

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar: status + role track + deck info
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBar(statusText, highlight: isMyDraft || isMyTurn),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _infoChip(cs, '目标 $targetDistricts 建筑', Icons.location_city),
                      _infoChip(cs, '牌库 $deckCount', Icons.style),
                      if (faceDownCount > 0)
                        _infoChip(cs, '暗弃 $faceDownCount', Icons.visibility_off),
                      if (faceUpDiscards.isNotEmpty)
                        _infoChip(
                          cs,
                          '明弃: ${faceUpDiscards.map((r) => _roleName(r, roles)).join("/")}',
                          Icons.visibility,
                        ),
                    ],
                  ),
                ],
              ),
              if (lastAction.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    lastAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
                  ),
                ),
              const SizedBox(height: 6),

              // Role Bar 1..8
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final rObj in roles)
                      _buildRoleBadge(
                        cs,
                        rObj as Map,
                        currentRole: currentRole,
                        killedRole: killedRole,
                        robbedRole: robbedRole,
                        faceUpDiscards: faceUpDiscards,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Main scrollable area: interactive panel + players' cities + my hand
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isMyDraft) _buildDraftPicker(cs, availableRoles, roles),
                      if (isMyTurn && subphase == 'income') _buildIncomePanel(cs),
                      if (isMyTurn && subphase == 'keep_card')
                        _buildKeepCardPanel(cs, drawnCards),
                      if (isMyTurn && subphase == 'action')
                        _buildActionPanel(
                          cs,
                          currentRole: currentRole,
                          roles: roles,
                          skillUsed: skillUsed,
                          taxTaken: taxTaken,
                          taxAvailable: taxAvailable,
                          buildsRemaining: buildsRemaining,
                          myHand: myHand,
                          warlordTargets: warlordTargets,
                        ),
                      const SizedBox(height: 6),

                      // Players and their cities
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in g.seatsFromMe())
                            if (s < pList.length)
                              _buildPlayerCard(
                                cs,
                                pList[s] as Map,
                                crown: crown,
                                activeSeat: activeSeat,
                                draftSeat: draftSeat,
                                phase: phase,
                                targetDistricts: targetDistricts,
                                roles: roles,
                              ),
                        ],
                      ),

                      if (g.seat >= 0) ...[
                        const SizedBox(height: 8),
                        _buildMyHandSection(
                          cs,
                          myHand,
                          canBuildNow: isMyTurn && subphase == 'action' && buildsRemaining > 0,
                          myGold: myGold,
                          myCityIds: myCityIds,
                          inMagicianExchange: isMyTurn &&
                              subphase == 'action' &&
                              currentRole == 3 &&
                              !skillUsed,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (g.over && v['result'] != null)
            Align(
              alignment: Alignment.center,
              child: _buildResultBanner(cs, v['result'] as Map, pList),
            ),
        ],
      ),
    );
  }

  Widget _infoChip(ColorScheme cs, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(
    ColorScheme cs,
    Map r, {
    required int currentRole,
    required int killedRole,
    required int robbedRole,
    required List<int> faceUpDiscards,
  }) {
    final id = (r['id'] as num).toInt();
    final name = '${r['name']}';
    final colorStr = '${r['color'] ?? ''}';
    final isCurrent = id == currentRole;
    final isKilled = id == killedRole;
    final isRobbed = id == robbedRole;
    final isDiscarded = faceUpDiscards.contains(id);

    final accent = colorStr.isNotEmpty ? _districtColor(colorStr) : cs.primary;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? accent.withValues(alpha: 0.3)
            : cs.surface.withValues(alpha: isDiscarded ? 0.35 : 0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent ? accent : cs.outline.withValues(alpha: 0.35),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$id.$name',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              decoration: isKilled || isDiscarded ? TextDecoration.lineThrough : null,
            ),
          ),
          if (isKilled) ...[
            const SizedBox(width: 3),
            const Icon(Icons.close, size: 13, color: Colors.redAccent),
          ],
          if (isRobbed) ...[
            const SizedBox(width: 3),
            const Icon(Icons.savings, size: 13, color: Colors.amber),
          ],
        ],
      ),
    );
  }

  Widget _buildDraftPicker(ColorScheme cs, List<int> availableRoles, List roles) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选择你的角色：', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final rId in availableRoles)
                if (rId >= 1 && rId <= roles.length)
                  _buildDraftRoleButton(cs, roles[rId - 1] as Map),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDraftRoleButton(ColorScheme cs, Map r) {
    final id = (r['id'] as num).toInt();
    final name = '${r['name']}';
    final desc = '${r['desc']}';
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => g.act({'type': 'draft', 'role': id}),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.primary.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$id. $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomePanel(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('选择本回合收入：', style: TextStyle(fontWeight: FontWeight.bold)),
          FilledButton.icon(
            onPressed: () => g.act({'type': 'income', 'choice': 'gold'}),
            icon: const Icon(Icons.monetization_on, size: 16),
            label: const Text('拿取 2 金币'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => g.act({'type': 'income', 'choice': 'cards'}),
            icon: const Icon(Icons.style, size: 16),
            label: const Text('摸建筑牌'),
          ),
        ],
      ),
    );
  }

  Widget _buildKeepCardPanel(ColorScheme cs, List drawnCards) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('点击选择要保留的建筑牌：', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < drawnCards.length; i++)
                _buildDistrictTile(
                  cs,
                  drawnCards[i] as Map,
                  onTap: () => g.act({'type': 'keep_card', 'index': i}),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel(
    ColorScheme cs, {
    required int currentRole,
    required List roles,
    required bool skillUsed,
    required bool taxTaken,
    required int taxAvailable,
    required int buildsRemaining,
    required List myHand,
    required List warlordTargets,
  }) {
    final killedRole = (v['killedRole'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '行动阶段（可建造 $buildsRemaining 座）',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (!taxTaken && taxAvailable > 0)
                FilledButton.tonalIcon(
                  onPressed: () => g.act({'type': 'tax'}),
                  icon: const Icon(Icons.account_balance, size: 15),
                  label: Text('征收领地税 +$taxAvailable 金'),
                ),
              FilledButton.icon(
                onPressed: () {
                  _exchangeSelected.clear();
                  g.act({'type': 'end_turn'});
                },
                icon: const Icon(Icons.check, size: 15),
                label: const Text('结束回合'),
              ),
            ],
          ),
          if (!skillUsed && (currentRole == 1 || currentRole == 2 || currentRole == 3 || currentRole == 8)) ...[
            const Divider(height: 12),
            if (currentRole == 1) ...[
              const Text('刺客技能 — 选择要刺杀的角色：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var r = 2; r <= 8; r++)
                    ActionChip(
                      label: Text('$r.${_roleName(r, roles)}', style: const TextStyle(fontSize: 11)),
                      onPressed: () => g.act({'type': 'skill', 'targetRole': r}),
                    ),
                ],
              ),
            ],
            if (currentRole == 2) ...[
              const Text('盗贼技能 — 选择要偷窃的角色：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var r = 3; r <= 8; r++)
                    if (r != killedRole)
                      ActionChip(
                        label: Text('$r.${_roleName(r, roles)}', style: const TextStyle(fontSize: 11)),
                        onPressed: () => g.act({'type': 'skill', 'targetRole': r}),
                      ),
                ],
              ),
            ],
            if (currentRole == 3) ...[
              const Text('魔术师技能 — 与玩家换牌或点选手牌置换：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var s = 0; s < g.players; s++)
                    if (s != g.seat)
                      ActionChip(
                        label: Text('与 ${g.name(s)} 互换手牌', style: const TextStyle(fontSize: 11)),
                        onPressed: () => g.act({'type': 'skill', 'mode': 'swap', 'targetSeat': s}),
                      ),
                  if (_exchangeSelected.isNotEmpty)
                    FilledButton.tonal(
                      onPressed: () {
                        final list = _exchangeSelected.toList();
                        setState(() => _exchangeSelected.clear());
                        g.act({'type': 'skill', 'mode': 'exchange', 'cards': list});
                      },
                      child: Text('置换选中的 ${_exchangeSelected.length} 张手牌'),
                    ),
                ],
              ),
            ],
            if (currentRole == 8 && warlordTargets.isNotEmpty) ...[
              const Text('军阀技能 — 选择要摧毁的建筑：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in warlordTargets)
                    Builder(builder: (context) {
                      final m = t as Map;
                      final ts = (m['targetSeat'] as num).toInt();
                      final di = (m['districtIdx'] as num).toInt();
                      final cost = (m['cost'] as num).toInt();
                      final pList = (v['players'] as List?) ?? const [];
                      String dName = '建筑';
                      if (ts >= 0 && ts < pList.length) {
                        final city = (pList[ts] as Map)['city'] as List? ?? const [];
                        if (di >= 0 && di < city.length) {
                          dName = '${(city[di] as Map)['name']}';
                        }
                      }
                      return ActionChip(
                        label: Text('摧毁 ${g.name(ts)} 的【$dName】($cost金)', style: const TextStyle(fontSize: 11)),
                        onPressed: () => g.act({'type': 'skill', 'targetSeat': ts, 'districtIdx': di}),
                      );
                    }),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerCard(
    ColorScheme cs,
    Map p, {
    required int crown,
    required int activeSeat,
    required int draftSeat,
    required String phase,
    required int targetDistricts,
    required List roles,
  }) {
    final s = (p['seat'] as num).toInt();
    final gold = (p['gold'] as num?)?.toInt() ?? 0;
    final handCount = (p['handCount'] as num?)?.toInt() ?? 0;
    final role = (p['role'] as num?)?.toInt() ?? 0;
    final score = (p['score'] as num?)?.toInt() ?? 0;
    final city = (p['city'] as List?) ?? const [];
    final isActive = (phase == 'draft' && s == draftSeat) || (phase == 'turn' && s == activeSeat);
    final roleStr = role > 0 ? '$role号 ${_roleName(role, roles)}' : '角色暗置';

    return Container(
      width: 265,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? cs.primary : cs.outline.withValues(alpha: 0.35),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: g.tag(
                  s,
                  active: isActive,
                  size: 30,
                  sub: '$roleStr · 💰$gold · 🃏$handCount · ⭐$score',
                ),
              ),
              if (s == crown)
                const Tooltip(
                  message: '持有王冠',
                  child: Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '城区 (${city.length}/$targetDistricts)：',
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 4),
          if (city.isEmpty)
            Text('尚无建筑', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)))
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final d in city) _buildCompactCityDistrict(d as Map),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCompactCityDistrict(Map d) {
    final color = _districtColor('${d['color']}');
    final name = '${d['name']}';
    final cost = (d['cost'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        '$name($cost)',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildMyHandSection(
    ColorScheme cs,
    List myHand, {
    required bool canBuildNow,
    required int myGold,
    required Set<String> myCityIds,
    required bool inMagicianExchange,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '我的手牌 (${myHand.length}) — 点击可建造的卡牌进行建造${inMagicianExchange ? "（或勾选后发动魔术师置换）" : ""}：',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (myHand.isEmpty)
            const Text('暂无手牌', style: TextStyle(fontSize: 12))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < myHand.length; i++)
                  Builder(builder: (context) {
                    final d = myHand[i] as Map;
                    final cost = (d['cost'] as num?)?.toInt() ?? 0;
                    final id = '${d['id']}';
                    final buildable = canBuildNow && myGold >= cost && !myCityIds.contains(id);
                    final selected = _exchangeSelected.contains(i);
                    return _buildDistrictTile(
                      cs,
                      d,
                      highlight: buildable,
                      selected: selected,
                      onTap: buildable
                          ? () => g.act({'type': 'build', 'card': i})
                          : (inMagicianExchange
                              ? () => setState(() {
                                    if (selected) {
                                      _exchangeSelected.remove(i);
                                    } else {
                                      _exchangeSelected.add(i);
                                    }
                                  })
                              : null),
                    );
                  }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDistrictTile(
    ColorScheme cs,
    Map d, {
    bool highlight = false,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final name = '${d['name']}';
    final colorStr = '${d['color']}';
    final cost = (d['cost'] as num?)?.toInt() ?? 0;
    final effect = '${d['effect'] ?? ''}';
    final color = _districtColor(colorStr);

    final tile = Container(
      width: 118,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? Colors.amber : (highlight ? color : color.withValues(alpha: 0.5)),
          width: selected || highlight ? 2 : 1,
        ),
        boxShadow: highlight
            ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 4)]
            : null,
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
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$cost',
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _colorLabel(colorStr),
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
            ),
          ),
          if (effect.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              effect,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9.5, color: cs.onSurface.withValues(alpha: 0.75)),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return tile;
    return InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap, child: tile);
  }

  Widget _buildResultBanner(ColorScheme cs, Map res, List pList) {
    final winners = ((res['winners'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final scores = ((res['scores'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final title = winners.isEmpty ? '游戏结束' : '🏆 ${winners.map(g.name).join("、")} 获胜！';
    return ResultBanner(
      title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var s = 0; s < g.players && s < scores.length; s++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${g.name(s)}：${scores[s]} 分（建筑 ${(pList[s] as Map)['city']?.length ?? 0} 座）',
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
