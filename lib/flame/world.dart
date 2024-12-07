import 'dart:async';

import 'package:flame/components.dart';
import 'package:wordgame/flame/cursor.dart';

class WordWorld extends World {
  @override
  Future<void> onLoad() async {
    await add(Cursor());
  }
}