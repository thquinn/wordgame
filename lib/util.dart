import 'dart:collection';
import 'dart:math';

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