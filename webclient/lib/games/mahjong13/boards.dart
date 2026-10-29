import '../../widgets/common.dart';
import 'm13_board.dart';

/// 红中赖子麻将 / 北京麻将 / 南京麻将 / 宁夏滑水麻将
final Map<String, BoardBuilder> mahjong13Boards = {
  'hongzhongmj': (g) => M13Board(g),
  'beijingmj': (g) => M13Board(g),
  'nanjingmj': (g) => M13Board(g),
  'ningxiamj': (g) => M13Board(g),
};
