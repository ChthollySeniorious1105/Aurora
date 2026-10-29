import '../../widgets/common.dart';
import 'm5_board.dart';

/// 杭州麻将 / 南昌麻将 / 天津麻将
final Map<String, BoardBuilder> mahjong5Boards = {
  'hangzhoumj': (g) => M5Board(g),
  'nanchangmj': (g) => M5Board(g),
  'tianjinmj': (g) => M5Board(g),
};
