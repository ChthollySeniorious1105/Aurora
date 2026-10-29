import '../../widgets/common.dart';
import 'canstop_board.dart';
import 'qwirkle_board.dart';
import 'saboteur_board.dart';

/// 欲罢不能 / 形色牌 / 矮人矿坑
final Map<String, BoardBuilder> party7Boards = {
  'canstop': (g) => CanStopBoard(g),
  'qwirkle': (g) => QwirkleBoard(g),
  'saboteur': (g) => SaboteurBoard(g),
};
