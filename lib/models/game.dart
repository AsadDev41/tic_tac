import 'dart:async';

class Player {
  static const p1 = 'x';
  static const p2 = '0';
  static const empty = '';
}

class Game {
  static const boardlength = 9;
  static const boardsize = 100.0;
  static List<String> board = initgameBoard();
  static List<List<int>> winningCombinations = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  static List<String> initgameBoard() =>
      List.generate(boardlength, (index) => Player.empty);
  static StreamController<String> moveStreamController =
      StreamController<String>.broadcast();
}
