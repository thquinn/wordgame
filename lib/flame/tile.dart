import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/color_matrix_hsv.dart';
import 'package:wordgame/flame/extensions.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/model.dart';
import 'package:wordgame/state.dart';

class TileManager extends PositionComponent with HasGameRef<WordGame> {
    static int updates = 0;

    late WordGameState appState;
    Map<Point<int>, TileWrapper> tiles = {};

    @override
    void onMount() {
      super.onMount();
      appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
      appState.addListener(() => update(0)); // get notified changes on the same frame they happen
    }

    @override
    void update(double dt) {
      if (appState.game == null) return;
      // Remove tiles.
      final removedCoors = tiles.keys.where((coor) => !appState.game!.state.placedTiles.containsKey(coor) && !appState.localState!.provisionalTiles.containsKey(coor)).toList();
      for (final removedCoor in removedCoors) {
        TileWrapper tile = tiles[removedCoor]!;
        tile.isVisible = false;
        remove(tile);
        tiles.remove(removedCoor);
      }
      // Add tiles.
      final tileCoors = List.from(appState.game!.state.placedTiles.keys)..addAll(appState.localState!.provisionalTiles.keys);
      for (final coor in tileCoors) {
        if (!tiles.containsKey(coor)) {
          TileWrapper tile = TileWrapper(appState, coor);
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
  final WordGameState appState;
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

  TileWrapper(this.appState, this.coor) : super.polygon(
    position: Vector2(coor.x.toDouble(), coor.y.toDouble()),
    points: clippingPoints,
    size: Vector2(1, 1),
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    tile = Tile(appState, coor);
    add(tile);
  }

  @override
  void onMount() {
    transform.position = Vector2(coor.x.toDouble(), coor.y.toDouble());
  }

  @override void render(Canvas canvas) {
    if (tile.lift > 0) {
      super.render(canvas);
    }
  }
}

class Tile extends SpriteComponent with HasGameRef<WordGame> {
  static final List<ColorFilter> teammateFilters = [
    ColorMatrixHsv.matrix(hue: 2),
    ColorMatrixHsv.matrix(hue: 0.8, brightness: -0.05), // blue
    ColorMatrixHsv.matrix(hue: 0.07, saturation: 0.5), // yellow
    ColorMatrixHsv.matrix(hue: 0.5, brightness: -0.05), // teal
    ColorMatrixHsv.matrix(hue: 0.25, saturation: 0.15), // green
    ColorMatrixHsv.matrix(hue: -0.3, saturation: 0.25, brightness: -0.1), // rosy pink
  ];

  TileState tileState = TileState.unknown;
  final WordGameState appState;
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

  Tile(this.appState, this.coor) : super(size: Vector2.all(1));

  @override
  Future<void> onLoad() async {
    spriteTile = await Sprite.load('tile.png');
    spriteTilePlaced = await Sprite.load('tile_placed.png');
    spriteProvisional = await Sprite.load('tile_outline.png');
    sprite = spriteTile;
    anchor = Anchor(.5, .5);
    final letter = appState.localState!.provisionalTiles.containsKey(coor) ? appState.localState!.provisionalTiles[coor] : appState.game!.state.placedTiles[coor]!.letter;
    textComponent = TextBoxComponent(
      text: letter,
      textRenderer: styleTile,
      position: Vector2(-1, -1),
      align: Anchor.center,
      size: Vector2(3, 2.35),
      pixelRatio: 200,
      priority: 1,
    );
    update(0);
    add(textComponent);
  }

  @override
  void update(double dt) {
    LocalState localState = appState.localState!;
    TileState newState = localState.provisionalTiles.containsKey(coor) ? TileState.provisional : TileState.played;
    if (newState != tileState) {
      if (newState == TileState.played && TileManager.updates > 20) {
        lift = 1;
        opacity = 0;
        add(OpacityEffect.fadeIn(EffectController(duration: .25)));
      }
      tileState = newState;
      sprite = tileState == TileState.provisional ? spriteProvisional : lift > 0 ? spriteTile : spriteTilePlaced;
      textComponent.textRenderer = tileState == TileState.provisional ? styleProvisional : styleTile;
      if (tileState == TileState.played) {
        paint.colorFilter = teammateFilters[0];
      }
    }
    final letter = tileState == TileState.provisional ? localState.provisionalTiles[coor] : appState.game?.state.placedTiles[coor]?.letter;
    textComponent.text = letter?.toUpperCase() ?? '';
    // Placement animation.
    if (lift > 0) {
      lift = max(lift - dt * 2, 0);
      position = Vector2(0, Curves.easeInOutCubic.transform(lift) * -.5);
      if (lift == 0) {
        sprite = spriteTilePlaced;
      }
    }
  }
}

enum TileState { unknown, provisional, played }