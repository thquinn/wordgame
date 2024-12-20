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

  // Only returns rectangles of weight and height >= 2.
  static RectInt? findLargestNewRectangle(Set<Point<int>> before, Set<Point<int>> after) {
    final diff = after.difference(before);
    if (diff.isEmpty) return null;
    return diff.map((e) => _findLargestNewRectangleHelper(after, e)).reduce((a, b) => (a?.area ?? 0) >= (b?.area ?? 0) ? a : b);
  }
  static RectInt? _findLargestNewRectangleHelper(Set<Point<int>> points, Point<int> coor) {
    int left = coor.x, right = coor.x;
    while (points.contains(Point(left - 1, coor.y))) {
      left--;
    }
    while (points.contains(Point(right + 1, coor.y))) {
      right++;
    }
    if (left == right) return null;
    // Find all spans of filled coors, each a subspan of the one previous.
    final spans = [Point(left, right)];
    int minY;
    for (minY = coor.y - 1; true; minY--) {
      final span = _findLargestNewRectangleHelperSpan(points, Point(coor.x, minY), spans.first);
      if (span == null) {
        minY++;
        break;
      }
      spans.insert(0, span);
    }
    for (int y = coor.y + 1; true; y++) {
      final span = _findLargestNewRectangleHelperSpan(points, Point(coor.x, y), spans.last);
      if (span == null) break;
      spans.add(span);
    }
    if (spans.length == 1) return null;
    // Given the sizes of each span, find the indices for the subarray that maximizes len(arr) * min(arr).
    final spanSizes = spans.map((e) => e.y - e.x + 1).toList();
    int startIndex = -1, endIndex = -1, rectSize = -1;
    for (int i = 0; i < spanSizes.length - 1; i++) {
      for (int j = i + 1; j < spanSizes.length; j++) {
        // Since every array increases and then decreases, the minimum value of any subarray is guaranteed to be on one of its ends.
        final minValue = min(spanSizes[i], spanSizes[j]);
        final area = minValue * (j - i + 1);
        if (area > rectSize) {
          startIndex = i;
          endIndex = j;
          rectSize = area;
        }
      }
    }
    
    final rectY = startIndex + minY;
    final rectWidth = min(spanSizes[startIndex], spanSizes[endIndex]);
    final rectHeight = endIndex - startIndex + 1;
    final rectX = spans.skip(startIndex).take(rectHeight).map((e) => e.x).reduce(max);
    return RectInt(Point<int>(rectX, rectY), Point<int>(rectWidth, rectHeight));
  }
  static Point<int>? _findLargestNewRectangleHelperSpan(Set<Point<int>> points, Point<int> start, Point<int> previousSpan) {
    if (!points.contains(start)) return null;
    int left = start.x, right = start.x;
    while (left > previousSpan.x && points.contains(Point(left - 1, start.y))) {
      left--;
    }
    while (right < previousSpan.y && points.contains(Point(right + 1, start.y))) {
      right++;
    }
    if (left == right) return null;
    return Point(left, right);
  }

  static List<Set<Point<int>>> findNewEnclosedEmptyAreas(Set<Point<int>> before, Set<Point<int>> after) {
    final beforeAreas = findEnclosedEmptyAreas(before);
    return findEnclosedEmptyAreas(after).where((afterArea) => beforeAreas.every((beforeArea) => beforeArea.intersection(afterArea).isEmpty)).toList();
  }
  static const cardinalDirections = [Point<int>(-1, 0), Point<int>(1, 0), Point<int>(0, -1), Point<int>(0, 1)];
  static const cardinalAndDiagonalDirections = [Point<int>(-1, 0), Point<int>(1, 0), Point<int>(0, -1), Point<int>(0, 1),
                                                Point<int>(-1, -1), Point<int>(1, -1), Point<int>(-1, 1), Point<int>(1, 1)];
  static List<Set<Point<int>>> findEnclosedEmptyAreas(Set<Point<int>> tiles) {
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

  static Iterable<Point<int>> allCoorsWithinBounds(Iterable<Point<int>> coors) sync* {
    if (coors.isEmpty) return;
    final minX = coors.map((e) => e.x).reduce(min);
    final maxX = coors.map((e) => e.x).reduce(max);
    final minY = coors.map((e) => e.y).reduce(min);
    final maxY = coors.map((e) => e.y).reduce(max);
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        yield Point<int>(x, y);
      }
    }
  }
}

class RectInt {
  final Point<int> upperLeft;
  final Point<int> size;

  RectInt(this.upperLeft, this.size);

  int get left => upperLeft.x;
  int get top => upperLeft.y;
  int get right => upperLeft.x + size.x;
  int get bottom => upperLeft.y + size.y;
  int get width => right - left;
  int get height => bottom - top;
  int get area => width * height;
}