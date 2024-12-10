import 'dart:ui';

import 'package:flame/components.dart';

class ScaledNineTileBoxComponent extends NineTileBoxComponent {
  @override
  Future<void> onLoad() async {
    // We have to do this stupid dance because NineTileBoxComponent has no way of setting the corner scale.
    size = size..divide(scale);
    print('scaled9tb onload');
  }
}
class AlphaNineTileBox extends NineTileBox {
  // And we have to make this stupid thing because there's no way to set opacity on NineTileBoxComponent.
  late Rect spriteCenter;
  late Paint paint;

  AlphaNineTileBox(super.sprite, {opacity = 1.0, leftWidth, bottomHeight, rightWidth, topHeight}) : super.withGrid() {
    spriteCenter = Rect.fromLTRB(leftWidth, topHeight, sprite.src.width - rightWidth, sprite.src.height - bottomHeight);
    paint = Paint()..color = Color.fromRGBO(255, 255, 255, opacity);
  }

  @override
  void drawRect(Canvas c, [Rect? dst]) {
    c.drawImageNine(sprite.image, spriteCenter, dst!, paint);
  }
}