import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/layout.dart';
import 'package:flame/palette.dart';
import 'package:flutter/painting.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/state.dart';

class TeamAnchor extends AlignComponent {
  TeamAnchor() : super(
    child: TeamPanels(),
    alignment: Anchor.bottomRight,
  );
}

class TeamPanels extends PositionComponent with HasGameRef<WordGame> {
  static final TextPaint stylePlayers = TextPaint(
    style: TextStyle(
      fontSize: 24,
      fontFamily: 'Solway',
      fontWeight: FontWeight.bold,
      color: BasicPalette.white.color,
    ),
  );

  late WordGameState appState;
  late TextBoxComponent textbox;

  @override
  FutureOr<void> onLoad() {
    textbox = TextBoxComponent(
      textRenderer: stylePlayers,
      size: Vector2(500, 500),
      anchor: Anchor.bottomRight,
      align: Anchor.bottomRight,
    );
    add(textbox);
  }

  @override
  FutureOr<void> onMount() {
    appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
  }

  @override
  void update(double dt) {
    final List<String> usernames = appState.channel!.presenceState().map((e) => e.presences.first.payload['username']).where((e) => e != null).cast<String>().toList();
    usernames.sort();
    textbox.text = usernames.join('\n');
  }
}