import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class HighSocietyBoard extends StatefulWidget {
  final GameContext g;
  const HighSocietyBoard(this.g, {super.key});

  @override
  State<HighSocietyBoard> createState() => _HighSocietyBoardState();
}

class _HighSocietyBoardState extends State<HighSocietyBoard> {
  final Set<int> _selectedMoney = {};

  GameContext get g => widget.g;

  @override
  void didUpdateWidget(covariant HighSocietyBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hand = ((g.view['myHand'] as List?) ?? const []).cast<int>().toSet();
    _selectedMoney.removeWhere((c) => !hand.contains(c));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final phase = (v['phase'] as String?) ?? 'auction';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final darkGreenCount = (v['darkGreenCount'] as num?)?.toInt() ?? 0;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final highestBid = (v['highestBid'] as num?)?.toInt() ?? 0;
    final currentCard = v['currentCard'] as Map?;
    final inAuction = ((v['inAuction'] as List?) ?? const []).map((e) => e == true).toList();
    final bids = ((v['bids'] as List?) ?? const []).map((e) => ((e as List?) ?? const []).cast<int>()).toList();
    final bidSums = ((v['bidSums'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final handCounts = ((v['handCounts'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final myHand = ((v['myHand'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final myMoney = (v['myMoney'] as num?)?.toInt() ?? 0;
    final won = ((v['won'] as List?) ?? const []).map((e) => ((e as List?) ?? const []).cast<Map>()).toList();
    final prestige = ((v['prestige'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final lastEvent = (v['lastEvent'] as String?) ?? '';
    final poorest = ((v['poorest'] as List?) ?? const []).map((e) => e == true).toList();
    final moneyLeft = ((v['moneyLeft'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final placings = ((v['placings'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();

    final isMyTurn = !g.over && g.seat == turn;
    final myCurrentBid = (g.seat >= 0 && g.seat < bidSums.length) ? bidSums[g.seat] : 0;
    final selectedSum = _selectedMoney.fold<int>(0, (a, b) => a + b);
    final newTotalBid = myCurrentBid + selectedSum;
    final canBid = isMyTurn && phase == 'auction' && _selectedMoney.isNotEmpty && newTotalBid > highestBid;

    String statusText;
    if (g.over) {
      statusText = '游戏结束！最穷玩家已破产出局';
    } else if (phase == 'faux_pas') {
      statusText = isMyTurn ? '请点击弃掉 1 张你已获得的奢华品卡' : '等待 ${g.name(turn)} 选择弃掉 1 张奢华品卡';
    } else {
      statusText = isMyTurn ? '轮到你竞拍：选择支票加注或放弃' : '等待 ${g.name(turn)} 竞拍操作…';
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
                    // Header row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBar(statusText, highlight: isMyTurn),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _pill(
                              cs,
                              '深绿终局牌: $darkGreenCount / 4',
                              Colors.teal.shade800,
                              Colors.white,
                            ),
                            const SizedBox(width: 6),
                            _pill(cs, '牌堆: $deckCount', cs.surfaceContainerHighest, cs.onSurface),
                          ],
                        ),
                      ],
                    ),
                    if (lastEvent.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        lastEvent,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
                      ),
                    ],
                    if (g.over) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: ResultBanner(
                          _buildResultTitle(placings),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var s = 0; s < g.players; s++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    '${g.name(s)}：声望 ${s < prestige.length ? prestige[s] : 0} | 剩余 ${s < moneyLeft.length ? moneyLeft[s] : 0}k 法郎 '
                                    '${(s < poorest.length && poorest[s]) ? "【破产出局】" : (s < placings.length && placings[s] == 1 ? "🏆 获胜" : "")}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: (s < placings.length && placings[s] == 1) ? FontWeight.bold : FontWeight.normal,
                                      color: (s < poorest.length && poorest[s]) ? cs.error : cs.onSurface,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Center Status Card Spotlight
                    if (currentCard != null) _buildCenterCard(cs, currentCard, highestBid),
                    const SizedBox(height: 8),
                    // Players grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in g.seatsFromMe())
                          _buildPlayerCard(
                            cs: cs,
                            seat: s,
                            isTurn: !g.over && s == turn,
                            inAuc: s < inAuction.length ? inAuction[s] : false,
                            bidCards: s < bids.length ? bids[s] : const [],
                            bidTotal: s < bidSums.length ? bidSums[s] : 0,
                            handCnt: s < handCounts.length ? handCounts[s] : 0,
                            wonCards: s < won.length ? won[s] : const [],
                            prest: s < prestige.length ? prestige[s] : 0,
                            isPoor: g.over && s < poorest.length && poorest[s],
                            canDiscardLuxury: isMyTurn && phase == 'faux_pas' && s == g.seat,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // My hand & controls
                    if (g.seat >= 0 && !g.over)
                      _buildMyControls(
                        cs: cs,
                        myHand: myHand,
                        myMoney: myMoney,
                        myCurrentBid: myCurrentBid,
                        newTotalBid: newTotalBid,
                        highestBid: highestBid,
                        isMyTurn: isMyTurn,
                        phase: phase,
                        canBid: canBid,
                        isDisgrace: currentCard?['kind'] == 'disgrace',
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _buildResultTitle(List<int> placings) {
    final winners = <String>[];
    for (var s = 0; s < placings.length; s++) {
      if (placings[s] == 1) winners.add(g.name(s));
    }
    return winners.isEmpty ? '拍卖终局' : '${winners.join("、")} 荣登社交之巅！';
  }

  Widget _pill(ColorScheme cs, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _buildCenterCard(ColorScheme cs, Map card, int highestBid) {
    final kind = card['kind'] as String? ?? 'luxury';
    final darkGreen = card['darkGreen'] == true;
    final name = card['name'] as String? ?? '';
    final desc = card['desc'] as String? ?? '';
    final isDisgrace = kind == 'disgrace';

    final bgColor = darkGreen
        ? const Color(0xFF0F4C3A)
        : (isDisgrace ? const Color(0xFF6E1E2A) : const Color(0xFF5C4318));
    final borderColor = darkGreen
        ? Colors.greenAccent
        : (isDisgrace ? Colors.redAccent : Colors.amber);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isDisgrace ? Icons.warning_amber_rounded : (darkGreen ? Icons.workspace_premium : Icons.diamond),
                    color: borderColor,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '当前最高出价: ${highestBid}k 法郎',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: borderColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$desc · ${isDisgrace ? "反向拍卖（先Pass者拿牌保钱，他人失钱）" : "正向拍卖（最高价得牌，Pass收回支票）"}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard({
    required ColorScheme cs,
    required int seat,
    required bool isTurn,
    required bool inAuc,
    required List<int> bidCards,
    required int bidTotal,
    required int handCnt,
    required List<Map> wonCards,
    required int prest,
    required bool isPoor,
    required bool canDiscardLuxury,
  }) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTurn ? cs.primary : (isPoor ? cs.error : cs.outline.withValues(alpha: 0.3)),
          width: isTurn ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          g.tag(
            seat,
            active: isTurn,
            sub: '声望 $prest · 手牌 $handCnt 张${inAuc ? "" : " (已放弃)"}',
            size: 30,
          ),
          const SizedBox(height: 6),
          Text(
            '桌面出价: ${bidTotal}k ${bidCards.isEmpty ? "(无)" : "[${bidCards.join(", ")}]"}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
          ),
          if (wonCards.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final c in wonCards)
                  InkWell(
                    onTap: (canDiscardLuxury && c['kind'] == 'luxury')
                        ? () => g.act({'type': 'discard_luxury', 'card': c['id']})
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c['darkGreen'] == true
                            ? Colors.teal.shade700
                            : (c['kind'] == 'disgrace' ? Colors.red.shade700 : Colors.amber.shade800),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${c['name']}',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMyControls({
    required ColorScheme cs,
    required List<int> myHand,
    required int myMoney,
    required int myCurrentBid,
    required int newTotalBid,
    required int highestBid,
    required bool isMyTurn,
    required String phase,
    required bool canBid,
    required bool isDisgrace,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '我的支票手牌（剩余总额 ${myMoney}k 法郎 · 桌面已出 ${myCurrentBid}k）',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in myHand)
                FilterChip(
                  label: Text('${c}k'),
                  selected: _selectedMoney.contains(c),
                  onSelected: isMyTurn && phase == 'auction'
                      ? (sel) {
                          setState(() {
                            if (sel) {
                              _selectedMoney.add(c);
                            } else {
                              _selectedMoney.remove(c);
                            }
                          });
                        }
                      : null,
                ),
            ],
          ),
          if (isMyTurn && phase == 'auction') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                FilledButton.icon(
                  onPressed: canBid
                      ? () {
                          final chosen = _selectedMoney.toList()..sort();
                          setState(() => _selectedMoney.clear());
                          g.act({'type': 'bid', 'cards': chosen});
                        }
                      : null,
                  icon: const Icon(Icons.gavel, size: 16),
                  label: Text('加注至 ${newTotalBid}k (需 > ${highestBid}k)'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _selectedMoney.clear());
                    g.act({'type': 'pass'});
                  },
                  icon: const Icon(Icons.pan_tool_alt, size: 16),
                  label: Text(isDisgrace ? '跳过并收下厄运卡 (保住支票)' : '放弃竞拍 (收回桌面支票)'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
