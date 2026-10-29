import '../../widgets/common.dart';
import 'canasta_board.dart';
import 'daifugo_board.dart';
import 'germanwhist_board.dart';

/// 德国惠斯特 / 卡纳斯塔 / 大富豪
final Map<String, BoardBuilder> cards10Boards = {
  'germanwhist': (g) => GermanWhistBoard(g),
  'canasta': (g) => CanastaBoard(g),
  'daifugo': (g) => DaifugoBoard(g),
};
