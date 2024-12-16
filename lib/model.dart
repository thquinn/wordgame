import 'dart:math';

import 'package:wordgame/util.dart';
import 'words.dart';

class Game {
  final int id;
  final String channel;
  final GameState state;
  final bool active;
  final DateTime endsAt;
  final int version;

  Game(this.id, this.channel, this.state, this.active, this.endsAt, this.version);
  static Game? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return Game(
      json['id'] as int,
      json['channel'] as String,
      GameState(json['state']),
      json['active'] as bool,
      DateTime.parse(json['ends_at']),
      json['version'] as int,
    );
  }
}

class GameState {
  int score = 0;
  Map<Point<int>, PlacedTile> placedTiles;

  GameState.empty() : placedTiles = {};

  GameState._(this.score, this.placedTiles);

  factory GameState(Map<String, dynamic> json) {
    final score = json['score'];
    List placedTilesList = json['placed_tiles'];
    final placedTiles = <Point<int>, PlacedTile>{};
    for (var i = 0; i < placedTilesList.length; i += 4) {
      final coor = Point<int>(placedTilesList[i], placedTilesList[i + 1]);
      placedTiles[coor] = PlacedTile(placedTilesList[i + 2], placedTilesList[i + 3]);
    }
    return GameState._(score, placedTiles);
  }

  jsonAfterProvisional(LocalState presence, ProvisionalResult provisionalResult) {
    // Set state.
    final letterList = [];
    for (final entry in placedTiles.entries) {
      letterList.addAll([entry.key.x, entry.key.y, entry.value.letter, entry.value.username]);
    }
    for (final entry in presence.provisionalTiles.entries) {
      letterList.addAll([entry.key.x, entry.key.y, entry.value, presence.username]);
    }
    return {
      'score': score + provisionalResult.score(),
      'placed_tiles': letterList,
    };
  }
}
class PlacedTile {
  final String letter, username;
  PlacedTile(this.letter, this.username);
}

class LocalState {
  static const int PARTIAL_REFILL = 5;

  DateTime joinTime;
  String username;
  Point<int> cursor;
  bool cursorHorizontal;
  int rackSize;
  List<String> rack;
  int overflowTiles;
  List<double> bagDistribution;
  Map<Point<int>, String> provisionalTiles;
  String? assister; // set to a username when another player gives you an assist tile

  LocalState(this.joinTime, this.username, this.cursor, this.cursorHorizontal, this.rackSize, this.rack, this.overflowTiles, this.bagDistribution, this.provisionalTiles);
  factory LocalState.newLocal(String username) {
    final localState = LocalState(DateTime.now().toUtc(), username, Point(0, 0), true, 10, [], 0, List<double>.from(Words.letterDistribution), {});
    localState.reset();
    return localState;
  }

  reset() {
    cursor = Point(0, 0);
    cursorHorizontal = true;
    rackSize = 10;
    rack = [];
    overflowTiles = 0;
    bagDistribution = List<double>.from(Words.letterDistribution);
    provisionalTiles.clear();
    partiallyFillRackIfEmpty();
    rack.sort();
  }

  drawTile({bool overflow = false}) {
    if (rack.length >= rackSize) {
      if (overflow) {
        overflowTiles++;
      }
      return;
    }
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
    print('static letter dist is');
    print(Words.letterDistribution);
    print(Words.wordSet.length);
    for (int i = 0; i < bagDistribution.length; i++) {
      bagDistribution[i] += Words.letterDistribution[i];
    }
  }

  partiallyFillRackIfEmpty() {
    if (rack.isEmpty) {
      while (rack.length < PARTIAL_REFILL) {
        drawTile();
      }
    }
  }
  spendOverflowTiles() {
    while (rack.length < rackSize && overflowTiles > 0) {
      drawTile();
      overflowTiles--;
    }
  }

  toPresenceJson() {
    final provisionalList = [];
    for (final entry in provisionalTiles.entries) {
      provisionalList.addAll([entry.key.x, entry.key.y, entry.value]);
    }
    return {
      'join_time': joinTime.toString(),
      'username': username,
      'cursor': [cursor.x, cursor.y],
      'rack_size': rackSize,
      'rack': rack,
      'provisional_tiles': provisionalList,
    };
  }
}
