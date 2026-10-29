import '../../src/engine.dart';

const String koikoiRules = '''
# 花札·来来 (Koi-Koi) 规则说明

## 基本配置
- **人数**：2 人对战（支持 3月快速 / 6月半庄 / 12月全庄）。
- **牌库构成**：传统日本 48 张花札（1~12 月，每月 4 张牌，编号 `0..47`，`月份 = cardId ~/ 4 + 1`）：
  - **光札（5张）**：1月松上鹤(0)、3月樱上幕(8)、8月芒上月(28)、11月柳上道风(40，雨光)、12月桐上凤凰(44)。
  - **种札（9张）**：2月梅上莺(4)、4月藤上杜鹃(12)、5月菖蒲八桥(16)、6月牡丹蝶(20)、7月萩间猪(24)、8月芒上雁(29)、9月菊上盃(32，酒杯同时计入种札与粕札！)、10月枫间鹿(36)、11月柳间燕(41)。
  - **短册（10张）**：赤短3张（1月松1、2月梅5、3月樱9）、青短3张（6月牡丹21、9月菊33、10月枫37）、普通短册4张（4月13、5月17、7月25、11月42）。
  - **粕札（24张）**：其余每月素牌（连同9月菊上盃共25张可计入粕）。

## 发牌与回合流程
- 开局庄家（亲）与闲家（子）各发 8 张手牌，桌面（场）亮出 8 张牌，其余 24 张作为山牌（若场上出现同月4张或4组对子则自动重发）。
- 每回合分为两个步骤：
  1. **打出手牌 (`hand`)**：从手牌打出 1 张。若场上有同月份的牌，将其配对收入自己的捕获区（若场上有 2 张同月牌则任选其一，若有 3 张则连同手牌共 4 张全部捕获）；若无同月牌则留在场上。
  2. **翻开山牌 (`stock`)**：翻开山牌顶 1 张牌，按同样规则与场上同月牌配对捕获或留在场上（若场上有 2 张同月牌则由当前玩家选择捕获哪一张）。

## 役种（Yaku）与「来来 / 胜负」抉择
当玩家在本回合捕获新牌使得役种总点数增加时，进入 **`koikoi` 抉择阶段**：
- **胜负 (`shobu`)**：立即结束本局并获得当前役种分数（若基础役分 >= 7 分则分数 **×2**；若对手本局曾宣告过「来来」，则分数再 **×2**！）。
- **来来 (`koikoi`)**：放弃立即结算，继续本局以追求更大役种；但一旦对手在后续回合达成新役并选择「胜负」，对手得分将 **×2**！

## 役种一览
- **五光 (10分)**：集齐全部 5 张光札。
- **四光 (8分)**：集齐除柳上道风外的 4 张光札。
- **雨四光 (7分)**：集齐包含柳上道风在内的任意 4 张光札。
- **三光 (5分)**：集齐除柳上道风外的任意 3 张光札。
- **猪鹿蝶 (5分)**：集齐 7月萩间猪(24)、10月枫间鹿(36)、6月牡丹蝶(20)。
- **花见酒 (5分)**：集齐 3月樱上幕(8) + 9月菊上盃(32)。
- **月见酒 (5分)**：集齐 8月芒上月(28) + 9月菊上盃(32)。
- **赤短 (5分)**：集齐 1、2、3 月三张赤短。
- **青短 (5分)**：集齐 6、9、10 月三张青短（赤短与青短同成共 10 分）。
- **种 (1分+)**：集齐 5 张及以上种札，得 `张数 - 4` 分。
- **短 (1分+)**：集齐 5 张及以上短册，得 `张数 - 4` 分。
- **粕 (1分+)**：集齐 10 张及以上粕札（含菊上盃），得 `张数 - 9` 分。
''';

class HanafudaCardInfo {
  final int id;
  final int month;
  final String monthName;
  final String flower;
  final String name;
  final String category; // 'bright', 'animal', 'ribbon', 'chaff'
  final String? ribbonKind; // 'red_poetry', 'blue', 'plain'

  const HanafudaCardInfo({
    required this.id,
    required this.month,
    required this.monthName,
    required this.flower,
    required this.name,
    required this.category,
    this.ribbonKind,
  });
}

const List<String> kHanafudaMonthFlowers = [
  '1月松',
  '2月梅',
  '3月樱',
  '4月藤',
  '5月菖蒲',
  '6月牡丹',
  '7月萩',
  '8月芒',
  '9月菊',
  '10月枫',
  '11月柳',
  '12月桐',
];

const List<HanafudaCardInfo> kHanafudaCards = [
  // 1月 松 (Jan - Pine)
  HanafudaCardInfo(id: 0, month: 1, monthName: '1月松', flower: '松', name: '松上鹤', category: 'bright'),
  HanafudaCardInfo(id: 1, month: 1, monthName: '1月松', flower: '松', name: '松上赤短', category: 'ribbon', ribbonKind: 'red_poetry'),
  HanafudaCardInfo(id: 2, month: 1, monthName: '1月松', flower: '松', name: '松之粕一', category: 'chaff'),
  HanafudaCardInfo(id: 3, month: 1, monthName: '1月松', flower: '松', name: '松之粕二', category: 'chaff'),
  // 2月 梅 (Feb - Plum)
  HanafudaCardInfo(id: 4, month: 2, monthName: '2月梅', flower: '梅', name: '梅上莺', category: 'animal'),
  HanafudaCardInfo(id: 5, month: 2, monthName: '2月梅', flower: '梅', name: '梅上赤短', category: 'ribbon', ribbonKind: 'red_poetry'),
  HanafudaCardInfo(id: 6, month: 2, monthName: '2月梅', flower: '梅', name: '梅之粕一', category: 'chaff'),
  HanafudaCardInfo(id: 7, month: 2, monthName: '2月梅', flower: '梅', name: '梅之粕二', category: 'chaff'),
  // 3月 樱 (Mar - Cherry)
  HanafudaCardInfo(id: 8, month: 3, monthName: '3月樱', flower: '樱', name: '樱上幕', category: 'bright'),
  HanafudaCardInfo(id: 9, month: 3, monthName: '3月樱', flower: '樱', name: '樱上赤短', category: 'ribbon', ribbonKind: 'red_poetry'),
  HanafudaCardInfo(id: 10, month: 3, monthName: '3月樱', flower: '樱', name: '樱之粕一', category: 'chaff'),
  HanafudaCardInfo(id: 11, month: 3, monthName: '3月樱', flower: '樱', name: '樱之粕二', category: 'chaff'),
  // 4月 藤 (Apr - Wisteria)
  HanafudaCardInfo(id: 12, month: 4, monthName: '4月藤', flower: '藤', name: '藤上杜鹃', category: 'animal'),
  HanafudaCardInfo(id: 13, month: 4, monthName: '4月藤', flower: '藤', name: '藤上短册', category: 'ribbon', ribbonKind: 'plain'),
  HanafudaCardInfo(id: 14, month: 4, monthName: '4月藤', flower: '藤', name: '藤之粕一', category: 'chaff'),
  HanafudaCardInfo(id: 15, month: 4, monthName: '4月藤', flower: '藤', name: '藤之粕二', category: 'chaff'),
  // 5月 菖蒲 (May - Iris)
  HanafudaCardInfo(id: 16, month: 5, monthName: '5月菖蒲', flower: '菖蒲', name: '菖蒲八桥', category: 'animal'),
  HanafudaCardInfo(id: 17, month: 5, monthName: '5月菖蒲', flower: '菖蒲', name: '菖蒲短册', category: 'ribbon', ribbonKind: 'plain'),
  HanafudaCardInfo(id: 18, month: 5, monthName: '5月菖蒲', flower: '菖蒲', name: '菖蒲之粕一', category: 'chaff'),
  HanafudaCardInfo(id: 19, month: 5, monthName: '5月菖蒲', flower: '菖蒲', name: '菖蒲之粕二', category: 'chaff'),
  // 6月 牡丹 (Jun - Peony)
  HanafudaCardInfo(id: 20, month: 6, monthName: '6月牡丹', flower: '牡丹', name: '牡丹蝶', category: 'animal'),
  HanafudaCardInfo(id: 21, month: 6, monthName: '6月牡丹', flower: '牡丹', name: '牡丹青短', category: 'ribbon', ribbonKind: 'blue'),
  HanafudaCardInfo(id: 22, month: 6, monthName: '6月牡丹', flower: '牡丹', name: '牡丹之粕一', category: 'chaff'),
  HanafudaCardInfo(id: 23, month: 6, monthName: '6月牡丹', flower: '牡丹', name: '牡丹之粕二', category: 'chaff'),
  // 7月 萩 (Jul - Bush Clover)
  HanafudaCardInfo(id: 24, month: 7, monthName: '7月萩', flower: '萩', name: '萩间猪', category: 'animal'),
  HanafudaCardInfo(id: 25, month: 7, monthName: '7月萩', flower: '萩', name: '萩上短册', category: 'ribbon', ribbonKind: 'plain'),
  HanafudaCardInfo(id: 26, month: 7, monthName: '7月萩', flower: '萩', name: '萩之粕一', category: 'chaff'),
  HanafudaCardInfo(id: 27, month: 7, monthName: '7月萩', flower: '萩', name: '萩之粕二', category: 'chaff'),
  // 8月 芒 (Aug - Susuki Grass)
  HanafudaCardInfo(id: 28, month: 8, monthName: '8月芒', flower: '芒', name: '芒上月', category: 'bright'),
  HanafudaCardInfo(id: 29, month: 8, monthName: '8月芒', flower: '芒', name: '芒上雁', category: 'animal'),
  HanafudaCardInfo(id: 30, month: 8, monthName: '8月芒', flower: '芒', name: '芒之粕一', category: 'chaff'),
  HanafudaCardInfo(id: 31, month: 8, monthName: '8月芒', flower: '芒', name: '芒之粕二', category: 'chaff'),
  // 9月 菊 (Sep - Chrysanthemum)
  HanafudaCardInfo(id: 32, month: 9, monthName: '9月菊', flower: '菊', name: '菊上盃', category: 'animal'),
  HanafudaCardInfo(id: 33, month: 9, monthName: '9月菊', flower: '菊', name: '菊上青短', category: 'ribbon', ribbonKind: 'blue'),
  HanafudaCardInfo(id: 34, month: 9, monthName: '9月菊', flower: '菊', name: '菊之粕一', category: 'chaff'),
  HanafudaCardInfo(id: 35, month: 9, monthName: '9月菊', flower: '菊', name: '菊之粕二', category: 'chaff'),
  // 10月 枫 (Oct - Maple)
  HanafudaCardInfo(id: 36, month: 10, monthName: '10月枫', flower: '枫', name: '枫间鹿', category: 'animal'),
  HanafudaCardInfo(id: 37, month: 10, monthName: '10月枫', flower: '枫', name: '枫上青短', category: 'ribbon', ribbonKind: 'blue'),
  HanafudaCardInfo(id: 38, month: 10, monthName: '10月枫', flower: '枫', name: '枫之粕一', category: 'chaff'),
  HanafudaCardInfo(id: 39, month: 10, monthName: '10月枫', flower: '枫', name: '枫之粕二', category: 'chaff'),
  // 11月 柳 (Nov - Willow)
  HanafudaCardInfo(id: 40, month: 11, monthName: '11月柳', flower: '柳', name: '柳上道风', category: 'bright'),
  HanafudaCardInfo(id: 41, month: 11, monthName: '11月柳', flower: '柳', name: '柳间燕', category: 'animal'),
  HanafudaCardInfo(id: 42, month: 11, monthName: '11月柳', flower: '柳', name: '柳上短册', category: 'ribbon', ribbonKind: 'plain'),
  HanafudaCardInfo(id: 43, month: 11, monthName: '11月柳', flower: '柳', name: '柳之雷粕', category: 'chaff'),
  // 12月 桐 (Dec - Paulownia)
  HanafudaCardInfo(id: 44, month: 12, monthName: '12月桐', flower: '桐', name: '桐上凤凰', category: 'bright'),
  HanafudaCardInfo(id: 45, month: 12, monthName: '12月桐', flower: '桐', name: '桐之粕一', category: 'chaff'),
  HanafudaCardInfo(id: 46, month: 12, monthName: '12月桐', flower: '桐', name: '桐之粕二', category: 'chaff'),
  HanafudaCardInfo(id: 47, month: 12, monthName: '12月桐', flower: '桐', name: '桐之粕三', category: 'chaff'),
];

const Set<int> kBrightCards = {0, 8, 28, 40, 44};
const Set<int> kAnimalCards = {4, 12, 16, 20, 24, 29, 32, 36, 41};
const Set<int> kRibbonCards = {1, 5, 9, 13, 17, 21, 25, 33, 37, 42};
const Set<int> kRedPoetryRibbons = {1, 5, 9};
const Set<int> kBlueRibbons = {21, 33, 37};
const int kRainManCard = 40;
const int kCurtainCard = 8;
const int kMoonCard = 28;
const int kSakeCupCard = 32;
const int kButterflyCard = 20;
const int kBoarCard = 24;
const int kDeerCard = 36;

int hanafudaMonth(int cardId) => (cardId ~/ 4) + 1;
HanafudaCardInfo hanafudaInfo(int cardId) => kHanafudaCards[cardId.clamp(0, 47)];

bool isChaffOrSakeCup(int cardId) =>
    cardId == kSakeCupCard || hanafudaInfo(cardId).category == 'chaff';

bool hasInvalidInitialMonths(List<int> cards) {
  final counts = List<int>.filled(13, 0);
  for (final c in cards) {
    counts[hanafudaMonth(c)]++;
  }
  if (counts.any((n) => n == 4)) return true;
  final pairs = counts.where((n) => n == 2).length;
  return pairs == 4;
}

class KoiKoiYakuEval {
  final List<Map<String, dynamic>> yakus;
  final int points;
  const KoiKoiYakuEval(this.yakus, this.points);
}

KoiKoiYakuEval computeKoiKoiYaku(Iterable<int> capturedCards) {
  final set = capturedCards.toSet();
  final yakus = <Map<String, dynamic>>[];
  var total = 0;

  void addYaku(String name, int pts) {
    yakus.add({'name': name, 'points': pts});
    total += pts;
  }

  // 1. Brights (光札)
  final brights = set.intersection(kBrightCards);
  final hasRain = brights.contains(kRainManCard);
  if (brights.length == 5) {
    addYaku('五光', 10);
  } else if (brights.length == 4 && !hasRain) {
    addYaku('四光', 8);
  } else if (brights.length == 4 && hasRain) {
    addYaku('雨四光', 7);
  } else if (brights.length == 3 && !hasRain) {
    addYaku('三光', 5);
  }

  // 2. Viewing Yakus (花见酒 / 月见酒)
  if (set.contains(kCurtainCard) && set.contains(kSakeCupCard)) {
    addYaku('花见酒', 5);
  }
  if (set.contains(kMoonCard) && set.contains(kSakeCupCard)) {
    addYaku('月见酒', 5);
  }

  // 3. Ino-Shika-Cho (猪鹿蝶) & Animals (种)
  final animals = set.intersection(kAnimalCards);
  if (set.contains(kBoarCard) && set.contains(kDeerCard) && set.contains(kButterflyCard)) {
    addYaku('猪鹿蝶', 5);
  }
  if (animals.length >= 5) {
    addYaku('种', animals.length - 4);
  }

  // 4. Ribbons (赤短 / 青短 / 短)
  final hasRed = set.containsAll(kRedPoetryRibbons);
  final hasBlue = set.containsAll(kBlueRibbons);
  if (hasRed && hasBlue) {
    addYaku('赤短·青短', 10);
  } else if (hasRed) {
    addYaku('赤短', 5);
  } else if (hasBlue) {
    addYaku('青短', 5);
  }
  final ribbons = set.intersection(kRibbonCards);
  if (ribbons.length >= 5) {
    addYaku('短', ribbons.length - 4);
  }

  // 5. Chaff (粕, Sake Cup 32 counts as both Animal and Chaff!)
  final chaffCount = set.where(isChaffOrSakeCup).length;
  if (chaffCount >= 10) {
    addYaku('粕', chaffCount - 9);
  }

  return KoiKoiYakuEval(yakus, total);
}

typedef KoiKoi = KoiKoiGame;

class KoiKoiGame extends GameEngine {
  late int maxRounds;

  int round = 1;
  int dealer = 0;
  int turn = 0;
  String step = 'hand'; // 'hand', 'stock', 'koikoi', 'over'

  List<int> field = [];
  List<int> stock = [];
  List<List<int>> hands = [[], []];
  List<List<int>> captured = [[], []];

  List<int> scores = [0, 0];
  List<int> lastYakuPoints = [0, 0];
  List<bool> calledKoiKoi = [false, false];

  int? drawnCard;
  Map<String, dynamic>? lastMove;
  Map<String, dynamic>? lastRoundResult;
  Map<String, dynamic>? result;

  bool _over = false;
  int? _resignedSeat;

  KoiKoiGame(super.setup) {
    maxRounds = setup.opt<int>('rounds', 6);
  }

  String get phase => step;
  set phase(String v) => step = v;

  @override
  void start() {
    scores = [0, 0];
    round = 1;
    dealer = 0;
    _over = false;
    _resignedSeat = null;
    result = null;
    lastRoundResult = null;
    _startRound();
  }

  void _startRound() {
    List<int> deck;
    var attempts = 0;
    do {
      deck = shuffled([for (var i = 0; i < 48; i++) i], rng);
      attempts++;
    } while (attempts < 20 &&
        (hasInvalidInitialMonths(deck.sublist(16, 24)) ||
            hasInvalidInitialMonths(deck.sublist(0, 8)) ||
            hasInvalidInitialMonths(deck.sublist(8, 16))));

    hands = [
      deck.sublist(0, 8)..sort(),
      deck.sublist(8, 16)..sort(),
    ];
    field = deck.sublist(16, 24);
    stock = deck.sublist(24, 48);
    captured = [[], []];
    lastYakuPoints = [0, 0];
    calledKoiKoi = [false, false];
    drawnCard = null;
    turn = dealer;
    step = 'hand';
    lastMove = null;
  }

  List<int> fieldMatchesForMonth(int month) => [
        for (final f in field)
          if (hanafudaMonth(f) == month) f,
      ];

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    if (step == 'hand') {
      if (type != 'play_hand') throw GameError('请先从手牌打出一张牌');
      final card = asInt(action['card'], -1);
      if (!hands[seat].contains(card)) throw GameError('手中没有这张花札');

      final m = hanafudaMonth(card);
      final matches = fieldMatchesForMonth(m);
      final chosenMatch = action['match'] == null ? -1 : asInt(action['match'], -1);

      final gained = <int>[];
      if (matches.isEmpty) {
        hands[seat].remove(card);
        field.add(card);
      } else if (matches.length == 1) {
        if (chosenMatch >= 0 && chosenMatch != matches.first) {
          throw GameError('所选场牌与手牌月份不匹配');
        }
        hands[seat].remove(card);
        field.remove(matches.first);
        gained.addAll([card, matches.first]);
        captured[seat].addAll(gained);
      } else if (matches.length == 2) {
        if (!matches.contains(chosenMatch)) {
          throw GameError('场上有两张${kHanafudaMonthFlowers[m - 1]}，请指定要配对捕获的一张');
        }
        hands[seat].remove(card);
        field.remove(chosenMatch);
        gained.addAll([card, chosenMatch]);
        captured[seat].addAll(gained);
      } else {
        // 3 cards of that month on field -> capture all 4!
        hands[seat].remove(card);
        for (final f in matches) {
          field.remove(f);
        }
        gained.addAll([card, ...matches]);
        captured[seat].addAll(gained);
      }

      lastMove = {
        'seat': seat,
        'type': 'play_hand',
        'card': card,
        'captured': gained,
      };

      _resolveStockStep(seat);
      return;
    }

    if (step == 'stock') {
      if (type != 'match_stock') throw GameError('请选择山牌要配对捕获的场牌');
      final sCard = drawnCard;
      if (sCard == null) throw GameError('当前没有待配对的山牌');
      final matchCard = asInt(action['match'], -1);
      final matches = fieldMatchesForMonth(hanafudaMonth(sCard));
      if (!matches.contains(matchCard)) {
        throw GameError('请选择同月份的场牌进行配对');
      }
      field.remove(matchCard);
      captured[seat].addAll([sCard, matchCard]);
      drawnCard = null;
      lastMove = {
        ...?lastMove,
        'stockCard': sCard,
        'stockCaptured': [sCard, matchCard],
      };
      _checkYakuAfterTurn(seat);
      return;
    }

    if (step == 'koikoi') {
      if (type == 'shobu') {
        final eval = computeKoiKoiYaku(captured[seat]);
        final basePts = eval.points > 0 ? eval.points : lastYakuPoints[seat];
        var finalPts = basePts;
        final highBonus = basePts >= 7;
        if (highBonus) finalPts *= 2;
        final oppKoiBonus = calledKoiKoi[1 - seat];
        if (oppKoiBonus) finalPts *= 2;

        scores[seat] += finalPts;
        host.log(
          '${name(seat)} 宣告「胜负 (Shobu)」！达成 ${eval.yakus.map((y) => y['name']).join('、')}，本局获 $finalPts 文',
        );
        _finishRound(
          winner: seat,
          basePoints: basePts,
          finalPoints: finalPts,
          yakus: eval.yakus,
          highBonus: highBonus,
          oppKoiBonus: oppKoiBonus,
        );
        return;
      }
      if (type == 'koikoi') {
        calledKoiKoi[seat] = true;
        lastMove = {
          'seat': seat,
          'type': 'koikoi',
          'points': lastYakuPoints[seat],
        };
        host.log('${name(seat)} 宣告「来来 (Koi-Koi)」！继续冲击更高役种');
        _advanceTurnOrEndRound();
        return;
      }
      throw GameError('请选择「胜负 (shobu)」或「来来 (koikoi)」');
    }

    throw GameError('未知操作');
  }

  void _resolveStockStep(int seat) {
    if (stock.isEmpty) {
      _checkYakuAfterTurn(seat);
      return;
    }
    final sCard = stock.removeAt(0);
    final m = hanafudaMonth(sCard);
    final matches = fieldMatchesForMonth(m);

    if (matches.isEmpty) {
      field.add(sCard);
      lastMove = {...?lastMove, 'stockCard': sCard, 'stockCaptured': <int>[]};
      _checkYakuAfterTurn(seat);
    } else if (matches.length == 1) {
      field.remove(matches.first);
      captured[seat].addAll([sCard, matches.first]);
      lastMove = {
        ...?lastMove,
        'stockCard': sCard,
        'stockCaptured': [sCard, matches.first],
      };
      _checkYakuAfterTurn(seat);
    } else if (matches.length >= 3) {
      for (final f in matches) {
        field.remove(f);
      }
      captured[seat].addAll([sCard, ...matches]);
      lastMove = {
        ...?lastMove,
        'stockCard': sCard,
        'stockCaptured': [sCard, ...matches],
      };
      _checkYakuAfterTurn(seat);
    } else {
      // Exactly 2 matching cards on field: player must choose!
      drawnCard = sCard;
      step = 'stock';
    }
  }

  void _checkYakuAfterTurn(int seat) {
    final eval = computeKoiKoiYaku(captured[seat]);
    if (eval.points > lastYakuPoints[seat]) {
      lastYakuPoints[seat] = eval.points;
      step = 'koikoi';
      return;
    }
    _advanceTurnOrEndRound();
  }

  void _advanceTurnOrEndRound() {
    if (hands[0].isEmpty && hands[1].isEmpty) {
      host.log('第 $round 月双方手牌打完无人宣告胜负，本局流局');
      _finishRound(
        winner: null,
        basePoints: 0,
        finalPoints: 0,
        yakus: const [],
        highBonus: false,
        oppKoiBonus: false,
      );
      return;
    }
    final next = 1 - turn;
    turn = hands[next].isNotEmpty ? next : turn;
    step = 'hand';
  }

  void _finishRound({
    required int? winner,
    required int basePoints,
    required int finalPoints,
    required List<Map<String, dynamic>> yakus,
    required bool highBonus,
    required bool oppKoiBonus,
  }) {
    lastRoundResult = {
      'round': round,
      'winner': winner,
      'basePoints': basePoints,
      'finalPoints': finalPoints,
      'yakus': yakus,
      'highBonus': highBonus,
      'oppKoiBonus': oppKoiBonus,
      'scores': List<int>.of(scores),
    };

    if (winner != null) {
      dealer = winner;
    }

    if (round >= maxRounds) {
      _over = true;
      step = 'over';
      final maxSc = scores[0] >= scores[1] ? scores[0] : scores[1];
      final winners = [
        for (var s = 0; s < players; s++)
          if (scores[s] == maxSc) s,
      ];
      result = {
        'winners': winners,
        'scores': List<int>.of(scores),
        'lastRound': lastRoundResult,
      };
      return;
    }

    round++;
    _startRound();
  }

  @override
  Map<String, dynamic> view(int seat) {
    final y0 = computeKoiKoiYaku(captured[0]);
    final y1 = computeKoiKoiYaku(captured[1]);
    return {
      'round': round,
      'maxRounds': maxRounds,
      'dealer': dealer,
      'turn': turn,
      'step': step,
      'phase': step,
      'field': List<int>.of(field),
      'stockCount': stock.length,
      'drawnCard': drawnCard,
      'myHand': seat >= 0 && seat < players ? List<int>.of(hands[seat]) : const <int>[],
      'handCounts': [hands[0].length, hands[1].length],
      'captured': [List<int>.of(captured[0]), List<int>.of(captured[1])],
      'yakus': [y0.yakus, y1.yakus],
      'yakuPoints': [y0.points, y1.points],
      'calledKoiKoi': List<bool>.of(calledKoiKoi),
      'scores': List<int>.of(scores),
      'lastMove': lastMove,
      'lastRoundResult': lastRoundResult,
      'result': result,
    };
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get isOver => _over;

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over) return;
    _resignedSeat = seat;
    _over = true;
    step = 'over';
    final winner = 1 - seat;
    result = {
      'winners': [winner],
      'scores': List<int>.of(scores),
      'resigned': seat,
    };
  }

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (_resignedSeat != null) {
      return rankWinners(players, [1 - _resignedSeat!]);
    }
    return rankByScore(scores);
  }

  int _cardPriority(int c) {
    final info = hanafudaInfo(c);
    if (c == kSakeCupCard) return 45;
    switch (info.category) {
      case 'bright':
        return 50;
      case 'animal':
        return 35;
      case 'ribbon':
        return info.ribbonKind == 'plain' ? 20 : 30;
      default:
        return 10;
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (step == 'koikoi') {
      final myHandCount = hands[seat].length;
      final eval = computeKoiKoiYaku(captured[seat]);
      final oppYaku = computeKoiKoiYaku(captured[1 - seat]);
      if (myHandCount == 0 ||
          eval.points >= 6 ||
          calledKoiKoi[1 - seat] ||
          oppYaku.points > 0 ||
          myHandCount <= 2) {
        return {'type': 'shobu'};
      }
      if (botLevel >= 1 && myHandCount >= 4 && eval.points <= 2) {
        return {'type': 'koikoi'};
      }
      return {'type': 'shobu'};
    }

    if (step == 'stock') {
      final sCard = drawnCard!;
      final matches = fieldMatchesForMonth(hanafudaMonth(sCard));
      matches.sort((a, b) => _cardPriority(b).compareTo(_cardPriority(a)));
      return {'type': 'match_stock', 'match': matches.first};
    }

    // step == 'hand'
    final hand = hands[seat];
    int? bestCard;
    int? bestMatch;
    var bestScore = -1000;

    for (final c in hand) {
      final matches = fieldMatchesForMonth(hanafudaMonth(c));
      if (matches.isEmpty) {
        final sc = -_cardPriority(c);
        if (sc > bestScore) {
          bestScore = sc;
          bestCard = c;
          bestMatch = null;
        }
      } else {
        for (final f in matches) {
          final sc = _cardPriority(c) + _cardPriority(f) + 100;
          if (sc > bestScore) {
            bestScore = sc;
            bestCard = c;
            bestMatch = f;
          }
        }
      }
    }

    return {
      'type': 'play_hand',
      'card': bestCard ?? hand.first,
      if (bestMatch != null) 'match': bestMatch,
    };
  }
}
