import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/palette.dart';
import 'package:flame/text.dart';
import 'package:flutter/animation.dart';
import 'package:wordgame/flame/extensions.dart';

class NotificationManager extends PositionComponent {
  static List<GameNotification> pending = [];
  static void enqueueFromBroadcast(String type, Map<String, String> args) {
    if (type == 'word') enqueueWord(args['username']!, args['qualifier']!, args['word']!);
    if (type == 'enclosed_area') enqueueArea(args['username']!, int.parse(args['area']!));
    if (type == 'tile_block') enqueueTileBlock(args['username']!, args['dimensions']!);
  }
  static void enqueueWord(String username, String qualifier, String word) {
    pending.add(GameNotification([
        BoldTextNode(PlainTextNode(username)),
        PlainTextNode(' played the $qualifier word '),
        CodeTextNode(PlainTextNode(word.toUpperCase())),
        PlainTextNode('!'),
    ]));
  }
  static void enqueueArea(String username, int area) {
    pending.add(GameNotification([
        BoldTextNode(PlainTextNode(username)),
        PlainTextNode(' surrounded '),
        BoldTextNode(PlainTextNode('$area tiles')),
        PlainTextNode('!'),
    ]));
  }
  static void enqueueTileBlock(String username, String dimensions) {
    pending.add(GameNotification([
        BoldTextNode(PlainTextNode(username)),
        PlainTextNode(' made a '),
        BoldTextNode(PlainTextNode('$dimensions block')),
        PlainTextNode('!'),
    ]));
  }

  NotificationManager() : super(position: Vector2(10, 10));
    
  @override
  void update(double dt) {
    if (pending.isNotEmpty) {
      double y = -100;
      if (children.isNotEmpty) {
        y = min(y, (children.last as GameNotification).position.y - 55.0 - 10);
      }
      add(pending.removeAt(0)..add(SequenceEffect([
        MoveByEffect(Vector2(0, -y), EffectController(duration: 1, curve: Curves.easeOutQuad)),
        MoveByEffect(Vector2.zero(), EffectController(duration: 5)),
        MoveByEffect(Vector2(-1000, 0), EffectController(duration: 1, curve: Curves.easeInOutBack)),
        RemoveEffect(),
      ]))..position = Vector2(0, y));
    }
    double nextY = -999;
    for (final child in children.reversed().whereType<GameNotification>()) {
      child.position.y = max(child.position.y, nextY);
      nextY = max(nextY, child.position.y + child.height + 10);
    }
  }
}

class GameNotification extends PositionComponent {
  static DocumentStyle styleDocument = DocumentStyle(
    width: 1000,
    height: 200,
    text: InlineTextStyle(
      fontFamily: 'Solway',
      fontSize: 24,
      color: BasicPalette.white.color,
    ),
    boldText: InlineTextStyle(
      fontFamily: 'Solway',
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: BasicPalette.white.color,
    ),
    codeText: InlineTextStyle(
      fontFamily: 'Katahdin Round',
      fontSize: 24,
      color: BasicPalette.white.color,
    ),
  );
  static final TextPaint styleInfo = TextPaint(
    style: TextStyle(
      fontSize: 40,
      fontFamily: 'Solway',
      fontWeight: FontWeight.bold,
      color: BasicPalette.white.color,
    ),
  );

  final List<InlineTextNode> textNodes;

  GameNotification(this.textNodes);

  @override
  FutureOr<void> onLoad() async {
    height = 55.0;
    // Information symbol.
    add(SpriteComponent(
      sprite: await Sprite.load('circle.png'),
      size: Vector2.all(height),
    )..paint.colorFilter = ColorFilter.mode(Color.fromRGBO(95, 95, 177, 1), BlendMode.srcATop)..opacity = .8);
    add(TextComponent(
      textRenderer: styleInfo,
      text: 'i',
      position: Vector2(20, 5),
      size: Vector2.all(100),
    ));
    // Measure text.
    final document = DocumentRoot([ParagraphNode.group(textNodes)]);
    final groupElement = document.format(styleDocument);
    // Backing.
    final box = ScaledNineTileBoxComponent(.275);
    //box.anchor = Anchor.topLeft;
    final sprite = await Sprite.load('panel.png');
    box.nineTileBox = AlphaNineTileBox(sprite, opacity: 0.8, leftWidth: 120, bottomHeight: 120, rightWidth: 120, topHeight: 120);
    Rect textSize = groupElement.children.first.boundingBox;
    box.position = Vector2(height + 10, 0);
    box.size = Vector2(textSize.width + 40, height);
    add(box);
    // Add text.
    add(TextElementComponent.fromDocument(document: document, style: styleDocument, position: Vector2(30 + height, 7)));
  }

  @override
  void update(double dt) {
    
  }
}