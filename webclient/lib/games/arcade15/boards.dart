import '../../widgets/common.dart';
import 'kurotto_board.dart';
import 'stitches_board.dart';
import 'tatamibari_board.dart';

/// 榻榻米分割竞速 / 跨宫缝线竞速 / 黑格邻群计数竞速
final Map<String, BoardBuilder> arcade15Boards = {
  'tatamibari': (g) => TatamibariBoard(g),
  'stitches': (g) => StitchesBoard(g),
  'kurotto': (g) => KurottoBoard(g),
};
