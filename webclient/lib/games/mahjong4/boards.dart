import '../../widgets/common.dart';
import 'm4_board.dart';

/// 贵阳捉鸡麻将 / 哈尔滨麻将 / 福建游金麻将
final Map<String, BoardBuilder> mahjong4Boards = {
  'guizhoumj': (g) => M4Board(g),
  'harbinmj': (g) => M4Board(g),
  'fujianmj': (g) => M4Board(g),
};
