import '../../widgets/common.dart';
import 'm3_board.dart';

/// 武汉麻将 / 血流成河 / 青天井麻将
final Map<String, BoardBuilder> mahjong3Boards = {
  'wuhanmj': (g) => M3Board(g),
  'xueliu': (g) => M3Board(g),
  'aotenjou': (g) => M3Board(g),
};
