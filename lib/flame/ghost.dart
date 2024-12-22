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
        if (username == null) continue; // should only happen when using admin tools
        if (username == appState.localState!.username) continue;
        if (!ghosts.containsKey(username)) {
          print('Creating ghost for user $username');
          Ghost ghost = Ghost(appState, username);
          ghosts[username] = ghost;
          add(ghost);
        }
      }
    }
}

class Ghost extends PositionComponent with HasGameRef<WordGame>, HasVisibility {
  final FixedHeightTextPaint textPaint = FixedHeightTextPaint(
    .3,
    style: TextStyle(
      fontSize: .25,
      fontFamily: 'Solway',
      fontWeight: FontWeight.bold,
      color: BasicPalette.white.color,
    ),
  );

  final WordGameState appState;
  final String username;
  late ScaledNineTileBoxComponent boxComponent;
  late TextBoxComponent textComponent;
  
  Ghost(this.appState, this.username) : super();
  
  @override
  Future<void> onLoad() async {
    position = Vector2(0, 1);
    final boxSprite = await Sprite.load('ghost.png');
    boxComponent = ScaledNineTileBoxComponent(.004);
    boxComponent.nineTileBox = AlphaNineTileBox(boxSprite, opacity: 0.1, leftWidth: 75, rightWidth: 75, topHeight: 127, bottomHeight: 127);
    boxComponent.position = Vector2(0, -.73);
    boxComponent.anchor = Anchor(.5, 0);
    boxComponent.size = Vector2(2, 1);
    boxComponent.scale = Vector2(1, 1);
    add(boxComponent);
    textComponent = TextBoxComponent(
      anchor: Anchor.center,
      textRenderer: textPaint,
      text: username,
      align: Anchor(.5, .49),
      size: Vector2(3, .5),
      pixelRatio: 100,
      boxConfig: TextBoxConfig(maxWidth: 10000),
    );
    add(textComponent);
    textComponent.update(0); // it occasionally fails to align, this seems to fix it...?
    final arrowSprite = await Sprite.load('ghost_arrow.png');
    add(SpriteComponent(sprite: arrowSprite, position: Vector2(0, .275), size: Vector2(1, 1), anchor: Anchor.bottomCenter)..opacity=0.1);
  }

  @override
  void update(double dt) {
    try {
      final presences = appState.channel!.presenceState().map((e) => e.presences.first);
      final presence = presences.firstWhere((e) => e.payload['username'] == username);
      final payload = presence.payload;
      final cursor = Point<int>(payload['cursor'][0], payload['cursor'][1]);
      // Find players at this position.
      final usernames = presences.where((e) => Point<int>(e.payload['cursor'][0], e.payload['cursor'][1]) == cursor).map((e) => e.payload['username'] as String).toList();
      usernames.removeWhere((e) => e == appState.localState!.username);
      usernames.sort();
      usernames.add(' '); // _HACK: text box layout messes up with just one line
      isVisible = usernames[0] == username;
      if (!isVisible) return;
      final width = max(usernames.map((u) => textComponent.getLineWidth(u, u.length)).reduce(max) + .5, 1.0);
      textComponent.lines.clear();
      textComponent.lines.addAll(usernames);
      final height = (usernames.length - 1) * textPaint.fixedHeight + .8;
      textComponent.size = Vector2(width, height);
      textComponent.position = Vector2(0, height / 2 - .5);
      boxComponent.setSize(Vector2(width, height));
      position = Vector2(cursor.x.toDouble(), cursor.y + 1.2);
    } catch (e, stackTrace) {
      isVisible = false;
      print('Ghost for $username failed to find presence.');
      print(e.toString());
      print(stackTrace.toString());
    }
  }
}