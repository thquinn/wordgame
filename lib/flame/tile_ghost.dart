import 'dart:async';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/flame/tile.dart';
import 'package:wordgame/state.dart';

class TileGhostManager extends PositionComponent with HasGameRef<WordGame> {
  late WordGameState appState;
  late Sprite sprite;
  final List<TileGhost> ghosts = [];

  @override
  void onMount() async {
    appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
    sprite = await Sprite.load('tile_ghost.png');
  }

  @override
  void update(double dt) {
    final List<TileGhostTemplate> templates = [];
    for (final payload in appState.channel!.presenceState().map((e) => e.presences.first.payload)) {
      final username = payload['username'];
      if (username == appState.localState!.username) continue;
      final colorFilter = Tile.getColorFilterForUsername(username);
      final provisionalList = payload['provisional_tiles'] as List<dynamic>;
      for (int i = 0; i < provisionalList.length; i += 3) {
        templates.add(TileGhostTemplate(Vector2(provisionalList[i], provisionalList[i + 1]), colorFilter));
      }
    }
    while (ghosts.length < templates.length) {
      final ghost = TileGhost(sprite);
      add(ghost);
      ghosts.add(ghost);
    }
    for (int i = 0; i < ghosts.length; i++) {
      final ghost = ghosts[i];
      ghost.isVisible = i < templates.length;
      if (!ghost.isVisible) continue;
      ghost.position = templates[i].position - Vector2.all(0.5);
      ghost.paint.colorFilter = templates[i].colorFilter;
    }
  }
}

class TileGhostTemplate {
  Vector2 position;
  ColorFilter colorFilter;

  TileGhostTemplate(this.position, this.colorFilter);
}

class TileGhost extends SpriteComponent with HasVisibility {
  TileGhost(Sprite sprite) : super(sprite: sprite, size: Vector2.all(1));

  @override
  FutureOr<void> onLoad() {
    opacity = 0.5;
  }
}