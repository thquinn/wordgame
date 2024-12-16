import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wordgame/util.dart';
import 'flame/area_glow.dart';
import 'package:wordgame/flame/notification.dart';
import 'package:wordgame/words.dart';

import 'model.dart';

class WordGameState extends ChangeNotifier {
  String? roomID;
  RealtimeChannel? channel;
  LocalState? localState;
  Game? game;

  bool isConnected() {
    return roomID != null && channel != null && localState != null;
  }
  bool hasGame() {
    return isConnected() && game != null;
  }
  bool gameIsActive() {
    return hasGame() && game!.active && game!.endsAt.isAfter(DateTime.now());
  }
  bool isAdmin() {
    if (channel!.presenceState().isEmpty) return false;
    return isConnected() && localState!.joinTime == channel!.presenceState().map((e) => DateTime.parse(e.presences.first.payload['join_time'])).reduce((a, b) => a.isBefore(b) ? a : b);
  }
  String getAdminUsername() {
    if (!isConnected()) return '';
    if (channel!.presenceState().isEmpty) return '';
    final earliestJoin = channel!.presenceState().map((e) => DateTime.parse(e.presences.first.payload['join_time'])).reduce((a, b) => a.isBefore(b) ? a : b);
    return channel!.presenceState().firstWhere((e) => DateTime.parse(e.presences.first.payload['join_time']) == earliestJoin).presences.first.payload['username'];
  }

  connect(String roomID, String username) {
    roomID = roomID.toLowerCase();
    this.roomID = roomID;
    channel = Supabase.instance.client.channel(roomID);
    Supabase.instance.client.from('games').select().eq('channel', roomID).eq('active', true).maybeSingle().then((value) {
      game = Game.fromJson(value);
      notifyListeners();
    });
    Supabase.instance.client.channel('game-changes').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'games',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'channel', value: roomID),
      callback: (payload) async {
        final updatedGame = Game.fromJson(payload.newRecord);
        if (game != null && updatedGame != null) {
          AreaGlowManager.instance.gameDelta(game!, updatedGame);
        }
        if (game != null && game!.id != updatedGame!.id) {
          // A new game has started.
          localState!.reset();
          await channel!.track(localState!.toPresenceJson());
        }
        game = updatedGame;
        if (gameIsActive()) {
          for (final coor in game!.state.placedTiles.keys) {
            if (localState!.provisionalTiles.containsKey(coor)) {
              clearProvisionalTiles();
              break;
            }
          }
        } else {
          clearProvisionalTiles();
        }
        notifyListeners();
      },
    ).subscribe();
    Supabase.instance.client.channel('game-delete').onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'games',
      callback: (payload) {
        if (payload.oldRecord['id'] == game?.id) {
          game = null;
          notifyListeners();
        }
      },
    ).subscribe();
    localState = LocalState.newLocal(username);
    channel!
      .onBroadcast(event: 'notification', callback: onReceiveNotification)
      .onBroadcast(event: 'assist', callback: onReceiveAssist)
      .subscribe((status, error) async {
        if (status != RealtimeSubscribeStatus.subscribed) return;
        await channel!.track(localState!.toPresenceJson());
      });
    notifyListeners();
  }

  // Broadcast messages.
  onReceiveAssist(payload) {
    final usernames = List<String>.from(payload['usernames'] as List);
    if (usernames.contains(localState!.username)) {
      localState!.drawTile(overflow: true);
      localState!.assister = payload['sender'];
    }
  }
  onReceiveNotification(payload) {
    NotificationManager.enqueueFromBroadcast(payload['notiftype'], Util.castJsonToStringMap(payload['args']));
  }

  // Commands.
  startGame() async {
    if (!isConnected()) return;
    if (gameIsActive()) return;
    if (!isAdmin()) return;
    // Finish existing game.
    if (game != null) {
      final version = game!.version;
      final result = await Supabase.instance.client.from('games').update({
        'active': false
      }).eq('channel', roomID!).eq('version', version).eq('active', true).select().maybeSingle();
      if (result == null) {
        return;
      }
    }
    // Start new game from waiting room.
    try {
      await Supabase.instance.client.from('games').insert({
        'channel': roomID,
        'active': true,
      });
    } on PostgrestException catch (e) {
      print('Failed to start new game:');
      print(e.toString());
    }
  }

  moveCursorTo(Point<int> coor) async {
    if (!hasGame()) return;
    localState!.cursor = coor;
    await channel!.track(localState!.toPresenceJson());
  }
  tryPlayingTile(String letter) async {
    if (!gameIsActive()) return;
    final localState = this.localState!;
    // Must have enough of the letter on rack.
    int numOnRack = localState.rack.where((item) => item == letter).length;
    int numProvisional = localState.provisionalTiles.values.where((item) => item == letter).length;
    if (numOnRack <= numProvisional) {
      return;
    }
    // Can't place on top of an existing tile.
    while (game!.state.placedTiles.containsKey(localState.cursor)) {
      localState.cursor += Point<int>(localState.cursorHorizontal == true ? 1 : 0, localState.cursorHorizontal == true ? 0 : 1);
    }
    // Place.
    localState.provisionalTiles[localState.cursor] = letter;
    await advanceCursor();
  }
  advanceCursor() async {
    if (!gameIsActive()) return;
    do {
      localState?.cursor += Point<int>(localState?.cursorHorizontal == true ? 1 : 0, localState?.cursorHorizontal == true ? 0 : 1);
    } while (game!.state.placedTiles.containsKey(localState!.cursor));
    notifyListeners();
    await channel!.track(localState!.toPresenceJson());
  }
  retreatCursorAndDelete() async {
    if (!gameIsActive()) return;
    if (localState!.provisionalTiles.containsKey(localState!.cursor)) {
      localState!.provisionalTiles.remove(localState!.cursor);
      return;
    }
    do {
      localState!.cursor -= Point<int>(localState!.cursorHorizontal == true ? 1 : 0, localState!.cursorHorizontal == true ? 0 : 1);
    } while (game!.state.placedTiles.containsKey(localState!.cursor));
    localState!.provisionalTiles.remove(localState!.cursor);
    await channel!.track(localState!.toPresenceJson());
  }
  confirmProvisionalTiles() async {
    if (!gameIsActive()) return;
    final provisionalTiles = localState!.provisionalTiles;
    if (provisionalTiles.isEmpty) return;
    // Can only play tiles in a straight line.
    if (!provisionalTiles.keys.every((coor) => coor.x == provisionalTiles.keys.first.x) && !provisionalTiles.keys.every((coor) => coor.y == provisionalTiles.keys.first.y)) {
      return;
    }
    // If there are tiles on the board, you have to play adjacent to one.
    final placedTiles = game!.state.placedTiles;
    if (placedTiles.isNotEmpty && !provisionalTiles.keys.any((Point<int> coor) {
      return placedTiles.containsKey(Point<int>(coor.x - 1, coor.y)) ||
        placedTiles.containsKey(Point<int>(coor.x + 1, coor.y)) ||
        placedTiles.containsKey(Point<int>(coor.x, coor.y - 1)) ||
        placedTiles.containsKey(Point<int>(coor.x, coor.y + 1));
    })) {
      return;
    }
    // Check for word legality.
    final provisionalResult = Words.getProvisionalResult(this);
    if (provisionalResult.words.any((w) => !Words.isLegal(w.word))) {
      return;
    }
    // Play.
    final version = game!.version;
    final results = await Supabase.instance.client.from('games').update({
      'state': game!.state.jsonAfterProvisional(localState!, provisionalResult),
      'version': version + 1,
    }).eq('channel', roomID!).eq('version', version).eq('active', true).select();
    // NOTE: using maybeSingle() on the query above returns an error: "The result contains 0 rows"
    // Yeah, I know that!
    if (results.isNotEmpty) {
      // Finalize move.
      for (final letter in provisionalTiles.values) {
        localState!.rack.remove(letter);
      }
      localState!.partiallyFillRackIfEmpty();
      localState!.spendOverflowTiles();
      provisionalTiles.clear();
      await channel!.track(localState!.toPresenceJson());
      // Broadcasts.
      final assistUsernames = provisionalResult.words.expand((pw) => pw.usernames).toSet().toList();
      assistUsernames.remove(localState!.username);
      if (assistUsernames.isNotEmpty) {
        channel!.sendBroadcastMessage(event: 'assist', payload: {'sender': localState!.username, 'usernames': assistUsernames});
      }
      for (final wordQualifierPair in provisionalResult.words.map((e) => [e.word, e.getNotificationQualifier()]).where((e) => e[1] != null)) {
        channel!.sendBroadcastMessage(event: 'notification', payload: {
          'sender': localState!.username,
          'notiftype': 'word',
          'args': {
            'username': localState!.username,
            'qualifier': wordQualifierPair.last,
            'word': wordQualifierPair.first,
          }
        });
      }
      final enclosedArea = provisionalResult.enclosedAreas.isEmpty ? 0 : provisionalResult.enclosedAreas.map((e) => e.length).reduce((a, b) => a + b);
      if (enclosedArea > 1) {
        channel!.sendBroadcastMessage(event: 'notification', payload: {
          'sender': localState!.username,
          'notiftype': 'enclosed_area',
          'args': {
            'username': localState!.username,
            'area': enclosedArea,
          }
        });
      }
    }
  }
  clearProvisionalTiles() async {
    if (!hasGame()) return;
    if (localState!.provisionalTiles.isEmpty) return;
    localState!.provisionalTiles.clear();
    await channel!.track(localState!.toPresenceJson());
  }
}
