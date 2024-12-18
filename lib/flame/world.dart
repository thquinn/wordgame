import 'dart:async';

import 'package:flame/components.dart';
import 'package:wordgame/flame/area_glow.dart';
import 'package:wordgame/flame/cursor.dart';
import 'package:wordgame/flame/ghost.dart';
import 'package:wordgame/flame/pickup.dart';
import 'package:wordgame/flame/tile.dart';

class WordWorld extends World {
  late Cursor cursor;

  @override
  Future<void> onLoad() async {
    await add(cursor = Cursor());
    await add(TileManager());
    await add(PickupManager());
    await add(GhostManager());
    await add(AreaGlowManager());
  }
}