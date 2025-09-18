import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// void main() {
//   runApp(const SnakeGameApp());
// }

class SnakeGameApp extends StatelessWidget {
  const SnakeGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snake Game',
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'monospace',
      ),
      home: const SnakeGameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum GameState { waiting, playing, paused, gameOver }

enum Direction { up, down, left, right }

class SnakeGameModel {
  static const int gridSize = 20;
  static const int initialSpeed = 200; // milliseconds
  static const int speedIncrease = 10; // milliseconds per food
  static const List<Point<int>> _neighborDirs = <Point<int>>[
    Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1)
  ];
  
  List<Point<int>> snake = [];
  Point<int> food = const Point(10, 10);
  Direction direction = Direction.right;
  Direction nextDirection = Direction.right;
  int score = 0;
  int highScore = 0;
  int speed = initialSpeed;
  bool gameStarted = false;
  GameState gameState = GameState.waiting;
  int _tickCount = 0;
  final Random _rng = Random();
  
  void initializeGame() {
    snake = [
      const Point(10, 10),
      const Point(9, 10),
      const Point(8, 10),
    ];
    direction = Direction.right;
    nextDirection = Direction.right;
    score = 0;
    speed = initialSpeed;
    gameState = GameState.waiting;
    _tickCount = 0;
    generateFood();
  }
  
  void generateFood() {
    final random = _rng;
    do {
      food = Point(
        random.nextInt(gridSize),
        random.nextInt(gridSize),
      );
    } while (snake.contains(food));
  }

  void maybeMoveInsect() {
    if (gameState != GameState.playing) return;
    _tickCount++;
    // Insect gets faster with score, but capped
    final int interval = (_insectIntervalForScore(score));
    if (_tickCount % interval == 0) {
      _moveInsectOneStep();
    }
  }

  int _insectIntervalForScore(int s) {
    // 4 ticks at start, then 3, 2, down to 1 at high score
    if (s >= 20) return 1;
    if (s >= 12) return 2;
    if (s >= 6) return 3;
    return 4;
  }

  void _moveInsectOneStep() {
    final Point<int> head = snake.first;
    final List<Point<int>> candidates = [];
    for (final d in _neighborDirs) {
      final nx = food.x + d.x;
      final ny = food.y + d.y;
      final np = Point(nx, ny);
      if (nx < 0 || nx >= gridSize || ny < 0 || ny >= gridSize) continue;
      if (snake.contains(np)) continue;
      candidates.add(np);
    }
    if (candidates.isEmpty) return;

    Point<int> best = candidates.first;
    double bestScore = -1e9;
    for (final c in candidates) {
      final double dist = (c.x - head.x).abs() + (c.y - head.y).abs() + _rng.nextDouble()*0.2;
      if (dist > bestScore) {
        bestScore = dist;
        best = c;
      }
    }
    food = best;
  }
  
  void changeDirection(Direction newDirection) {
    // Prevent snake from going backwards into itself
    if (gameState != GameState.playing) return;
    
    switch (newDirection) {
      case Direction.up:
        if (direction != Direction.down) nextDirection = newDirection;
        break;
      case Direction.down:
        if (direction != Direction.up) nextDirection = newDirection;
        break;
      case Direction.left:
        if (direction != Direction.right) nextDirection = newDirection;
        break;
      case Direction.right:
        if (direction != Direction.left) nextDirection = newDirection;
        break;
    }
  }
  
  bool moveSnake() {
    if (gameState != GameState.playing) return false;
    
    direction = nextDirection;
    Point<int> head = snake.first;
    Point<int> newHead;
    
    switch (direction) {
      case Direction.up:
        newHead = Point(head.x, head.y - 1);
        break;
      case Direction.down:
        newHead = Point(head.x, head.y + 1);
        break;
      case Direction.left:
        newHead = Point(head.x - 1, head.y);
        break;
      case Direction.right:
        newHead = Point(head.x + 1, head.y);
        break;
    }
    
    // Check wall collision
    if (newHead.x < 0 || newHead.x >= gridSize || 
        newHead.y < 0 || newHead.y >= gridSize) {
      gameState = GameState.gameOver;
      return false;
    }
    
    // Check self collision
    if (snake.contains(newHead)) {
      gameState = GameState.gameOver;
      return false;
    }
    
    snake.insert(0, newHead);
    
    // Check food collision
    if (newHead == food) {
      score++;
      speed = (initialSpeed - (score * speedIncrease)).clamp(50, initialSpeed);
      generateFood();
    } else {
      snake.removeLast();
    }
    
    return true;
  }
  
  void startGame() {
    if (gameState == GameState.waiting || gameState == GameState.gameOver) {
      initializeGame();
    }
    gameState = GameState.playing;
  }
  
  void pauseGame() {
    if (gameState == GameState.playing) {
      gameState = GameState.paused;
    } else if (gameState == GameState.paused) {
      gameState = GameState.playing;
    }
  }
  
  void resetGame() {
    initializeGame();
  }
  
  Future<void> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt('snake_high_score') ?? 0;
  }
  
  Future<void> saveHighScore() async {
    if (score > highScore) {
      highScore = score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('snake_high_score', highScore);
    }
  }
}

class SnakeGameScreen extends StatefulWidget {
  const SnakeGameScreen({super.key});

  @override
  State<SnakeGameScreen> createState() => _SnakeGameScreenState();
}

class _SnakeGameScreenState extends State<SnakeGameScreen> {
  late SnakeGameModel gameModel;
  Timer? gameTimer;
  late FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    gameModel = SnakeGameModel();
    focusNode = FocusNode();
    gameModel.loadHighScore().then((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    focusNode.dispose();
    super.dispose();
  }

  void startGameLoop() {
    gameTimer?.cancel();
    gameTimer = Timer.periodic(
      Duration(milliseconds: gameModel.speed),
      (timer) {
        if (gameModel.gameState == GameState.playing) {
          setState(() {
            gameModel.maybeMoveInsect();
            if (!gameModel.moveSnake()) {
              timer.cancel();
              gameModel.saveHighScore();
            }
          });
        }
      },
    );
  }

  void handleDirectionChange(Direction direction) {
    setState(() {
      gameModel.changeDirection(direction);
    });
  }

  void handleStart() {
    setState(() {
      gameModel.startGame();
    });
    startGameLoop();
  }

  void handlePause() {
    setState(() {
      gameModel.pauseGame();
    });
    if (gameModel.gameState == GameState.playing) {
      startGameLoop();
    } else {
      gameTimer?.cancel();
    }
  }

  void handleReset() {
    setState(() {
      gameModel.resetGame();
    });
    gameTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            switch (event.logicalKey) {
              case LogicalKeyboardKey.arrowUp:
              case LogicalKeyboardKey.keyW:
                handleDirectionChange(Direction.up);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowDown:
              case LogicalKeyboardKey.keyS:
                handleDirectionChange(Direction.down);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowLeft:
              case LogicalKeyboardKey.keyA:
                handleDirectionChange(Direction.left);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowRight:
              case LogicalKeyboardKey.keyD:
                handleDirectionChange(Direction.right);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.space:
                if (gameModel.gameState == GameState.waiting) {
                  handleStart();
                } else {
                  handlePause();
                }
                return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: SafeArea(
          child: Column(
            children: [
              // Header with score and controls
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Score: ${gameModel.score}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'High Score: ${gameModel.highScore}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _getGameStateText(),
                              style: TextStyle(
                                color: _getGameStateColor(),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Speed: ${((SnakeGameModel.initialSpeed - gameModel.speed) / SnakeGameModel.speedIncrease).round()}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildControlButton(
                          'Start',
                          Colors.green,
                          gameModel.gameState == GameState.waiting || 
                          gameModel.gameState == GameState.gameOver,
                          handleStart,
                        ),
                        _buildControlButton(
                          gameModel.gameState == GameState.paused ? 'Resume' : 'Pause',
                          Colors.orange,
                          gameModel.gameState == GameState.playing || 
                          gameModel.gameState == GameState.paused,
                          handlePause,
                        ),
                        _buildControlButton(
                          'Reset',
                          Colors.red,
                          true,
                          handleReset,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Game board
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0b0f0c),
                            Color(0xFF0a0d0b),
                          ],
                        ),
                        border: Border.all(color: Colors.greenAccent, width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x5500ff7f),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        painter: SnakeGamePainter(gameModel),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Mobile controls
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Up button
                    _buildDirectionButton(
                      Icons.keyboard_arrow_up,
                      () => handleDirectionChange(Direction.up),
                    ),
                    const SizedBox(height: 8),
                    // Left, Down, Right buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDirectionButton(
                          Icons.keyboard_arrow_left,
                          () => handleDirectionChange(Direction.left),
                        ),
                        _buildDirectionButton(
                          Icons.keyboard_arrow_down,
                          () => handleDirectionChange(Direction.down),
                        ),
                        _buildDirectionButton(
                          Icons.keyboard_arrow_right,
                          () => handleDirectionChange(Direction.right),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(String text, Color color, bool enabled, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDirectionButton(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Icon(
            icon,
            color: Colors.green,
            size: 32,
          ),
        ),
      ),
    );
  }

  String _getGameStateText() {
    switch (gameModel.gameState) {
      case GameState.waiting:
        return 'Press Start';
      case GameState.playing:
        return 'Playing';
      case GameState.paused:
        return 'Paused';
      case GameState.gameOver:
        return 'Game Over';
    }
  }

  Color _getGameStateColor() {
    switch (gameModel.gameState) {
      case GameState.waiting:
        return Colors.grey;
      case GameState.playing:
        return Colors.green;
      case GameState.paused:
        return Colors.orange;
      case GameState.gameOver:
        return Colors.red;
    }
  }
}

class SnakeGamePainter extends CustomPainter {
  final SnakeGameModel gameModel;

  SnakeGamePainter(this.gameModel);

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / SnakeGameModel.gridSize;

    // Draw subtle grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    for (int i = 0; i <= SnakeGameModel.gridSize; i++) {
      final pos = i * cellSize;
      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), gridPaint);
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), gridPaint);
    }

    // Convert grid point to center offset
    Offset centerOf(Point<int> p) => Offset(
          (p.x + 0.5) * cellSize,
          (p.y + 0.5) * cellSize,
        );

    // Draw snake as a tapered, flexible body composed of capsules and circles
    if (gameModel.snake.isNotEmpty) {
      // Base centers for each segment
      final basePoints = gameModel.snake.map(centerOf).toList();

      // Slithering wiggle perpendicular to local direction
      final time = DateTime.now().millisecondsSinceEpoch / 200.0;
      final double amplitude = cellSize * 0.18;
      final double frequency = 0.8;

      Offset normalize(Offset v) {
        final d = v.distance;
        return d == 0 ? const Offset(0, 0) : v / d;
      }

      List<Offset> points = <Offset>[];
      for (int i = 0; i < basePoints.length; i++) {
        final prev = i > 0 ? basePoints[i - 1] : basePoints[min(i + 1, basePoints.length - 1)];
        final next = i < basePoints.length - 1 ? basePoints[i + 1] : basePoints[max(i - 1, 0)];
        final tangent = normalize(next - prev);
        final perp = normalize(Offset(-tangent.dy, tangent.dx));
        final headFalloff = i == 0 ? 0.6 : 1.0;
        final phase = (i * frequency) + time;
        final Offset wiggle = perp * (amplitude * headFalloff * sin(phase));
        points.add(basePoints[i] + wiggle);
      }

      // Tapered radius: thicker at head, thinner at tail
      final double maxRadius = cellSize * 0.45;
      final double minRadius = cellSize * 0.18;
      double radiusForIndex(int i) {
        final denom = max(1, points.length - 1);
        final t = i / denom;
        return maxRadius + (minRadius - maxRadius) * t;
      }

      // Glow underlay for the whole body
      final glowPaint = Paint()
        ..color = const Color(0x3300ff7f)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Draw capsules between consecutive points to ensure continuous body
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final r0 = radiusForIndex(i);
        final r1 = radiusForIndex(i + 1);
        final stroke = max(r0, r1) * 2;

        // Glow stroke
        glowPaint.strokeWidth = stroke + 6;
        canvas.drawLine(p0, p1, glowPaint);

        // Body stroke with green gradient
        final bodyPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = stroke
          ..shader = ui.Gradient.linear(
            p0,
            p1,
            const [Color(0xFF00ff7f), Color(0xFF00d16f)],
          );
        canvas.drawLine(p0, p1, bodyPaint);
      }

      // Draw circles at points to smooth joints and add highlight
      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        final r = radiusForIndex(i);
        // Base fill (solid)
        canvas.drawCircle(p, r, Paint()..color = const Color(0xFF00e676));
        // Top highlight
        final hl = Paint()..shader = ui.Gradient.radial(
          p.translate(0, -r * 0.4),
          r,
          const [Color(0xAAFFFFFF), Color(0x00000000)],
        );
        canvas.drawCircle(p, r * 0.9, hl);
      }

      // Head ellipse with eyes and a forked tongue
      final head = points.first;
      final neck = points.length > 1 ? points[1] : head + const Offset(1, 0);
      Offset dir = normalize(head - neck);
      dir = dir == Offset.zero ? const Offset(1, 0) : dir;
      final headR = radiusForIndex(0) * 1.1;

      canvas.save();
      canvas.translate(head.dx, head.dy);
      final angle = atan2(dir.dy, dir.dx);
      canvas.rotate(angle);
      // Head shape (ellipse)
      final headRect = Rect.fromCenter(center: Offset.zero, width: headR * 2.2, height: headR * 1.8);
      canvas.drawOval(headRect, Paint()..color = const Color(0xFF66ffb2));
      // Head glow
      canvas.drawOval(headRect.inflate(4), Paint()..color = const Color(0x2200ff7f));

      // Eyes
      final eyeWhite = Paint()..color = Colors.white;
      final eyeBlack = Paint()..color = Colors.black87;
      final eyeOffset = Offset(0, -headR * 0.35);
      final eyeSpread = headR * 0.45;
      canvas.drawCircle(Offset(0, 0) + eyeOffset + Offset(-eyeSpread, 0), headR * 0.20, eyeWhite);
      canvas.drawCircle(Offset(0, 0) + eyeOffset + Offset(eyeSpread, 0), headR * 0.20, eyeWhite);
      canvas.drawCircle(Offset(0, 0) + eyeOffset + Offset(-eyeSpread, 0), headR * 0.12, eyeBlack);
      canvas.drawCircle(Offset(0, 0) + eyeOffset + Offset(eyeSpread, 0), headR * 0.12, eyeBlack);

      // Forked tongue (flicks)
      final flick = (DateTime.now().millisecondsSinceEpoch ~/ 250) % 2 == 0;
      if (flick) {
        final tonguePaint = Paint()
          ..color = const Color(0xFFFF4D4D)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        final tip = Offset(headR * 1.4, 0);
        canvas.drawLine(Offset(headR * 1.0, 0), tip, tonguePaint);
        canvas.drawLine(tip, tip + const Offset(6, 3), tonguePaint);
        canvas.drawLine(tip, tip + const Offset(6, -3), tonguePaint);
      }

      canvas.restore();
    }

    // Draw food as a tiny insect
    final foodCenter = centerOf(gameModel.food);
    final timeFood = DateTime.now().millisecondsSinceEpoch / 600.0;
    final angle = sin(timeFood + gameModel.food.x + gameModel.food.y) * 0.25;
    final bodyLen = cellSize * 0.6;
    final bodyWid = cellSize * 0.32;
    final headR = bodyWid * 0.45;
    final wingLen = bodyLen * 0.55;
    final wingWid = bodyWid * 0.7;

    canvas.save();
    canvas.translate(foodCenter.dx, foodCenter.dy);
    canvas.rotate(angle);

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(2, 3),
        width: bodyLen * 0.9,
        height: bodyWid * 0.9,
      ),
      Paint()..color = const Color(0x33000000),
    );

    // Wings (semi-transparent)
    final wingPaint = Paint()..color = const Color(0x88B3E5FC);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-bodyLen * 0.1, -bodyWid * 0.9),
        width: wingLen,
        height: wingWid,
      ),
      wingPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bodyLen * 0.1, -bodyWid * 0.9),
        width: wingLen,
        height: wingWid,
      ),
      wingPaint,
    );

    // Body (gradient)
    final bodyRect = Rect.fromCenter(
      center: Offset.zero,
      width: bodyLen,
      height: bodyWid,
    );
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        bodyRect.topLeft,
        bodyRect.bottomRight,
        const [Color(0xFF3E2723), Color(0xFF6D4C41)],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyWid * 0.5)),
      bodyPaint,
    );

    // Head
    final headPaint = Paint()..color = const Color(0xFF1B1B1B);
    canvas.drawCircle(Offset(0, -bodyWid * 0.9), headR, headPaint);
    // Eyes
    final eyePaintW = Paint()..color = Colors.white;
    final eyePaintB = Paint()..color = Colors.black87;
    final eyeOffsetX = headR * 0.45;
    final eyeOffsetY = headR * -0.1;
    canvas.drawCircle(Offset(-eyeOffsetX, -bodyWid * 0.9 + eyeOffsetY), headR * 0.35, eyePaintW);
    canvas.drawCircle(Offset(eyeOffsetX, -bodyWid * 0.9 + eyeOffsetY), headR * 0.35, eyePaintW);
    canvas.drawCircle(Offset(-eyeOffsetX, -bodyWid * 0.9 + eyeOffsetY), headR * 0.18, eyePaintB);
    canvas.drawCircle(Offset(eyeOffsetX, -bodyWid * 0.9 + eyeOffsetY), headR * 0.18, eyePaintB);

    // Legs
    final legPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int i = -1; i <= 1; i++) {
      final y = i * bodyWid * 0.33;
      canvas.drawLine(Offset(-bodyLen * 0.35, y), Offset(-bodyLen * 0.55, y - 3), legPaint);
      canvas.drawLine(Offset(bodyLen * 0.35, y), Offset(bodyLen * 0.55, y - 3), legPaint);
    }

    // Antennae
    canvas.drawLine(
      Offset(-headR * 0.4, -bodyWid * 0.9 - headR),
      Offset(-headR * 0.9, -bodyWid * 0.9 - headR * 1.6),
      legPaint,
    );
    canvas.drawLine(
      Offset(headR * 0.4, -bodyWid * 0.9 - headR),
      Offset(headR * 0.9, -bodyWid * 0.9 - headR * 1.6),
      legPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
