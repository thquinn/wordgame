import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wordgame/flame/game.dart';

class WordCamera extends CameraComponent with KeyboardHandler {
  double zoom = 10;
  double inputX = 0, inputY = 0, inputZoom = 0;

  WordCamera() : super() {
    backdrop.add(ParallaxGrid());
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    inputX = keysPressed.contains(LogicalKeyboardKey.arrowLeft) ? -1 : keysPressed.contains(LogicalKeyboardKey.arrowRight) ? 1 : 0;
    inputY = keysPressed.contains(LogicalKeyboardKey.arrowUp) ? -1 : keysPressed.contains(LogicalKeyboardKey.arrowDown) ? 1 : 0;
    inputZoom = keysPressed.contains(LogicalKeyboardKey.minus) ? -1 : keysPressed.contains(LogicalKeyboardKey.equal) ? 1 : 0;
    return false;
  }

  @override
  void update(double dt) {
    viewfinder.transform.position -= Vector2(inputX, inputY) * 10 * dt;
    zoom /= pow(4, dt * inputZoom);
    viewfinder.visibleGameSize = Vector2(zoom, zoom);
  }
}

class ParallaxGrid extends ParallaxComponent<WordGame> {
  @override
  Future<void> onLoad() async {
    parallax = await game.loadParallax(
      [ParallaxImageData('grid.png')],
      repeat: ImageRepeat.repeat,
      alignment: Alignment.center,
      fill: LayerFill.none,
    );
  }
}