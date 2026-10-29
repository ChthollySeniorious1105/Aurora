import '../../widgets/common.dart';
import 'everdell_board.dart';
import 'quacks_board.dart';
import 'sagrada_board.dart';
import 'wingspan_board.dart';

export 'everdell_board.dart';
export 'quacks_board.dart';
export 'sagrada_board.dart';
export 'wingspan_board.dart';

/// 展翅翱翔 / 奎德林堡的庸医 / 仙境幽谷 / 圣家族大教堂
final Map<String, BoardBuilder> euro10Boards = {
  'wingspan': (g) => WingspanBoard(g),
  'quacks': (g) => QuacksBoard(g),
  'everdell': (g) => EverdellBoard(g),
  'sagrada': (g) => SagradaBoard(g),
};
