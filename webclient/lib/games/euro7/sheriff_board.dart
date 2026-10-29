import 'dart:math';

import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro7/sheriff.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<Color> _goodColors = [
  Color(0xFF38A169), // 0: 苹果
  Color(0xFFD69E2E), // 1: 奶酪
  Color(0xFFDD6B20), // 2: 面包
  Color(0xFF3182CE), // 3: 鸡肉
  Color(0xFFC53030), // 4: 胡椒
  Color(0xFFB7791F), // 5: 蜂蜜酒
  Color(0xFF805AD5), // 6: 丝绸
  Color(0xFF2D3748), // 7: 弩箭
];

class SheriffBoard extends StatefulWidget {
  final GameContext g;
  const SheriffBoard(this.g, {super.key});

  @override
  State<SheriffBoard> createState() => _SheriffBoardState();
}

class _SheriffBoardState extends State<SheriffBoard> {
  final Set<int> _selectedHand = {};
  int _declaredType = 0;
  int _bribe = 0;
  String _stateKey = '';

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final sheriff = asInt(v['sheriff'], 0);
    final round = asInt(v['round'], 1);
    final maxRounds = asInt(v['maxRounds'], 3);
    final phase = asStr(v['phase'], 'pack');
    final currentMerchant = asInt(v['currentMerchant'], -1);
    final lastLog = asStr(v['lastLog']);

    final hand = asIntList(v['hand']);
    final myBag = asIntList(v['myBag']);
    final playersList = [
      for (final p in (v['players'] as List? ?? const [])) (p as Map).cast<String, dynamic>(),
    ];

    final me = g.seat;
    final myPlayerMap = me >= 0 && me < playersList.length ? playersList[me] : null;
    final myGold = myPlayerMap != null ? asInt(myPlayerMap['gold'], 50) : 0;
    final myPacked = myPlayerMap != null && myPlayerMap['packed'] == true;

    final canPack = !g.over && !g.replay && phase == 'pack' && me >= 0 && me != sheriff && !myPacked;
    final canInspect = !g.over && !g.replay && phase == 'inspect' && me == sheriff && currentMerchant >= 0;

    final curKey = '$round-$phase-$sheriff-$currentMerchant-$myPacked-${hand.length}';
    if (_stateKey != curKey) {
      _stateKey = curKey;
      _selectedHand.clear();
      _bribe = _bribe.clamp(0, min(10, myGold));
    }

    String statusText;
    if (g.over) {
      statusText = lastLog.isNotEmpty ? lastLog : '游戏已结束';
    } else if (phase == 'pack') {
      if (me == sheriff) {
        statusText = '第 $round/$maxRounds 轮 · 你是本轮警长，等待商人们装袋申报…';
      } else if (canPack) {
        statusText = '第 $round/$maxRounds 轮 · 请选择 1～5 张手牌装袋，并申报合法货物与贿赂金额';
      } else {
        statusText = '第 $round/$maxRounds 轮 · 等待其他商人完成装袋申报…';
      }
    } else {
      if (canInspect) {
        statusText = '你是警长：请决定对 ${g.name(currentMerchant)} 的货袋「放行」或「开袋检查」！';
      } else {
        statusText = '警长 ${g.name(sheriff)} 正在盘查 ${currentMerchant >= 0 ? g.name(currentMerchant) : ''} 的货袋';
      }
    }

    Widget? banner;
    if (g.over) {
      final res = (v['result'] as Map?)?.cast<String, dynamic>();
      final scores = res != null ? asIntList(res['scores']) : <int>[];
      final bonuses = res != null ? asIntList(res['bonuses']) : <int>[];
      final pl = res != null ? asIntList(res['placings']) : <int>[];
      final winners = [
        for (var s = 0; s < pl.length; s++)
          if (pl[s] == 1) g.name(s),
      ];
      banner = ResultBanner(
        winners.isEmpty ? '游戏结束' : '${winners.join('、')} 获胜！',
        child: scores.isEmpty
            ? null
            : Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  for (var s = 0; s < scores.length; s++)
                    Text(
                      '${g.name(s)}: ${scores[s]}金${s < bonuses.length && bonuses[s] > 0 ? ' (含头衔+${bonuses[s]})' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600 || constraints.maxHeight < 480;
        return Stack(
          children: [
            Container(
              color: g.table,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: StatusBar(statusText, highlight: canPack || canInspect)),
                    const SizedBox(height: 6),
                    // Players & Market Stands
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final p in playersList)
                          Builder(builder: (_) {
                            final s = asInt(p['seat'], 0);
                            final isSheriffSeat = s == sheriff;
                            final isInspectTarget = phase == 'inspect' && s == currentMerchant;
                            final pGold = asInt(p['gold'], 0);
                            final isPacked = p['packed'] == true;
                            final bagCnt = asInt(p['bagCount'], 0);
                            final decl = p['declared'] != null ? asInt(p['declared'], 0).clamp(0, 3) : null;
                            final pBribe = asInt(p['bribe'], 0);
                            final legalStand = asIntList(p['legalStand']);
                            final contraCnt = asInt(p['contrabandCount'], 0);

                            final standParts = <String>[
                              for (var gId = 0; gId < 4 && gId < legalStand.length; gId++)
                                if (legalStand[gId] > 0) '${kSheriffGoods[gId].name}×${legalStand[gId]}',
                              if (contraCnt > 0) '违禁×$contraCnt',
                            ];

                            return Container(
                              width: compact ? 172 : 210,
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: cs.surface.withValues(alpha: isInspectTarget ? 0.92 : 0.76),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isInspectTarget
                                      ? Colors.amberAccent
                                      : (isSheriffSeat ? cs.primary : cs.outline.withValues(alpha: 0.3)),
                                  width: isInspectTarget || isSheriffSeat ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  g.tag(
                                    s,
                                    active: isInspectTarget || (phase == 'pack' && s != sheriff && !isPacked),
                                    size: 28,
                                    sub: '${isSheriffSeat ? '【警长】' : '【商人】'} $pGold金',
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    standParts.isEmpty ? '摊位：暂无货物' : '摊位：${standParts.join(' ')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10.5, color: cs.onSurface.withValues(alpha: 0.85)),
                                  ),
                                  if (!isSheriffSeat && isPacked && decl != null) ...[
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '货袋: $bagCnt件 · 申报「${kSheriffGoods[decl].name}」· 贿赂$pBribe金',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: cs.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Sheriff Inspection Panel when in 'inspect' phase
                    if (phase == 'inspect' && currentMerchant >= 0 && currentMerchant < playersList.length)
                      Builder(builder: (_) {
                        final mp = playersList[currentMerchant];
                        final bagCnt = asInt(mp['bagCount'], 0);
                        final decl = asInt(mp['declared'], 0).clamp(0, 3);
                        final pBribe = asInt(mp['bribe'], 0);
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amberAccent, width: 1.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '当前受检货袋：${g.name(currentMerchant)} 装了 $bagCnt 张牌，声称是「${kSheriffGoods[decl].name}」，提供贿赂 $pBribe 金币',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              if (canInspect) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 6,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () => g.act({'type': 'pass'}),
                                      icon: const Icon(Icons.check_circle_outline, size: 16),
                                      label: Text('放行货袋${pBribe > 0 ? ' (收下 $pBribe 金贿赂)' : ''}'),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: () => g.act({'type': 'open'}),
                                      icon: const Icon(Icons.search, size: 16),
                                      label: const Text('开袋检查！'),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    // My Hand & Merchant Pack Controls
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lastLog,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8)),
                          ),
                          const SizedBox(height: 6),
                          if (me >= 0) ...[
                            Text(
                              canPack
                                  ? '我的手牌（点选 1～5 张装入货袋，已选 ${_selectedHand.length}/5）'
                                  : '我的手牌${myBag.isNotEmpty ? '（本轮已装袋：${myBag.map((c) => kSheriffGoods[c].name).join('、')}）' : ''}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (var i = 0; i < hand.length; i++)
                                  Builder(builder: (_) {
                                    final gId = hand[i].clamp(0, 7);
                                    final def = kSheriffGoods[gId];
                                    final col = _goodColors[gId];
                                    final sel = _selectedHand.contains(i);
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: canPack
                                          ? () {
                                              setState(() {
                                                if (sel) {
                                                  _selectedHand.remove(i);
                                                } else if (_selectedHand.length < 5) {
                                                  _selectedHand.add(i);
                                                  if (def.legal) _declaredType = def.id;
                                                }
                                              });
                                            }
                                          : null,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 140),
                                        width: 86,
                                        transform: Matrix4.translationValues(0, sel ? -5 : 0, 0),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: col.withValues(alpha: sel ? 0.36 : 0.16),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: sel ? Colors.amberAccent : col,
                                            width: sel ? 2 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '${def.name}${def.legal ? '' : ' [违禁]'}',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '价值${def.value} · 罚金${def.penalty}',
                                              style: TextStyle(fontSize: 9.5, color: cs.onSurface.withValues(alpha: 0.8)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                            if (canPack) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text('申报合法货物:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  for (var d = 0; d < 4; d++)
                                    ChoiceChip(
                                      label: Text(kSheriffGoods[d].name, style: const TextStyle(fontSize: 11)),
                                      selected: _declaredType == d,
                                      visualDensity: VisualDensity.compact,
                                      onSelected: (_) => setState(() => _declaredType = d),
                                    ),
                                  const SizedBox(width: 4),
                                  Text('贿赂: $_bribe金', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _bribe > 0 ? () => setState(() => _bribe--) : null,
                                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _bribe < min(10, myGold) ? () => setState(() => _bribe++) : null,
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _selectedHand.isNotEmpty
                                        ? () {
                                            g.act({
                                              'type': 'pack',
                                              'indices': _selectedHand.toList(),
                                              'declared': _declaredType,
                                              'bribe': _bribe,
                                            });
                                            setState(() => _selectedHand.clear());
                                          }
                                        : null,
                                    icon: const Icon(Icons.inventory_2_outlined, size: 16),
                                    label: Text('确认装袋 (${_selectedHand.length}件)'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (banner != null) Align(alignment: Alignment.topCenter, child: banner),
          ],
        );
      },
    );
  }
}
