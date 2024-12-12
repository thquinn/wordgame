import 'dart:math';

import 'package:wordgame/util.dart';
import 'package:wordgame/words.dart';

class Game {
  final int id;
  final String channel;
  final State state;
  final bool active;
  final DateTime endsAt;
  final int version;

  Game(this.id, this.channel, this.state, this.active, this.endsAt, this.version);
  static Game? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return Game(
      json['id'] as int,
      json['channel'] as String,
      State(json['state']),
      json['active'] as bool,
      DateTime.parse(json['ends_at']),
      json['version'] as int,
    );
  }
}

class State {
  int score = 0;
  Map<Point<int>, PlacedTile> placedTiles;

  State._(this.score, this.placedTiles);

  factory State(Map<String, dynamic> json) {
    final score = json['score'];
    List placedTilesList = json['placed_tiles'];
    final placedTiles = <Point<int>, PlacedTile>{};
    for (var i = 0; i < placedTilesList.length; i += 4) {
      final coor = Point<int>(placedTilesList[i], placedTilesList[i + 1]);
      placedTiles[coor] = PlacedTile(placedTilesList[i + 2], placedTilesList[i + 3]);
    }
    return State._(score, placedTiles);
  }

  jsonAfterProvisional(LocalState presence, List<ProvisionalWord> provisionalWords) {
    // Calculate move score.
    int moveScore = 0;
    for (ProvisionalWord provisionalWord in provisionalWords) {
      moveScore += provisionalWord.score();
    }
    // Set state.
    final letterList = [];
    for (final entry in placedTiles.entries) {
      letterList.addAll([entry.key.x, entry.key.y, entry.value.letter, entry.value.username]);
    }
    for (final entry in presence.provisionalTiles.entries) {
      letterList.addAll([entry.key.x, entry.key.y, entry.value, presence.username]);
    }
    return {
      'score': score + moveScore,
      'placed_tiles': letterList,
    };
  }
}
class PlacedTile {
  final String letter, username;
  PlacedTile(this.letter, this.username);
}

class LocalState {
  String username;
  Point<int> cursor;
  bool cursorHorizontal;
  int rackSize;
  List<String> rack;
  List<double> bagDistribution;
  Map<Point<int>, String> provisionalTiles;
  String? assister; // set to a username when another player gives you an assist tile

  LocalState(this.username, this.cursor, this.cursorHorizontal, this.rackSize, this.rack, this.bagDistribution, this.provisionalTiles);
  factory LocalState.newLocal(String username) {
    final localState = LocalState(username, Point(0, 0), true, 7, [], List<double>.from(Words.letterDistribution), {});
    while (localState.rack.length < 4) {
      localState.drawTile();
    }
    localState.rack.sort();
    return localState;
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

  toPresenceJson() {
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
