import 'dart:math';

import 'package:wordgame/flame/extensions.dart';
import 'package:wordgame/util.dart';
import 'words.dart';

class Game {
  final int id;
  final String channel;
  final GameState state;
  final bool active;
  final DateTime startsAt, endsAt;
  final int version;

  Game(this.id, this.channel, this.state, this.active, this.startsAt, this.endsAt, this.version);
  static Game? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return Game(
      json['id'] as int,
      json['channel'] as String,
      GameState(json['state']),
      json['active'] as bool,
      DateTime.parse(json['starts_at']),
      DateTime.parse(json['ends_at']),
      json['version'] as int,
    );
  }
}

class GameState {
  int score = 0;
  Map<Point<int>, PlacedTile> placedTiles;
  Map<Point<int>, PickupType> pickups;

  GameState.empty() : placedTiles = {}, pickups = {};

  GameState._(this.score, this.placedTiles, this.pickups);

  factory GameState(Map<String, dynamic> json) {
    final score = json['score'];
    List placedTilesList = json['placed_tiles'];
    final placedTiles = <Point<int>, PlacedTile>{};
    for (var i = 0; i < placedTilesList.length; i += 4) {
      final coor = Point<int>(placedTilesList[i], placedTilesList[i + 1]);
      placedTiles[coor] = PlacedTile(placedTilesList[i + 2], placedTilesList[i + 3]);
    }
    List pickupsList = json['pickups'] ?? [];
    final pickups = <Point<int>, PickupType>{};
    for (var i = 0; i < pickupsList.length; i += 3) {
      final coor = Point<int>(pickupsList[i], pickupsList[i + 1]);
      pickups[coor] = PickupType.values.byName(pickupsList[i + 2]);
    }
    return GameState._(score, placedTiles, pickups);
  }

  jsonAfterProvisional(LocalState presence, ProvisionalResult provisionalResult) {
    // Set state.
    final letterList = [];
    for (final entry in placedTiles.entries) {
      letterList.addAll([entry.key.x, entry.key.y, entry.value.letter, entry.value.username]);
    }
    for (final entry in provisionalResult.provisionalTiles.entries) {
      letterList.addAll([entry.key.x, entry.key.y, entry.value, presence.username]);
    }
    final pickupList = [];
    for (final entry in pickups.entries) {
      if (provisionalResult.provisionalTiles.containsKey(entry.key)) continue; // Pickup has been picked up!
      pickupList.addAll([entry.key.x, entry.key.y, entry.value.toString().split('.').last]);
    }
    // Spawn pickups.
    List<Point<int>> tileCoors = placedTiles.keys.followedBy(provisionalResult.provisionalTiles.keys).toList();
    final targetPickupCount = (tileCoors.length / 15.0).floor();
    // Don't count pickups on the board that players are unlikely to ever be able to get.
    final gettablePickupCount = pickups.keys.where((e) => _countAdjacentEmptySpaces(e) > 2).length;
    final pickupsToSpawn = targetPickupCount - gettablePickupCount;
    if (pickupsToSpawn > 0) {
      Set<Point<int>> coorsToAvoid = tileCoors.followedBy(pickups.keys).toSet();
      for (int i = 0; i < pickupsToSpawn; i++) {
        // Find a coordinate at least 5 spaces from everything on the board.
        for (int j = 0; j < 100; j++) { // Try a bunch of times to find a spot.
          Point<int> spawnCandidate = tileCoors[Util.random.nextInt(tileCoors.length)];
          final distance = 6 + Util.random.nextInt(2);
          final xySplit = Util.random.nextInt(distance + 1);
          spawnCandidate = Point(spawnCandidate.x + xySplit * (Util.random.nextBool() ? -1 : 1), spawnCandidate.y + (distance - xySplit) * (Util.random.nextBool() ? -1 : 1));
          if (coorsToAvoid.every((e) => e.manhattanDistanceTo(spawnCandidate) >= 5)) {
            pickupList.addAll([spawnCandidate.x, spawnCandidate.y, PickupType.wildcard.toString().split('.').last]);
            break;
          }
        }
      }
    }
    // Return.
    return {
      'score': score + provisionalResult.score().total,
      'placed_tiles': letterList,
      'pickups': pickupList,
    };
  }
  int _countAdjacentEmptySpaces(Point<int> coor) {
    return Util.cardinalDirections.map((e) => coor + e).where((e) => !placedTiles.containsKey(e)).length;
  }
}
class PlacedTile {
  final String letter, username;
  PlacedTile(this.letter, this.username);
}
enum PickupType {
  wildcard
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
    rack.add('*');
    sortRack();
  }

  sortRack() {
    rack.sort((a, b) => a == '*' ? 1 : b == '*' ? -1 : a.compareTo(b));
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
    for (int i = 0; i < bagDistribution.length; i++) {
      bagDistribution[i] += Words.letterDistribution[i];
    }
  }

  countProvisionalWildcards() {
    return provisionalTiles.isEmpty ? 0 : provisionalTiles.values.toSet().map((e) => max(0, provisionalTiles.values.where((f) => e == f).length - rack.where((f) => e == f).length)).reduce((a, b) => a + b);
  }

  loseLetterOrWildcard(String letter) {
    rack.remove(rack.contains(letter) ? letter : '*');
  }

  partiallyFillRackIfEmpty() {
    if (rack.isEmpty) {
      while (rack.length < PARTIAL_REFILL) {
        drawTile();
      }
      sortRack();
    }
  }
  pickup(List<PickupType> pickups) {
    for (final pickup in pickups) {
      switch (pickup) {
        case PickupType.wildcard:
          if (rack.length < rackSize) {
            rack.add('*');
          }
          break;
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
