import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/experimental.dart';
import 'package:flame/palette.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/extensions.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/model.dart';
import 'package:wordgame/state.dart';

class PickupManager extends PositionComponent with HasGameRef<WordGame> {
  late WordGameState appState;
  Map<Point<int>, Pickup> pickups = {};

  @override
  void onMount() {
    super.onMount();
    appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
    appState.addListener(() => update(0)); // get notified changes on the same frame they happen
  }

    @override
    void update(double dt) {
      if (appState.game == null) return;
      // Remove tiles.
      final removedCoors = pickups.keys.where((coor) => !appState.game!.state.pickups.containsKey(coor)).toList();
      for (final removedCoor in removedCoors) {
        Pickup pickup = pickups[removedCoor]!;
        pickup.isVisible = false;
        remove(pickup);
        pickups.remove(removedCoor);
      }
      // Add tiles.
      final newCoors = appState.game!.state.pickups.keys.where((e) => !pickups.containsKey(e)).toList();
      for (final coor in newCoors) {
          Pickup pickup = Pickup(appState, coor);
          add(pickup);
          pickups[coor] = pickup;
      }
    }
}

class Pickup extends PositionComponent with HasVisibility {
  static const double RADIUS = 0.17;
  static const double SIDE_HEIGHT = 0.0733;
  static RRect RRECT = RRect.fromRectAndRadius(Rect.fromLTRB(.08, .02, .92, .84), Radius.circular(RADIUS));
  static Path pathTop = RoundedRectangle.fromRRect(RRECT).asPath();
  static Path pathSide = Path()..moveTo(RRECT.left, RRECT.bottom - RADIUS)
                               ..arcTo(Rect.fromCircle(center: Offset(RRECT.left + RADIUS, RRECT.bottom - RADIUS), radius: RADIUS), pi, pi / -2, false)
                               ..arcTo(Rect.fromCircle(center: Offset(RRECT.right - RADIUS, RRECT.bottom - RADIUS), radius: RADIUS), pi / 2, pi / -2, false)
                               ..arcTo(Rect.fromCircle(center: Offset(RRECT.right - RADIUS, RRECT.bottom - RADIUS + SIDE_HEIGHT), radius: RADIUS), 0, pi / 2, false)
                               ..arcTo(Rect.fromCircle(center: Offset(RRECT.left + RADIUS, RRECT.bottom - RADIUS + SIDE_HEIGHT), radius: RADIUS), pi / 2, pi / 2, false)
                               ..close();
  static final paintIcon = Paint()..colorFilter = ColorFilter.mode(Color.fromRGBO(142, 138, 208, 1), BlendMode.modulate);

  final WordGameState appState;
  final Point<int> coor;
  late SpriteComponent stripesTop, stripesSide, icon;
  double t = 0.0;

  Pickup(this.appState, this.coor);

  @override
  FutureOr<void> onLoad() async {
    position = Vector2(coor.x - 0.5, coor.y - 0.5);
    final sprite = await Sprite.load('pickup_stripes.png');
    add(ClipPathComponent(
      pathTop,
      children: [stripesTop = SpriteComponent(
        anchor: Anchor(.1, 0),
        size: Vector2.all(1.5),
        paint: BasicPalette.white.paint()..filterQuality = FilterQuality.high,
        sprite: sprite,
      )..opacity = 0.8
    ]));
    add(ClipPathComponent(
      pathSide,
      children: [stripesSide = SpriteComponent(
        anchor: Anchor.topRight,
        size: stripesTop.size,
        scale: Vector2(-1, 1),
        paint: BasicPalette.white.paint()..filterQuality = FilterQuality.high,
        sprite: sprite,
      )..opacity = 0.4
    ]));
    PickupType type = PickupType.wildcard;//appState.game!.state.pickups[coor]!;
    final spriteIcon = await Sprite.load('pickup_${type.toString().split('.').last}.png');
    add(icon = SpriteComponent(
      paint: paintIcon,
      sprite: spriteIcon,
      size: Vector2.all(1),
    ));
  }

  @override
  void update(double dt) {
    isVisible = !appState.localState!.provisionalTiles.containsKey(coor);
    t += dt;
    stripesTop.position = Vector2((t * .1) % (0.065 * stripesTop.size.x), 0);
    stripesSide.position = Vector2((t * -.1) % (0.065 * stripesSide.size.x), 0);
    icon.opacity = appState.localState!.cursor == coor ? 0 : 1;
  }
} 