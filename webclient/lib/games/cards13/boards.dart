import '../../widgets/common.dart';
import 'belote_board.dart';
import 'cassino_board.dart';
import 'millebornes_board.dart';

/// 法国贝洛特 Belote / 卡西诺抓牌 Cassino / 千里之行 Mille Bornes
final Map<String, BoardBuilder> cards13Boards = {
  'belote': (g) => BeloteBoard(g),
  'cassino': (g) => CassinoBoard(g),
  'millebornes': (g) => MilleBornesBoard(g),
};
