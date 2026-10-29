import '../../widgets/common.dart';
import 'm12_board.dart';

/// 扬州麻将 / 大连穷胡麻将 / 甘肃兰州麻将
final Map<String, BoardBuilder> mahjong12Boards = {
  'yangzhoumj': (g) => M12Board(g),
  'dalianmj': (g) => M12Board(g),
  'gansumj': (g) => M12Board(g),
};
