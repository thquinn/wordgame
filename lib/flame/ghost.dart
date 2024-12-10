import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/extensions.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/state.dart';

class GhostManager extends PositionComponent with HasGameRef<WordGame> {
    late WordGameState appState;
    Map<Point<int>, Ghost> tiles = {};

    @override
    void onMount() {
      super.onMount();
      appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
      //add(Ghost('mickeymilan'));
    }

    @override
    void update(double dt) {
      if (appState.game == null) return;
    }
}

class Ghost extends PositionComponent with HasGameRef<WordGame> {
  final TextPaint textPaint = TextPaint(
    style: TextStyle(
      fontSize: .33,
      fontFamily: 'Solway',
      fontWeight: FontWeight.bold,
      color: BasicPalette.white.color,
    ),
  );

  late WordGameState appState;
  late NineTileBoxComponent boxComponent;
  late TextBoxComponent textComponent;
  String username;
  
  Ghost(this.username) : super();
  
  @override
  Future<void> onLoad() async {
    final boxSprite = await Sprite.load('ghost.png');
    boxComponent = ScaledNineTileBoxComponent();
    boxComponent.nineTileBox = AlphaNineTileBox(boxSprite, opacity: 0.1, leftWidth: 75, rightWidth: 75, topHeight: 127, bottomHeight: 127);
    boxComponent.size = Vector2(2, 1);
    boxComponent.scale = Vector2(.1, .1);
    add(boxComponent);
    textComponent = TextBoxComponent(
      textRenderer: textPaint,
      text: username,
      align: Anchor.center,
      size: Vector2(10, 1),
      pixelRatio: 100,
    );
    add(textComponent);
  }

  @override
  void onMount() {
    super.onMount();
    appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
  }

  @override
  void update(double dt) {
    final width = textComponent.getLineWidth(username, username.length);
    size = Vector2(width, 1);
  }
}