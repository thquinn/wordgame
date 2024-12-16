import 'dart:collection';
import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';

class Util {
  static Random random = Random();

  static Map<String, String> castJsonToStringMap(dynamic json) {
    final ret = json.map((key, value) => MapEntry(
      key.toString(), 
      value is int ? value.toString() : value as String
    ));
    return Map<String, String>.from(ret);
  }

  static Vector2 reflectPointAcrossLine(Vector2 a, Vector2 b, Vector2 c) {
    Vector2 lineVector = c - b;
    Vector2 pointVector = a - b;
    double dotProduct = pointVector.dot(lineVector);
    double lineVectorLengthSquared = lineVector.dot(lineVector);
    double scalar = dotProduct / lineVectorLengthSquared;
    Vector2 projectionPoint = b + lineVector * scalar;
    Vector2 reflectedPoint = projectionPoint + (projectionPoint - a);
    return reflectedPoint;
  }

  static double smoothDamp(double current, double target, List<double> velocity, double smoothTime, double dt) {
    smoothTime = max(.0001, smoothTime);
    final omega = 2 / smoothTime;
    final x = omega * dt;
    final exp = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x);
    final change = current - target;
    final originalTo = target;
    target = current - change;
    final temp = (velocity[0] + omega * change) * dt;
    velocity[0] = (velocity[0] - omega * temp) * exp;
    double output = target + (change + temp) * exp;
    // Prevent overshooting
    if (originalTo - current > 0.0 == output > originalTo) {
        output = originalTo;
        velocity[0] = (output - originalTo) / dt;
    }
    return output;
  }
  static Vector2 smoothDampVec2(Vector2 current, Vector2 target, Vector2 velocity, double smoothTime, double dt) {
    smoothTime = max(.0001, smoothTime);
    final omega = 2 / smoothTime;
    final x = omega * dt;
    final exp = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x);
    final changeX = current.x - target.x;
    final changeY = current.y - target.y;
    final originalTo = target.clone();
    target.x = current.x - changeX;
    target.y = current.y - changeY;
    final tempX = (velocity.x + omega * changeX) * dt;
    final tempY = (velocity.y + omega * changeY) * dt;
    velocity.x = (velocity.x - omega * tempX) * exp;
    velocity.y = (velocity.y - omega * tempY) * exp;
    double outputX = target.x + (changeX + tempX) * exp;
    double outputY = target.y + (changeY + tempY) * exp;
    // Prevent overshooting
    final origMinusCurrentX = originalTo.x - current.x;
    final origMinusCurrentY = originalTo.y - current.y;
    final outMinusOrigX = outputX - originalTo.x;
    final outMinusOrigY = outputY - originalTo.y;
    if (origMinusCurrentX * outMinusOrigX + origMinusCurrentY * outMinusOrigY > 0) {
        outputX = originalTo.x;
        outputY = originalTo.y;
        velocity.x = (outputX - originalTo.x) / dt;
        velocity.y = (outputY - originalTo.y) / dt;
    }
    return Vector2(outputX, outputY);
  }

  static Vector2 getCameraPointWithinRect(Vector2 point, Rect rect) {
    if (rect.contains(point.toOffset())) return point;
    final x = point.x > rect.left && point.x < rect.right ? (rect.left + rect.right) / 2 : clampDouble(point.x, rect.left, rect.right);
    final y = point.y > rect.top && point.y < rect.bottom ? (rect.top + rect.bottom) / 2 : clampDouble(point.y, rect.top, rect.bottom);
    return Vector2(x, y);
  }

  static List<Set<Point<int>>> FindNewEnclosedEmptyAreas(Set<Point<int>> before, Set<Point<int>> after) {
    final beforeAreas = FindEnclosedEmptyAreas(before);
    return FindEnclosedEmptyAreas(after).where((afterArea) => beforeAreas.every((beforeArea) => beforeArea.intersection(afterArea).isEmpty)).toList();
  }
  static const cardinalDirections = [Point<int>(-1, 0), Point<int>(1, 0), Point<int>(0, -1), Point<int>(0, 1)];
  static const cardinalAndDiagonalDirections = [Point<int>(-1, 0), Point<int>(1, 0), Point<int>(0, -1), Point<int>(0, 1),
                                                Point<int>(-1, -1), Point<int>(1, -1), Point<int>(-1, 1), Point<int>(1, 1)];
  static List<Set<Point<int>>> FindEnclosedEmptyAreas(Set<Point<int>> tiles) {
    if (tiles.isEmpty) return [];
    final minX = tiles.map((e) => e.x).reduce(min);
    final maxX = tiles.map((e) => e.x).reduce(max);
    final minY = tiles.map((e) => e.y).reduce(min);
    final maxY = tiles.map((e) => e.y).reduce(max);
    final List<Set<Point<int>>> areas = [];
    final Set<Point<int>> seeds = tiles.expand((e) => cardinalDirections.map((d) => d + e)).where((e) => e.x > minX && e.x < maxX && e.y > minY && e.y < maxY && !tiles.contains(e)).toSet();
    final Set<Point<int>> checked = {};
    for (final seed in seeds) {
      if (checked.contains(seed)) continue;
      // Check this empty space to see if it's entirely enclosed.
      Set<Point<int>> area = {seed};
      Queue<Point<int>> queue = Queue.of([seed]);
      bool contained = true;
      outerLoop:
      while (queue.isNotEmpty) {
        final current = queue.removeFirst();
        for (final neighbor in cardinalAndDiagonalDirections.map((e) => current + e)) {
          if (tiles.contains(neighbor)) continue;
          if (neighbor.x <= minX || neighbor.x >= maxX || neighbor.y <= minY || neighbor.y >= maxY) {
            contained = false;
            break outerLoop;
          }
          if (!area.contains(neighbor)) {
            area.add(neighbor);
            queue.add(neighbor);
          }
        }
      }
      if (contained) {
        areas.add(area);
      }
      checked.addAll(area);
    }
    return areas;
  }
}