import '../../widgets/common.dart';
import 'm7_board.dart';

/// 山东麻将 / 山西抠点麻将 / 云南十风麻将
final Map<String, BoardBuilder> mahjong7Boards = {
  'shandongmj': (g) => M7Board(g),
  'shanximj': (g) => M7Board(g),
  'yunnanmj': (g) => M7Board(g),
};
