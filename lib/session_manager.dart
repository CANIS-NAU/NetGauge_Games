// used to track data that needs to be accessible across files/functions
class SessionManager {
  static String? _sessionId;
  static String? _playerName;
  static String? _currentGame; 

  static String? get sessionId => _sessionId;
  static String? get playerName => _playerName;
  static String? get currentGame => _currentGame;

  static void setSessionId(String id) {
    _sessionId = id;
  }

  static void setPlayerName(String name){
    _playerName = name;
    print('Player name set to $_playerName');
  }

  static void startGame(String gameTitle){
    _currentGame = gameTitle;
    print('Game started: $_currentGame');
  }

  static void endGame(){
    print('Game ended: $_currentGame');
    _currentGame = null;
  }
}