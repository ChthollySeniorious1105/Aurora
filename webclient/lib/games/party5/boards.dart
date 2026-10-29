import '../../widgets/common.dart';
import 'camelup_board.dart';
import 'incangold_board.dart';

export 'camelup_board.dart';
export 'incangold_board.dart';

/// 印加宝藏 / 骆驼大赛
final Map<String, BoardBuilder> party5Boards = {
  'incangold': (g) => IncanGoldBoard(g),
  'camelup': (g) => CamelUpBoard(g),
};
