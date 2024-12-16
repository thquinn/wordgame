import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/layout.dart';
import 'package:flame/palette.dart';
import 'package:flutter/painting.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/extensions.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/state.dart';

class TeamAnchor extends AlignComponent {
  TeamAnchor() : super(
    child: TeamPanels(),
    alignment: Anchor.bottomRight,
  );
}

class TeamPanels extends PositionComponent with HasGameRef<WordGame> {
  static const double LINE_SPACING = 30;
  static final TextPaint stylePlayers = FixedHeightTextPaint(
    LINE_SPACING,
    style: TextStyle(
      fontSize: 24,
      fontFamily: 'Solway',
      fontWeight: FontWeight.bold,
      color: BasicPalette.white.color,
    ),
  );

  late WordGameState appState;
  late TextBoxComponent textbox;
  late SpriteComponent crown;

  @override
  FutureOr<void> onLoad() async {
    Sprite crownSprite = await Sprite.load('crown.png');
    add(textbox = TextBoxComponent(
      position: Vector2(-30, 0),
      textRenderer: stylePlayers,
      size: Vector2(500, 500),
      anchor: Anchor.bottomRight,
      align: Anchor.bottomRight,
    ));
    add(crown = SpriteComponent(
      sprite: crownSprite,
      size: Vector2.all(24),
      anchor: Anchor.center,
      paint: Paint()..filterQuality = FilterQuality.high,
    ));
  }

  @override
  FutureOr<void> onMount() {
    appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
  }

  @override
  void update(double dt) {
    final presences = appState.channel!.presenceState().map((e) => e.presences.first);
    final adminUsername = appState.getAdminUsername();
    print('admin is $adminUsername');
    final List<String> usernames = presences.map((e) => e.payload['username']).where((e) => e != null).cast<String>().toList();
    usernames.sort();
    final lines = [];
    for (final username in usernames.reversed) {
      lines.insert(0, username);
      if (username == adminUsername) {
        crown.position = Vector2(-20, lines.length * -LINE_SPACING + 6);
      }
    }
    textbox.text = usernames.join('\n');
  }
}