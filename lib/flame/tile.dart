import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/color_matrix_hsvc.dart';
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
    ColorMatrixHSVC.make(hue: 0.45, brightness: -0.2), // blue
    ColorMatrixHSVC.make(hue: 0.15, saturation: 1.2), // green
    ColorMatrixHSVC.make(hue: -0.15, brightness: -0.33), // dull red
    ColorMatrixHSVC.make(hue: -0.4, saturation: 2, brightness: -0.3), // purple
    ColorMatrixHSVC.make(hue: -0.2, saturation: 2), // pink
    ColorMatrixHSVC.make(hue: 0.02, saturation: 2.5), // yellow
    ColorMatrixHSVC.make(hue: 0.5, saturation: 2, brightness: 0.3), // ice blue
    ColorMatrixHSVC.make(hue: -.05, saturation: 2.5), // orange
    ColorMatrixHSVC.make(saturation: 0, brightness: .2), // light gray
    ColorMatrixHSVC.make(hue: 0.33, saturation: 0.7), // teal
    ColorMatrixHSVC.make(hue: -0.125, saturation: 3, brightness: -0.1), // peach
  ];
  static final Map<String, int> teammateFilterIndices = {};

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

  Tile(this.appState, this.coor) : super(size: Vector2.all(1), paint: Paint()..filterQuality = FilterQuality.high);

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
      anchor: Anchor(0, 0),
      position: Vector2(.1, .1),
      align: Anchor(.5, .52),
      size: Vector2(.8, .8),
      pixelRatio: 200,
      priority: 1,
    );
    update(0);
    add(textComponent);
  }

  @override
  void update(double dt) {
    LocalState localState = appState.localState!;
    TileState newState = localState.provisionalTiles.containsKey(coor) ? TileState.provisional : appState.game!.state.placedTiles.containsKey(coor) ? TileState.played : TileState.removed;
    if (newState == TileState.removed) {
      return;
    }
    if (newState != tileState) {
      tileState = newState;
      // Start placement animation.
      if (tileState == TileState.played && TileManager.updates > 20) {
        lift = 1;
        opacity = 0;
        add(OpacityEffect.fadeIn(EffectController(duration: .25)));
      }
      // Set sprite and text.
      sprite = tileState == TileState.provisional ? spriteProvisional : lift > 0 ? spriteTile : spriteTilePlaced;
      textComponent.textRenderer = tileState == TileState.provisional ? styleProvisional : styleTile;
      // Teammate colors.
      if (tileState == TileState.played) {
        PlacedTile placed = appState.game!.state.placedTiles[coor]!;
        if (placed.username != appState.localState!.username) {
          if (!teammateFilterIndices.containsKey(placed.username)) {
            teammateFilterIndices[placed.username] = teammateFilterIndices.length % teammateFilters.length;
          }
          paint.colorFilter = teammateFilters[teammateFilterIndices[placed.username]!];
        }
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

enum TileState { unknown, provisional, played, removed }