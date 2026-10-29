import '../../widgets/common.dart';
import 'ataxx_board.dart';
import 'dvonn_board.dart';
import 'tzaar_board.dart';

/// 德沃恩棋 DVONN / 沙皇棋 TZAAR / 同化棋 Ataxx
final Map<String, BoardBuilder> abstract7Boards = {
  'dvonn': (g) => DvonnBoardView(g),
  'tzaar': (g) => TzaarBoardView(g),
  'ataxx': (g) => AtaxxBoardView(g),
};
