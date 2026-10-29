import '../../widgets/common.dart';
import 'm6_board.dart';

/// 陕西麻将 / 合肥麻将 / 苏州麻将
final Map<String, BoardBuilder> mahjong6Boards = {
  'shaanximj': (g) => M6Board(g),
  'hefeimj': (g) => M6Board(g),
  'suzhoumj': (g) => M6Board(g),
};
