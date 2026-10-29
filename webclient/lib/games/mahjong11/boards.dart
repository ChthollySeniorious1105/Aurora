import '../../widgets/common.dart';
import 'm11_board.dart';

/// 唐山麻将 / 无锡麻将 / 海南麻将
final Map<String, BoardBuilder> mahjong11Boards = {
  'tangshanmj': (g) => M11Board(g),
  'wuximj': (g) => M11Board(g),
  'hainanmj': (g) => M11Board(g),
};
