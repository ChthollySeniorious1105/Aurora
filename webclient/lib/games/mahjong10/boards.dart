import '../../widgets/common.dart';
import 'm10_board.dart';

/// 潮汕麻将 / 常州麻将 / 青岛麻将
final Map<String, BoardBuilder> mahjong10Boards = {
  'chaoshanmj': (g) => M10Board(g),
  'changzhoumj': (g) => M10Board(g),
  'qingdaomj': (g) => M10Board(g),
};
