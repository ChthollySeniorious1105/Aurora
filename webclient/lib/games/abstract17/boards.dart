import '../../widgets/common.dart';
import 'kuba_board.dart';
import 'martian_chess_board.dart';
import 'six_hex_board.dart';

/// 库巴推球棋 Kuba / 六角六形棋 SIX / 火星象棋 Martian Chess
final Map<String, BoardBuilder> abstract17Boards = {
  'kuba': (g) => KubaBoard(g),
  'six_hex': (g) => SixHexBoard(g),
  'martian_chess': (g) => MartianChessBoard(g),
};
