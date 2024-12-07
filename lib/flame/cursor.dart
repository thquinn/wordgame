import 'dart:async';

import 'package:flame/components.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/state.dart';

class Cursor extends SpriteComponent with HasGameRef<WordGame> {
  late MyAppState appState;

  Cursor() : super(size: Vector2.all(2));

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('cursor.png');
    anchor = Anchor(.5, .5);
  }

  @override
  void onMount() {
    super.onMount();
    //appState = game.buildContext!.watch<MyAppState>();
  }

  @override
  void update(double dt) {
    //transform.angleDegrees = appState.presenceState!.cursorHorizontal ? 0 : -90;
    super.update(dt);
  }
}