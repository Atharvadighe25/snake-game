import 'dart:async';
import 'dart:math';
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
  
  List<Point<int>> snake = [];
  Point<int> food = const Point(10, 10);
  Direction direction = Direction.right;
  Direction nextDirection = Direction.right;
  int score = 0;
  int highScore = 0;
  int speed = initialSpeed;
  bool gameStarted = false;
  GameState gameState = GameState.waiting;
  
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
    generateFood();
  }
  
  void generateFood() {
    final random = Random();
    do {
      food = Point(
        random.nextInt(gridSize),
        random.nextInt(gridSize),
      );
    } while (snake.contains(food));
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
                        border: Border.all(color: Colors.green, width: 2),
                        borderRadius: BorderRadius.circular(8),
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
    
    // Draw grid
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 0.5;
    
    for (int i = 0; i <= SnakeGameModel.gridSize; i++) {
      final pos = i * cellSize;
      canvas.drawLine(
        Offset(pos, 0),
        Offset(pos, size.height),
        gridPaint,
      );
      canvas.drawLine(
        Offset(0, pos),
        Offset(size.width, pos),
        gridPaint,
      );
    }
    
    // Draw snake
    final snakePaint = Paint()..color = Colors.green;
    for (int i = 0; i < gameModel.snake.length; i++) {
      final point = gameModel.snake[i];
      final rect = Rect.fromLTWH(
        point.x * cellSize + 1,
        point.y * cellSize + 1,
        cellSize - 2,
        cellSize - 2,
      );
      
      // Head is brighter
      if (i == 0) {
        snakePaint.color = Colors.lightGreen;
      } else {
        snakePaint.color = Colors.green;
      }
      
      canvas.drawRect(rect, snakePaint);
    }
    
    // Draw food
    final foodPaint = Paint()..color = Colors.red;
    final foodRect = Rect.fromLTWH(
      gameModel.food.x * cellSize + 2,
      gameModel.food.y * cellSize + 2,
      cellSize - 4,
      cellSize - 4,
    );
    canvas.drawOval(foodRect, foodPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
