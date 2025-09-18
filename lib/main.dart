import 'package:demo/snake_game.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const SnakeGameApp()); 
  // runApp(const TicTacToeApp());
}

class TicTacToeApp extends StatelessWidget {
  const TicTacToeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tic Tac Toe',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const TicTacToeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen>
    with TickerProviderStateMixin {
  List<List<String>> board = [
    ['', '', ''],
    ['', '', ''],
    ['', '', ''],
  ];
  
  String currentPlayer = 'X';
  int playerXWins = 0;
  int playerOWins = 0;
  String? winner;
  List<List<int>>? winningTiles;
  bool gameOver = false;
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  List<List<bool>> animatingTiles = [
    [false, false, false],
    [false, false, false],
    [false, false, false],
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void makeMove(int row, int col) {
    if (board[row][col].isEmpty && !gameOver) {
      setState(() {
        board[row][col] = currentPlayer;
        animatingTiles[row][col] = true;
        _animationController.forward().then((_) {
          setState(() {
            animatingTiles[row][col] = false;
          });
          _animationController.reset();
        });
        
        if (checkWinner()) {
          gameOver = true;
          if (winner == 'X') {
            playerXWins++;
          } else if (winner == 'O') {
            playerOWins++;
          }
        } else if (isBoardFull()) {
          gameOver = true;
          winner = 'Draw';
        } else {
          currentPlayer = currentPlayer == 'X' ? 'O' : 'X';
        }
      });
    }
  }

  bool checkWinner() {
    // Check rows
    for (int i = 0; i < 3; i++) {
      if (board[i][0].isNotEmpty &&
          board[i][0] == board[i][1] &&
          board[i][1] == board[i][2]) {
        winner = board[i][0];
        winningTiles = [[i, 0], [i, 1], [i, 2]];
        return true;
      }
    }

    // Check columns
    for (int j = 0; j < 3; j++) {
      if (board[0][j].isNotEmpty &&
          board[0][j] == board[1][j] &&
          board[1][j] == board[2][j]) {
        winner = board[0][j];
        winningTiles = [[0, j], [1, j], [2, j]];
        return true;
      }
    }

    // Check diagonals
    if (board[0][0].isNotEmpty &&
        board[0][0] == board[1][1] &&
        board[1][1] == board[2][2]) {
      winner = board[0][0];
      winningTiles = [[0, 0], [1, 1], [2, 2]];
      return true;
    }

    if (board[0][2].isNotEmpty &&
        board[0][2] == board[1][1] &&
        board[1][1] == board[2][0]) {
      winner = board[0][2];
      winningTiles = [[0, 2], [1, 1], [2, 0]];
      return true;
    }

    return false;
  }

  bool isBoardFull() {
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (board[i][j].isEmpty) {
          return false;
        }
      }
    }
    return true;
  }

  void resetBoard() {
    setState(() {
      board = [
        ['', '', ''],
        ['', '', ''],
        ['', '', ''],
      ];
      animatingTiles = [
        [false, false, false],
        [false, false, false],
        [false, false, false],
      ];
      currentPlayer = 'X';
      winner = null;
      winningTiles = null;
      gameOver = false;
    });
  }

  void resetScore() {
    setState(() {
      playerXWins = 0;
      playerOWins = 0;
      resetBoard();
    });
  }

  Widget buildTile(int row, int col) {
    bool isWinningTile = winningTiles != null &&
        winningTiles!.any((tile) => tile[0] == row && tile[1] == col);
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: animatingTiles[row][col] 
              ? _scaleAnimation.value 
              : 1.0,
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isWinningTile 
                  ? Colors.green.withOpacity(0.3)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isWinningTile 
                      ? Colors.green.withOpacity(0.5)
                      : Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              border: isWinningTile 
                  ? Border.all(color: Colors.green, width: 3)
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => makeMove(row, col),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: board[row][col].isNotEmpty
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: board[row][col] == 'X'
                                ? [Colors.red.shade400, Colors.red.shade600]
                                : [Colors.blue.shade400, Colors.blue.shade600],
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      board[row][col],
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: board[row][col].isNotEmpty
                            ? Colors.white
                            : Colors.transparent,
                        shadows: board[row][col].isNotEmpty
                            ? [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildScoreCard(String player, int wins, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Text(
            'Player $player',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$wins',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFf093fb),
              Color(0xFFf5576c),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Title
                const Text(
                  'Tic Tac Toe',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Score Cards
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    buildScoreCard('X', playerXWins, Colors.red),
                    buildScoreCard('O', playerOWins, Colors.blue),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Current Turn Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text(
                    gameOver
                        ? winner == 'Draw'
                            ? 'It\'s a Draw!'
                            : 'Player $winner Wins!'
                        : 'Player $currentPlayer\'s Turn',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Game Board
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: buildTile(0, 0)),
                                  Expanded(child: buildTile(0, 1)),
                                  Expanded(child: buildTile(0, 2)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: buildTile(1, 0)),
                                  Expanded(child: buildTile(1, 1)),
                                  Expanded(child: buildTile(1, 2)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: buildTile(2, 0)),
                                  Expanded(child: buildTile(2, 1)),
                                  Expanded(child: buildTile(2, 2)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Control Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: resetBoard,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset Board'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 8,
                        shadowColor: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: resetScore,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Reset Score'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 8,
                        shadowColor: Colors.purple.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}