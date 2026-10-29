import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class KarubaBoard extends StatefulWidget {
  final GameContext g;
  const KarubaBoard(this.g, {super.key});

  @override
  State<KarubaBoard> createState() => _KarubaBoardState();
}

class _KarubaBoardState extends State<KarubaBoard> {
  int? _inspectSeat;
  int? _selectedAdv;

  static const List<Color> _advColors = [
    Color(0xFF1E88E5), // 0: 蓝
    Color(0xFFFBC02D), // 1: 黄
    Color(0xFF8D6E63), // 2: 棕
    Color(0xFF8E24AA), // 3: 紫
  ];

  static const List<String> _advNames = ['蓝', '黄', '棕', '紫'];

  static const List<(int, int)> _startCoords = [
    (1, -1),
    (4, -1),
    (6, 1),
    (6, 4),
  ];

  static const List<(int, int)> _templeCoords = [
    (-1, 4),
    (1, 6),
    (-1, 2),
    (4, 6),
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 0;
    final maxTiles = (v['maxTiles'] as num?)?.toInt() ?? 36;
    final currentTile = (v['currentTile'] as num?)?.toInt() ?? 1;
    final currentDirs =
        (v['currentDirs'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            const [0, 2];
    final currentGold = v['currentGold'] == true;
    final currentCrystal = v['currentCrystal'] == true;
    final maxSteps = (v['maxSteps'] as num?)?.toInt() ?? currentDirs.length;
    final acted =
        (v['acted'] as List?)?.map((e) => e == true).toList() ??
            List.filled(g.players, false);
    final scores =
        (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
            List.filled(g.players, 0);
    final templeTreasures = (v['templeTreasures'] as List?)
            ?.map((l) => (l as List).map((e) => (e as num).toInt()).toList())
            .toList() ??
        const [[5, 4, 3, 2], [5, 4, 3, 2], [5, 4, 3, 2], [5, 4, 3, 2]];
    final gridsRaw = (v['grids'] as List?) ?? const [];
    final advRRaw = (v['advR'] as List?) ?? const [];
    final advCRaw = (v['advC'] as List?) ?? const [];
    final inTempleRaw = (v['inTemple'] as List?) ?? const [];
    final legalMovesRaw = (v['legalMoves'] as List?) ?? const [];

    final mySeat = g.seat;
    final viewSeat = (_inspectSeat != null &&
            _inspectSeat! >= 0 &&
            _inspectSeat! < g.players)
        ? _inspectSeat!
        : (mySeat >= 0 && mySeat < g.players ? mySeat : 0);

    final canAct = !g.over && mySeat >= 0 && !acted[mySeat];

    final legalMoves = <List<Map<String, dynamic>>>[
      for (var a = 0; a < 4; a++)
        a < legalMovesRaw.length
            ? (legalMovesRaw[a] as List)
                .map((e) => (e as Map).cast<String, dynamic>())
                .toList()
            : const <Map<String, dynamic>>[],
    ];

    final statusText = g.over
        ? '卡鲁巴寻宝结束！'
        : '第 ${round + 1}/$maxTiles 轮 · 当前板块 #$currentTile（$maxSteps路口）· ${canAct ? "请放置板块或弃牌移动探险家" : "等待其他玩家行动"}';

    return Stack(
      children: [
        Container(
          color: g.table,
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              // Top bar: status + temple treasures
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBar(statusText, highlight: canAct),
                  for (var a = 0; a < 4; a++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _advColors[a],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_advNames[a]}神庙: ${templeTreasures[a].isEmpty ? "无" : templeTreasures[a].join("/")}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: a == 1 ? Colors.black87 : Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Player tags
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final s in g.seatsFromMe())
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _inspectSeat = s),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: viewSeat == s
                                  ? Border.all(color: Colors.amber, width: 2)
                                  : null,
                            ),
                            child: g.tag(
                              s,
                              active: !g.over && !acted[s],
                              sub:
                                  '${scores[s]}分 · ${acted[s] ? "已就绪✓" : "思考中"}',
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Main content: Current Tile + Action Mode + 6x6 Jungle Grid
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildControlBar(
                        cs,
                        currentTile: currentTile,
                        currentDirs: currentDirs,
                        currentGold: currentGold,
                        currentCrystal: currentCrystal,
                        maxSteps: maxSteps,
                        canAct: canAct,
                        legalMoves: legalMoves,
                      ),
                      const SizedBox(height: 8),
                      _buildJungleBoard(
                        cs,
                        viewSeat: viewSeat,
                        mySeat: mySeat,
                        canAct: canAct,
                        gridsRaw: gridsRaw,
                        advRRaw: advRRaw,
                        advCRaw: advCRaw,
                        inTempleRaw: inTempleRaw,
                        legalMoves: legalMoves,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (g.over)
          Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              child: ResultBanner(
                _winnerText(g, scores),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < g.players; s++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${g.name(s)}: ${scores[s]} 分',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _winnerText(GameContext g, List<int> scores) {
    if (scores.isEmpty) return '游戏结束';
    var best = scores.first;
    for (final s in scores) {
      if (s > best) best = s;
    }
    final winners = <String>[
      for (var i = 0; i < g.players; i++)
        if (scores[i] == best) g.name(i),
    ];
    return '${winners.join("、")} 获胜！（$best 分）';
  }

  Widget _buildControlBar(
    ColorScheme cs, {
    required int currentTile,
    required List<int> currentDirs,
    required bool currentGold,
    required bool currentCrystal,
    required int maxSteps,
    required bool canAct,
    required List<List<Map<String, dynamic>>> legalMoves,
  }) {
    final g = widget.g;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Current tile preview
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: CustomPaint(
                  painter: _JungleTilePainter(
                    tileId: currentTile,
                    dirs: currentDirs,
                    gold: currentGold,
                    crystal: currentCrystal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '当前板块 #$currentTile',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '弃牌可走 $maxSteps 步${currentGold ? " · 含金块(+2)" : currentCrystal ? " · 含水晶(+1)" : ""}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          if (canAct) ...[
            ChoiceChip(
              label: const Text('拼放板块'),
              selected: _selectedAdv == null,
              onSelected: (_) => setState(() => _selectedAdv = null),
            ),
            for (var a = 0; a < 4; a++)
              if (legalMoves[a].isNotEmpty)
                ChoiceChip(
                  label: Text('移动${_advNames[a]}探险家(${legalMoves[a].length})'),
                  selected: _selectedAdv == a,
                  selectedColor: _advColors[a].withValues(alpha: 0.45),
                  onSelected: (_) =>
                      setState(() => _selectedAdv = _selectedAdv == a ? null : a),
                ),
            if (_selectedAdv != null &&
                _selectedAdv! >= 0 &&
                _selectedAdv! < 4)
              for (final m in legalMoves[_selectedAdv!])
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _advColors[_selectedAdv!],
                    foregroundColor:
                        _selectedAdv == 1 ? Colors.black87 : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  onPressed: () {
                    final adv = _selectedAdv!;
                    setState(() => _selectedAdv = null);
                    g.act({
                      'type': 'move',
                      'adv': adv,
                      'targetR': m['r'],
                      'targetC': m['c'],
                    });
                  },
                  child: Text(
                    m['temple'] == true
                        ? '进入${_advNames[_selectedAdv!]}色神庙!'
                        : '移至(${(m['r'] as int) + 1},${(m['c'] as int) + 1})',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildJungleBoard(
    ColorScheme cs, {
    required int viewSeat,
    required int mySeat,
    required bool canAct,
    required List gridsRaw,
    required List advRRaw,
    required List advCRaw,
    required List inTempleRaw,
    required List<List<Map<String, dynamic>>> legalMoves,
  }) {
    final g = widget.g;
    final isMyBoard = viewSeat == mySeat;
    final seatGrid =
        viewSeat < gridsRaw.length ? (gridsRaw[viewSeat] as List) : const [];
    final seatAdvR = viewSeat < advRRaw.length
        ? (advRRaw[viewSeat] as List).map((e) => (e as num).toInt()).toList()
        : [for (final c in _startCoords) c.$1];
    final seatAdvC = viewSeat < advCRaw.length
        ? (advCRaw[viewSeat] as List).map((e) => (e as num).toInt()).toList()
        : [for (final c in _startCoords) c.$2];
    final seatInTemple = viewSeat < inTempleRaw.length
        ? (inTempleRaw[viewSeat] as List).map((e) => e == true).toList()
        : const [false, false, false, false];

    final activeMoves = (isMyBoard &&
            canAct &&
            _selectedAdv != null &&
            _selectedAdv! >= 0 &&
            _selectedAdv! < 4)
        ? legalMoves[_selectedAdv!]
        : const <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2E4E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade700, width: 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 8x8 visual matrix: r from -1..6, c from -1..6
            for (var r = -1; r <= 6; r++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = -1; c <= 6; c++)
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: _buildCoordCell(
                        r: r,
                        c: c,
                        isMyBoard: isMyBoard,
                        canAct: canAct,
                        seatGrid: seatGrid,
                        seatAdvR: seatAdvR,
                        seatAdvC: seatAdvC,
                        seatInTemple: seatInTemple,
                        activeMoves: activeMoves,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              '${g.name(viewSeat)} 的丛林岛屿（点击空格直接放置当前板块）',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordCell({
    required int r,
    required int c,
    required bool isMyBoard,
    required bool canAct,
    required List seatGrid,
    required List<int> seatAdvR,
    required List<int> seatAdvC,
    required List<bool> seatInTemple,
    required List<Map<String, dynamic>> activeMoves,
  }) {
    final g = widget.g;
    final isTarget = activeMoves.any((m) => m['r'] == r && m['c'] == c);

    // Check if this is one of the 4 Temples
    for (var a = 0; a < 4; a++) {
      if (_templeCoords[a] == (r, c)) {
        final arrived = seatInTemple[a];
        return GestureDetector(
          onTap: isTarget && _selectedAdv == a
              ? () {
                  setState(() => _selectedAdv = null);
                  g.act({
                    'type': 'move',
                    'adv': a,
                    'targetR': r,
                    'targetC': c,
                  });
                }
              : null,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _advColors[a],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isTarget ? Colors.amberAccent : Colors.white70,
                width: isTarget ? 3 : 1.5,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    arrived ? Icons.emoji_events : Icons.account_balance,
                    size: 18,
                    color: a == 1 ? Colors.black87 : Colors.white,
                  ),
                  Text(
                    arrived ? '${_advNames[a]}已达' : '${_advNames[a]}神庙',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: a == 1 ? Colors.black87 : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    // Check if this is one of the 4 Beach Starting Positions
    for (var a = 0; a < 4; a++) {
      if (_startCoords[a] == (r, c)) {
        final onBeach =
            !seatInTemple[a] && seatAdvR[a] == r && seatAdvC[a] == c;
        return GestureDetector(
          onTap: onBeach && isMyBoard && canAct
              ? () => setState(
                    () => _selectedAdv = _selectedAdv == a ? null : a,
                  )
              : null,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE6C280),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _selectedAdv == a ? Colors.amber : _advColors[a],
                width: _selectedAdv == a ? 3 : 1.5,
              ),
            ),
            child: Center(
              child: onBeach
                  ? _buildAdventurerToken(a)
                  : Text(
                      '${_advNames[a]}起点',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
            ),
          ),
        );
      }
    }

    // Outside 6x6 and not a start or temple
    if (r < 0 || r >= 6 || c < 0 || c >= 6) {
      return const SizedBox(width: 44, height: 44);
    }

    // Inside 6x6 Jungle Grid
    Map<String, dynamic>? tile;
    if (r < seatGrid.length) {
      final rowList = seatGrid[r] as List;
      if (c < rowList.length && rowList[c] != null) {
        tile = (rowList[c] as Map).cast<String, dynamic>();
      }
    }

    int? advHere;
    for (var a = 0; a < 4; a++) {
      if (!seatInTemple[a] && seatAdvR[a] == r && seatAdvC[a] == c) {
        advHere = a;
        break;
      }
    }

    final canPlaceHere =
        isMyBoard && canAct && _selectedAdv == null && tile == null;

    return GestureDetector(
      onTap: () {
        if (isTarget && _selectedAdv != null) {
          final adv = _selectedAdv!;
          setState(() => _selectedAdv = null);
          g.act({'type': 'move', 'adv': adv, 'targetR': r, 'targetC': c});
        } else if (canPlaceHere) {
          g.act({'type': 'place', 'r': r, 'c': c});
        } else if (advHere != null && isMyBoard && canAct) {
          setState(
            () => _selectedAdv = _selectedAdv == advHere ? null : advHere,
          );
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: tile != null
              ? const Color(0xFF3E6B2C)
              : const Color(0xFF4F7D3B).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isTarget
                ? Colors.amberAccent
                : canPlaceHere
                    ? Colors.lightGreenAccent.withValues(alpha: 0.6)
                    : Colors.white24,
            width: isTarget ? 2.5 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (tile != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: _JungleTilePainter(
                    tileId: (tile['id'] as num).toInt(),
                    dirs: (tile['dirs'] as List)
                        .map((e) => (e as num).toInt())
                        .toList(),
                    gold: tile['gold'] == true,
                    crystal: tile['crystal'] == true,
                  ),
                ),
              )
            else
              Text(
                '${r + 1},${c + 1}',
                style: const TextStyle(fontSize: 10, color: Colors.white30),
              ),
            if (advHere != null) _buildAdventurerToken(advHere),
          ],
        ),
      ),
    );
  }

  Widget _buildAdventurerToken(int a) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: _advColors[a],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
      ),
      child: Center(
        child: Text(
          _advNames[a],
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: a == 1 ? Colors.black87 : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _JungleTilePainter extends CustomPainter {
  final int tileId;
  final List<int> dirs;
  final bool gold;
  final bool crystal;

  const _JungleTilePainter({
    required this.tileId,
    required this.dirs,
    required this.gold,
    required this.crystal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF3B6E28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5)),
      bgPaint,
    );

    final roadBorder = Paint()
      ..color = const Color(0xFF6D4C41)
      ..strokeWidth = size.width * 0.30
      ..strokeCap = StrokeCap.round;
    final roadFill = Paint()
      ..color = const Color(0xFFD7CCC8)
      ..strokeWidth = size.width * 0.20
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final endpoints = <int, Offset>{
      0: Offset(size.width / 2, 0),
      1: Offset(size.width, size.height / 2),
      2: Offset(size.width / 2, size.height),
      3: Offset(0, size.height / 2),
    };

    for (final d in dirs) {
      final ep = endpoints[d];
      if (ep != null) {
        canvas.drawLine(center, ep, roadBorder);
      }
    }
    for (final d in dirs) {
      final ep = endpoints[d];
      if (ep != null) {
        canvas.drawLine(center, ep, roadFill);
      }
    }

    if (gold || crystal) {
      final gemPaint = Paint()
        ..color = gold ? const Color(0xFFFFB300) : const Color(0xFF00E5FF);
      canvas.drawCircle(center, size.width * 0.14, gemPaint);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: '$tileId',
        style: TextStyle(
          fontSize: size.width * 0.22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontFamilyFallback: kFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(2, 1));
  }

  @override
  bool shouldRepaint(covariant _JungleTilePainter old) =>
      old.tileId != tileId || old.gold != gold || old.crystal != crystal;
}
