import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro17/verdant.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class VerdantBoard extends StatefulWidget {
  final GameContext g;
  const VerdantBoard(this.g, {super.key});

  @override
  State<VerdantBoard> createState() => _VerdantBoardState();
}

class _VerdantBoardState extends State<VerdantBoard> {
  int _selectedCol = 0;
  bool _pickPlant = true;
  int _fertR = -1;
  int _fertC = -1;
  int? _inspectSeat;

  static const List<Color> _cardColors = [
    Color(0xFF2E7D32), // 0: 🟩 观叶
    Color(0xFFC62828), // 1: 🟥 开花
    Color(0xFFF9A825), // 2: 🟨 多肉
    Color(0xFF1565C0), // 3: 🟦 奇珍
    Color(0xFF6A1B9A), // 4: 🟪 爬藤
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = asInt(v['round'], 1);
    final maxTurns = asInt(v['maxTurns'], 13);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final plantRow = (v['plantRow'] as List?) ?? const [];
    final tokenRow = (v['tokenRow'] as List?) ?? const [];
    final roomRow = (v['roomRow'] as List?) ?? const [];
    final plantThumbs = (v['plantThumbs'] as List?) ?? const [];
    final roomThumbs = (v['roomThumbs'] as List?) ?? const [];
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
    final myThumbs = asInt(myData['thumbs'], 0);

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
                                    ? '轮到你！先选市场列(植物/房间)，再点3×5棋盘对应奇偶空位放置 · $lastAction'
                                    : '等待 ${g.name(turn)} 行动 · $lastAction'),
                            highlight: isMyTurn,
                          ),
                        ),
                      ),
                      if (isMyTurn && myThumbs >= 2) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => g.act({
                            'type': 'use_thumb',
                            'r': _fertR,
                            'c': _fertC,
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '👍×2 催熟(+1🌿)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🪴第 $round/$maxTurns 回合',
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
                        final pvp = asInt(pd['plantVp'], 0);
                        final rvp = asInt(pd['roomBonusVp'], 0);
                        final tvp = asInt(pd['tokenVp'], 0);
                        final th = asInt(pd['thumbs'], 0);
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
                              sub: '⭐$sc分 (🪴$pvp 🛋️$rvp 🐱$tvp) · 👍$th',
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
                                child: _buildMarketPanel(
                                  plantRow,
                                  tokenRow,
                                  roomRow,
                                  plantThumbs,
                                  roomThumbs,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildHomeGridPanel(
                                  viewSeat,
                                  viewData,
                                  isMyTurn && viewSeat == mySeat,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildMarketPanel(
                                  plantRow,
                                  tokenRow,
                                  roomRow,
                                  plantThumbs,
                                  roomThumbs,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildHomeGridPanel(
                                  viewSeat,
                                  viewData,
                                  isMyTurn && viewSeat == mySeat,
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
                '绿意盎然终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarketPanel(
    List<dynamic> plantRow,
    List<dynamic> tokenRow,
    List<dynamic> roomRow,
    List<dynamic> plantThumbs,
    List<dynamic> roomThumbs,
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
              '🛒 园艺市场 (当前已选: 第${_selectedCol + 1}列 ${_pickPlant ? "🌱植物卡" : "🛋️房间卡"} + 中间园艺标记)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 3),
          // Row 0: Plants
          Expanded(
            flex: 4,
            child: Row(
              children: [
                for (var col = 0; col < 4; col++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _buildMarketPlantCard(
                        col,
                        col < plantRow.length
                            ? plantRow[col] as Map<String, dynamic>?
                            : null,
                        col < plantThumbs.length ? asInt(plantThumbs[col], 0) : 0,
                        cs,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          // Row 1: Tokens
          Expanded(
            flex: 2,
            child: Row(
              children: [
                for (var col = 0; col < 4; col++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _buildMarketTokenCard(
                        col,
                        col < tokenRow.length
                            ? tokenRow[col] as Map<String, dynamic>?
                            : null,
                        cs,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          // Row 2: Rooms
          Expanded(
            flex: 4,
            child: Row(
              children: [
                for (var col = 0; col < 4; col++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _buildMarketRoomCard(
                        col,
                        col < roomRow.length
                            ? roomRow[col] as Map<String, dynamic>?
                            : null,
                        col < roomThumbs.length ? asInt(roomThumbs[col], 0) : 0,
                        cs,
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

  Widget _buildMarketPlantCard(
    int col,
    Map<String, dynamic>? card,
    int thumbsOnCard,
    ColorScheme cs,
  ) {
    if (card == null) return const SizedBox();
    final sel = _selectedCol == col && _pickPlant;
    final colIdx = asInt(card['color'], 0).clamp(0, 4);
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCol = col;
        _pickPlant = true;
      }),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: sel
              ? _cardColors[colIdx].withValues(alpha: 0.25)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? Colors.amber : _cardColors[colIdx],
            width: sel ? 2 : 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${card['colorEmoji']}${card['emoji']} ${card['name']}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              Text(
                '需:${card['lightEmoji']} · 目标:🌿${card['targetVerdancy']} · ⭐${card['vp']}分',
                style: const TextStyle(fontSize: 10),
              ),
              if (thumbsOnCard > 0)
                Text(
                  '附带 👍×$thumbsOnCard',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketTokenCard(
    int col,
    Map<String, dynamic>? tok,
    ColorScheme cs,
  ) {
    if (tok == null) return const SizedBox();
    final sel = _selectedCol == col;
    final isFert = asBool(tok['isFertilizer']);
    return GestureDetector(
      onTap: () => setState(() => _selectedCol = col),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: sel
              ? Colors.teal.withValues(alpha: 0.22)
              : cs.secondaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: sel ? Colors.amber : cs.outline.withValues(alpha: 0.3),
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${tok['emoji']}${tok['name']} (${isFert ? "+2🌿" : "+2⭐"})',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketRoomCard(
    int col,
    Map<String, dynamic>? card,
    int thumbsOnCard,
    ColorScheme cs,
  ) {
    if (card == null) return const SizedBox();
    final sel = _selectedCol == col && !_pickPlant;
    final colIdx = asInt(card['color'], 0).clamp(0, 4);
    final le = (card['lightEmojis'] as List?) ?? const ['☀️', '⛅', '🌙', '☀️'];
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCol = col;
        _pickPlant = false;
      }),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: sel
              ? _cardColors[colIdx].withValues(alpha: 0.25)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? Colors.amber : _cardColors[colIdx],
            width: sel ? 2 : 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${card['colorEmoji']}${card['emoji']} ${card['name']}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              Text(
                '窗[北${le[0]} 东${le[1]} 南${le[2]} 西${le[3]}]',
                style: const TextStyle(fontSize: 10),
              ),
              if (thumbsOnCard > 0)
                Text(
                  '附带 👍×$thumbsOnCard',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeGridPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    bool canActHere,
    ColorScheme cs,
  ) {
    final grid = (viewData['grid'] as List?) ?? const [];

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
              '🏡 ${widget.g.name(viewSeat)} 的 3×5 棋盘格家居 (偶格🌱植物 / 奇格🛋️房间 · 点选空位放置)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              children: [
                for (var r = 0; r < VerdantGame.rows; r++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Row(
                        children: [
                          for (var c = 0; c < VerdantGame.cols; c++)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 1.5),
                                child: _buildGridCell(
                                  r,
                                  c,
                                  (r < grid.length &&
                                          c < (grid[r] as List).length)
                                      ? (grid[r] as List)[c]
                                          as Map<String, dynamic>?
                                      : null,
                                  canActHere,
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

  Widget _buildGridCell(
    int r,
    int c,
    Map<String, dynamic>? cell,
    bool canActHere,
    ColorScheme cs,
  ) {
    final plantSlot = VerdantGame.isPlantCell(r, c);
    if (cell == null) {
      final matchesPick =
          (plantSlot && _pickPlant) || (!plantSlot && !_pickPlant);
      return GestureDetector(
        onTap: (!canActHere || !matchesPick)
            ? null
            : () {
                widget.g.act({
                  'type': 'draft',
                  'col': _selectedCol,
                  'pickPlant': _pickPlant,
                  'r': r,
                  'c': c,
                  'fertR': _fertR >= 0 ? _fertR : r,
                  'fertC': _fertC >= 0 ? _fertC : c,
                });
              },
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: (canActHere && matchesPick)
                ? cs.primaryContainer.withValues(alpha: 0.65)
                : cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (canActHere && matchesPick)
                  ? cs.primary
                  : cs.outline.withValues(alpha: 0.25),
              width: (canActHere && matchesPick) ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  plantSlot ? '🌱植物位' : '🛋️房间位',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '($r,$c)',
                  style: TextStyle(
                    fontSize: 9,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final kind = asStr(cell['kind']);
    final colIdx = asInt(cell['color'], 0).clamp(0, 4);

    if (kind == 'plant') {
      final potted = asBool(cell['potted']);
      final curV = asInt(cell['currentVerdancy'], 0);
      final tarV = asInt(cell['targetVerdancy'], 3);
      final fertSel = _fertR == r && _fertC == c;
      return GestureDetector(
        onTap: () => setState(() {
          _fertR = r;
          _fertC = c;
        }),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: _cardColors[colIdx].withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: fertSel ? Colors.amber : _cardColors[colIdx],
              width: fertSel ? 2 : 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${cell['colorEmoji']}${cell['emoji']}${cell['name']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 10),
                ),
                Text(
                  potted
                      ? '🏺已装盆 ⭐${cell['vp']}+${cell['potBonus']}'
                      : '需${cell['lightEmoji']} · 🌿$curV/$tarV (⭐${cell['vp']})',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: potted ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final le = (cell['lightEmojis'] as List?) ?? const ['☀️', '⛅', '🌙', '☀️'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _cardColors[colIdx].withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardColors[colIdx], width: 1.2),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${cell['colorEmoji']}${cell['emoji']}${cell['name']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
            ),
            Text(
              '北${le[0]} 东${le[1]} 南${le[2]} 西${le[3]}',
              style: const TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
