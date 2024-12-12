import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/state.dart';

class Cursor extends SpriteComponent with HasGameRef<WordGame>, KeyboardHandler, HasVisibility {
  late WordGameState appState;
  late SpriteComponent arrow;

  Cursor() : super(size: Vector2.all(2), anchor: Anchor.center, paint: Paint()..filterQuality = FilterQuality.high,);

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('cursor.png');
    final spriteArrow = await Sprite.load('cursor_arrow.png');
    arrow = SpriteComponent(
      sprite: spriteArrow,
      position: Vector2(1, .933),
      size: Vector2.all(2),
      anchor: Anchor.center,
      paint: Paint()..filterQuality = FilterQuality.high,
    );
    add(arrow);
    priority = 2;
  }

  @override
  void onMount() {
    super.onMount();
    appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
  }

  @override
  void update(double dt) {
    isVisible = appState.hasGame();
    transform.position = Vector2(appState.localState!.cursor.x.toDouble(), appState.localState!.cursor.y.toDouble());
    arrow.transform.angleDegrees = appState.localState!.cursorHorizontal ? 0 : 90;
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final keyDown = event is KeyDownEvent;
    final keyRepeat = event is KeyRepeatEvent;
    final keyDownOrRepeat = keyDown || keyRepeat;
    // Change cursor direction.
    if (keyDown && event.logicalKey == LogicalKeyboardKey.tab) {
      appState.localState!.cursorHorizontal = !appState.localState!.cursorHorizontal;
      return false;
    }
    // Move cursor.
    if (keyDownOrRepeat && !keysPressed.contains(LogicalKeyboardKey.shiftLeft) && !keysPressed.contains(LogicalKeyboardKey.shiftRight)) {
      final inputX = event.logicalKey == LogicalKeyboardKey.arrowLeft ? -1 : event.logicalKey == LogicalKeyboardKey.arrowRight ? 1 : 0;
      final inputY = event.logicalKey == LogicalKeyboardKey.arrowUp ? -1 : event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : 0;
      appState.moveCursorTo(appState.localState!.cursor + Point<int>(inputX, inputY));
    }
    // Placing tiles.
    if (event.character != null && 'abcdefghijklmnopqrstuvwxyz'.contains(event.character!)) {
      appState.tryPlayingTile(event.character!);
    }
    // Deleting.
    if (keyDown && event.logicalKey == LogicalKeyboardKey.backspace) {
      appState.retreatCursorAndDelete();
    }
    // Delete all.
    if (keyRepeat && event.logicalKey == LogicalKeyboardKey.backspace) {
      appState.clearProvisionalTiles();
    }
    // Submitting tiles.
    if (keyDown && event.logicalKey == LogicalKeyboardKey.enter) {
      appState.confirmProvisionalTiles();
    }
    // Sort rack.
    if (keyDown && event.logicalKey == LogicalKeyboardKey.digit1) {
      appState.localState!.rack.sort();
    }
    // DEBUG: Start a new game.
    if (keyDown && event.logicalKey == LogicalKeyboardKey.f2) {
      appState.startGame();
      return false;
    }
    // DEBUG: Show assist text.
    if (keyDown && event.logicalKey == LogicalKeyboardKey.f3) {
      appState.localState!.assister = 'swarrizard';
      return false;
    }
    return true;
  }
}