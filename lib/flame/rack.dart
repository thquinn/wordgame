import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/experimental.dart';
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
  late WordGameState appState;
  late LocalState localState;
  late Point<double> tileTimer;

  Rack() : super(size: Vector2(1, RackBack.rackHeight)) {
    renderShape = false;
    resetTileTimer();
  }
  resetTileTimer() {
    tileTimer = Point(0, 7);
  }

  @override
  void onMount() {
    super.onMount();
    appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
    localState = appState.localState!;
    add(RackBack(localState));
    for (int i = 0; i < localState.rackSize; i++) {
      add(RackTile(localState, i));
    }
    add(RackCooldown(appState, this));
    add(RackOverflowCounter(localState));
  }

  @override
  void update(double dt) {
    if (!appState.gameIsActive()) {
      resetTileTimer();
      return;
    }
    if (localState.rack.length >= localState.rackSize) {
      resetTileTimer();
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

  RackBack(this.localState) : super(.2);

  @override
  Future<void> onLoad() async {
    final sprite = await Sprite.load('rack.png');
    nineTileBox = AlphaNineTileBox(sprite, opacity: 0.8, leftWidth: 1, bottomHeight: 1, rightWidth: 128, topHeight: 128);
    final width = localState.rackSize * RackTile.spacing + 10;
    // We have to do this stupid dance because NineTileBoxComponent has no way of setting the corner scale.
    size = Vector2(width, rackHeight);
    super.onLoad();
  }
}

class RackTile extends SpriteComponent {
  static double spacing = 100;

  LocalState localState;
  int index;
  late Sprite spriteTile, spriteSlot;
  late TextComponent textComponent;
  late MoveAlongPathEffect hopEffect;

  static final TextPaint styleTile = TextPaint(
    style: TextStyle(
      fontSize: 72,
      fontFamily: 'Katahdin Round Dekerned',
      color: BasicPalette.black.color,
    ),
  );
  static final TextPaint styleAssist = TextPaint(
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
    add(textComponent = TextBoxComponent(
      textRenderer: styleTile,
      position: Vector2.zero(),
      align: Anchor.center,
      size: Vector2(RackBack.rackHeight, RackBack.rackHeight - 5),
    ));
    add(hopEffect = MoveAlongPathEffect(
      Path()..quadraticBezierTo(0, -20, 0, 0),
      EffectController(duration: 0.2, curve: Curves.slowMiddle)
    )..pause()..removeOnFinish = false);
  }

  @override
  void update(double dt) {
    final tilePresent = index < localState.rack.length;
    if (tilePresent != textComponent.text.isNotEmpty) {
      if (tilePresent) {
        sprite = spriteTile;
        hopEffect.reset();
      } else {
        sprite = spriteSlot;
        opacity = .8;
        textComponent.text = '';
      }
    }
    if (!tilePresent) return;
    
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
      final x = size.x / 2 + (localState.overflowTiles > 0 ? spacing : 0) - 3;
      add(TextBoxComponentWithOpacity(
        text: '¢${localState.assister}',
        textRenderer: styleAssist,
        anchor: Anchor.center,
        align: Anchor.center,
        position: Vector2(x, -20),
      )..opacity = 0
      ..add(MoveByEffect(
        Vector2(0, -50),
        CurvedEffectController(3, Curves.slowMiddle)
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

class RackCooldown extends PositionComponent with HasVisibility {
  static final TextPaint styleLabel = TextPaint(
    style: TextStyle(
      fontSize: 36,
      fontFamily: 'Katahdin Round Dekerned',
      color: BasicPalette.white.color,
    ),
  );

  final WordGameState state;
  final Rack rack;
  late TextBoxComponent label;

  RackCooldown(this.state, this.rack);

  @override
  FutureOr<void> onLoad() {
    add(RackCooldownCircle(rack));
    add(label = TextBoxComponent(
      textRenderer: styleLabel,
      anchor: Anchor.center,
      align: Anchor.center,
      size: Vector2.all(200),
    ));
  }

  @override
  void update(double dt) {
    final localState = state.localState!;
    isVisible = state.gameIsActive() && localState.rack.length < localState.rackSize;
    position = Vector2(localState.rack.length * RackTile.spacing + RackBack.rackHeight / 2 + 2, RackBack.rackHeight / 2);
    label.text = (rack.tileTimer.y - rack.tileTimer.x).ceil().toString();
  }
}

class RackCooldownCircle extends ClipComponent {
  final Rack rack;

  RackCooldownCircle(this.rack) : super.circle(size: Vector2.all(75));

  @override
  Future<void> onLoad() async {
    final spriteCircle = await Sprite.load('circle.png');
    add(SpriteComponent(
      sprite: spriteCircle,
      size: size,
      anchor: Anchor.center,
    )..opacity = .2);
  }

  @override
  void render(Canvas canvas) {
    final percent = rack.tileTimer.x / rack.tileTimer.y;
    final points = [
      Vector2(0, 0),
      Vector2(0, -size.x),
      if (percent > .125) Vector2(size.x, -size.x),
      if (percent > .375) Vector2(size.x, size.x),
      if (percent > .625) Vector2(-size.x, size.x),
      if (percent > .875) Vector2(-size.x, -size.x),
    ];
    final radians = percent * 2 * pi;
    points.add(Vector2(sin(radians), -cos(radians)) * size.x * 2);
    canvas.clipPath(Polygon(points).asPath());
  }
}

class RackOverflowCounter extends PositionComponent with HasVisibility {
  LocalState localState;
  late TextBoxComponent text;

  RackOverflowCounter(this.localState);

  @override
  FutureOr<void> onLoad() async {
    final box = ScaledNineTileBoxComponent(.1);
    final boxSprite = await Sprite.load('panel.png');
    box.nineTileBox = AlphaNineTileBox(boxSprite, opacity: 0.8, leftWidth: 120, rightWidth: 120, topHeight: 120, bottomHeight: 120);
    box.anchor = Anchor.center;
    box.size = Vector2(70, 70);
    add(box);
    add(text = TextBoxComponent(
      textRenderer: RackCooldown.styleLabel,
      size: Vector2(70, 70),
      anchor: Anchor.center,
      align: Anchor.center,
    ));
  }

  @override
  void update(double dt) {
    isVisible = localState.overflowTiles > 0;
    position = Vector2(localState.rackSize * RackTile.spacing + RackBack.rackHeight / 2 + 12, RackBack.rackHeight / 2);
    if (text.text != '+${localState.overflowTiles}') {
      text.text = '+${localState.overflowTiles}';
    }
  }
}
