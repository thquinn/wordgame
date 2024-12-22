import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:wordgame/flame/camera.dart';
import 'package:wordgame/flame/world.dart';

class WordGame extends FlameGame with HasKeyboardHandlerComponents, ScrollDetector {
  WordGame() : super(world: WordWorld(), camera: WordCamera());

  get wordCamera => camera as WordCamera;

  @override
  void onScroll(PointerScrollInfo info) {
    // Would rather this be in the camera, but only Games can be ScrollDetectors...?
    wordCamera.scroll(info.eventPosition.global, info.scrollDelta.global.y);
  }
}