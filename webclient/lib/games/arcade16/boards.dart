import '../../widgets/common.dart';
import 'chocona_board.dart';
import 'lits_board.dart';
import 'magnets_board.dart';

/// 四格骨牌竞速 / 巧克块矩形竞速 / 磁铁正负极竞速
final Map<String, BoardBuilder> arcade16Boards = {
  'lits': (g) => LitsBoard(g),
  'chocona': (g) => ChoconaBoard(g),
  'magnets': (g) => MagnetsBoard(g),
};
