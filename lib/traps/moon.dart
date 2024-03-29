import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import '/game.dart';

class Moon extends SpriteAnimationComponent with HasGameRef<Gain> {
  bool isVertical;
  final double plusOffset;
  final double minusOffset;
  Moon({super.position, super.size, required this.isVertical, required this.minusOffset, required this.plusOffset});

  static const double spinSpeed = 0.08;
  static const double moveSpeed = 50;
  static const double tileSize = 16;
  double xydir = 1;
  double posRange = 0;
  double negRange = 0;

  @override
  FutureOr<void> onLoad() {
    priority = -1;
    if (isVertical) {
      negRange = position.y - (minusOffset * tileSize);
      posRange = position.y + (plusOffset * tileSize);
    } else {
      negRange = position.x - (minusOffset * tileSize);
      posRange = position.x + (plusOffset * tileSize);
    }
    animation = _createSpriteAnime();
    add(CircleHitbox());
    return super.onLoad();
  }

  @override
  void update(double dt) {
    if (isVertical) {
      _moveVert(dt);
    } else {
      _moveHorz(dt);
    }
    super.update(dt);
  }

  SpriteAnimation _createSpriteAnime() {
    return SpriteAnimation.fromFrameData(
      game.images.fromCache("Traps/Moon/Moon On.png"),
      SpriteAnimationData.sequenced(
        amount: 8,
        stepTime: spinSpeed,
        textureSize: Vector2.all(32),
      ),
    );
  }

  void _moveHorz(double dt) {
    if (position.x >= posRange) {
      xydir = -1;
    } else if (position.x <= negRange) {
      xydir = 1;
    }
    position.x += xydir * moveSpeed * dt;
  }

  void _moveVert(double dt) {
    if (position.y >= posRange) {
      xydir = -1;
    } else if (position.y <= negRange) {
      xydir = 1;
    }
    position.y += xydir * moveSpeed * dt;
  }
}
