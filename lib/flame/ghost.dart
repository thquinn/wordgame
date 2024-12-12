import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/extensions.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/state.dart';

class GhostManager extends PositionComponent with HasGameRef<WordGame> {
    late WordGameState appState;
    Map<String, Ghost> ghosts = {};

    @override
    void onMount() {
      super.onMount();
      appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
    }

    @override
    void update(double dt) {
      // Removing ghosts.
      final removedUsernames = ghosts.keys.where((username) => !appState.channel!.presenceState().any((p) => p.presences[0].payload['username'] == username)).toList();
      for (final removedUsername in removedUsernames) {
        print('Removing ghost for user $removedUsername');
        Ghost ghost = ghosts[removedUsername]!;
        remove(ghost);
        ghosts.remove(removedUsername);
      }
      // Adding ghosts.
      for (final presence in appState.channel!.presenceState()) {
        final username = presence.presences[0].payload['username'];
        if (username == appState.localState!.username) continue;
        if (!ghosts.containsKey(username)) {
          print('Creating ghost for user $username');
          Ghost ghost = Ghost(username);
          ghosts[username] = ghost;
          add(ghost);
        }
      }
    }
}

class Ghost extends PositionComponent with HasGameRef<WordGame> {
  final FixedHeightTextPaint textPaint = FixedHeightTextPaint(
    .3,
    style: TextStyle(
      fontSize: .25,
      fontFamily: 'Solway',
      fontWeight: FontWeight.bold,
      color: BasicPalette.white.color,
    ),
  );

  late WordGameState appState;
  late ScaledNineTileBoxComponent boxComponent;
  late TextBoxComponent textComponent;
  String username;
  
  Ghost(this.username) : super();
  
  @override
  Future<void> onLoad() async {
    position = Vector2(0, 1);
    final boxSprite = await Sprite.load('ghost.png');
    boxComponent = ScaledNineTileBoxComponent(.005);
    boxComponent.nineTileBox = AlphaNineTileBox(boxSprite, opacity: 0.1, leftWidth: 75, rightWidth: 75, topHeight: 127, bottomHeight: 127);
    boxComponent.position = Vector2(0, -.75);
    boxComponent.anchor = Anchor(.5, 0);
    boxComponent.size = Vector2(2, 1);
    boxComponent.scale = Vector2(1, 1);
    add(boxComponent);
    textComponent = TextBoxComponent(
      textRenderer: textPaint,
      text: username,
      position: Vector2(0, -8.1),
      align: Anchor.topCenter,
      size: Vector2(50, 10),
      anchor: Anchor(.5, 0),
      pixelRatio: 200,
      boxConfig: TextBoxConfig(growingBox: true)
    );
    add(textComponent);
    final arrowSprite = await Sprite.load('ghost_arrow.png');
    add(SpriteComponent(sprite: arrowSprite, position: Vector2(0, .275), size: Vector2(1, 1), anchor: Anchor.bottomCenter)..opacity=0.1);
  }

  @override
  void onMount() {
    super.onMount();
    appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
  }

  @override
  void update(double dt) {
    final usernames = [username];//, 'anotherguy', 'Thirdman McLongname', 'fourtho', 'fiff', 'sicks'];
    final width = max(usernames.map((u) => textComponent.getLineWidth(u, u.length)).reduce(max) + .5, 1.0);
    textComponent.text = usernames.join('\n');
    final height = usernames.length * textPaint.fixedHeight + .8;
    boxComponent.setSize(Vector2(width, height));
    try {
      final presence = appState.channel!.presenceState().firstWhere((presence) => presence.presences[0].payload['username'] == username);
      final payload = presence.presences[0].payload;
      final cursor = Point<int>(payload['cursor'][0], payload['cursor'][1]);
      position = Vector2(cursor.x.toDouble(), cursor.y.toDouble() + 1.2);
    } catch (e) {
      print('Ghost for $username failed to find presence.');
      print(e.toString());
    }
  }
}