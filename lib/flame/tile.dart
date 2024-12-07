import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flutter/painting.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/state.dart';

class TileManager extends PositionComponent with HasGameRef<WordGame> {
    late MyAppState appState;
    Map<Point<int>, Tile> placedTiles = {};

    TileManager() : super(size: Vector2.all(1));

    @override
    void onMount() {
      super.onMount();
      appState = Provider.of<MyAppState>(game.buildContext!, listen: false);
    }

    @override
    void update(double dt) {
      if (appState.game == null) return;
      for (final entry in appState.game!.state.placedTiles.entries) {
        if (!placedTiles.containsKey(entry.key)) {
          Tile tile = Tile(entry.key);
          add(tile);
          placedTiles[entry.key] = tile;
        }
      }
    }
}

class Tile extends SpriteComponent with HasGameRef<WordGame> {
  late MyAppState appState;
  Point<int> coor;
  late TextComponent textComponent;

  Tile(this.coor) : super(size: Vector2.all(1));

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('tile.png');
    anchor = Anchor(.5, .5);
    textComponent = TextBoxComponent(
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: .66,
          fontFamily: 'Katahdin Round Dekerned',
          color: BasicPalette.black.color,
        ),
      ),
      position: Vector2(-1, -1),
      align: Anchor.center,
      size: Vector2(3, 2.35),
      pixelRatio: 100,
      priority: 1,
    );
    add(textComponent);
  }

  @override
  void onMount() {
    super.onMount();
    appState = Provider.of<MyAppState>(game.buildContext!, listen: false);
  }

  @override
  void update(double dt) {
    transform.position = Vector2(coor.x.toDouble(), coor.y.toDouble());
    textComponent.text = appState.game?.state.placedTiles[coor]?.letter ?? '';
  }
}