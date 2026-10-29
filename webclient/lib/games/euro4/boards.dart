import '../../widgets/common.dart';
import 'centuryspice_board.dart';
import 'citadels_board.dart';
import 'machikoro_board.dart';

/// 富饶之城 / 香料之路 / 骰子街
final Map<String, BoardBuilder> euro4Boards = {
  'citadels': (g) => CitadelsBoard(g),
  'centuryspice': (g) => CenturySpiceBoard(g),
  'machikoro': (g) => MachiKoroBoard(g),
};
