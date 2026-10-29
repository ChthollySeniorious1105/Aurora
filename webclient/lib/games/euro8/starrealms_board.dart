import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _factionIcons = ['🛸', '🦠', '⭐', '⚙️', '🚀'];
const List<Color> _factionColors = [
  Color(0xFF1565C0), // 贸易联盟 blue
  Color(0xFF2E7D32), // 异虫 green
  Color(0xFFF9A825), // 星际帝国 yellow
  Color(0xFFC62828), // 机械神教 red
  Color(0xFF546E7A), // 中立 grey
];

class StarRealmsBoard extends StatelessWidget {
  final GameContext g;
  const StarRealmsBoard(this.g, {super.key});

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final turnCount = (v['turnCount'] as num?)?.toInt() ?? 1;
    final over = v['over'] == true || g.over;
    final tradePool = (v['tradePool'] as num?)?.toInt() ?? 0;
    final combatPool = (v['combatPool'] as num?)?.toInt() ?? 0;
    final scrapCredits = (v['scrapCredits'] as num?)?.toInt() ?? 0;
    final explorersLeft = (v['explorersLeft'] as num?)?.toInt() ?? 0;
    final tradeDeckCount = (v['tradeDeckCount'] as num?)?.toInt() ?? 0;
    final lastAction = (v['lastAction'] as String?) ?? '';

    final authority = (v['authority'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [50, 50];
    final tradeRow = (v['tradeRow'] as List?) ?? const [];
    final myHand = (v['myHand'] as List?)?.cast<Map>() ?? const [];
    final playersData = (v['playersData'] as List?)?.cast<Map>() ?? const [];

    final me = g.seat >= 0 && g.seat < 2 ? g.seat : 0;
    final opp = 1 - me;
    final isMyTurn = !over && g.seat >= 0 && g.seat == turn;

    final myData = me < playersData.length ? playersData[me] : const {};
    final oppData = opp < playersData.length ? playersData[opp] : const {};

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBar(
                      over
                          ? '星域奇航 已结束'
                          : (isMyTurn ? '你的指挥回合 — 出牌、购舰、开火！' : '等待 ${g.name(turn)} 行动…'),
                      highlight: isMyTurn,
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('回合 $turnCount · 💰贸易:$tradePool · ⚔️战力:$combatPool${scrapCredits > 0 ? " · 🗑️报废:$scrapCredits" : ""}'),
                    ),
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
                      _buildOpponentZone(cs, opp, oppData, authority[opp], isMyTurn, combatPool),
                      const SizedBox(height: 8),
                      _buildTradeRowSection(cs, tradeRow, explorersLeft, tradeDeckCount, isMyTurn, tradePool),
                      const SizedBox(height: 8),
                      _buildMyZone(cs, me, myData, myHand, authority[me], isMyTurn, tradePool, combatPool, scrapCredits),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (over && v['result'] != null)
            Align(
              alignment: Alignment.center,
              child: _buildResultBanner(v['result'] as Map, authority),
            ),
        ],
      ),
    );
  }

  Widget _buildOpponentZone(
    ColorScheme cs,
    int opp,
    Map oppData,
    int oppAuth,
    bool isMyTurn,
    int combatPool,
  ) {
    final bases = (oppData['bases'] as List?)?.cast<Map>() ?? const [];
    final inPlay = (oppData['inPlay'] as List?)?.cast<Map>() ?? const [];
    final handCount = (oppData['handCount'] as num?)?.toInt() ?? 0;
    final deckCount = (oppData['deckCount'] as num?)?.toInt() ?? 0;
    final discardCount = (oppData['discardCount'] as num?)?.toInt() ?? 0;
    final hasOutpost = oppData['hasOutpost'] == true;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              g.tag(
                opp,
                active: g.view['turn'] == opp && !g.over,
                sub: '🛡️母舰权威: $oppAuth · 手牌:$handCount · 牌库:$deckCount · 弃牌:$discardCount',
                size: 32,
              ),
              if (isMyTurn && combatPool > 0)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                  icon: const Icon(Icons.bolt, size: 16),
                  label: Text(
                    hasOutpost ? '需先摧毁敌方前哨站！' : '攻击母舰 (-$combatPool🛡️)',
                  ),
                  onPressed: !hasOutpost ? () => g.act({'type': 'attack_player'}) : null,
                ),
            ],
          ),
          if (bases.isNotEmpty || inPlay.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var i = 0; i < bases.length; i++)
                  Builder(builder: (context) {
                    final b = bases[i];
                    final isOutpost = b['isOutpost'] == true;
                    final def = (b['defense'] as num?)?.toInt() ?? 0;
                    final canAttack = isMyTurn && combatPool >= def && (isOutpost || !hasOutpost);
                    return _buildCardChip(
                      cs,
                      b,
                      actionLabel: canAttack ? '⚔️摧毁(-$def)' : null,
                      onTap: canAttack ? () => g.act({'type': 'attack_base', 'index': i}) : null,
                    );
                  }),
                for (final c in inPlay) _buildCardChip(cs, c),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTradeRowSection(
    ColorScheme cs,
    List tradeRow,
    int explorersLeft,
    int tradeDeckCount,
    bool isMyTurn,
    int tradePool,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
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
              Text('🌌 中央星际贸易行 (牌库余 $tradeDeckCount 张)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
              if (explorersLeft > 0)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text('🚀 购入探索者 (2💰 · 余$explorersLeft)'),
                  onPressed: isMyTurn && tradePool >= 2 ? () => g.act({'type': 'buy_explorer'}) : null,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var s = 0; s < tradeRow.length; s++)
                if (tradeRow[s] != null)
                  Builder(builder: (context) {
                    final card = tradeRow[s] as Map;
                    final cost = (card['cost'] as num?)?.toInt() ?? 0;
                    final canBuy = isMyTurn && tradePool >= cost;
                    return _buildCardChip(
                      cs,
                      card,
                      showCost: true,
                      actionLabel: canBuy ? '购入($cost💰)' : null,
                      onTap: canBuy ? () => g.act({'type': 'buy', 'slot': s}) : null,
                    );
                  }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyZone(
    ColorScheme cs,
    int me,
    Map myData,
    List<Map> myHand,
    int myAuth,
    bool isMyTurn,
    int tradePool,
    int combatPool,
    int scrapCredits,
  ) {
    final bases = (myData['bases'] as List?)?.cast<Map>() ?? const [];
    final inPlay = (myData['inPlay'] as List?)?.cast<Map>() ?? const [];
    final discard = (myData['discard'] as List?)?.cast<Map>() ?? const [];
    final deckCount = (myData['deckCount'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMyTurn ? cs.primary : cs.outline.withValues(alpha: 0.3), width: isMyTurn ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              g.tag(
                me,
                active: isMyTurn,
                sub: '🛡️母舰权威: $myAuth · 牌库:$deckCount · 弃牌:${discard.length}',
                size: 32,
              ),
              if (isMyTurn)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (myHand.isNotEmpty)
                      FilledButton.icon(
                        icon: const Icon(Icons.flash_on, size: 16),
                        label: Text('一键打出全部手牌 (${myHand.length})'),
                        onPressed: () => g.act({'type': 'play_all'}),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.skip_next, size: 16),
                      label: const Text('结束回合'),
                      onPressed: () => g.act({'type': 'end_turn'}),
                    ),
                  ],
                ),
            ],
          ),
          if (bases.isNotEmpty || inPlay.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('🛸 我方在场基地与本回合已出战舰：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final b in bases) _buildCardChip(cs, b),
                for (var i = 0; i < inPlay.length; i++)
                  Builder(builder: (context) {
                    final c = inPlay[i];
                    final scrapCombat = (c['selfScrapCombat'] as num?)?.toInt() ?? 0;
                    return _buildCardChip(
                      cs,
                      c,
                      actionLabel: isMyTurn && scrapCombat > 0 ? '报废+$scrapCombat⚔️' : null,
                      onTap: isMyTurn && scrapCombat > 0
                          ? () => g.act({'type': 'scrap_in_play', 'index': i})
                          : null,
                    );
                  }),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text('🃏 我方手牌 (${myHand.length} 张)：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
          const SizedBox(height: 4),
          if (myHand.isEmpty)
            Text('手牌已全部打出', style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var i = 0; i < myHand.length; i++)
                  _buildCardChip(
                    cs,
                    myHand[i],
                    actionLabel: isMyTurn ? '打出' : null,
                    onTap: isMyTurn ? () => g.act({'type': 'play', 'index': i}) : null,
                  ),
              ],
            ),
          if (isMyTurn && scrapCredits > 0 && discard.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('🗑️ 机械神教报废技能 (剩余 $scrapCredits 次) — 点击弃牌堆卡牌永久销毁：',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var i = 0; i < discard.length; i++)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text('销毁 ${discard[i]['name']}'),
                    onPressed: () => g.act({'type': 'scrap_card', 'zone': 'discard', 'index': i}),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardChip(
    ColorScheme cs,
    Map card, {
    bool showCost = false,
    String? actionLabel,
    VoidCallback? onTap,
  }) {
    final faction = (card['faction'] as num?)?.toInt() ?? 4;
    final name = (card['name'] as String?) ?? '';
    final cost = (card['cost'] as num?)?.toInt() ?? 0;
    final isBase = card['isBase'] == true;
    final isOutpost = card['isOutpost'] == true;
    final defense = (card['defense'] as num?)?.toInt() ?? 0;

    final effects = <String>[];
    final tr = (card['trade'] as num?)?.toInt() ?? 0;
    final cb = (card['combat'] as num?)?.toInt() ?? 0;
    final hl = (card['heal'] as num?)?.toInt() ?? 0;
    final dr = (card['draw'] as num?)?.toInt() ?? 0;
    final sc = (card['scrapPower'] as num?)?.toInt() ?? 0;
    if (tr > 0) effects.add('+$tr💰');
    if (cb > 0) effects.add('+$cb⚔️');
    if (hl > 0) effects.add('+$hl🛡️');
    if (dr > 0) effects.add('抽$dr');
    if (sc > 0) effects.add('报废$sc');

    final allyEffects = <String>[];
    final atr = (card['allyTrade'] as num?)?.toInt() ?? 0;
    final acb = (card['allyCombat'] as num?)?.toInt() ?? 0;
    final ahl = (card['allyHeal'] as num?)?.toInt() ?? 0;
    final adr = (card['allyDraw'] as num?)?.toInt() ?? 0;
    if (atr > 0) allyEffects.add('+$atr💰');
    if (acb > 0) allyEffects.add('+$acb⚔️');
    if (ahl > 0) allyEffects.add('+$ahl🛡️');
    if (adr > 0) allyEffects.add('抽$adr');

    final color = _factionColors[faction % 5];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onTap != null ? Colors.amberAccent : Colors.white.withValues(alpha: 0.45),
            width: onTap != null ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${_factionIcons[faction % 5]} $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                if (showCost)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$cost💰', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            if (isBase)
              Text(
                isOutpost ? '🛡️前哨站 (防御$defense)' : '🛰️基地 (防御$defense)',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            Text(
              effects.join(' '),
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            if (allyEffects.isNotEmpty)
              Text(
                '同盟: ${allyEffects.join(" ")}',
                style: const TextStyle(color: Colors.yellowAccent, fontSize: 10),
              ),
            if (actionLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultBanner(Map res, List<int> authority) {
    final winner = (res['winner'] as num?)?.toInt() ?? 0;
    return ResultBanner(
      '${g.name(winner)} 击毁敌方母舰获胜！',
      child: Text('${g.name(0)}: ${authority[0]} 🛡️  vs  ${g.name(1)}: ${authority[1]} 🛡️'),
    );
  }
}
