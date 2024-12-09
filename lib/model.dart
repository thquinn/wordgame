import 'dart:math';

import 'package:wordgame/util.dart';
import 'package:wordgame/words.dart';

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
    for (var i = 0; i < placedTilesList.length; i += 4) {
      final coor = Point<int>(placedTilesList[i], placedTilesList[i + 1]);
      placedTiles[coor] = PlacedTile(placedTilesList[i + 2], placedTilesList[i + 3]);
    }
    return State._(placedTiles);
  }

  jsonAfterProvisional(PresenceState presence) {
    final letterList = [];
    for (final entry in placedTiles.entries) {
      letterList.addAll([entry.key.x, entry.key.y, entry.value.letter, entry.value.username]);
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
  int rackSize;
  List<String> rack;
  List<double> bagDistribution;
  Map<Point<int>, String> provisionalTiles;

  PresenceState(this.username, this.cursor, this.cursorHorizontal, this.rackSize, this.rack, this.bagDistribution, this.provisionalTiles);
  factory PresenceState.newLocal(String username) {
    final presenceState = PresenceState(username, Point(0, 0), true, 10, [], List<double>.from(Words.letterDistribution), {});
    while (presenceState.rack.length < presenceState.rackSize) {
      presenceState.drawTile();
    }
    presenceState.rack.sort();
    return presenceState;
  }

  drawTile() {
    if (rack.length >= rackSize) return;
    final totalWeight = bagDistribution.reduce((a, b) => a + b);
    double selector = Util.random.nextDouble() * totalWeight;
    for (int i = 0; i < bagDistribution.length; i++) {
      selector -= bagDistribution[i];
      if (selector <= 0) {
        bagDistribution[i] -= .01;
        if (bagDistribution[i] < 0) {
          refillBag();
        }
        rack.add('abcdefghijklmnopqrstuvwxyz'[i]);
        return;
      }
    }
  }
  refillBag() {
    for (int i = 0; i < bagDistribution.length; i++) {
      bagDistribution[i] += Words.letterDistribution[i];
    }
  }

  toJson() {
    final provisionalList = [];
    for (final entry in provisionalTiles.entries) {
      provisionalList.addAll([entry.key.x, entry.key.y, entry.value]);
    }
    return {
      'username': username,
      'cursor': [cursor.x, cursor.y],
      'rackSize': rackSize,
      'rack': rack,
      'provisionalTiles': provisionalList,
    };
  }
}
