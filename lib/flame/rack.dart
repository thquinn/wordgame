import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/layout.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/extensions.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/model.dart';
import 'package:wordgame/state.dart';

class RackAnchor extends AlignComponent {
  RackAnchor() : super(
    child: Rack(),
    alignment: Anchor.bottomLeft,
  );
}

class Rack extends RectangleComponent with HasGameRef<WordGame> {
  late PresenceState presenceState;
  late Point<double> tileTimer;

  Rack() : super(size: Vector2(1000, RackBack.rackHeight)) {
    renderShape = false;
    tileTimer = Point(0, 4);
  }

  @override
  void onMount() {
    super.onMount();
    final appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
    presenceState = appState.presenceState!;
    add(RackBack(presenceState));
    for (int i = 0; i < presenceState.rackSize; i++) {
      add(RackTile(presenceState, i));
    }
  }

  @override
  void update(double dt) {
    if (presenceState.rack.length >= presenceState.rackSize) {
      tileTimer = Point(0, tileTimer.y);
    } else {
      tileTimer += Point(dt, 0);
    }
    if (tileTimer.x >= tileTimer.y) {
      presenceState.drawTile();
      tileTimer -= Point(tileTimer.y, 0);
    }
  }
}

class RackBack extends ScaledNineTileBoxComponent {
  static double rackHeight = 105;

  PresenceState presenceState;

  RackBack(this.presenceState);

  @override
  Future<void> onLoad() async {
    final sprite = await Sprite.load('rack.png');
    nineTileBox = AlphaNineTileBox(sprite, opacity: 0.8, leftWidth: 1, bottomHeight: 1, rightWidth: 128, topHeight: 128);
    final width = presenceState.rackSize * RackTile.spacing + 10;
    // We have to do this stupid dance because NineTileBoxComponent has no way of setting the corner scale.
    size = Vector2(width, rackHeight);
    cornerScale = .2;
    super.onLoad();
  }
}

class RackTile extends SpriteComponent {
  static double spacing = 100;

  PresenceState presenceState;
  int index;
  late Sprite spriteTile, spriteSlot;
  late TextComponent textComponent;

  final TextPaint styleTile = TextPaint(
    style: TextStyle(
      fontSize: 72,
      fontFamily: 'Katahdin Round Dekerned',
      color: BasicPalette.black.color,
    ),
  );

  RackTile(this.presenceState, this.index) : super(size: Vector2.all(spacing * 1.1));

  @override
  Future<void> onLoad() async {
    spriteTile = await Sprite.load('tile.png');
    spriteSlot = await Sprite.load('rack_slot.png');
    sprite = spriteSlot;
    position = Vector2(index * spacing, -12);
    textComponent = TextBoxComponent(
      textRenderer: styleTile,
      position: Vector2.zero(),
      align: Anchor.center,
      size: Vector2(RackBack.rackHeight, RackBack.rackHeight - 5),
    );
    add(textComponent);
  }

  @override
  void update(double dt) {
    final tilePresent = index < presenceState.rack.length;
    if (!tilePresent) {
      sprite = spriteSlot;
      opacity = .8;
      textComponent.text = '';
      return;
    }
    sprite = spriteTile;
    final letter = presenceState.rack[index];
    textComponent.text = letter.toUpperCase();
    // Check if provisional.
    int numOfLetter = presenceState.provisionalTiles.values.where((item) => item == letter).length;
    bool isProvisional = numOfLetter > 0;
    for (int i = index - 1; i >= 0; i--) {
      if (presenceState.rack[i] == letter) {
        numOfLetter--;
        if (numOfLetter == 0) {
          isProvisional = false;
          break;
        }
      }
    }
    opacity = isProvisional ? 0.5 : 1;
  }
}