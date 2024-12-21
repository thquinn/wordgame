import 'package:flame/components.dart';
import 'package:flame/layout.dart';
import 'package:provider/provider.dart';
import 'package:wordgame/flame/game.dart';
import 'package:wordgame/state.dart';

class CountdownAnchor extends AlignComponent {
  CountdownAnchor() : super(
    child: CountdownManager(),
    alignment: Anchor.topCenter,
  );
}

class CountdownManager extends PositionComponent with HasGameRef<WordGame> {
  late WordGameState appState;

  @override
  void onMount() {
    appState = Provider.of<WordGameState>(game.buildContext!, listen: false);
  }

  @override
  void update(double dt) {
    
  }
}
