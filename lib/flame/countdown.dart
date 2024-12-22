import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/layout.dart';
import 'package:flame/palette.dart';
import 'package:flame/rendering.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/state.dart';

class CountdownAnchor extends AlignComponent {
  CountdownAnchor() : super(
    child: CountdownManager(),
    alignment: Anchor.topCenter,
  );
}

class CountdownManager extends PositionComponent with HasGameRef<WordGame> {
  late WordGameState appState;
  int lastSecondsLeft = -1;

  @override
  FutureOr<void> onLoad() {
    appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
    add(CountdownLabel(appState));
  }

  @override
  void update(double dt) {
    if (appState.game == null) return;
    final game = appState.game!;
    final startSeconds = clampSecondsOrDefault((game.startsAt.difference(DateTime.now()).inMilliseconds / 1000).ceil(), 1, 5);
    final endSeconds = clampSecondsOrDefault((game.endsAt.difference(DateTime.now()).inMilliseconds / 1000).ceil(), 1, 10);
    final secondsLeft = startSeconds != -1 ? startSeconds : endSeconds;
    if (secondsLeft == lastSecondsLeft) return;
    if (secondsLeft != -1) {
      add(CountdownNumber(secondsLeft));
    }
    lastSecondsLeft = secondsLeft;
  }

  int clampSecondsOrDefault(int seconds, int min, int max) {
    if (seconds >= min && seconds <= max) return seconds;
    return -1;
  }
}

class CountdownLabel extends TextComponent {
  static final TextPaint style = TextPaint(
    style: TextStyle(
      fontSize: 24,
      fontFamily: 'Solway',
      color: BasicPalette.white.color.withOpacity(0),
    ),
  );

  final WordGameState appState;
  MoveEffect? moveEffect;

  CountdownLabel(this.appState) : super(textRenderer: style, text: 'Text text testo!', position: Vector2(0, 100), size: Vector2(1000, 1000));

  @override
  FutureOr<void> onLoad() {
    decorator.addLast(Shadow3DDecorator(
      angle: 0,
      blur: 2,
      ascent: -1,
    ));
  }

  @override
  void update(double dt) {
    if (appState.game == null) return;
    final gameStarting = appState.game!.startsAt.isAfter(DateTime.now());
    final secondsLeft = appState.game!.endsAt.difference(DateTime.now()).inMilliseconds / 1000;
    final gameEnding = secondsLeft > 0 && secondsLeft <= 10;
    bool enabled = true;
    if (gameStarting) setText('game starts in');
    else if (gameEnding) setText('game ends in');
    else enabled = false;
    final double targetY = enabled ? 150 : 100;
    if (y != targetY && moveEffect?.isRemoved != false) {
      add(moveEffect = MoveEffect.to(Vector2(position.x, targetY), EffectController(duration: .5, curve: Curves.easeInOut)));
    }
    // Opacity.
    final double targetOpacity = enabled ? 1 : 0;
    if ((textRenderer as TextPaint).style.color!.opacity != targetOpacity) {
      final double opacity = lerpDouble(1 - targetOpacity, targetOpacity, moveEffect!.previousProgress)!;
      textRenderer = TextPaint(style: style.style.copyWith(color: BasicPalette.white.color.withOpacity(opacity)));
    }
  }

  void setText(String newText) {
    if (newText == text) return;
    text = newText;
    final width = style.getLineMetrics(newText).width;
    position.x = width / -2;
  }
}

class CountdownNumber extends TextComponent {
  static final TextPaint style = TextPaint(
    style: TextStyle(
      fontSize: 100,
      fontFamily: 'Solway',
      fontWeight: FontWeight.bold,
      color: BasicPalette.white.color.withOpacity(0),
    ),
  );

  late ScaleEffect scaleEffect;

  CountdownNumber(int number) : super(position: Vector2(0, 250), anchor: Anchor.center) {
    text = number.toString();
    decorator.addLast(Shadow3DDecorator(
      opacity: 0.25,
      angle: 0,
      blur: 4,
      ascent: -2,
    ));
    add(SequenceEffect([
      scaleEffect = ScaleEffect.to(Vector2.all(1.5), EffectController(duration: 1.0, curve: Curves.slowMiddle)),
      RemoveEffect(),
    ]));
  }

  @override
  void update(double dt) {
    final double opacity = clampDouble((1 - (scaleEffect.controller.progress * -2 + 1).abs()) * 3, 0, 1);
    textRenderer = TextPaint(style: style.style.copyWith(color: BasicPalette.white.color.withOpacity(opacity)));
  }
}
