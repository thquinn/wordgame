import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:provider/provider.dart';
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
    add(Pickup(appState, Point(-5, -5)));
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
  static Paint? paintTop;
  static final paintIcon = Paint()..colorFilter = ColorFilter.mode(Color.fromRGBO(142, 138, 208, 1), BlendMode.modulate);

  final WordGameState appState;
  final Point<int> coor;

  Pickup(this.appState, this.coor);

  @override
  FutureOr<void> onLoad() async {
    /*
    if (paintTop == null) {
      FragmentProgram fp = await FragmentProgram.fromAsset('shaders/pickup.frag');
      FragmentShader fs = fp.fragmentShader();
      paintTop = Paint()..shader = fs;
    }
    position = Vector2(coor.x - 0.5, coor.y - 0.5);
    final spriteTop = await Sprite.load('tile_placed_top.png');
    add(SpriteComponent(
      paint: paintTop,
      sprite: spriteTop,
      size: Vector2.all(1),
    ));
    */
    PickupType type = PickupType.wildcard;//appState.game!.state.pickups[coor]!;
    final spriteIcon = await Sprite.load('pickup_${type.toString().split('.').last}.png');
    add(SpriteComponent(
      paint: paintIcon,
      sprite: spriteIcon,
      size: Vector2.all(1),
    ));
  }
} 