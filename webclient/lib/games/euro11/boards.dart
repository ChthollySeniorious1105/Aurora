import '../../widgets/common.dart';
import 'calico_board.dart';
import 'photosynthesis_board.dart';
import 'stoneage_board.dart';
import 'takenoko_board.dart';

/// 猫咪与花被 / 熊猫园丁 / 光合作用 / 石器时代
final Map<String, BoardBuilder> euro11Boards = {
  'calico': (g) => CalicoBoard(g),
  'takenoko': (g) => TakenokoBoard(g),
  'photosynthesis': (g) => PhotosynthesisBoard(g),
  'stoneage': (g) => StoneAgeBoard(g),
};
