import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/experimental.dart';
import 'package:flame/palette.dart';
import 'package:flame/text.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

class ScaledNineTileBoxComponent extends NineTileBoxComponent {
  double cornerScale;

  ScaledNineTileBoxComponent(this.cornerScale);

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

// courtesy of spydon: https://github.com/flame-engine/flame/issues/1013#issuecomment-1652400956
mixin HasOpacityProvider on Component implements OpacityProvider {
  final Paint _paint = BasicPalette.white.paint();
  final Paint _srcOverPaint = Paint()..blendMode = BlendMode.srcOver;

  @override
  double get opacity => _paint.color.opacity;

  @override
  set opacity(double newOpacity) {
    _paint
      ..color = _paint.color.withOpacity(newOpacity)
      ..blendMode = BlendMode.modulate;
  }

  @override
  void renderTree(Canvas canvas) {
    canvas.saveLayer(null, _srcOverPaint);
    super.renderTree(canvas);
    canvas.drawPaint(_paint);
    canvas.restore();
  }
}

class TextBoxComponentWithOpacity extends TextBoxComponent with HasOpacityProvider {
  TextBoxComponentWithOpacity({super.text, super.textRenderer, super.boxConfig, super.align, super.pixelRatio, super.position, super.size, super.scale, super.angle, super.anchor, super.children, super.priority, super.onComplete, super.key});
}

class CurveAverager extends Curve {
  final List<Curve> curves;

  CurveAverager(this.curves);
  
  @override
  double transformInternal(double t) {
    return curves.map((c) => c.transform(t)).reduce((a, b) => a + b) / curves.length;
  }
}

class RoundedRectangleComponent extends ShapeComponent {
  final RoundedRectangle rect;
  late Path path;

  RoundedRectangleComponent(this.rect, {super.children, super.paint}) {
    path = rect.asPath();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawPath(path, paint);
  }
}

class PathComponent extends ShapeComponent {
  Path path;

  PathComponent(this.path, {super.paint});

  @override
  void render(Canvas canvas) {
    canvas.drawPath(path, paint);
  }
}

class ClipPathComponent extends ClipComponent {
  Path path;

  ClipPathComponent(this.path, {super.children, super.position,  super.priority}) : super(builder: (size) => Circle(Vector2.zero(), 1));

  @override Future<void> onLoad();

  @override
  void render(Canvas canvas) {
    canvas.clipPath(path);
  }

  @override
  bool containsPoint(Vector2 point) {
    return path.contains((point - position).toOffset());
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    return path.contains(point.toOffset());
  }
}

extension PointNormalization on Point {
  Point normalize() {
    return Point(
      x < 0 ? -1 : x == 0 ? 0 : 1,
      y < 0 ? -1 : y == 0 ? 0 : 1
    );
  }
}

extension PointDistances on Point<int> {
  int manhattanDistanceTo(Point<int> other) {
    return (x - other.x).abs() + (y - other.y).abs();
  }
}
