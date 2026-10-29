import '../../widgets/common.dart';
import 'm9_board.dart';

/// 沈阳麻将 / 长春麻将 / 温州麻将
final Map<String, BoardBuilder> mahjong9Boards = {
  'shenyangmj': (g) => M9Board(g),
  'changchunmj': (g) => M9Board(g),
  'wenzhoumj': (g) => M9Board(g),
};
