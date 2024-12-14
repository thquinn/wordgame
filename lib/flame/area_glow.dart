import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:wordgame/model.dart';
import 'package:wordgame/util.dart';

class AreaGlowManager extends PositionComponent {
  static late AreaGlowManager instance;
  static double _tileScale = 1.0013;

  late Sprite spriteHorizontal, spriteVertical, spriteCorner, spriteICorner;

  AreaGlowManager() : super(position: Vector2(-1, -1.13));

  @override
  FutureOr<void> onLoad() async {
    instance = this;
    spriteHorizontal = await Sprite.load('areaglow_horizontal.png');
    spriteVertical = await Sprite.load('areaglow_vertical.png');
    spriteCorner = await Sprite.load('areaglow_corner.png');
    spriteICorner = await Sprite.load('areaglow_icorner.png');
  }

  void stateDelta(GameState oldState, GameState newState) {
    
  }
  void animateArea(Set<Point<int>> coors) {
    // Find a coordinate with empty space to the left.
    Point<int> coor = coors.first;
    while (coors.contains(coor - Point(1, 0))) {
      coor -= Point(1, 0);
    }
    Point start = coor;
    List<Point<int>> outline = [coor + Point(0, 1)];
    // Follow the outline of the point set.
    final normals = [Point(-1, 0), Point(0, -1), Point(1, 0), Point(0, 1)];
    int normalIndex = 0;
    do {
      for (int normalIndexOffset = 1; normalIndexOffset <= 4; normalIndexOffset++) {
        final checkNormal = normals[(normalIndex + normalIndexOffset) % 4];
        outline.add(outline.last + checkNormal);
        if (coors.contains(coor + checkNormal)) {
          coor += checkNormal;
          normalIndex = (normalIndex + normalIndexOffset + 3) % 4;
          break;
        }
      }
      if (coors.contains(coor + normals[normalIndex])) {
        coor += normals[normalIndex];
        normalIndex = (normalIndex + 3) % 4;
      }
    } while (coor != start);
    // Create path.
    if (outline.first == outline.last) {
      outline.removeLast();
    }
    final path = PathComponent(Paint()
      ..style = PaintingStyle.stroke
      ..color = Color.fromRGBO(215, 215, 255, 1)
      ..strokeWidth = 0.066
      ..strokeCap = StrokeCap.round
    , outline.map((e) => Vector2(e.x + 0.5, e.y + 0.633)).toList(), true, radius: .25);
    final pathTime = path.pathLength * .05;
    path.add(PathStartPercentEffect(EffectController(duration: pathTime, curve: Curves.easeInOut)));
    path.add(PathEndPercentEffect(EffectController(duration: pathTime, curve: Curves.easeOutQuad)));
    path.add(SequenceEffect([
      OpacityEffect.to(0, EffectController(duration: pathTime * .05)),
      OpacityEffect.fadeIn(EffectController(duration: pathTime * .3, curve: Curves.easeIn)),
      OpacityEffect.to(1, EffectController(duration: pathTime * .3)),
      OpacityEffect.fadeOut(EffectController(duration: pathTime * .3, curve: Curves.easeOut)),
      RemoveEffect(),
    ]));
    add(path);
    // Create outline glow sprites.
    final paint = Paint()..colorFilter = ColorFilter.mode(Color.fromRGBO(215, 215, 255, 1), BlendMode.modulate);
    final area = Component();
    for (int i = 0; i < outline.length; i++) {
      final a = outline[i];
      final b = outline[(i + 1) % outline.length];
      final c = outline[(i + 2) % outline.length];
      final dcb = c - b;
      final dba = b - a;
      final dd = dcb - dba;
      if (dd == Point(0, 0)) {
        area.add(SpriteComponent(
          paint: paint,
          sprite: dcb.y == 0 ? spriteHorizontal : spriteVertical,
          size: Vector2.all(1),
          scale: Vector2(_tileScale, _tileScale),
          position: Vector2(b.x.toDouble(), b.y.toDouble()),
        ));
      } else {
        final flipped = dd.x != dd.y;
        area.add(SpriteComponent(
          paint: paint,
          sprite: dd.y == 1 ? spriteCorner : spriteICorner,
          size: Vector2.all(1),
          scale: Vector2(_tileScale * (flipped ? -1 : 1), _tileScale),
          position: Vector2(b.x.toDouble() + (flipped ? 1 : 0), b.y.toDouble()),
        ));
      }
    }
    (area.children.first as SpriteComponent).makeTransparent();
    area.children.first.add(SequenceEffect([
      OpacityEffect.to(0, EffectController(duration: pathTime)),
      OpacityEffect.fadeIn(EffectController(duration: .15, curve: Curves.easeInExpo)),
      OpacityEffect.fadeOut(EffectController(duration: .85)),
    ]));
    area.add(RemoveEffect(delay: 4.25));
    add(area);
  }

  List<Point<int>> removeColinear(List<Point<int>> points) {
    List<Point<int>> ret = [points.first];
    for (int i = 1; i < points.length; i++) {
      Point<int> a = points[i - 1];
      Point<int> b = points[i];
      Point<int> c = points[(i + 1) % points.length];
      if (c - b != b - a) {
        points.add(b);
      }
    }
    return ret;
  }
}

class PathComponent extends Component implements OpacityProvider {
  Path path;
  late PathMetric pathMetric;
  late double pathLength;
  Paint paint;
  double startPercent = 0, endPercent = 1;

  PathComponent(this.paint, List<Vector2> points, bool closed, {radius = 0}) : path = radius == 0 ? pathFromPoints(points, closed) : roundedPathFromPoints(points, closed, radius) {
    pathMetric = path.computeMetrics().first;
    pathLength = pathMetric.length;
  }
  static Path pathFromPoints(List<Vector2> points, bool closed) {
    final Path path = Path();
    path.moveTo(points.first.x, points.first.y);
    for (final point in points.skip(1)) {
      path.lineTo(point.x, point.y);
    }
    if (closed) {
      path.close();
    }
    return path;
  }
  static Path roundedPathFromPoints(List<Vector2> points, bool closed, double radius) {
    final Path path = Path();
    if (closed) {
      final start = points[1].clone();
      start.moveToTarget(points[0], radius);
      path.moveTo(start.x, start.y);
    } else {
      path.moveTo(points.first.x, points.first.y);
    }
    for (int i = 0; i < (closed ? points.length : points.length - 1); i++) {
      if (!closed && i == points.length - 2) {
        path.lineTo(points.last.x, points.last.y);
        return path;
      }
      Vector2 a = points[i];
      Vector2 b = points[(i + 1) % points.length];
      Vector2 c = points[(i + 2) % points.length];
      final circlePointA = b.clone()..moveToTarget(a, radius);
      final circlePointC = b.clone()..moveToTarget(c, radius);
      Vector2 circleCenter = Util.reflectPointAcrossLine(b, circlePointA, circlePointC);
      Rect circleRect = Rect.fromCircle(center: circleCenter.toOffset(), radius: radius);
      final startAngle = atan2(circlePointA.y - circleCenter.y, circlePointA.x - circleCenter.x);
      final endAngle = atan2(circlePointC.y - circleCenter.y, circlePointC.x - circleCenter.x);
      double sweepAngle = endAngle - startAngle;
      if (sweepAngle > pi) { 
        sweepAngle -= 2 * pi;
      } else if (sweepAngle < -pi) { 
        sweepAngle += 2 * pi;
      }
      path.arcTo(circleRect, startAngle, sweepAngle, false);
    }
    path.close();
    return path;
  }

  @override
  void render(Canvas canvas) {
    if (startPercent >= endPercent) {
      return;
    }
    if (startPercent == 0 && endPercent == 1) {
      canvas.drawPath(path, paint);
    } else {
      canvas.drawPath(pathMetric.extractPath(pathLength * startPercent, pathLength * endPercent), paint);
    }
  }
  
  @override
  double get opacity => paint.color.opacity;

  @override
  set opacity(double newOpacity) {
    paint.color = paint.color.withOpacity(newOpacity);
  }
}

abstract class PathPercentEffect extends ComponentEffect<PathComponent> {
  late final Tween<double> _tween;
  late double _original;

  PathPercentEffect(
    super.controller, {
    double percentFrom = 0,
    double percentTo = 1,
    super.onComplete,
  })  : _tween = Tween(begin: percentFrom, end: percentTo);

  double getPercent();
  void setPercent(double percent);

  @override
  Future<void> onMount() async {
    super.onMount();
    _original = getPercent();
  }

  @override
  void apply(double progress) {
    final percent = min(max(_tween.transform(progress), 0.0), 1.0);
    setPercent(percent);
  }

  @override
  void reset() {
    super.reset();
    setPercent(_original);
  }
}

class PathStartPercentEffect extends PathPercentEffect {
  PathStartPercentEffect(super.controller);

  @override
  double getPercent() {
    return target.startPercent;
  }
  @override
  void setPercent(double percent) {
    target.startPercent = percent;
  }
}

class PathEndPercentEffect extends PathPercentEffect {
  PathEndPercentEffect(super.controller);

  @override
  double getPercent() {
    return target.endPercent;
  }
  @override
  void setPercent(double percent) {
    target.endPercent = percent;
  }
}
