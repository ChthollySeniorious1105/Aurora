import '../../widgets/common.dart';
import 'gizmos_board.dart';
import 'istanbul_board.dart';
import 'parks_board.dart';
import 'ra_board.dart';

final Map<String, BoardBuilder> euro9Boards = {
  'parks': ParksBoard.new,
  'istanbul': IstanbulBoard.new,
  'ra': RaBoard.new,
  'gizmos': GizmosBoard.new,
};
