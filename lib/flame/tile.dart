import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/state.dart';

class TileManager extends PositionComponent with HasGameRef<WordGame> {
    static int updates = 0;

    late WordGameState appState;
    Map<Point<int>, TileWrapper> tiles = {};

    TileManager() : super(size: Vector2.all(1));

    @override
    void onMount() {
      super.onMount();
      appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
    }

    @override
    void update(double dt) {
      if (appState.game == null) return;
      // Remove tiles.
      final removedCoors = tiles.keys.where((coor) => !appState.game!.state.placedTiles.containsKey(coor) && !appState.presenceState!.provisionalTiles.containsKey(coor)).toList();
      for (final removedCoor in removedCoors) {
        TileWrapper tile = tiles[removedCoor]!;
        tile.isVisible = false;
        remove(tile);
        tiles.remove(removedCoor);
      }
      // Add tiles.
      final tileCoors = List.from(appState.game!.state.placedTiles.keys)..addAll(appState.presenceState!.provisionalTiles.keys);
      for (final coor in tileCoors) {
        if (!tiles.containsKey(coor)) {
          TileWrapper tile = TileWrapper(coor);
          add(tile);
          tiles[coor] = tile;
        }
      }
      if (tiles.isNotEmpty) {
        updates++;
      }
    }
}

class TileWrapper extends ClipComponent with HasGameRef<WordGame>, HasVisibility {
  late WordGameState appState;
  Point<int> coor;
  late Tile tile;

  static List<Vector2> makeClippingPoints() {
    final points = [Vector2(.42, -1), Vector2(-.42, -1)];
    const radius = .15;
    const segments = 8;
    for (int i = 0; i <= segments; i++) {
      final theta = pi / 2 * i / segments;
      points.add(Vector2(
        -.42 + radius * (1 - cos(theta)),
        .41 - radius * (1 - sin(theta))
      ));
    }
    for (int i = 0; i <= segments; i++) {
      final theta = pi / 2 * i / segments;
      points.add(Vector2(
        .42 - radius * (1 - sin(theta)),
        .41 - radius * (1 - cos(theta))
      ));
    }
    return points;
  }
  static List<Vector2> clippingPoints = makeClippingPoints();

  TileWrapper(this.coor) : super.polygon(
    position: Vector2(coor.x.toDouble(), coor.y.toDouble()),
    points: clippingPoints,
    size: Vector2(1, 1),
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    tile = Tile(coor);
    add(tile);
  }

  @override
  void onMount() {
    super.onMount();
    appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
    transform.position = Vector2(coor.x.toDouble(), coor.y.toDouble());
    update(0);
  }

  @override void render(Canvas canvas) {
    //if (tile.lift > 0) {
      super.render(canvas);
    //}
  }
}

class Tile extends SpriteComponent with HasGameRef<WordGame> {
  TileState tileState = TileState.unknown;
  late WordGameState appState;
  Point<int> coor;
  late TextComponent textComponent;
  late Sprite spriteTile, spriteTilePlaced, spriteProvisional;
  double lift = 0;

  final TextPaint styleTile = TextPaint(
    style: TextStyle(
      fontSize: .66,
      fontFamily: 'Katahdin Round Dekerned',
      color: BasicPalette.black.color,
    ),
  );
  final TextPaint styleProvisional = TextPaint(
    style: TextStyle(
      fontSize: .66,
      fontFamily: 'Katahdin Round Dekerned',
      color: BasicPalette.white.color,
    ),
  );

  Tile(this.coor) : super(size: Vector2.all(1));

  @override
  Future<void> onLoad() async {
    spriteTile = await Sprite.load('tile.png');
    spriteTilePlaced = await Sprite.load('tile_placed.png');
    spriteProvisional = await Sprite.load('tile_outline.png');
    sprite = spriteTile;
    anchor = Anchor(.5, .5);
    textComponent = TextBoxComponent(
      textRenderer: styleTile,
      position: Vector2(-1, -1),
      align: Anchor.center,
      size: Vector2(3, 2.35),
      pixelRatio: 200,
      priority: 1,
    );
    add(textComponent);
  }

  @override
  void onMount() {
    super.onMount();
    appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
    update(0);
  }

  @override
  void update(double dt) {
    TileState newState = appState.presenceState!.provisionalTiles.containsKey(coor) ? TileState.provisional : TileState.played;
    if (newState != tileState) {
      if (newState == TileState.played && TileManager.updates > 20) {
        lift = 1;
        opacity = 0;
        add(OpacityEffect.fadeIn(EffectController(duration: .25)));
      }
      tileState = newState;
      sprite = tileState == TileState.provisional ? spriteProvisional : lift > 0 ? spriteTile : spriteTilePlaced;
      textComponent.textRenderer = tileState == TileState.provisional ? styleProvisional : styleTile;
    }
    final letter = tileState == TileState.provisional ? appState.presenceState?.provisionalTiles[coor] : appState.game?.state.placedTiles[coor]?.letter;
    textComponent.text = letter?.toUpperCase() ?? '';
    // Placement animation.
    if (lift > 0) {
      lift = max(lift - dt * 3, 0);
      position = Vector2(0, Curves.easeInOutCubic.transform(lift) * -.5);
      if (lift == 0) {
        sprite = spriteTilePlaced;
      }
    }
  }
}

enum TileState { unknown, provisional, played }