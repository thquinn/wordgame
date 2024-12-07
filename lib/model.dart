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
  Map<Point<int>, PlacedTile> placedTiles;

  State._(this.placedTiles);

  factory State(Map<String, dynamic> json) {
    List placedTilesList = json['placed_tiles'];
    final placedTiles = <Point<int>, PlacedTile>{};
    for (var i = 0; i < placedTiles.length; i += 4) {
      final coor = Point<int>(placedTilesList[i], placedTilesList[i + 2]);
      placedTiles[coor] = PlacedTile(placedTilesList[i + 2], placedTilesList[i + 3]);
    }
    return State._(placedTiles);
  }

  jsonAfterProvisional(PresenceState presence) {
    final letterList = [];
    for (final entry in placedTiles.entries) {
      letterList.addAll([entry.key.x, entry.key.y, entry.value, presence.username]);
    }
    for (final entry in presence.provisionalTiles.entries) {
      letterList.addAll([entry.key.x, entry.key.y, entry.value, presence.username]);
    }
    return {
      'placed_tiles': letterList,
    };
  }
}
class PlacedTile {
  final String letter, username;
  PlacedTile(this.letter, this.username);
}

class PresenceState {
  String username;
  Point<int> cursor;
  bool cursorHorizontal;
  List<String> rack;
  Map<Point<int>, String> provisionalTiles;

  PresenceState(this.username, this.cursor, this.cursorHorizontal, this.rack, this.provisionalTiles);
  PresenceState.newLocal(String username) : this(username, Point(0, 0), true, [], {});

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
