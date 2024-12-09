import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/layout.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  late MyAppState appState;

  Rack() : super(size: Vector2(1000, RackBack.rackHeight)) {
    renderShape = false;
  }

  @override
  Future<void> onLoad() async {
    
  }

  @override
  void onMount() {
    super.onMount();
    appState = Provider.of<MyAppState>(game.buildContext!, listen: false);
    final presenceState = appState.presenceState!;
    add(RackBack(presenceState));
    for (int i = 0; i < presenceState.rackSize; i++) {
      add(RackTile(presenceState, i));
    }
  }

  @override
  void update(double dt) {

  }
}

class RackBack extends NineTileBoxComponent {
  static double rackHeight = 105;

  PresenceState presenceState;

  RackBack(this.presenceState);

  @override
  Future<void> onLoad() async {
    final sprite = await Sprite.load('rack.png');
    nineTileBox = AlphaNineTileBox(sprite, opacity: 0.8, leftWidth: 1, bottomHeight: 1, rightWidth: 128, topHeight: 128);
    final width = presenceState.rackSize * RackTile.spacing + 10;
    // We have to do this stupid dance because NineTileBoxComponent has no way of setting the corner scale.
    scale = Vector2(.2, .2);
    size = Vector2(width, rackHeight)..divide(scale);
  }
}
class AlphaNineTileBox extends NineTileBox {
  // And we have to make this stupid thing because there's no way to set opacity on NineTileBoxComponent.
  late Rect spriteCenter;
  late Paint paint;

  AlphaNineTileBox(super.sprite, {opacity = 1.0, leftWidth, bottomHeight, rightWidth, topHeight}) : super.withGrid() {
    spriteCenter = Rect.fromLTRB(leftWidth, topHeight, sprite.src.width - rightWidth, sprite.src.height - bottomHeight);
    paint = Paint()..color = Color.fromRGBO(255, 255, 255, opacity);
  }

  @override
  void drawRect(Canvas c, [Rect? dst]) {
    c.drawImageNine(sprite.image, spriteCenter, dst!, paint);
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
    bool isProvisional = false;
    int numOfLetter = presenceState.provisionalTiles.values.where((item) => item == letter).length;
    for (int i = 0; i <= index; i++) {
      if (presenceState.rack[i] == letter) {
        numOfLetter--;
        if (numOfLetter == 0) {
          isProvisional = true;
          break;
        }
      }
    }
    opacity = isProvisional ? 0.5 : 1;
  }
}