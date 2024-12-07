import 'dart:async';

import 'package:flame/components.dart';
import 'package:wordgame/flame/cursor.dart';

class MyCrate extends SpriteComponent {
  MyCrate() : super(size: Vector2.all(1));

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('blob.png');
    anchor = Anchor(.5, .5);
  }
}

class WordWorld extends World {
  @override
  Future<void> onLoad() async {
    await add(MyCrate());
    final other = MyCrate();
    other.position = Vector2(1, 0);
    await add(other);
    await add(Cursor());
  }
}