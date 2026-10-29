import '../../widgets/common.dart';
import 'captain_sonar_board.dart';
import 'loot_board.dart';
import 'potion_explosion_board.dart';
import 'thats_life_board.dart';

export 'captain_sonar_board.dart';
export 'loot_board.dart';
export 'potion_explosion_board.dart';
export 'thats_life_board.dart';

final Map<String, BoardBuilder> party18Boards = {
  'captain_sonar': CaptainSonarBoard.new,
  'potion_explosion': PotionExplosionBoard.new,
  'loot': LootBoard.new,
  'thats_life': ThatsLifeBoard.new,
};
