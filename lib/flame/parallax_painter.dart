import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:wordgame/flame/game.dart';

class ParallaxPainter extends CustomPainter {
  final WordGame game;
  final Image image;
  final BoxFit fit;
  final double opacity;
  late Paint p;

  ParallaxPainter({
    required this.game,
    required this.image,
    required this.fit,
    this.opacity = 1.0,
  }) {
    p = Paint()..color = Color.fromRGBO(255, 255, 255, opacity);
  }

  @override
  void paint(Canvas canvas, Size size) async {
    try {
      final zoom = game.camera.viewfinder.zoom;
      final scale = zoom / 256;
      final mat = Matrix4.identity();
      mat.scale(scale);
      mat.translate(game.size.x * 128 / zoom, game.size.y * 128 / zoom, 0);
      mat.translate(game.camera.viewfinder.position.x * -256 + 128, game.camera.viewfinder.position.y * -256 + 128, 0);

      // Sure would love to not create a new shader every paint, but
      // there's no way to change an ImageShader's matrix.

      // Even better would be to use Parallax, but just look at what Flame does when you set a sprite to use repeating textures:
      /*
        for (final Rect tileRect in _generateImageTileRects(rect, destinationRect, repeat)) {
          canvas.drawImageRect(image, sourceRect, tileRect, paint);
        }
      */
      // God help us all.
      p.shader = ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        mat.storage
      );

      canvas.drawRect(
        Rect.fromLTWH(0, 0, game.size.x, game.size.y),
        p
      );
    } catch (e) {
      print('Error loading image: $e');
    }
  }

  @override
  bool shouldRepaint(ParallaxPainter oldDelegate) {
    return false;
  }
}