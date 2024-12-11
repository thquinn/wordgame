import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wordgame/words.dart';

import 'model.dart';

class WordGameState extends ChangeNotifier {
  String? roomID;
  RealtimeChannel? channel;
  LocalState? localState;
  Game? game;

  isConnected() {
    return roomID != null && channel != null && localState != null;
  }
  gameIsActive() {
    return isConnected() && game != null;
  }

  connect(String roomID, String username) {
    this.roomID = roomID;
    channel = Supabase.instance.client.channel(roomID);
    Supabase.instance.client.from('games').select().eq('channel', roomID).maybeSingle().then((value) {
      game = Game.fromJson(value);
      notifyListeners();
    });
    Supabase.instance.client.channel('game-changes').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'games',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'channel', value: roomID),
      callback: (payload) {
        game = Game.fromJson(payload.newRecord);
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
      localState!.drawTile();
      localState!.assister = payload['sender'];
    }
  }

  // Commands.
  startGame() async {
    if (!isConnected()) return;
    try {
      await Supabase.instance.client.from('games').insert({
        'channel': roomID,
        'active': true,
      });
    } on PostgrestException catch (e) {
      print(e.toString());
    }
  }

  moveCursorTo(Point<int> coor) async {
    if (!gameIsActive()) return;
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
    if (game!.state.placedTiles.containsKey(localState.cursor)) {
      await advanceCursor();
      return;
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
  playProvisionalTiles() async {
    if (!gameIsActive()) return;
    final provisionalTiles = localState!.provisionalTiles;
    if (provisionalTiles.isEmpty) return;
    // Can only play tiles in a straight line.
    if (!provisionalTiles.keys.every((coor) => coor.x == provisionalTiles.keys.first.x) && !provisionalTiles.keys.every((coor) => coor.y == provisionalTiles.keys.first.y)) {
      return;
    }
    // Can only play tiles connected to each other or already-played tiles.
    final minX = provisionalTiles.keys.map((e) => e.x).reduce(min);
    final maxX = provisionalTiles.keys.map((e) => e.x).reduce(max);
    final minY = provisionalTiles.keys.map((e) => e.y).reduce(min);
    final maxY = provisionalTiles.keys.map((e) => e.y).reduce(max);
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        final point = Point<int>(x, y);
        if (!provisionalTiles.containsKey(point) && !game!.state.placedTiles.containsKey(point)) {
          return;
        }
      } 
    }
    // Check for word legality.
    final provisionalWords = Words.getProvisionalWords(this);
    if (provisionalWords.any((w) => !Words.isLegal(w.word))) {
      return;
    }
    // Play.
    final version = game!.version;
    final result = await Supabase.instance.client.from('games').update({
      'state': game!.state.jsonAfterProvisional(localState!, provisionalWords),
      'version': version + 1,
    }).eq('channel', roomID!).eq('version', version).select().maybeSingle();
    if (result != null) {
      // Finalize move.
      for (final letter in provisionalTiles.values) {
        localState!.rack.remove(letter);
      }
      provisionalTiles.clear();
      await channel!.track(localState!.toPresenceJson());
      // Broadcasts.
      final assistUsernames = provisionalWords.expand((pw) => pw.usernames).toSet().toList();
      assistUsernames.remove(localState!.username);
      if (assistUsernames.isNotEmpty) {
        channel!.sendBroadcastMessage(event: 'assist', payload: {'sender': localState!.username, 'usernames': assistUsernames});
      }
    }
  }
}
