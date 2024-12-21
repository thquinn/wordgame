import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/layout.dart';
import 'package:flame/palette.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/extensions.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/state.dart';
import 'package:wordgame/words.dart';

class ProvisionalPanelAnchor extends AlignComponent {
  ProvisionalPanelAnchor() : super(
    child: ProvisionalPanel(),
    alignment: Anchor.bottomCenter,
  );
}

class ProvisionalPanel extends PositionComponent with HasGameRef<WordGame>, HasVisibility {
  late WordGameState appState;
  late ScaledNineTileBoxComponent box;

  static const double COLUMN_SPACING = 75;
  static const double LINE_HEIGHT = 25;
  static const double PADDING_HORIZONTAL = 20;
  static const double PADDING_TOP = 17;
  static const double PADDING_BOTTOM = 20;
  static final TextPaint styleWord = TextPaint(
    style: TextStyle(
      fontSize: 24,
      fontFamily: 'Katahdin Round',
      color: BasicPalette.white.color,
    ),
  );
  static final TextPaint styleQualifier = TextPaint(
    style: TextStyle(
      fontSize: 24,
      fontFamily: 'Solway',
      color: BasicPalette.white.color,
    ),
  );
  static final TextPaint styleScore = TextPaint(
    style: TextStyle(
      fontSize: 24,
      fontFamily: 'Solway',
      fontWeight: FontWeight.bold,
      color: BasicPalette.white.color,
    ),
  );
  static final TextPaint styleInvalid = TextPaint(
    style: TextStyle(
      fontSize: 48,
      fontFamily: 'Solway',
      fontWeight: FontWeight.bold,
      color: Color.fromRGBO(255, 105, 105, 1),
    ),
  );


  @override
  void onMount() {
    appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
    appState.addListener(() => set());
  }

  @override
  FutureOr<void> onLoad() async {
    box = ScaledNineTileBoxComponent(.275);
    final sprite = await Sprite.load('panel.png');
    box.nineTileBox = AlphaNineTileBox(sprite, opacity: 0.8, leftWidth: 120, bottomHeight: 120, rightWidth: 120, topHeight: 120);
    box.position = Vector2(0, -125);
    box.anchor = Anchor.bottomCenter;
    add(box);
  }

  void set() {
    removeWhere((e) => e is TextComponent || e is RectangleComponent);
    final result = Words.getProvisionalResult(appState).score();
    isVisible = result.displayLines.isNotEmpty || result.error != ProvisionalResultError.none;
    if (!isVisible) return;
    double height = LINE_HEIGHT * (result.error != ProvisionalResultError.none ? 1 : result.displayLines.length);
    if (result.error != ProvisionalResultError.none) {
      final errorString = result.error.toString();
      final width = styleQualifier.getLineMetrics(errorString).width;
      add(TextComponent(textRenderer: styleQualifier, text: errorString, position: Vector2(-width / 2, -LINE_HEIGHT + box.position.y - PADDING_BOTTOM)));
      box.setSize(Vector2(width + 2 * PADDING_HORIZONTAL, height + PADDING_TOP + PADDING_BOTTOM));
      return;
    }
    final showTotal = result.displayLines.every((e) => e.valid) && (result.displayLines.length > 1 || int.tryParse(result.displayLines.first.scoreText) == null);
    if (showTotal) height += LINE_HEIGHT + 15;
    // Left column.
    final List<TextComponent> leftTexts = [];
    double leftMaxWidth = 200;
    for (final (i, line) in result.displayLines.indexed) {
      final y = -height + LINE_HEIGHT * i;
      final wordText = line.wordText.isNotEmpty ? TextComponent(textRenderer: styleWord, text: line.wordText, position: Vector2(0, y)) : null;
      double width = 0;
      if (wordText != null) {
        width = styleWord.getLineMetrics(line.wordText).width;
        leftTexts.add(wordText);
      }
      if (line.qualifierText.isNotEmpty) {
        final spacing = wordText == null ? 0 : 10;
        leftTexts.add(TextComponent(textRenderer: styleQualifier, text: line.qualifierText, position: Vector2(width + spacing, y)));
        width += styleQualifier.getLineMetrics(line.qualifierText).width + spacing;
      }
      leftMaxWidth = max(leftMaxWidth, width);
    }
    // Right column.
    final List<PositionComponent> rightTexts = [];
    double rightMaxWidth = 0;
    for (final (i, line) in result.displayLines.indexed) {
      final style = line.valid ? styleScore : styleInvalid;
      final y = -height + LINE_HEIGHT * i + (line.valid ? 0 : -16);
      final width = style.getLineMetrics(line.scoreText).width;
      rightMaxWidth = max(rightMaxWidth, width);
      rightTexts.add(TextComponent(textRenderer: style, text: line.scoreText, position: Vector2(width / -2, y)));
    }
    // Total.
    if (showTotal) {
      final s = result.total.toString();
      final width = styleScore.getLineMetrics(s).width;
      rightMaxWidth = max(rightMaxWidth, width);
      rightTexts.add(TextComponent(textRenderer: styleScore, text: s, position: Vector2(width / -2, -LINE_HEIGHT)));
      final lineWidth = rightMaxWidth + 15;
      rightTexts.add(RectangleComponent(position: Vector2(lineWidth / -2, -LINE_HEIGHT - 6), size: Vector2(lineWidth, 2), paint: BasicPalette.white.paint()));
    }
    // Align and add.
    final totalWidth = leftMaxWidth + rightMaxWidth + COLUMN_SPACING;
    box.setSize(Vector2(totalWidth + 2 * PADDING_HORIZONTAL, height + PADDING_TOP + PADDING_BOTTOM));
    for (final leftText in leftTexts) {
      leftText.position += Vector2(totalWidth / -2, box.position.y - PADDING_BOTTOM);
      add(leftText);
    }
    for (final rightText in rightTexts) {
      rightText.position += Vector2(totalWidth / 2 - rightMaxWidth / 2, box.position.y - PADDING_BOTTOM);
      add(rightText);
    }
  }
}