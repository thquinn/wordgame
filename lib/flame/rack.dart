import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
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
  late LocalState localState;
  late Point<double> tileTimer;

  Rack() : super(size: Vector2(1000, RackBack.rackHeight)) {
    renderShape = false;
    tileTimer = Point(0, 4);
  }

  @override
  void onMount() {
    super.onMount();
    final appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
    localState = appState.localState!;
    add(RackBack(localState));
    for (int i = 0; i < localState.rackSize; i++) {
      add(RackTile(localState, i));
    }
  }

  @override
  void update(double dt) {
    if (localState.rack.length >= localState.rackSize) {
      tileTimer = Point(0, tileTimer.y);
    } else {
      tileTimer += Point(dt, 0);
    }
    if (tileTimer.x >= tileTimer.y) {
      localState.drawTile();
      tileTimer -= Point(tileTimer.y, 0);
    }
  }
}

class RackBack extends ScaledNineTileBoxComponent {
  static double rackHeight = 105;

  LocalState localState;

  RackBack(this.localState);

  @override
  Future<void> onLoad() async {
    final sprite = await Sprite.load('rack.png');
    nineTileBox = AlphaNineTileBox(sprite, opacity: 0.8, leftWidth: 1, bottomHeight: 1, rightWidth: 128, topHeight: 128);
    final width = localState.rackSize * RackTile.spacing + 10;
    // We have to do this stupid dance because NineTileBoxComponent has no way of setting the corner scale.
    size = Vector2(width, rackHeight);
    cornerScale = .2;
    super.onLoad();
  }
}

class RackTile extends SpriteComponent {
  static double spacing = 100;

  LocalState localState;
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
  final TextPaint styleAssist = TextPaint(
    style: TextStyle(
      fontSize: 24,
      fontFamily: 'Solway',
      fontWeight: FontWeight.bold,
      color: BasicPalette.white.color,
    ),
  );

  RackTile(this.localState, this.index) : super(size: Vector2.all(spacing * 1.1));

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
    final tilePresent = index < localState.rack.length;
    if (!tilePresent) {
      sprite = spriteSlot;
      opacity = .8;
      textComponent.text = '';
      return;
    }
    sprite = spriteTile;
    final letter = localState.rack[index];
    textComponent.text = letter.toUpperCase();
    // Check if provisional.
    int numOfLetter = localState.provisionalTiles.values.where((item) => item == letter).length;
    bool isProvisional = numOfLetter > 0;
    for (int i = index - 1; i >= 0; i--) {
      if (localState.rack[i] == letter) {
        numOfLetter--;
        if (numOfLetter == 0) {
          isProvisional = false;
          break;
        }
      }
    }
    opacity = isProvisional ? 0.5 : 1;
    // Assist notification.
    if (index == localState.rack.length - 1 && localState.assister != null) {
      add(TextBoxComponentWithOpacity(
        text: '¢${localState.assister}',
        textRenderer: styleAssist,
        anchor: Anchor.center,
        align: Anchor.center,
        position: Vector2(size.x / 2, -20),
      )..opacity = 0
      ..add(MoveByEffect(
        Vector2(0, -50),
        CurvedEffectController(3, CurveAverager([Curves.easeInOut, Curves.linear]))
      ))..add(SequenceEffect([
        OpacityEffect.fadeIn(EffectController(duration: 1)),
        OpacityEffect.to(1, EffectController(duration: 1)),
        OpacityEffect.fadeOut(EffectController(duration: 1)),
        RemoveEffect(),
      ])));
      localState.assister = null;
    }
  }
}