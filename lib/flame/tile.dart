import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/experimental.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/color_matrix_hsvc.dart';
import 'package:wordgame/flame/extensions.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/model.dart';
import 'package:wordgame/state.dart';
import 'package:wordgame/util.dart';

class TileManager extends PositionComponent with HasGameRef<WordGame> {
    static late TileManager instance;
    static int updates = 0;

    late WordGameState appState;
    Map<Point<int>, TileWrapper> tiles = {};
    Set<Point<int>> newCoors = {};
    Map<Point<int>, double> tileBlockTimes = {};

    @override
    FutureOr<void> onLoad() {
      instance = this;
    }

    @override
    void onMount() {
      super.onMount();
      appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
      appState.addListener(() => update(0)); // get notified changes on the same frame they happen
    }

    void gameDelta(Game oldGame, Game newGame) {
      if (oldGame.id != newGame.id) return;
      final largestNewRect = Util.findLargestNewRectangle(oldGame.state.placedTiles.keys.toSet(), newGame.state.placedTiles.keys.toSet());
      if (largestNewRect != null) {
        add(TileBlock(largestNewRect));
        for (int x = largestNewRect.upperLeft.x; x < largestNewRect.right; x++) {
          for (int y = largestNewRect.upperLeft.y; y < largestNewRect.bottom; y++) {
            tileBlockTimes[Point(x, y)] = TileBlock.LIFETIME;
          }
        }
      }
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
      newCoors = appState.game!.state.placedTiles.keys.followedBy(appState.localState!.provisionalTiles.keys).where((e) => !tiles.containsKey(e)).toSet();
      for (final coor in newCoors) {
          TileWrapper tile = TileWrapper(appState, coor);
          add(tile);
          tiles[coor] = tile;
      }
      if (tiles.isNotEmpty) {
        updates++;
      }
      // Update tile blocks.
      tileBlockTimes.removeWhere((k, v) => v <= dt);
      tileBlockTimes = tileBlockTimes.map((k, v) => MapEntry(k, v - dt));
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
  static const double placementAnimationSpeed = 2;

  TileState tileState = TileState.unknown;
  final WordGameState appState;
  Point<int> coor;
  late TextComponent textComponent;
  late Sprite spriteTile, spriteTilePlaced, spriteProvisional;
  double lift = 0;
  Effect? placementEffect;

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
    final letterWidth = styleTile.getLineMetrics(letter!).width;
    textComponent = TextComponent(
      position: Vector2(letterWidth / -2 + 0.5, -0.33),
      textRenderer: styleTile,
      size: Vector2(1, 1),
      text: letter,
    );
    update(0);
    add(textComponent);
  }

  @override
  void update(double dt) {
    final tileManager = (parent!.parent as TileManager);
    LocalState localState = appState.localState!;
    TileState newState = localState.provisionalTiles.containsKey(coor) ? TileState.provisional : appState.game!.state.placedTiles.containsKey(coor) ? TileState.played : TileState.removed;
    if (newState == TileState.removed) {
      return;
    }
    if (newState != tileState) {
      tileState = newState;
      // Start placement animation.
      if (tileState == TileState.played && TileManager.updates > 20) {
        final newCoors = tileManager.newCoors;
        if (newCoors.isNotEmpty) {
          final minX = newCoors.map((e) => e.x).reduce(min);
          final minY = newCoors.map((e) => e.y).reduce(min);
          final delay = max(coor.x - minX, coor.y - minY) * .1;
          lift = 1 + delay * placementAnimationSpeed;
          opacity = 0;
          add(placementEffect = OpacityEffect.fadeIn(EffectController(startDelay: delay, duration: .25)));
        }
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
      final clampedLift = clampDouble(lift, 0, 1);
      lift = max(lift - dt * placementAnimationSpeed, 0);
      position = Vector2(0, Curves.easeInOutCubic.transform(clampedLift) * -.5);
      if (lift == 0) {
        sprite = spriteTilePlaced;
        textComponent.textRenderer = styleTile;
      } else {
        // Would love to not create these every frame for every tile, but I don't see how to independently change
        // the opacity of TextComponents otherwise. TextBoxComponents, sure, but...
        final styleFade = TextPaint(
          style: TextStyle(
            fontSize: .66,
            fontFamily: 'Katahdin Round Dekerned',
            color: BasicPalette.black.color.withOpacity(1 - clampedLift),
          ),
        );
        textComponent.textRenderer = styleFade;
      }
    }
    // Hide for tile blocks.
    if (tileManager.tileBlockTimes.containsKey(coor)) {
      opacity = clampDouble(opacity - 10 * dt, 0, 1);
    } else if (placementEffect?.parent == null) {
      opacity = clampDouble(opacity + 10 * dt, 0, 1);
    }
  }
}
enum TileState { unknown, provisional, played, removed }

class TileBlock extends PositionComponent {
  static const double LIFETIME = 1.5;
  static final Curve OPACITY_MULTIPLIER_CURVE = CatmullRomCurve.precompute([
    Offset(.2, .5),
    Offset(.9, .6),
  ]);

  final RectInt rectInt;
  final RoundedRectangle roundedRect;
  late Paint gradientPaint;
  late AlphaNineTileBox edgeBox;
  late RectangleComponent shine;
  double t = 0;

  TileBlock(this.rectInt) : roundedRect = RoundedRectangle.fromLTRBR(
    rectInt.left.toDouble() - .42,
    rectInt.top.toDouble() - .48,
    rectInt.right.toDouble() - .59,
    rectInt.bottom.toDouble() - .645,
    0.17
  );

  @override
  FutureOr<void> onLoad() async {
    priority = -1;
    Sprite edgeSprite = await Sprite.load('tile_placed_edge.png');
    edgeBox = AlphaNineTileBox(edgeSprite, opacity: 0, leftWidth: 64, topHeight: 100, rightWidth: 64, bottomHeight: 100);
    add(ScaledNineTileBoxComponent(.00375)..nineTileBox = edgeBox..position = Vector2(roundedRect.center.x, roundedRect.bottom + 0.145)..size = Vector2(roundedRect.width + .16, 2)..anchor = Anchor.bottomCenter);
    gradientPaint = Paint();
    add(RoundedRectangleComponent(roundedRect, paint: gradientPaint));
    final shineTravelOffset = Vector2(roundedRect.width * 0.6 + roundedRect.height * 0.2 + 1.25, 0);
    final clip = ClipComponent(builder: (size) => roundedRect, children: [
      shine = RectangleComponent(
        paint: Paint()..color = BasicPalette.white.color.withOpacity(0.2),
        size: Vector2(roundedRect.width * 0.33, 20),
        angle: pi / 8,
        position: roundedRect.center - shineTravelOffset,
        anchor: Anchor.center,
      )..add(MoveEffect.to(roundedRect.center + shineTravelOffset, EffectController(duration: LIFETIME, curve: Curves.easeInOutCirc)))
    ]);
    add(clip);
  }

  @override
  void update(double dt) {
    t += dt;
    if (t >= LIFETIME) {
      removeFromParent();
      return;
    }
    double p = 2 * t / LIFETIME;
    if (p > 1) p = 2 - p;
    p = clampDouble(p, 0, 1);
    p = OPACITY_MULTIPLIER_CURVE.transform(p);
    final topOpacityBase = 0.15 + 0.1 * t / LIFETIME;
    final bottomOpacityBase = 0.45 + 0.1 * t / LIFETIME;
    const topShineOpacity = 0.7;
    const bottomShineOpacity = 0.9;
    final topOpacity = p < .5 ? topOpacityBase * p * 2 : lerpDouble(topOpacityBase, topShineOpacity, (p - 0.5) * 2)!;
    final bottomOpacity = p < .5 ? bottomOpacityBase * p * 2 : lerpDouble(bottomOpacityBase, bottomShineOpacity, (p - 0.5) * 2)!;
    gradientPaint.shader = ui.Gradient.linear(Offset(0, roundedRect.top), Offset(0, roundedRect.bottom), [Color.fromRGBO(255, 255, 255, topOpacity), Color.fromRGBO(255, 255, 255, bottomOpacity)]);
    edgeBox.paint.color = BasicPalette.white.color.withOpacity(clampDouble(p * 2 * .4, 0, .3));
  }
}
