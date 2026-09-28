import 'dart:math';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:wordgame/flame/tile.dart';
import 'package:wordgame/util.dart';
import 'flame/area_glow.dart';
import 'package:wordgame/flame/notification.dart';
import 'package:wordgame/words.dart';

import 'model.dart';
import 'room_channel.dart';

class WordGameState extends ChangeNotifier {
  String? roomID;
  RoomChannel? channel;
  LocalState? localState;
  Game? game;
  bool _joined = false;
  bool _connecting = false;
  bool _movePending = false;

  bool isConnected() {
    return _joined && roomID != null && channel != null && localState != null;
  }

  bool hasGame() {
    return isConnected() && game != null;
  }

  bool gameIsActive({bool andStarted = true}) {
    if (!hasGame()) return false;
    if (!game!.active) return false;
    final isAfterStart = game!.startsAt.isBefore(DateTime.now());
    final isBeforeEnd = game!.endsAt.isAfter(DateTime.now());
    return andStarted ? (isAfterStart && isBeforeEnd) : isBeforeEnd;
  }

  bool isAdmin() {
    return isConnected() && channel!.isAdmin;
  }

  String getAdminUsername() {
    return isConnected() ? channel!.adminUsername : '';
  }

  Future<void> connect(String roomID, String username) async {
    if (_connecting || _joined) return;
    _connecting = true;
    this.roomID = roomID.toLowerCase();
    localState = LocalState.newLocal(username);
    channel = RoomChannel(
      roomID: this.roomID!,
      username: username,
      initialPresence: localState!.toPresenceJson(),
      onGame: (value, {required created}) =>
          _applyGame(value, created: created),
      onPresence: () {
        if (_joined) notifyListeners();
      },
      onNotification: (payload) => onReceiveNotification(payload),
      onAssist: (payload) => onReceiveAssist(payload),
    );
    try {
      await channel!.connect();
      localState!.joinTime = DateTime.parse(channel!.joinTime!);
      _joined = true;
      html.window.history.pushState(
          null, '', '?room=${Uri.encodeQueryComponent(this.roomID!)}');
      notifyListeners();
    } catch (error) {
      channel?.dispose();
      channel = null;
      localState = null;
      this.roomID = null;
      game = null;
      notifyListeners();
      rethrow;
    } finally {
      _connecting = false;
    }
  }

  void _applyGame(Map<String, dynamic>? value, {bool created = false}) {
    final updatedGame = Game.fromJson(value);
    final oldGame = game;
    if (oldGame != null &&
        updatedGame != null &&
        (updatedGame.id < oldGame.id ||
            updatedGame.id == oldGame.id &&
                updatedGame.version < oldGame.version)) return;
    if (updatedGame != null &&
        (created || oldGame != null && oldGame.id != updatedGame.id)) {
      localState!.reset();
      channel!.track(localState!.toPresenceJson());
    } else if (oldGame != null &&
        updatedGame != null &&
        oldGame.version != updatedGame.version) {
      if (localState!.gameDelta(oldGame, updatedGame)) {
        channel!.track(localState!.toPresenceJson());
      }
      TileManager.instance.gameDelta(oldGame, updatedGame);
      AreaGlowManager.instance.gameDelta(oldGame, updatedGame);
    }
    game = updatedGame;
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

  sendNotification(String notifType, Map<String, dynamic> args) async {
    final payload = {
      'sender': localState!.username,
      'notiftype': notifType,
      'args': args
    };
    onReceiveNotification(payload);
    await channel!
        .sendBroadcastMessage(event: 'notification', payload: payload);
  }

  onReceiveNotification(payload) {
    NotificationManager.enqueueFromBroadcast(
        payload['notiftype'], Util.castJsonToStringMap(payload['args']));
  }

  // Commands.
  startGame() async {
    if (!isConnected()) return;
    if (gameIsActive(andStarted: false)) return;
    if (!isAdmin()) return;
    try {
      final result = await channel!.startGame();
      if (result['ok'] == true) {
        _applyGame(Map<String, dynamic>.from(result['game'] as Map),
            created: true);
      } else if (result['game'] is Map) {
        _applyGame(Map<String, dynamic>.from(result['game'] as Map));
      }
    } catch (error) {
      print('Failed to start game: $error');
    }
  }

  moveCursorTo(Point<int> coor) async {
    if (!hasGame()) return;
    if (localState!.cursor == coor) return;
    localState!.cursor = coor;
    await channel!.track(localState!.toPresenceJson());
  }

  tryPlayingTile(String letter) async {
    if (!gameIsActive()) return;
    final localState = this.localState!;
    final provisionalTiles = localState.provisionalTiles;
    final rack = localState.rack;
    // Must have enough of the letter on rack.
    final numOnRack = rack.where((item) => item == letter).length;
    final numProvisional =
        provisionalTiles.values.where((item) => item == letter).length;
    final numWildcards = rack.where((item) => item == '*').length;
    final numWildcardsUsed = localState.countProvisionalWildcards();
    if (numOnRack <= numProvisional && numWildcards <= numWildcardsUsed) {
      return;
    }
    // Can't place on top of an existing tile.
    while (game!.state.placedTiles.containsKey(localState.cursor)) {
      localState.cursor += Point<int>(
          localState.cursorHorizontal == true ? 1 : 0,
          localState.cursorHorizontal == true ? 0 : 1);
    }
    // Place.
    localState.provisionalTiles[localState.cursor] = letter;
    await advanceCursor();
  }

  advanceCursor() async {
    if (!gameIsActive()) return;
    do {
      localState?.cursor += Point<int>(
          localState?.cursorHorizontal == true ? 1 : 0,
          localState?.cursorHorizontal == true ? 0 : 1);
    } while (game!.state.placedTiles.containsKey(localState!.cursor) ||
        localState!.provisionalTiles.containsKey(localState!.cursor));
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
      localState!.cursor -= Point<int>(
          localState!.cursorHorizontal == true ? 1 : 0,
          localState!.cursorHorizontal == true ? 0 : 1);
    } while (game!.state.placedTiles.containsKey(localState!.cursor));
    localState!.provisionalTiles.remove(localState!.cursor);
    await channel!.track(localState!.toPresenceJson());
    notifyListeners();
  }

  confirmProvisionalTiles() async {
    if (!gameIsActive()) return;
    if (_movePending) return;
    final provisionalTiles = localState!.provisionalTiles;
    if (provisionalTiles.isEmpty) return;
    // Check for errors and word legality.
    final provisionalResult = Words.getProvisionalResult(this);
    if (provisionalResult.error != ProvisionalResultError.none ||
        provisionalResult.words.any((w) => !Words.isLegal(w.word))) {
      return;
    }
    // Play.
    _movePending = true;
    Map<String, dynamic> result;
    try {
      result = await channel!.commitMove(
        game!.version,
        Map<String, dynamic>.from(
            game!.state.jsonAfterProvisional(localState!, provisionalResult)),
      );
    } catch (error) {
      print('Failed to submit move: $error');
      _movePending = false;
      return;
    }
    _movePending = false;
    if (result['ok'] == true) {
      // Finalize move.
      for (final letter in provisionalResult.provisionalTiles.values) {
        localState!.loseLetterOrWildcard(letter);
      }
      localState!.partiallyFillRackIfEmpty();
      localState!.pickup(provisionalResult.pickups);
      localState!.spendOverflowTiles();
      provisionalTiles.clear();
      _applyGame(Map<String, dynamic>.from(result['game'] as Map));
      await channel!.track(localState!.toPresenceJson());
      // Broadcasts.
      final assistUsernames =
          provisionalResult.words.expand((pw) => pw.usernames).toSet().toList();
      assistUsernames.remove(localState!.username);
      if (assistUsernames.isNotEmpty) {
        await channel!.sendBroadcastMessage(event: 'assist', payload: {
          'sender': localState!.username,
          'usernames': assistUsernames
        });
      }
      for (final wordQualifierPair in provisionalResult.words
          .map((e) => [e.word, e.getNotificationQualifier()])
          .where((e) => e[1] != null)) {
        await sendNotification('word', {
          'username': localState!.username,
          'qualifier': wordQualifierPair.last,
          'word': wordQualifierPair.first,
        });
      }
      final enclosedArea = provisionalResult.enclosedAreas.isEmpty
          ? 0
          : provisionalResult.enclosedAreas
              .map((e) => e.length)
              .reduce((a, b) => a + b);
      if (enclosedArea > 1) {
        await sendNotification('enclosed_area', {
          'username': localState!.username,
          'area': enclosedArea,
        });
      }
      if ((provisionalResult.largestNewRect?.area ?? 0) > 4) {
        await sendNotification('tile_block', {
          'username': localState!.username,
          'dimensions':
              '${provisionalResult.largestNewRect!.width}×${provisionalResult.largestNewRect!.height}',
        });
      }
    } else if (result['game'] is Map) {
      _applyGame(Map<String, dynamic>.from(result['game'] as Map));
    }
  }

  clearProvisionalTiles() async {
    if (!hasGame()) return;
    if (localState!.provisionalTiles.isEmpty) return;
    localState!.provisionalTiles.clear();
    notifyListeners();
    await channel!.track(localState!.toPresenceJson());
  }

  @override
  void dispose() {
    channel?.dispose();
    super.dispose();
  }
}
