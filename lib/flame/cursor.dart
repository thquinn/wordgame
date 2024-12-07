import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/state.dart';

class Cursor extends SpriteComponent with HasGameRef<WordGame>, KeyboardHandler {
  late MyAppState appState;

  Cursor() : super(size: Vector2.all(2));

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('cursor.png');
    anchor = Anchor(.5, .5);
    priority = 2;
  }

  @override
  void onMount() {
    super.onMount();
    appState = Provider.of<MyAppState>(game.buildContext!, listen: false);
  }

  @override
  void update(double dt) {
    transform.position = Vector2(appState.presenceState!.cursor.x.toDouble(), appState.presenceState!.cursor.y.toDouble());
    transform.angleDegrees = appState.presenceState!.cursorHorizontal ? 0 : 90;
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final keyDown = event is KeyDownEvent;
    final keyDownOrRepeat = keyDown || event is KeyRepeatEvent;
    // Change cursor direction.
    if (keyDown && event.logicalKey == LogicalKeyboardKey.tab) {
      appState.presenceState!.cursorHorizontal = !appState.presenceState!.cursorHorizontal;
      return false;
    }
    // Move cursor.
    if (keyDownOrRepeat && !keysPressed.contains(LogicalKeyboardKey.shiftLeft) && !keysPressed.contains(LogicalKeyboardKey.shiftRight)) {
      final inputX = event.logicalKey == LogicalKeyboardKey.arrowLeft ? -1 : event.logicalKey == LogicalKeyboardKey.arrowRight ? 1 : 0;
      final inputY = event.logicalKey == LogicalKeyboardKey.arrowUp ? -1 : event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : 0;
      appState.presenceState!.cursor += Point<int>(inputX, inputY);
    }
    // Placing tiles.
    if (event.character != null && 'abcdefghijklmnopqrstuvwxyz'.contains(event.character!)) {
      appState.tryPlayingTile(event.character!);
    }
    // Deleting.
    if (keyDown && event.logicalKey == LogicalKeyboardKey.backspace) {
      appState.retreaatCursorAndDelete();
    }
    // Submitting tiles.
    if (keyDown && event.logicalKey == LogicalKeyboardKey.enter) {
      appState.playProvisionalTiles();
    }
    // DEBUG: Start a new game.
    if (keyDown && event.logicalKey == LogicalKeyboardKey.f2) {
      appState.startGame();
      return false;
    }
    return true;
  }
}