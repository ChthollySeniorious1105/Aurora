import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class MascaradeBoard extends StatefulWidget {
  final GameContext g;
  const MascaradeBoard(this.g, {super.key});

  @override
  State<MascaradeBoard> createState() => _MascaradeBoardState();
}

class _MascaradeBoardState extends State<MascaradeBoard> {
  int _selectedSwapTarget = -1;
  int _selectedCenterIdx = -1;
  int _selectedWitchTarget = -1;

  GameContext get g => widget.g;

  String _roleName(List<Map> catalog, int id) {
    if (id < 0 || id >= catalog.length) return '❓ 暗置身份';
    return '${catalog[id]['name']} (${catalog[id]['title']})';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final phase = (v['phase'] as String?) ?? 'action';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final coins = ((v['coins'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final courthouse = (v['courthouse'] as num?)?.toInt() ?? 0;
    final visibleRoles = ((v['visibleRoles'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final centerCount = (v['centerCount'] as num?)?.toInt() ?? 0;
    final peekedRole = (v['peekedRole'] as num?)?.toInt();
    final claimer = (v['claimer'] as num?)?.toInt() ?? -1;
    final claimedRole = (v['claimedRole'] as num?)?.toInt() ?? -1;
    final responseTurn = (v['responseTurn'] as num?)?.toInt() ?? -1;
    final lastRevealed = (v['lastRevealed'] as Map?)?.cast<String, dynamic>() ?? const {};
    final lastEvent = (v['lastEvent'] as String?) ?? '';
    final catalog = ((v['rolesCatalog'] as List?) ?? const []).cast<Map>();
    final placings = ((v['placings'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();

    final isMyAction = !g.over && phase == 'action' && turn == g.seat;
    final isMyChallenge = !g.over && phase == 'challenge' && responseTurn == g.seat;

    if (_selectedSwapTarget < 0 || _selectedSwapTarget == g.seat) {
      _selectedSwapTarget = (g.seat >= 0 ? (g.seat + 1) % g.players : 0);
    }
    if (_selectedWitchTarget < 0 || _selectedWitchTarget == g.seat) {
      _selectedWitchTarget = (g.seat >= 0 ? (g.seat + 1) % g.players : 0);
    }

    String statusText;
    if (g.over) {
      statusText = '舞会落幕！查看最终财富与身份';
    } else if (phase == 'challenge') {
      final rName = _roleName(catalog, claimedRole);
      statusText = isMyChallenge
          ? '${g.name(claimer)} 宣称是【$rName】，你要质疑还是放行？'
          : '等待 ${g.name(responseTurn)} 对 ${g.name(claimer)} 的【$rName】宣称表态…';
    } else {
      statusText = isMyAction ? '轮到你行动：宣告角色 / 桌下换牌 / 秘密看牌' : '等待 ${g.name(turn)} 执行舞会行动…';
    }

    return Container(
      color: g.table,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBar(statusText, highlight: isMyAction || isMyChallenge),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade900,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '🏛️ 法院罚金池: $courthouse 金币 · 中央牌: $centerCount 张',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    if (lastEvent.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        lastEvent,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85)),
                      ),
                    ],
                    if (peekedRole != null && peekedRole >= 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '👁️ 你秘密查看的当前身份卡是：【${_roleName(catalog, peekedRole)}】',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
                        ),
                      ),
                    ],
                    if (g.over) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: ResultBanner(
                          '假面舞会终局',
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var s = 0; s < g.players; s++)
                                Text(
                                  '${g.name(s)}：🪙 ${s < coins.length ? coins[s] : 0} 金币 · '
                                  '身份 ${_roleName(catalog, s < visibleRoles.length ? visibleRoles[s] : -1)} '
                                  '${s < placings.length && placings[s] == 1 ? "🏆" : ""}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Players Grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in g.seatsFromMe())
                          _buildPlayerSeat(
                            cs: cs,
                            seat: s,
                            coinCnt: s < coins.length ? coins[s] : 0,
                            roleId: s < visibleRoles.length ? visibleRoles[s] : -1,
                            revealedId: (lastRevealed['$s'] as num?)?.toInt(),
                            catalog: catalog,
                            isActive: !g.over && ((phase == 'action' && s == turn) || (phase == 'challenge' && s == responseTurn)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isMyChallenge) _buildChallengeBar(cs, claimer, claimedRole, catalog),
                    if (isMyAction) _buildActionPanel(cs, catalog, centerCount),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerSeat({
    required ColorScheme cs,
    required int seat,
    required int coinCnt,
    required int roleId,
    required int? revealedId,
    required List<Map> catalog,
    required bool isActive,
  }) {
    final roleText = _roleName(catalog, roleId);
    final revText = revealedId != null ? '刚亮牌: ${_roleName(catalog, revealedId)}' : null;

    return Container(
      width: 225,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? cs.primary : cs.outline.withValues(alpha: 0.3),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          g.tag(
            seat,
            active: isActive,
            sub: '🪙 $coinCnt / 13 金币',
            size: 30,
          ),
          const SizedBox(height: 4),
          Text(
            '身份卡: $roleText',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: roleId >= 0 ? cs.primary : cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
          if (revText != null)
            Text(
              revText,
              style: TextStyle(fontSize: 11, color: cs.tertiary),
            ),
        ],
      ),
    );
  }

  Widget _buildChallengeBar(ColorScheme cs, int claimer, int claimedRole, List<Map> catalog) {
    final rName = _roleName(catalog, claimedRole);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '🎭 ${g.name(claimer)} 宣称自己是【$rName】！',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          FilledButton.icon(
            onPressed: () => g.act({'type': 'challenge'}),
            icon: const Icon(Icons.gavel, size: 16),
            label: const Text('质疑：不，我才是！'),
          ),
          OutlinedButton.icon(
            onPressed: () => g.act({'type': 'pass'}),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('放行 (不质疑)'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel(ColorScheme cs, List<Map> catalog, int centerCount) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('① 宣告角色能力 (无需看牌即可诈唬)：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              OutlinedButton.icon(
                onPressed: () => g.act({'type': 'peek'}),
                icon: const Icon(Icons.visibility, size: 15),
                label: const Text('② 秘密看自己的牌'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in catalog)
                ActionChip(
                  label: Text('${r['name']} (${r['desc']})', style: const TextStyle(fontSize: 11)),
                  onPressed: () => g.act({
                    'type': 'claim',
                    'role': r['id'],
                    if (r['id'] == 5) 'target': _selectedWitchTarget,
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('③ 桌下真假换牌（选一名对手或中央牌，然后选【真换】或【假换】）：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var s = 0; s < g.players; s++)
                if (s != g.seat)
                  ChoiceChip(
                    label: Text(g.name(s)),
                    selected: _selectedCenterIdx < 0 && _selectedSwapTarget == s,
                    onSelected: (_) => setState(() {
                      _selectedCenterIdx = -1;
                      _selectedSwapTarget = s;
                      _selectedWitchTarget = s;
                    }),
                  ),
              for (var c = 0; c < centerCount; c++)
                ChoiceChip(
                  label: Text('中央牌 #${c + 1}'),
                  selected: _selectedCenterIdx == c,
                  onSelected: (_) => setState(() => _selectedCenterIdx = c),
                ),
              FilledButton.tonal(
                onPressed: () => g.act({
                  'type': 'swap',
                  if (_selectedCenterIdx >= 0) 'center': _selectedCenterIdx else 'target': _selectedSwapTarget,
                  'doSwap': true,
                }),
                child: const Text('真换 (互换位置)'),
              ),
              OutlinedButton(
                onPressed: () => g.act({
                  'type': 'swap',
                  if (_selectedCenterIdx >= 0) 'center': _selectedCenterIdx else 'target': _selectedSwapTarget,
                  'doSwap': false,
                }),
                child: const Text('假换 (保持原位)'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
