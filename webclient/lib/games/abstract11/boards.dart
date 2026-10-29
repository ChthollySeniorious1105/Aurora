import '../../widgets/common.dart';
import 'focus_board.dart';
import 'gipf_board.dart';
import 'kulami_board.dart';

/// 吉普夫棋 GIPF / 焦点叠塔棋 Focus / 库拉米木板棋 Kulami
final Map<String, BoardBuilder> abstract11Boards = {
  'gipf': (g) => GipfBoard(g),
  'focus': (g) => FocusBoard(g),
  'kulami': (g) => KulamiBoard(g),
};
