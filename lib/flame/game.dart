import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:wordgame/flame/camera.dart';
import 'package:wordgame/flame/world.dart';

class WordGame extends FlameGame with HasKeyboardHandlerComponents {
  WordGame() : super(world: WordWorld(), camera: WordCamera());
}