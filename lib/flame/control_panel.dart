import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/layout.dart';
import 'package:flame/palette.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordgame/flame/extensions.dart';

class ControlAnchor extends AlignComponent {
  ControlAnchor() : super(
    child: ControlPanel(),
    alignment: Anchor.bottomLeft,
  );
}

class ControlPanel extends PositionComponent with HasVisibility, KeyboardHandler {
  static const double LINE_SPACING = 22.5;
  static final TextPaint styleControls = FixedHeightTextPaint(
    LINE_SPACING,
    style: TextStyle(
      fontSize: 18,
      fontFamily: 'Solway',
      color: BasicPalette.white.color,
    ),
  );

  late SharedPreferences prefs;

  @override
  FutureOr<void> onLoad() async {
    prefs = await SharedPreferences.getInstance();
    isVisible = prefs.getBool('show_tutorial') ?? false;

    const text = '''
start game (as leader): space
move cursor: arrow keys
switch cursor direction: tab
submit word: enter
remove tiles: backspace
remove all tiles: escape, or hold backspace
sort tiles: 1
pan camera: shift + arrow keys
zoom camera: - and + (fine, technically it's - and =)
hide this: `
''';
    add(TextBoxComponent(
      position: Vector2(0, -90),
      textRenderer: styleControls,
      text: text,
      size: Vector2(700, 500),
      anchor: Anchor.bottomLeft,
      align: Anchor.bottomLeft,
    ));
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final keyDown = event is KeyDownEvent;
    // Change cursor direction.
    if (keyDown && event.logicalKey == LogicalKeyboardKey.backquote) {
      isVisible = !isVisible;
      prefs.setBool('show_tutorial', isVisible);
      return false;
    }
    return true;
  }
}