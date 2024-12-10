import 'package:flame/components.dart';
import 'package:flame/src/text/common/line_metrics.dart';
import 'package:flutter/painting.dart';

class ScaledNineTileBoxComponent extends NineTileBoxComponent {
  late double cornerScale;

  @override
  Future<void> onLoad() async {
    // We have to do this stupid dance because NineTileBoxComponent has no way of setting the corner scale.
    scale *= cornerScale;
    size = Vector2(size.x / scale.x, size.y / scale.y);
  }

  setSize(Vector2 s) {
    super.size = Vector2(s.x / scale.x, s.y / scale.y);
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

class FixedHeightTextPaint extends TextPaint {
  // We have to do this because TextStyle.height doesn't seem to work at low values.
  final double fixedHeight;

  FixedHeightTextPaint(this.fixedHeight, {super.style});

  @override
  LineMetrics getLineMetrics(String text) {
    final ret = super.getLineMetrics(text);
    return LineMetrics(left: ret.left, baseline: ret.baseline, width: ret.width, ascent: fixedHeight / 2, descent: fixedHeight / 2);
  }
}