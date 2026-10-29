import '../../widgets/common.dart';
import 'forsale_board.dart';
import 'ticketride_board.dart';
import 'tokyoking_board.dart';

/// 东京之王 / 车票之旅 / 房产拍卖
final Map<String, BoardBuilder> euro3Boards = {
  'tokyoking': (g) => TokyoKingBoard(g),
  'ticketride': (g) => TicketRideBoard(g),
  'forsale': (g) => ForSaleBoard(g),
};
