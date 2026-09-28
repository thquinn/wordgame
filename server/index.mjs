import { DurableObject } from "cloudflare:workers";
import { EMPTY_STATE, cleanBroadcast, cleanPresence, validMoveState, validRoomName, validUsername } from "./protocol.mjs";

const START_DELAY_MS = 3000;
const GAME_DURATION_MS = 4 * 60 * 1000;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/health") return new Response("ok");
    const room = url.searchParams.get("room")?.toLowerCase();
    if (url.pathname !== "/room" || !validRoomName(room)) {
      return new Response("Invalid room", { status: 400 });
    }
    if (request.method !== "GET" || request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("WebSocket required", { status: 426 });
    }
    return env.ROOMS.getByName(room).fetch(request);
  },
};

export class GameRoom extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS game (
        slot INTEGER PRIMARY KEY CHECK (slot = 1),
        id INTEGER NOT NULL,
        channel TEXT NOT NULL,
        state TEXT NOT NULL,
        active INTEGER NOT NULL,
        starts_at TEXT NOT NULL,
        ends_at TEXT NOT NULL,
        version INTEGER NOT NULL
      )
    `);
  }

  async fetch(request) {
    const room = new URL(request.url).searchParams.get("room")?.toLowerCase();
    if (!validRoomName(room)) return new Response("Invalid room", { status: 400 });
    if (room !== this.ctx.id.name) return new Response("Wrong room", { status: 400 });
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.ctx.acceptWebSocket(server);
    return new Response(null, { status: 101, webSocket: client });
  }

  currentGame() {
    const row = this.ctx.storage.sql.exec("SELECT * FROM game WHERE slot = 1").toArray()[0];
    if (!row) return null;
    return {
      id: row.id,
      channel: row.channel,
      state: JSON.parse(row.state),
      active: row.active === 1,
      starts_at: row.starts_at,
      ends_at: row.ends_at,
      version: row.version,
    };
  }

  saveGame(game) {
    this.ctx.storage.sql.exec(`
      INSERT INTO game (slot, id, channel, state, active, starts_at, ends_at, version)
      VALUES (1, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(slot) DO UPDATE SET
        id = excluded.id, channel = excluded.channel, state = excluded.state,
        active = excluded.active, starts_at = excluded.starts_at,
        ends_at = excluded.ends_at, version = excluded.version
    `, game.id, game.channel, JSON.stringify(game.state), game.active ? 1 : 0,
    game.starts_at, game.ends_at, game.version);
  }

  sessions() {
    return this.ctx.getWebSockets().map((ws) => ({ ws, data: ws.deserializeAttachment() }))
      .filter(({ data }) => data?.session_id);
  }

  admin() {
    const sessions = this.sessions().sort((a, b) =>
      a.data.joined_at - b.data.joined_at || a.data.session_id.localeCompare(b.data.session_id));
    return sessions[0]?.data ?? null;
  }

  players() {
    return this.sessions().map(({ data }) => ({
      session_id: data.session_id,
      payload: {
        username: data.username,
        join_time: data.join_time,
        cursor: data.cursor,
        provisional_tiles: data.provisional_tiles,
      },
    }));
  }

  send(ws, value) {
    ws.send(JSON.stringify(value));
  }

  sendOthers(sender, value) {
    const message = JSON.stringify(value);
    for (const { ws } of this.sessions()) {
      if (ws !== sender) ws.send(message);
    }
  }

  sendRoster() {
    const message = JSON.stringify({ type: "roster", players: this.players(), admin_id: this.admin()?.session_id });
    for (const { ws } of this.sessions()) ws.send(message);
  }

  reply(ws, requestId, ok, game = null, reason = null) {
    this.send(ws, { type: "result", request_id: requestId, ok, game, reason });
  }

  async webSocketMessage(ws, raw) {
    let message;
    try {
      if (typeof raw !== "string" || raw.length > 300000) throw new Error("Invalid message");
      message = JSON.parse(raw);
    } catch (_) {
      ws.close(1003, "Invalid message");
      return;
    }
    if (!message || typeof message !== "object") return;

    let session = ws.deserializeAttachment();
    if (message.type === "join") {
      if (session?.session_id) return;
      const presence = cleanPresence(message.presence);
      if (!validUsername(message.username) || !presence) {
        ws.close(1008, "Invalid player");
        return;
      }
      const now = Date.now();
      session = {
        session_id: crypto.randomUUID(), username: message.username,
        join_time: new Date(now).toISOString(), joined_at: now,
        ...presence,
      };
      ws.serializeAttachment(session);
      this.send(ws, {
        type: "welcome", session_id: session.session_id, join_time: session.join_time,
        game: this.currentGame(), players: this.players(), admin_id: this.admin()?.session_id,
      });
      this.sendRoster();
      return;
    }
    if (!session?.session_id) {
      ws.close(1008, "Join required");
      return;
    }

    if (message.type === "presence") {
      const presence = cleanPresence(message.presence);
      if (!presence) return;
      session = { ...session, ...presence };
      ws.serializeAttachment(session);
      this.sendOthers(ws, {
        type: "player_updated", session_id: session.session_id,
        payload: {
          username: session.username, join_time: session.join_time,
          cursor: session.cursor, provisional_tiles: session.provisional_tiles,
        },
      });
      return;
    }

    if (message.type === "broadcast") {
      const payload = cleanBroadcast(message.event, message.payload, session.username);
      if (!payload) return;
      this.sendOthers(ws, {
        type: "broadcast", event: message.event,
        payload,
      });
      return;
    }

    if (message.type === "start_game") {
      const current = this.currentGame();
      if (this.admin()?.session_id !== session.session_id) {
        this.reply(ws, message.request_id, false, current, "Only the room admin can start a game");
        return;
      }
      if (current?.active && Date.parse(current.ends_at) > Date.now()) {
        this.reply(ws, message.request_id, false, current, "Game is still active");
        return;
      }
      const starts = Date.now() + START_DELAY_MS;
      const game = {
        id: (current?.id ?? 0) + 1, channel: this.ctx.id.name,
        state: { ...EMPTY_STATE, placed_tiles: [], pickups: [] }, active: true,
        starts_at: new Date(starts).toISOString(),
        ends_at: new Date(starts + GAME_DURATION_MS).toISOString(), version: 0,
      };
      this.saveGame(game);
      this.reply(ws, message.request_id, true, game);
      this.sendOthers(ws, { type: "game_created", game });
      return;
    }

    if (message.type === "commit_move") {
      const current = this.currentGame();
      if (!current || !current.active || Date.now() < Date.parse(current.starts_at) ||
          Date.now() >= Date.parse(current.ends_at)) {
        this.reply(ws, message.request_id, false, current, "Game is not active");
        return;
      }
      if (!Number.isInteger(message.version) || message.version !== current.version) {
        this.reply(ws, message.request_id, false, current, "Board changed before your move");
        return;
      }
      if (!validMoveState(current.state, message.state, session.username)) {
        this.reply(ws, message.request_id, false, current, "Invalid move state");
        return;
      }
      const updated = { ...current, state: message.state, version: current.version + 1 };
      this.saveGame(updated);
      this.reply(ws, message.request_id, true, updated);
      this.sendOthers(ws, { type: "game_updated", game: updated });
    }
  }

  async webSocketClose(ws) {
    ws.serializeAttachment(null);
    this.sendRoster();
  }

  async webSocketError(ws) {
    ws.serializeAttachment(null);
    this.sendRoster();
  }
}
