import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'model.dart';

class MyAppState extends ChangeNotifier {
  String? roomID;
  RealtimeChannel? channel;
  PresenceState? presenceState;
  Game? game;

  isConnected() {
    return roomID != null && channel != null && presenceState != null;
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
    presenceState = PresenceState.newLocal('vsman');
    channel!.subscribe((status, error) async {
      if (status != RealtimeSubscribeStatus.subscribed) return;
      await channel!.track(presenceState!.toJson());
    });

    notifyListeners();
  }

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

  tryPlayingTile(String letter) async {
    if (!gameIsActive()) return;
    final presenceState = this.presenceState!;
    if (game!.state.placedTiles.containsKey(presenceState.cursor)) {
      await advanceCursor();
      return;
    }
    presenceState.provisionalTiles[presenceState.cursor] = letter;
    await advanceCursor();
  }
  advanceCursor() async {
    do {
      presenceState?.cursor += Point<int>(presenceState?.cursorHorizontal == true ? 1 : 0, presenceState?.cursorHorizontal == true ? 0 : 1);
    } while (game!.state.placedTiles.containsKey(presenceState!.cursor));
    await channel!.track(presenceState!.toJson());
  }
  retreaatCursorAndDelete() async {
    presenceState?.cursor -= Point<int>(presenceState?.cursorHorizontal == true ? 1 : 0, presenceState?.cursorHorizontal == true ? 0 : 1);
    presenceState?.provisionalTiles.remove(presenceState?.cursor);
    await channel!.track(presenceState!.toJson());
  }
  playProvisionalTiles() async {
    if (!gameIsActive()) return;
    final version = game!.version;
    final result = await Supabase.instance.client.from('games').update({
      'state': game!.state.jsonAfterProvisional(presenceState!),
      'version': version + 1,
    }).eq('channel', roomID!).eq('version', version).select().maybeSingle();
    if (result != null) {
      presenceState!.provisionalTiles.clear();
      await channel!.track(presenceState!.toJson());
    }
  }
}
