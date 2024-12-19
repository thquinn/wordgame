import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/flame/notification.dart';
import 'package:wordgame/flame/player_panels.dart';
import 'package:wordgame/flame/provisional_panel.dart';
import 'package:wordgame/flame/rack.dart';
import 'package:wordgame/flame/parallax_painter.dart';
import 'package:wordgame/flame/status_panels.dart';
import 'package:wordgame/flame/world.dart';
import 'package:wordgame/util.dart';

class WordCamera extends CameraComponent with HasGameRef<WordGame>, KeyboardHandler {
  double zoom = 15;
  double inputX = 0, inputY = 0, inputZoom = 0;

  Vector2 followVelocity = Vector2.zero();
  Vector2 lastCursorPosition = Vector2.zero();
  bool followCursor = true;

  WordCamera() : super() {
    backdrop.add(ParallaxGrid());
    viewport.add(RackAnchor());
    viewport.add(ProvisionalPanelAnchor());
    viewport.add(StatusAnchor());
    viewport.add(TeamAnchor());
    viewport.add(NotificationManager());
    viewport.add(FpsTextComponent());
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (!keysPressed.contains(LogicalKeyboardKey.shiftLeft) && !keysPressed.contains(LogicalKeyboardKey.shiftRight)) {
      inputX = inputY = 0;
    } else {
      inputX = keysPressed.contains(LogicalKeyboardKey.arrowLeft) ? -1 : keysPressed.contains(LogicalKeyboardKey.arrowRight) ? 1 : 0;
      inputY = keysPressed.contains(LogicalKeyboardKey.arrowUp) ? -1 : keysPressed.contains(LogicalKeyboardKey.arrowDown) ? 1 : 0;
    }
    inputZoom = keysPressed.contains(LogicalKeyboardKey.minus) ? -1 : keysPressed.contains(LogicalKeyboardKey.equal) ? 1 : 0;
    return true;
  }

  @override
  void update(double dt) {
    zoom /= pow(4, dt * inputZoom);
    zoom = zoom.clamp(8, 40);
    viewfinder.visibleGameSize = Vector2(zoom, zoom);
    viewfinder.position += Vector2(inputX, inputY) * 3 * sqrt(zoom) * dt;
    // Cursor-following behavior.
    final cursor = (game.world as WordWorld).cursor;
    if (cursor.position != lastCursorPosition) followCursor = true;
    lastCursorPosition = cursor.position.clone();
    if (inputX != 0 || inputY != 0 || inputZoom != 0) followCursor = false;
    final interiorRect = visibleWorldRect.deflate(visibleWorldRect.height * 0.1);
    if (followCursor && !interiorRect.contains(cursor.position.toOffset())) {
      Vector2 closestPoint = Util.getCameraPointWithinRect(cursor.position, interiorRect);
      Util.smoothDampVec2(viewfinder.position, closestPoint, followVelocity, .5, dt);
      viewfinder.position += followVelocity * dt;
    } else {
      followVelocity = Vector2.zero();
    }
  }
}

class ParallaxGrid extends CustomPainterComponent with HasGameRef<WordGame> {
  @override
  FutureOr<void> onLoad() async {
    final grid = await Sprite.load('grid.png');
    painter = ParallaxPainter(game: game, image: grid.image, fit: BoxFit.fill);
  }
}
