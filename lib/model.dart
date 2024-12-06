import 'dart:math';

class Game {
  final int id;
  final String channel;
  final State state;
  final bool active;
  final int version;

  Game(this.id, this.channel, this.state, this.active, this.version);
  static Game? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return Game(
      json['id'] as int,
      json['channel'] as String,
      State(json['state']),
      json['active'] as bool,
      json['version'] as int,
    );
  }
}

class State {
  Map<Point<int>, String> letters;

  State._(this.letters);

  factory State(Map<String, dynamic> json) {
    List letterList = json['letters'];
    final letters = <Point<int>, String>{};
    for (var i = 0; i < letters.length; i += 3) {
      final coor = Point<int>(letterList[i], letterList[i + 2]);
      letters[coor] = letterList[i + 2];
    }
    return State._(letters);
  }

  jsonAfterProvisional(PresenceState presence) {
    final letterList = [];
    for (final entry in letters.entries) {
      letterList.addAll([entry.key.x, entry.key.y, entry.value]);
    }
    for (final entry in presence.provisionalTiles.entries) {
      letterList.addAll([entry.key.x, entry.key.y, entry.value]);
    }
    return {
      'letters': letterList,
    };
  }
}

class PresenceState {
  String username;
  Point cursor;
  List<String> rack;
  Map<Point<int>, String> provisionalTiles;

  PresenceState(this.username, this.cursor, this.rack, this.provisionalTiles);
  PresenceState.newLocal(String username) : this(username, Point(0, 0), [], {});

  toJson() {
    final provisionalList = [];
    for (final entry in provisionalTiles.entries) {
      provisionalList.addAll([entry.key.x, entry.key.y, entry.value]);
    }
    return {
      'username': username,
      'cursor': [cursor.x, cursor.y],
      'rack': rack,
      'provisionalTiles': provisionalList,
    };
  }
}
