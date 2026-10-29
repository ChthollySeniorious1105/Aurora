import '../../widgets/common.dart';
import 'bagh_chal_board.dart';
import 'boop_board.dart';
import 'dobutsu_shogi_board.dart';
import 'gobblet_board.dart';
import 'orbito_board.dart';

/// 推猫上床 boop. / 套杯棋 Gobblet / 轨道旋转棋 Orbito / 虎羊棋 Bagh-Chal / 森林小将棋 Dōbutsu Shōgi
final Map<String, BoardBuilder> abstract18Boards = {
  'boop': (g) => BoopBoard(g),
  'gobblet': (g) => GobbletBoard(g),
  'orbito': (g) => OrbitoBoard(g),
  'bagh_chal': (g) => BaghChalBoard(g),
  'dobutsu_shogi': (g) => DobutsuShogiBoard(g),
};
