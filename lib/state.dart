import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'model.dart';

class MyAppState extends ChangeNotifier {
  String? roomID;
  RealtimeChannel? channel;
  PresenceState? presenceState;
  Game? game;

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

  isConnected() {
    return roomID != null && channel != null;
  }
  gameIsActive() {
    return isConnected() && game != null;
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
