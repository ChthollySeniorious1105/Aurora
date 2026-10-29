import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro17/santa_monica.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class SantaMonicaBoard extends StatefulWidget {
  final GameContext g;
  const SantaMonicaBoard(this.g, {super.key});

  @override
  State<SantaMonicaBoard> createState() => _SantaMonicaBoardState();
}

class _SantaMonicaBoardState extends State<SantaMonicaBoard> {
  int _selectedRow = 1;
  int _selectedCol = 0;
  int? _inspectSeat;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = asInt(v['round'], 1);
    final maxDrafts = asInt(v['maxDrafts'], 8);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final display = (v['display'] as List?) ?? const [];
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
    final myShells = asInt(myData['shells'], 0);
    final myMeeples =
        asInt(myData['vipPool'], 0) + asInt(myData['touristPool'], 0);

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
                                    ? '轮到你！点选展示排卡牌放入2×6海岸，或点击版图卡牌耗1🐚填满⭕活动环 · $lastAction'
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
                          '🏖️第 $round/$maxDrafts 轮',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pList.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, s) {
                        final pd = (pList[s] as Map).cast<String, dynamic>();
                        final sc = asInt(pd['score'], 0);
                        final rvp = asInt(pd['ringVp'], 0);
                        final cvp = asInt(pd['chainVp'], 0);
                        final avp = asInt(pd['adjVp'], 0);
                        final sh = asInt(pd['shells'], 0);
                        final vp = asInt(pd['vipPool'], 0);
                        final tp = asInt(pd['touristPool'], 0);
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
                              sub:
                                  '⭐$sc分 (⭕$rvp 贯$cvp 邻$avp) · 🐚$sh 🕶️$vp 📸$tp',
                              size: 26,
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
                                flex: 5,
                                child: _buildDisplayPanel(
                                  display,
                                  myShells,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildTableauPanel(
                                  viewSeat,
                                  viewData,
                                  isMyTurn && viewSeat == mySeat,
                                  myShells,
                                  myMeeples,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildDisplayPanel(
                                  display,
                                  myShells,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildTableauPanel(
                                  viewSeat,
                                  viewData,
                                  isMyTurn && viewSeat == mySeat,
                                  myShells,
                                  myMeeples,
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
                '圣莫尼卡海滩终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDisplayPanel(
    List<dynamic> display,
    int myShells,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '🌊 中央 2×4 海岸展示排 (底层免费拿取 / 顶层需 2🐚 · 当前已选: ${_selectedRow == 0 ? "顶层(2🐚)" : "底层(免费)"}第${_selectedCol + 1}列)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < SantaMonicaGame.displayRows; r++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          r == 0 ? '顶层\n(2🐚)' : '底层\n(免费)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: r == 0 ? Colors.orange : cs.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    for (var c = 0; c < SantaMonicaGame.displayCols; c++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _buildDisplayCard(
                            r,
                            c,
                            (r < display.length &&
                                    c < (display[r] as List).length)
                                ? (display[r] as List)[c]
                                    as Map<String, dynamic>?
                                : null,
                            myShells,
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
    );
  }

  Widget _buildDisplayCard(
    int r,
    int c,
    Map<String, dynamic>? card,
    int myShells,
    ColorScheme cs,
  ) {
    if (card == null) return const SizedBox();
    final sel = _selectedRow == r && _selectedCol == c;
    final isBeach = asInt(card['rowType'], 0) == 0;
    final canSelect = r == 1 || myShells >= 2;
    return GestureDetector(
      onTap: !canSelect
          ? null
          : () => setState(() {
                _selectedRow = r;
                _selectedCol = c;
              }),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: sel
              ? Colors.amber.withValues(alpha: 0.28)
              : (isBeach
                  ? Colors.cyan.withValues(alpha: 0.16)
                  : Colors.orange.withValues(alpha: 0.16)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel
                ? Colors.amber
                : (isBeach ? Colors.cyan : Colors.deepOrangeAccent),
            width: sel ? 2 : 1.2,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${card['rowEmoji']}${card['emoji']} ${card['name']}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              Text(
                '地标:${card['tagEmoji']} · +${card['gainShells']}🐚 ${asInt(card['spawnVip'], 0) > 0 ? "+🕶️" : ""}${asInt(card['spawnTourists'], 0) > 0 ? "+📸×${card['spawnTourists']}" : ""}',
                style: const TextStyle(fontSize: 10),
              ),
              Text(
                '⭕需${card['ringCap']}人➔+${card['ringVp']}⭐ · 邻${card['adjTagEmoji']}+${card['adjVp']}⭐',
                style: TextStyle(
                  fontSize: 9,
                  color: cs.onSurface.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableauPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    bool canActHere,
    int myShells,
    int myMeeples,
    ColorScheme cs,
  ) {
    final tab = (viewData['tableau'] as List?) ?? const [];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '🏝️ ${widget.g.name(viewSeat)} 的 2×6 海岸长廊 (点空位放入已选卡 · 点已有卡耗1🐚将🕶️/📸移入⭕活动环)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < SantaMonicaGame.tableauRows; r++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          r == 0 ? '🏖️\n海滩排' : '🛣️\n街区排',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    for (var c = 0; c < SantaMonicaGame.tableauCols; c++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: _buildTableauCell(
                            r,
                            c,
                            (r < tab.length && c < (tab[r] as List).length)
                                ? (tab[r] as List)[c] as Map<String, dynamic>?
                                : null,
                            canActHere,
                            myShells,
                            myMeeples,
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
    );
  }

  Widget _buildTableauCell(
    int r,
    int c,
    Map<String, dynamic>? card,
    bool canActHere,
    int myShells,
    int myMeeples,
    ColorScheme cs,
  ) {
    if (card == null) {
      return GestureDetector(
        onTap: !canActHere
            ? null
            : () {
                widget.g.act({
                  'type': 'draft',
                  'row': _selectedRow,
                  'col': _selectedCol,
                  'slotC': c,
                });
              },
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: canActHere
                ? cs.primaryContainer.withValues(alpha: 0.55)
                : cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: canActHere
                  ? cs.primary
                  : cs.outline.withValues(alpha: 0.25),
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r == 0 ? '🏖️海滩位' : '🛣️街区位',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold),
                ),
                Text(
                  '第${c + 1}列',
                  style: const TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final ringDone = asBool(card['ringDone']);
    final canSpendShell =
        canActHere && !ringDone && myShells >= 1 && myMeeples > 0;
    return GestureDetector(
      onTap: !canSpendShell
          ? null
          : () {
              widget.g.act({
                'type': 'spend_shell',
                'r': r,
                'c': c,
              });
            },
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: ringDone
              ? Colors.green.withValues(alpha: 0.22)
              : cs.secondaryContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: ringDone
                ? Colors.green
                : (canSpendShell
                    ? Colors.amber
                    : cs.outline.withValues(alpha: 0.35)),
            width: (ringDone || canSpendShell) ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${card['tagEmoji']}${card['emoji']}${card['name']}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
              ),
              Text(
                ringDone
                    ? '✅活动环已满 (+${card['ringVp']}⭐)'
                    : '⭕${card['ringFilled']}/${card['ringCap']} (+${card['ringVp']}⭐)',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: ringDone ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                '邻${card['adjTagEmoji']}+${card['adjVp']}⭐',
                style: const TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
