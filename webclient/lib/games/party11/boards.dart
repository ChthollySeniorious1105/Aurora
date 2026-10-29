import '../../widgets/common.dart';
import 'cashnguns_board.dart';
import 'highsociety_board.dart';
import 'mascarade_board.dart';
import 'sherlock13_board.dart';

final Map<String, BoardBuilder> party11Boards = {
  'highsociety': HighSocietyBoard.new,
  'cashnguns': CashNGunsBoard.new,
  'mascarade': MascaradeBoard.new,
  'sherlock13': Sherlock13Board.new,
};
