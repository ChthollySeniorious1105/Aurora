import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro18/marrakech.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class MarrakechBoard extends StatefulWidget {
  final GameContext g;
  const MarrakechBoard(this.g, {super.key});

  @override
  State<MarrakechBoard> createState() => _MarrakechBoardState();
}

class _MarrakechBoardState extends State<MarrakechBoard> {
  int _selR1 = -1;
  int _selC1 = -1;

  static const List<Color> _rugColors = [
    Color(0xFFD32F2F), // 0: 🟥 红毯商
    Color(0xFF1976D2), // 1: 🟦 蓝毯商
    Color(0xFF388E3C), // 2: 🟩 绿毯商
    Color(0xFF7B1FA2), // 3: 🟪 紫毯商
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = asInt(v['round'], 1);
    final turn = asInt(v['turn'], 0);
    final phase = asStr(v['phase'], 'orient');
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final assamR = asInt(v['assamR'], 3);
    final assamC = asInt(v['assamC'], 3);
    final assamDir = asInt(v['assamDir'], 0);
    final assamDirName = asStr(v['assamDirName'], '北');
    final assamDirArrow = asStr(v['assamDirArrow'], '⬆️');
    final lastRoll = asInt(v['lastRoll'], 0);
    final lastTribute = asInt(v['lastTribute'], 0);
    final grid = (v['grid'] as List?) ?? const [];
    final legalPlacements = (v['legalPlacements'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    final isMyTurn = !over && g.seat == turn;
    if (phase != 'place') {
      _selR1 = -1;
      _selC1 = -1;
    }

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
                                    ? (phase == 'orient'
                                        ? '轮到你！阶段1：为阿萨姆选择方向(左转/直行/右转)并掷拖鞋骰 · $lastAction'
                                        : '轮到你！阶段2：在阿萨姆周围选择2格铺设地毯 · $lastAction')
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
                          '🕌第 $round 轮 · ${phase == "orient" ? "转向移动" : "铺设地毯"}',
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
                        final cn = asInt(pd['coins'], 30);
                        final vis = asInt(pd['visibleRugs'], 0);
                        final rl = asInt(pd['rugsLeft'], 0);
                        final em = asStr(pd['emoji'], '🟥');
                        return g.tag(
                          s,
                          active: s == turn,
                          sub: '⭐$sc分 · 🪙$cn · $em可见$vis格 · 剩$rl毯',
                          size: 26,
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
                                flex: 7,
                                child: _buildBazaarGrid(
                                  grid,
                                  assamR,
                                  assamC,
                                  assamDirArrow,
                                  legalPlacements,
                                  isMyTurn && phase == 'place',
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: _buildControlPanel(
                                  assamR,
                                  assamC,
                                  assamDir,
                                  assamDirName,
                                  assamDirArrow,
                                  lastRoll,
                                  lastTribute,
                                  phase,
                                  legalPlacements,
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
                                child: _buildBazaarGrid(
                                  grid,
                                  assamR,
                                  assamC,
                                  assamDirArrow,
                                  legalPlacements,
                                  isMyTurn && phase == 'place',
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 4,
                                child: _buildControlPanel(
                                  assamR,
                                  assamC,
                                  assamDir,
                                  assamDirName,
                                  assamDirArrow,
                                  lastRoll,
                                  lastTribute,
                                  phase,
                                  legalPlacements,
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
                '摩洛哥集市终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  bool _isPairLegal(
      List<dynamic> legalPlacements, int r1, int c1, int r2, int c2) {
    for (final raw in legalPlacements) {
      final m = (raw as Map).cast<String, dynamic>();
      final mr1 = asInt(m['r1'], -1);
      final mc1 = asInt(m['c1'], -1);
      final mr2 = asInt(m['r2'], -1);
      final mc2 = asInt(m['c2'], -1);
      if ((mr1 == r1 && mc1 == c1 && mr2 == r2 && mc2 == c2) ||
          (mr1 == r2 && mc1 == c2 && mr2 == r1 && mc2 == c1)) {
        return true;
      }
    }
    return false;
  }

  bool _isCellInAnyLegal(List<dynamic> legalPlacements, int r, int c) {
    for (final raw in legalPlacements) {
      final m = (raw as Map).cast<String, dynamic>();
      if ((asInt(m['r1'], -1) == r && asInt(m['c1'], -1) == c) ||
          (asInt(m['r2'], -1) == r && asInt(m['c2'], -1) == c)) {
        return true;
      }
    }
    return false;
  }

  Widget _buildBazaarGrid(
    List<dynamic> grid,
    int assamR,
    int assamC,
    String assamDirArrow,
    List<dynamic> legalPlacements,
    bool canPlaceHere,
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
              _selR1 >= 0
                  ? '🕌 7×7 摩洛哥露天集市 (已选起点 ($_selR1,$_selC1)，请点击相邻目标格完成铺毯)'
                  : '🕌 7×7 摩洛哥露天集市 (👳阿萨姆位于 ($assamR,$assamC) $assamDirArrow · 边界带 U 型折返轨)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < MarrakechGame.size; r++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        children: [
                          for (var c = 0; c < MarrakechGame.size; c++)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                child: _buildBazaarCell(
                                  r,
                                  c,
                                  (r < grid.length &&
                                          c < (grid[r] as List).length)
                                      ? (grid[r] as List)[c]
                                          as Map<String, dynamic>?
                                      : null,
                                  assamR == r && assamC == c,
                                  assamDirArrow,
                                  legalPlacements,
                                  canPlaceHere,
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
        ],
      ),
    );
  }

  Widget _buildBazaarCell(
    int r,
    int c,
    Map<String, dynamic>? rugCell,
    bool hasAssam,
    String assamDirArrow,
    List<dynamic> legalPlacements,
    bool canPlaceHere,
    ColorScheme cs,
  ) {
    final isFirstSelected = _selR1 == r && _selC1 == c;
    final canCompleteSecond = canPlaceHere &&
        _selR1 >= 0 &&
        _isPairLegal(legalPlacements, _selR1, _selC1, r, c);
    final canStartFirst =
        canPlaceHere && _selR1 < 0 && _isCellInAnyLegal(legalPlacements, r, c);

    Color bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.45);
    Color borderColor = cs.outline.withValues(alpha: 0.25);
    double borderWidth = 1;

    if (rugCell != null) {
      final owner = asInt(rugCell['owner'], 0);
      final rCol = _rugColors[owner % _rugColors.length];
      bgColor = rCol.withValues(alpha: 0.28);
      borderColor = rCol;
      borderWidth = 1.4;
    }

    if (hasAssam) {
      bgColor = Colors.amber.withValues(alpha: 0.35);
      borderColor = Colors.amber.shade800;
      borderWidth = 2;
    } else if (isFirstSelected) {
      borderColor = Colors.amberAccent;
      borderWidth = 2.2;
    } else if (canCompleteSecond) {
      borderColor = Colors.greenAccent.shade700;
      borderWidth = 2;
    } else if (canStartFirst) {
      borderColor = cs.primary;
      borderWidth = 1.5;
    }

    return GestureDetector(
      onTap: !canPlaceHere || hasAssam
          ? null
          : () {
              if (_selR1 < 0) {
                if (_isCellInAnyLegal(legalPlacements, r, c)) {
                  setState(() {
                    _selR1 = r;
                    _selC1 = c;
                  });
                }
              } else if (_selR1 == r && _selC1 == c) {
                setState(() {
                  _selR1 = -1;
                  _selC1 = -1;
                });
              } else if (_isPairLegal(legalPlacements, _selR1, _selC1, r, c)) {
                final r1 = _selR1;
                final c1 = _selC1;
                setState(() {
                  _selR1 = -1;
                  _selC1 = -1;
                });
                widget.g.act({
                  'type': 'place_rug',
                  'r1': r1,
                  'c1': c1,
                  'r2': r,
                  'c2': c,
                });
              } else if (_isCellInAnyLegal(legalPlacements, r, c)) {
                setState(() {
                  _selR1 = r;
                  _selC1 = c;
                });
              }
            },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasAssam)
                Text(
                  '👳$assamDirArrow',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                )
              else if (rugCell != null)
                Text(
                  '${rugCell['emoji']}#${rugCell['rugId']}',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold),
                )
              else
                Text(
                  '($r,$c)',
                  style: TextStyle(
                    fontSize: 9,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              if (rugCell != null)
                Text(
                  'P${asInt(rugCell['owner'], 0) + 1}',
                  style: const TextStyle(fontSize: 8),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel(
    int assamR,
    int assamC,
    int assamDir,
    String assamDirName,
    String assamDirArrow,
    int lastRoll,
    int lastTribute,
    String phase,
    List<dynamic> legalPlacements,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final leftDir = (assamDir + 3) % 4;
    final rightDir = (assamDir + 1) % 4;

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
              '👳 阿萨姆位置: ($assamR,$assamC) 朝向:$assamDirArrow$assamDirName · 上次拖鞋骰:${lastRoll > 0 ? "$lastRoll步" : "未掷"} · 过路费:$lastTribute🪙',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 4),
          if (phase == 'orient') ...[
            const Text(
              '阶段 1：选择阿萨姆前进方向并投掷拖鞋骰 [1,2,2,3,3,4]（严禁 180° 掉头）：',
              style: TextStyle(fontSize: 10),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _buildOrientBtn(
                    label:
                        '↰ 左转90° (${marrakechDirArrows[leftDir]}${marrakechDirNames[leftDir]})',
                    delta: -1,
                    enabled: isMyTurn,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildOrientBtn(
                    label:
                        '⬆️ 直行 (${marrakechDirArrows[assamDir]}${marrakechDirNames[assamDir]})',
                    delta: 0,
                    enabled: isMyTurn,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildOrientBtn(
                    label:
                        '↱ 右转90° (${marrakechDirArrows[rightDir]}${marrakechDirNames[rightDir]})',
                    delta: 1,
                    enabled: isMyTurn,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              '阶段 2：点击下方任意合法 1×2 铺毯方案（或直接在左侧棋盘连点 2 格）：',
              style: TextStyle(fontSize: 10),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final raw in legalPlacements)
                      Builder(
                        builder: (context) {
                          final m = (raw as Map).cast<String, dynamic>();
                          final r1 = asInt(m['r1'], 0);
                          final c1 = asInt(m['c1'], 0);
                          final r2 = asInt(m['r2'], 0);
                          final c2 = asInt(m['c2'], 0);
                          return InkWell(
                            onTap: !isMyTurn
                                ? null
                                : () => widget.g.act({
                                      'type': 'place_rug',
                                      'r1': r1,
                                      'c1': c1,
                                      'r2': r2,
                                      'c2': c2,
                                    }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: cs.primary.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                '🧶($r1,$c1)-($r2,$c2)',
                                style: const TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrientBtn({
    required String label,
    required int delta,
    required bool enabled,
    required Color color,
  }) {
    return InkWell(
      onTap: !enabled
          ? null
          : () => widget.g.act({
                'type': 'orient_assam',
                'turnDelta': delta,
              }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.85) : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
