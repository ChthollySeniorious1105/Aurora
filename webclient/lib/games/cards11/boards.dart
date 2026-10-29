import '../../widgets/common.dart';
import 'bohnanza_board.dart';
import 'pinochle_board.dart';
import 'skat_board.dart';
import 'yaniv_board.dart';

/// 德国斯卡特 Skat / 皮诺克 Pinochle / 雅尼夫 Yaniv / 种豆得豆 Bohnanza
final Map<String, BoardBuilder> cards11Boards = {
  'skat': (g) => SkatBoard(g),
  'pinochle': (g) => PinochleBoard(g),
  'yaniv': (g) => YanivBoard(g),
  'bohnanza': (g) => BohnanzaBoard(g),
};
