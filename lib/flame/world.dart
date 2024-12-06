import 'dart:async';

import 'package:flame/components.dart';

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
  }
}