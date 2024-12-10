import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/flame/rack.dart';

class WordCamera extends CameraComponent with KeyboardHandler {
  double zoom = 10;
  double inputX = 0, inputY = 0, inputZoom = 0;

  WordCamera() : super() {
    backdrop.add(ParallaxGrid());
    viewport.add(RackAnchor());
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
    viewfinder.transform.position -= Vector2(inputX, inputY) * 750 * dt;
    zoom /= pow(4, dt * inputZoom);
    zoom = zoom.clamp(6, 24);
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
    parallax!.layers[0] = CustomParallaxLayer(parallax!.layers.first.parallaxRenderer, game);
  }
}

class CustomParallaxLayer extends ParallaxLayer {
  WordGame game;

  CustomParallaxLayer(super.parallaxRenderer, this.game);

  @override
  void render(Canvas canvas) {
    final scale = parallaxRenderer.image.width / game.camera.viewfinder.zoom;
    Vector2 position = game.camera.viewfinder.transform.position.clone();
    Vector2 upperLeft = Vector2.zero();
    final mod = 512 / scale;
    upperLeft.x -= mod - (position.x % mod);
    upperLeft.y -= mod - (position.y % mod);
    upperLeft.x -= mod / 4;
    upperLeft.y -= mod / 4;
    // This whole thing is hacked together, but the worst part is Flutter's paintImage implementation:
    // if a sprite repeats, instead of using proper draw calls, it calculates every rect where it would be
    // and performs repeated draw calls
    // TODO: switch to something more performant
    paintImage(
      canvas: canvas,
      image: parallaxRenderer.image,
      rect: Rect.fromPoints(upperLeft.toOffset(), game.size.toOffset()),
      repeat: parallaxRenderer.repeat,
      scale: scale,
      alignment: Alignment.topLeft,
      filterQuality: parallaxRenderer.filterQuality,
    );
  }
}
