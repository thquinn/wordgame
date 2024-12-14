import 'dart:math';

import 'package:flame/game.dart';

class Util {
  static Random random = Random();

  static Vector2 reflectPointAcrossLine(Vector2 a, Vector2 b, Vector2 c) {
    // Calculate the vector from point b to point c (line direction)
    Vector2 lineVector = c - b;
    
    // Calculate the vector from point b to point a
    Vector2 pointVector = a - b;
    
    // Calculate the projection of pointVector onto lineVector
    double dotProduct = pointVector.dot(lineVector);
    double lineVectorLengthSquared = lineVector.dot(lineVector);
    
    // Projection scalar
    double scalar = dotProduct / lineVectorLengthSquared;
    
    // Calculate the projection point on the line
    Vector2 projectionPoint = b + lineVector * scalar;
    
    // Calculate the reflected point by extending the reflection across the line
    Vector2 reflectedPoint = projectionPoint + (projectionPoint - a);
    
    return reflectedPoint;
  }
}