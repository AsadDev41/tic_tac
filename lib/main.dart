import 'package:flutter/material.dart';
import 'package:tic_tac/models/game.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: const Color(0xFF00061a),
        hintColor: const Color(0xFF001456),
        focusColor: const Color(0xFF4169e8),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController roomIdController = TextEditingController();
  String lastValue = 'X';
  bool gameover = false;
  int turn = 0;
  int? tappedindex;
  String? createdRoomId;
  String? roomId;
  bool roomcreated = false;
  bool roomjoined = false;

  @override
  void initState() {
    super.initState();
    loadGameState();
  }

  Future<String> createRoom() async {
    const url = 'https://tictac-615f4-default-rtdb.firebaseio.com/rooms.json';
    try {
      final response = await http.post(
        Uri.parse(url),
        body: jsonEncode({
          'board': [],
          'turn': 0,
          'lastValue': 'X',
          'tappedindex': 0,
          'gameover': false
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String roomId = data['name'];
        roomcreated = true;
        roomjoined = false;
        return roomId;
      } else {
        throw Exception('Failed to create room');
      }
    } catch (error) {
      throw error;
    }
  }

  Future<void> joinRoom(String roomId) async {
    final url =
        'https://tictac-615f4-default-rtdb.firebaseio.com/rooms/$roomId.json';
    try {
      print('Joining Room: $roomId');
      final response = await http.get(Uri.parse(url));
      print('Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        roomjoined = true;
        roomcreated = false;
        print('Data received: $data');

        if (data['board'] != null &&
            data['turn'] != null &&
            data['lastValue'] != null &&
            data['tappedindex'] != null &&
            data['gameover'] != null) {
          setState(() {
            Game.board = List<String>.from(data['board']);
            turn = data['turn'];
            lastValue = data['lastValue'];
            gameover = false;
            createdRoomId = roomId;
            tappedindex = data['tappedindex'];
          });

          // Listen for moves when the room is joined
          Game.moveStreamController.stream.listen((String move) {
            final parts = move.split('@');
            final String player = parts[0];
            final int index = int.parse(parts[1]);
            setState(() {
              Game.board[index] = player;
            });
          });

          print('Room Joined Successfully');
        }
      } else {
        print('Failed to join the room. Response: ${response.body}');
      }
    } catch (error) {
      print('Error joining room: $error');
    }
  }

  Future<void> loadGameState() async {
    try {
      if (roomcreated == true || roomjoined == true) {
        final url =
            'https://tictac-615f4-default-rtdb.firebaseio.com/rooms/$roomId.json';
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);

          setState(() {
            tappedindex = data['tappedindex'];
            Game.board = List<String>.from(data['board']);
            gameover = data['gameover'] ?? false;
            turn = data['turn'] ?? 0;
            lastValue = data['lastValue'] ?? 'X';
          });
        } else {
          print(
              'Failed to load game state from Firebase. Response: ${response.body}');
        }
      } else {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        setState(() {
          tappedindex = prefs.getInt('tappedindex');
          Game.board = prefs.getStringList('board') ?? Game.initgameBoard();
          gameover = prefs.getBool('gameover') ?? false;
          turn = prefs.getInt('turn') ?? 0;
          lastValue = prefs.getString('lastValue') ?? 'X';
        });
      }
    } catch (error) {
      print('Error loading game state: $error');
    }
  }

  Future<void> saveGameState() async {
    try {
      if (roomcreated == true || roomjoined == true) {
        final url =
            'https://tictac-615f4-default-rtdb.firebaseio.com/rooms/$createdRoomId.json';

        final response = await http.patch(
          Uri.parse(url),
          body: jsonEncode({
            'turn': turn,
            'tappedindex': tappedindex,
          }),
        );

        if (response.statusCode == 200) {
          print('Game state saved in Firebase successfully');
          Game.moveStreamController
              .add('$lastValue@$tappedindex'); // Broadcast the move
        } else {
          print(
              'Failed to save game state in Firebase. Response: ${response.body}');
        }
      } else {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setInt('tappedindex', tappedindex ?? 0);
        prefs.setStringList('board', Game.board);
        prefs.setBool('gameover', gameover);
        prefs.setInt('turn', turn);
        prefs.setString('lastValue', lastValue);
      }
    } catch (error) {
      print('Error Saving Game State: $error');
      throw error;
    }
  }

  String? checkWinner() {
    for (var i = 0; i < Game.winningCombinations.length; i++) {
      var sequence = Game.winningCombinations[i];
      if (Game.board[sequence[0]] != Player.empty &&
          Game.board[sequence[0]] == Game.board[sequence[1]] &&
          Game.board[sequence[1]] == Game.board[sequence[2]]) {
        return Game.board[sequence[0]];
      }
    }
    return null;
  }

  void onCellTapped(int gridindex) {
    saveGameState();

    if (!gameover && Game.board[gridindex] == '') {
      setState(() {
        Game.board[gridindex] = lastValue;
        tappedindex = gridindex;
        if (checkWinner() != null) {
          gameover = true;
          showWinnerDialog(checkWinner());
        } else {
          if (!Game.board.contains(Player.empty)) {
            gameover = true;
            showWinnerDialog(null);
          } else {
            turn++;
            lastValue = turn % 2 == 0 ? 'X' : 'O';
          }
        }
      });
    }
  }

  void showWinnerDialog(String? winner) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            winner != null ? '$winner is the Winner!' : 'It\'s a tie! ',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                resetGame();
              },
              child: const Text('Play Again'),
            ),
          ],
        );
      },
    );
  }

  void resetGame() {
    setState(() {
      Game.board = Game.initgameBoard();
      gameover = false;
      turn = 0;
      lastValue = 'X';
    });
  }

  void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Room Id Copied to clipboard'),
      ),
    );
  }

  Future<void> dialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Join Room'),
          content: TextField(
            controller: roomIdController,
            decoration: const InputDecoration(
              hintText: 'Enter Room Id ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                String roomId = roomIdController.text;
                if (roomId.isNotEmpty) {
                  joinRoom(roomId);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Join Now'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).hintColor,
        title: const Text(
          'TIC TAC GAME',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await createRoom().then((roomId) {
                setState(() {
                  createdRoomId = roomId;
                  resetGame();
                });
              }).catchError((error) {
                print('Error creating room: $error');
              });
              print(createdRoomId);
            },
            child: const Text(
              'Create Room',
              style: TextStyle(color: Colors.white),
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  dialog(context);
                },
                child: const Text(
                  'Join Room',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          )
        ],
      ),
      backgroundColor: Theme.of(context).primaryColor,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (createdRoomId != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Room Id: $createdRoomId ',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      copyToClipboard(createdRoomId!);
                      print(createdRoomId);
                    },
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
            ),
          Text(
            'It\'s $lastValue turn'.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 20),
          Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width,
            child: GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(16.0),
              mainAxisSpacing: 8.0,
              crossAxisSpacing: 8.0,
              children: List.generate(Game.boardlength, (index) {
                return InkWell(
                  onTap: () => onCellTapped(index),
                  child: Container(
                    width: Game.boardsize,
                    height: Game.boardsize,
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Center(
                      child: StreamBuilder<String>(
                        stream: Game.moveStreamController.stream,
                        builder: (context, snapshot) {
                          return Text(
                            Game.board[index],
                            style: TextStyle(
                              color: Game.board[index] == 'X'
                                  ? Colors.blue
                                  : Colors.pink,
                              fontSize: 50,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          TextButton(
            onPressed: () {
              resetGame();
            },
            child: const Text(
              'Reset Game',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
