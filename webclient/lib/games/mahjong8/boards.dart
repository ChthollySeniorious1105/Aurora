import '../../widgets/common.dart';
import 'm8_board.dart';

/// 河南麻将 / 广西买马麻将 / 宁波麻将
final Map<String, BoardBuilder> mahjong8Boards = {
  'henanmj': (g) => M8Board(g),
  'guangximj': (g) => M8Board(g),
  'ningbomj': (g) => M8Board(g),
};
