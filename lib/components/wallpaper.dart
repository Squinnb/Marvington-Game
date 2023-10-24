import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/painting.dart';
import 'package:gain/game.dart';

class WallPaper extends ParallaxComponent<Gain> with HasGameRef<Gain> {
  String color;
  WallPaper({super.position, super.size, this.color = "Gray"});

  @override
  FutureOr<void> onLoad() async {
    priority = -10;
    size = Vector2.all(64);
    parallax =
        await gameRef.loadParallax([ParallaxImageData("Background/$color.png")], baseVelocity: Vector2(0, 0), repeat: ImageRepeat.repeat, fill: LayerFill.none);

    return super.onLoad();
  }
}
