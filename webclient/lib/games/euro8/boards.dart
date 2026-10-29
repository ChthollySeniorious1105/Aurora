import '../../widgets/common.dart';
import 'cascadia_board.dart';
import 'nidavellir_board.dart';
import 'puertorico_board.dart';
import 'starrealms_board.dart';

/// 卡斯卡迪亚之旅 / 波多黎各 / 尼达维利亚 / 星域奇航
final Map<String, BoardBuilder> euro8Boards = {
  'cascadia': (g) => CascadiaBoard(g),
  'puertorico': (g) => PuertoRicoBoard(g),
  'nidavellir': (g) => NidavellirBoard(g),
  'starrealms': (g) => StarRealmsBoard(g),
};
