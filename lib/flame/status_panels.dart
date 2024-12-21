import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/layout.dart';
import 'package:flame/palette.dart';
import 'package:flame/text.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/extensions.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/model.dart';
import 'package:wordgame/state.dart';

class StatusAnchor extends AlignComponent {
  StatusAnchor() : super(
    child: StatusPanels(),
    alignment: Anchor.topRight,
  );
}

class StatusPanels extends PositionComponent with HasGameRef<WordGame> {
  @override
  FutureOr<void> onMount() {
    final appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
    add(StatusBox(
      0,
      'Score',
      () => (appState.game?.state.score ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')
    ));
    add(StatusBox(
      1,
      'Time',
      () {
        final Game? game = appState.game;
        if (game == null) return '';
        final duration = game.endsAt.difference(game.startsAt.isBefore(DateTime.now()) ? DateTime.now() : game.startsAt);
        if (duration.isNegative) return '0:00';
        final milliseconds = duration.inMilliseconds;
        final minutes = milliseconds ~/ (60 * 1000);
        final seconds = min(59, (milliseconds.remainder(60 * 1000) / 1000).ceil());
        return '$minutes:${seconds.toString().padLeft(2, '0')}';
      }
    ));
  }
}

class StatusBox extends PositionComponent {
  static double panelWidth = 300;
  static double panelHeight = 60;
  static double panelSpacing = 10;
  final TextPaint styleLabel = TextPaint(
    style: TextStyle(
      fontSize: 24,
      fontFamily: 'Solway',
      fontWeight: FontWeight.bold,
      color: BasicPalette.white.color,
    ),
  );
  final TextPaint styleContent = TextPaint(
    style: TextStyle(
      fontSize: 48,
      fontFamily: 'Solway',
      fontWeight: FontWeight.bold,
      color: BasicPalette.white.color,
    ),
  );

  int index;
  String label;
  String Function() getContent;

  late ScaledNineTileBoxComponent box;
  late TextBoxComponent contentText;

  StatusBox(this.index, this.label, this.getContent);

  @override
  FutureOr<void> onLoad() async {
    position = Vector2(-panelSpacing, panelSpacing + (panelHeight + panelSpacing) * index);
    box = ScaledNineTileBoxComponent(.2);
    box.anchor = Anchor.topRight;
    final sprite = await Sprite.load('panel.png');
    box.nineTileBox = AlphaNineTileBox(sprite, opacity: 0.8, leftWidth: 120, bottomHeight: 120, rightWidth: 120, topHeight: 120);
    box.size = Vector2(panelWidth, panelHeight);
    add(box);
    add(TextBoxComponent(
      text: label,
      textRenderer: styleLabel,
      position: Vector2(-panelWidth + panelSpacing, 2),
      size: Vector2(panelWidth, panelHeight),
      align: Anchor.bottomLeft,
    ));
    add(contentText = TextBoxComponent(
      textRenderer: styleContent,
      position: Vector2(-panelWidth, 8),
      size: Vector2(panelWidth - panelSpacing, panelHeight),
      align: Anchor.bottomRight,
    ));
  }

  @override
  void update(double dt) {
    contentText.text = getContent();
  }
}
