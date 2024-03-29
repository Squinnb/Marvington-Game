// ignore_for_file: prefer_final_fields

import 'dart:async';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/src/services/raw_keyboard.dart';
import 'package:marvington_game/actors/bullet.dart';
import 'package:marvington_game/components/door.dart';
import 'package:marvington_game/levels/rock.dart';
import '/components/checkpoint.dart';
import '../components/shitake.dart';
import '../enemies/blob.dart';
import '../traps/moon.dart';
import '/game.dart';
import '/levels/platform.dart';
import '/traps/fire.dart';

enum PlayerState { appear, idle, running, jumping, falling, disappear, hit, entering, entered }

class Marv extends SpriteAnimationGroupComponent with HasGameRef<Gain>, KeyboardHandler, CollisionCallbacks {
  String character;
  Marv({
    super.position,
    super.anchor = Anchor.center,
    this.character = "Marv",
  });

  double stepTime = 0.05;
  double xDir = 0.0;
  double _moveSpeed = 130;
  double _gravity = 11;
  double _jumpForce = 320;
  double _terminalYVelocity = 275;
  double fixedDeltaTime = 1 / 60;
  double accumulatedTime = 0;
  int health = 3;

  static const Duration _dur = Duration(milliseconds: 350);

  bool _jumpPressed = false;
  bool _isOnGround = true;
  bool upPressed = false;
  bool _dead = false;
  bool hasBeatLevel = false;
  bool fired = false;
  bool enteredDoor = false;

  List<Platform> platforms = [];
  Set<Rock> rocks = {};
  Vector2 velocity = Vector2.zero();
  late Vector2 spawnLocation; // playerSpawnLocation

  @override
  FutureOr<void> onLoad() {
    _loadAllAnimations();
    add(RectangleHitbox(position: Vector2(1, 1), size: Vector2(24, 28), collisionType: CollisionType.active)); //
    return super.onLoad();
  }

  @override
  void update(double dt) {
    accumulatedTime += dt; // this evens out perform on all diff platforms.
    while (accumulatedTime >= fixedDeltaTime) {
      if (!_dead && !hasBeatLevel) {
        _updateAnimation();
        _updatePlayerMovement(fixedDeltaTime);
        _handleXPlatformCollision();
        _applyGravity(fixedDeltaTime);
        _handleYPlatformCollision();
      }
      accumulatedTime -= fixedDeltaTime;
    }
    super.update(dt);
  }

  @override
  bool onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    bool leftKeyPressed = keysPressed.contains(LogicalKeyboardKey.keyA) || keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    bool rightKeyPressed = keysPressed.contains(LogicalKeyboardKey.keyD) || keysPressed.contains(LogicalKeyboardKey.arrowRight);
    bool downPressed = keysPressed.contains(LogicalKeyboardKey.keyS) || keysPressed.contains(LogicalKeyboardKey.arrowDown);
    upPressed = keysPressed.contains(LogicalKeyboardKey.keyS) || keysPressed.contains(LogicalKeyboardKey.arrowUp);
    fired = keysPressed.contains(LogicalKeyboardKey.keyF);

    if (fired) {
      if (upPressed) {
        _shoot(ydir: -1);
      } else if (downPressed && !_isOnGround) {
        _shoot(ydir: 1);
      } else {
        _shoot();
      }
    }
    xDir = 0;
    xDir += leftKeyPressed ? -1 : 0;
    xDir += rightKeyPressed ? 1 : 0;
    _jumpPressed = keysPressed.contains(LogicalKeyboardKey.space);
    return super.onKeyEvent(event, keysPressed);
  }

  void _applyGravity(double dt) {
    velocity.y += _gravity;
    velocity.y = velocity.y.clamp(-_jumpForce, _terminalYVelocity);
    position.y += velocity.y * dt;
  }

  void _jump() {
    FlameAudio.play("jump1.wav", volume: game.volume);
    velocity.y = -_jumpForce;
    _isOnGround = false;
    _jumpPressed = false;
  }

  void _updatePlayerMovement(double dt) {
    if (_jumpPressed && _isOnGround) _jump();
    velocity.x = xDir * _moveSpeed;
    position.x += (velocity.x * dt);

    // position.clamp(_minClamp, _maxClamp);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Shitake) {
      other.collect();
    } else if (other is Moon) {
      _die();
    } else if (other is Platform && other.isLethal) {
      _die();
    } else if (other is Checkpoint) {
      // _beatLevel();
      FlameAudio.play("synth3.wav", volume: game.volume);
    } else if (other is Blob) {
      bool stomp = (velocity.y > 0 && other.wasJumpedOn(position.y + (height / 2)));
      if (stomp) {
        other.die();
        velocity.y = -_jumpForce;
      } else {
        if (!other.dead) _die();
      }
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Fire) {
      if (other.isActive()) _die();
    } else if (other is Door) {
      if (upPressed && !enteredDoor) _enterDoor(other.levelName);
    }
  }

  SpriteAnimation _spriteAnimation(String state, int amount) {
    String cacheUrl = "Marvington/Marv $state.png";
    double txtSzX = 26;
    double txtSzY = 29;
    if (state == "Disappear" || state == "Appear") {
      cacheUrl = "Marvington/Marv $state.png";
      txtSzX = 47;
      txtSzY = 47;
    }
    return SpriteAnimation.fromFrameData(
      game.images.fromCache(cacheUrl),
      SpriteAnimationData.sequenced(
        amount: amount,
        stepTime: stepTime,
        textureSize: Vector2(txtSzX, txtSzY),
      ),
    );
  }

  void _loadAllAnimations() {
    SpriteAnimation idleAnime = _spriteAnimation("Idle", 6);
    SpriteAnimation runningAnime = _spriteAnimation("Run", 7);
    SpriteAnimation jumpAnime = _spriteAnimation("Jump", 1);
    SpriteAnimation fallAnime = _spriteAnimation("Fall", 1);
    SpriteAnimation enteredAnime = _spriteAnimation("Turned Away", 1);
    SpriteAnimation enterAnime = _spriteAnimation("Enter", 4)..loop = false;
    SpriteAnimation disappearAnime = _spriteAnimation("Disappear", 6)..loop = false;
    SpriteAnimation appearAnime = _spriteAnimation("Appear", 6)..loop = false;
    SpriteAnimation hitAnime = _spriteAnimation("Hit", 4)..loop = false;
    animations = {
      PlayerState.idle: idleAnime,
      PlayerState.running: runningAnime,
      PlayerState.jumping: jumpAnime,
      PlayerState.falling: fallAnime,
      PlayerState.entering: enterAnime,
      PlayerState.entered: enteredAnime,
      PlayerState.appear: appearAnime,
      PlayerState.hit: hitAnime,
      PlayerState.disappear: disappearAnime
    };
    current = PlayerState.idle;
  }

  void _updateAnimation() {
    PlayerState playerState = PlayerState.idle;
    if (velocity.x < 0 && scale.x > 0) {
      flipHorizontallyAroundCenter();
    } else if (velocity.x > 0 && scale.x < 0) {
      flipHorizontallyAroundCenter();
    }
    if (velocity.x > 0 || velocity.x < 0) playerState = PlayerState.running;
    if (velocity.y > 0 && !_isOnGround) playerState = PlayerState.falling;
    if (velocity.y < 0 && !_isOnGround) playerState = PlayerState.jumping;
    current = playerState;
  }

  void _hit() async {
    print("Hello... $health");
    health--;
    current = PlayerState.hit;
    await animationTicker?.completed;
    if (health < 1) {
      _die();
    }
  }

  void _die() async {
    _dead = true;
    FlameAudio.play("hitHurt.wav", volume: game.volume);
    current = PlayerState.hit;
    await animationTicker?.completed;

    // respawn
    scale.x = 1; // face to the right
    position = spawnLocation;
    current = PlayerState.appear;
    await animationTicker?.completed;
    animationTicker?.reset();

    velocity = Vector2.zero();
    // _updateAnimation();
    Future.delayed(_dur, () => _dead = false);
  }

  // void _beatLevel() async {
  //   hasBeatLevel = true;
  //   current = PlayerState.disappear;
  //   game.currWorld.wallPaper.parallax?.baseVelocity = Vector2(0, -75);
  //   await animationTicker?.completed;
  //   xDir = 0;
  //   velocity = Vector2.zero(); // this doesn't do anything/work.
  //   hasBeatLevel = false;
  //   removeFromParent();
  //   Future.delayed(const Duration(seconds: 2), () {
  //     game.loadNextLevel();
  //   });
  // }

  void _enterDoor(String levelName) async {
    hasBeatLevel = true;
    enteredDoor = true;
    current = PlayerState.entering;
    await animationTicker?.completed;
    current = PlayerState.entered;
    xDir = 0;
    velocity = Vector2.zero();
    enteredDoor = false;
    Future.delayed(const Duration(milliseconds: 350), () {
      hasBeatLevel = false;
      game.loadNextLevel(levelName);
    });
  }

  void _handleXPlatformCollision() {
    for (Platform other in platforms) {
      Rect platformRect = other.toRect();
      Rect playerRect = toRect();
      if (playerRect.overlaps(platformRect)) {
        if (velocity.x > 0 && !other.isPassable) {
          velocity.x = 0;
          position.x = other.x - (width / 2);
        } else if (velocity.x < 0 && !other.isPassable) {
          velocity.x = 0;
          position.x = (other.x + other.width) + (width / 2);
        }
        break; // think this is ok
      }
    }
  }

  void _handleYPlatformCollision() {
    for (Platform other in platforms) {
      Rect platformRect = other.toRect();
      Rect playerRect = toRect();
      if (playerRect.overlaps(platformRect)) {
        if (velocity.y < 0 && !other.isPassable) {
          velocity.y = 0;
          position.y = other.y + other.height + (height / 2);
        }
        if (velocity.y > 0) {
          if ((other.isPassable && (position.y + (height / 3)) < other.y) || !other.isPassable) {
            velocity.y = 0;
            position.y = other.y - (height / 2);
            _isOnGround = true;
          }
        }
        break; // think this is ok
      }
    }
  }

  void _shoot({double ydir = 0}) {
    if (ydir == 0) {
      Vector2 standingPosition = Vector2(position.x, (position.y - (height / 3)));
      Bullet b = Bullet(dir: scale.x, position: standingPosition);
      parent?.add(b);
    } else {
      Vector2 upPosition = Vector2(position.x, (position.y - (height / 3)));
      Vector2 downnPosition = Vector2(position.x, (position.y + (height / 3)));
      Bullet b = Bullet(dir: ydir, position: ydir == 1 ? downnPosition : upPosition, isVert: true);
      parent?.add(b);
    }
  }
}
