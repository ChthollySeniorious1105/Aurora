import '../../widgets/common.dart';
import 'chameleon_board.dart';
import 'secretpolicy_board.dart';
import 'themessage_board.dart';

/// 秘密法案 / 变色龙 / 风声
final Map<String, BoardBuilder> social2Boards = {
  'secretpolicy': (g) => SecretPolicyBoard(g),
  'chameleon': (g) => ChameleonBoard(g),
  'themessage': (g) => TheMessageBoard(g),
};
