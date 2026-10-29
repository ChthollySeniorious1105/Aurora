import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

int _asInt(Object? v, [int d = 0]) => v is num ? v.toInt() : d;
List<int> _asInts(Object? v) => [for (final x in (v as List? ?? const [])) (x as num).toInt()];
List<String> _asStrs(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];

const Map<String, String> _suitLabel = {'S': '♠黑桃', 'H': '♥红桃', 'D': '♦方片', 'C': '♣梅花'};

Widget _pill(String text, Color color, {double fontSize = 11}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
          fontFamilyFallback: kFontFallback,
        ),
      ),
    );

class DurakBoard extends StatelessWidget {
  final GameContext g;
  const DurakBoard(this.g, {super.key});

  Map<String, dynamic> get v => g.view;

  @override
  Widget build(BuildContext context) {
    final me = g.seat;
    final phase = '${v['phase'] ?? 'attack'}';
    final boutNo = _asInt(v['boutNo'], 1);
    final attacker = _asInt(v['attacker'], 0);
    final defender = _asInt(v['defender'], 1);
    final turn = _asInt(v['turn'], 0);
    final trumpCard = '${v['trumpCard'] ?? ''}';
    final trumpSuit = '${v['trumpSuit'] ?? 'S'}';
    final talonCount = _asInt(v['talonCount'], 0);
    final discardCount = _asInt(v['discardCount'], 0);
    final hand = _asStrs(v['hand']);
    final legal = _asStrs(v['legalCards']).toSet();
    final handCounts = _asInts(v['handCounts']);
    final finishedOrder = _asInts(v['finishedOrder']);
    final table = (v['table'] as List?) ?? const [];

    final myTurn = me >= 0 && turn == me && !g.over;
    final seats = g.seatsFromMe();
    final bottomSeat = seats.first;
    final others = seats.sublist(1);

    String statusText;
    if (phase == 'attack') {
      if (myTurn) {
        statusText = table.isEmpty
            ? '你是进攻方：请打出一张手牌发起进攻'
            : '防守方已挡住，可继续追加同点数牌进攻，或点击“结束进攻”';
      } else {
        statusText = table.isEmpty
            ? '等待进攻方 ${g.name(attacker)} 出牌进攻 ${g.name(defender)}…'
            : '等待进攻方 ${g.name(attacker)} 追加进攻或结束本轮…';
      }
    } else if (phase == 'defend') {
      if (myTurn) {
        statusText = '你是防守方：请打出更大同花色牌或主牌防守，或点击“放弃收牌”';
      } else {
        statusText = '等待防守方 ${g.name(defender)} 防守…';
      }
    } else {
      statusText = '对局结束';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final compact = h < 480;
        final cardW = (w / (w > h ? 15 : 8.5)).clamp(28.0, compact ? 42.0 : 56.0);

        return Stack(fit: StackFit.expand, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(children: [
              // Header bar
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _pill('杜拉克 · 第 $boutNo 轮', Colors.brown.shade800),
                  const SizedBox(width: 6),
                  _pill('主花色: ${_suitLabel[trumpSuit] ?? trumpSuit}',
                      trumpSuit == 'H' || trumpSuit == 'D' ? Colors.red.shade700 : Colors.grey.shade900),
                  const SizedBox(width: 6),
                  _pill('牌堆: $talonCount 张', Colors.indigo.shade700),
                  const SizedBox(width: 6),
                  _pill('弃牌堆: $discardCount 张', Colors.blueGrey.shade700),
                  const SizedBox(width: 6),
                  _pill('攻: ${g.name(attacker)} ⚔️ 守: ${g.name(defender)}', Colors.deepOrange.shade800),
                ]),
              ),
              const SizedBox(height: 4),
              // Opponents row
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final s in others)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildPlayerTag(s, turn, attacker, defender, handCounts, finishedOrder, compact),
                    ),
                ]),
              ),
              const SizedBox(height: 4),
              // Center table area
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(compact ? 6 : 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildTableArea(cardW, talonCount, trumpCard, trumpSuit, table),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Status bar + action buttons
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  StatusBar(statusText, highlight: myTurn),
                  if (myTurn && phase == 'attack' && table.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.teal.shade700),
                      onPressed: () => g.act({'type': 'done'}),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('结束进攻 (Done)'),
                    ),
                  ],
                  if (myTurn && phase == 'defend') ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
                      onPressed: () => g.act({'type': 'take'}),
                      icon: const Icon(Icons.pan_tool_alt, size: 16),
                      label: const Text('放弃并收牌 (Take)'),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 4),
              // Bottom player tag
              FittedBox(
                fit: BoxFit.scaleDown,
                child: _buildPlayerTag(bottomSeat, turn, attacker, defender, handCounts, finishedOrder, compact),
              ),
              if (me >= 0 && hand.isNotEmpty) ...[
                const SizedBox(height: 4),
                SizedBox(
                  height: cardW * 1.4 + (compact ? 6 : 10),
                  width: w - 24,
                  child: Center(
                    child: OverlapRow(
                      itemWidth: cardW,
                      children: [
                        for (final c in hand)
                          PlayingCard(
                            c,
                            width: cardW,
                            dim: myTurn && !legal.contains(c),
                            onTap: myTurn && legal.contains(c)
                                ? () => g.act({'type': phase == 'attack' ? 'attack' : 'defend', 'card': c})
                                : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ]),
          ),
          if (g.over)
            Center(
              child: SingleChildScrollView(
                child: _buildOverBanner(finishedOrder),
              ),
            ),
        ]);
      }),
    );
  }

  Widget _buildPlayerTag(
    int s,
    int turn,
    int attacker,
    int defender,
    List<int> handCounts,
    List<int> finishedOrder,
    bool compact,
  ) {
    final cnt = s < handCounts.length ? handCounts[s] : 0;
    final finIdx = finishedOrder.indexOf(s);
    String role = '';
    if (finIdx >= 0) {
      role = ' · 第${finIdx + 1}名脱身';
    } else if (s == attacker) {
      role = ' · ⚔️进攻';
    } else if (s == defender) {
      role = ' · 🛡️防守';
    }
    return g.tag(
      s,
      active: !g.over && turn == s,
      size: compact ? 24 : 30,
      sub: '手牌 $cnt 张$role',
    );
  }

  Widget _buildTableArea(
    double cardW,
    int talonCount,
    String trumpCard,
    String trumpSuit,
    List<dynamic> table,
  ) {
    final log = _asStrs(v['log']);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Talon & Trump card display
        Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: cardW * 1.5,
            height: cardW * 1.4,
            child: Stack(alignment: Alignment.center, children: [
              if (talonCount > 0 && trumpCard.isNotEmpty)
                Positioned(
                  right: 0,
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: PlayingCard(trumpCard, width: cardW * 0.85),
                  ),
                ),
              if (talonCount > 1)
                Positioned(
                  left: 0,
                  child: PlayingCard('back', width: cardW * 0.85, faceDown: true),
                ),
              if (talonCount == 0)
                Container(
                  width: cardW,
                  height: cardW * 1.3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white30, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _suitLabel[trumpSuit] ?? trumpSuit,
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 4),
          _pill(talonCount > 0 ? '牌堆 $talonCount 张 (底:$trumpCard)' : '牌堆已空 (主:${_suitLabel[trumpSuit]})',
              Colors.deepPurple.shade700),
        ]),
        const SizedBox(width: 24),
        // Table attack/defense bouts
        if (table.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              '桌面暂无交战牌 · 等待进攻方出牌',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          )
        else
          Wrap(spacing: 12, runSpacing: 8, children: [
            for (var i = 0; i < table.length; i++) _buildBoutPair(i + 1, table[i] as Map, cardW),
          ]),
      ]),
      if (log.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final line in (log.length > 2 ? log.sublist(log.length - 2) : log))
          Text(line, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    ]);
  }

  Widget _buildBoutPair(int idx, Map pair, double cardW) {
    final atk = '${pair['attack'] ?? ''}';
    final def = pair['defense'] as String?;
    return SizedBox(
      width: cardW * 1.35,
      height: cardW * 1.65,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: 0,
          top: 0,
          child: PlayingCard(atk, width: cardW),
        ),
        if (def != null && def.isNotEmpty)
          Positioned(
            right: 0,
            bottom: 0,
            child: PlayingCard(def, width: cardW),
          )
        else
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('待防', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
      ]),
    );
  }

  Widget _buildOverBanner(List<int> finishedOrder) {
    final loser = _asInt(v['durakLoser'], -1);
    final placings = _asInts(v['placings']);
    final title = loser >= 0 ? '🃏 游戏结束 · ${g.name(loser)} 成为最后的杜拉克（傻瓜）！' : '🏆 游戏结束 · 全员脱身！';
    return ResultBanner(
      title,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
          for (var s = 0; s < g.players; s++)
            _pill(
              s == loser
                  ? '🤡 杜拉克: ${g.name(s)}'
                  : '#${s < placings.length ? placings[s] : 1} ${g.name(s)}',
              s == loser ? Colors.red.shade800 : Colors.green.shade700,
              fontSize: 12,
            ),
        ]),
      ]),
    );
  }
}
