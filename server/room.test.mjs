import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

// Replace only the Cloudflare base class so the room logic can run in Node.
const source = (await readFile(new URL("./index.mjs", import.meta.url), "utf8"))
  .replace('import { DurableObject } from "cloudflare:workers";',
    'class DurableObject { constructor(ctx, env) { this.ctx = ctx; this.env = env; } }')
  .replace('from "./protocol.mjs"',
    `from "${new URL("./protocol.mjs", import.meta.url).href}"`);
const { GameRoom } = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`);

class Socket {
  messages = [];
  attachment = null;
  send(value) { this.messages.push(JSON.parse(value)); }
  close() {}
  serializeAttachment(value) { this.attachment = value; }
  deserializeAttachment() { return this.attachment; }
  last(type) { return this.messages.findLast((message) => message.type === type); }
}

function makeRoom() {
  const sockets = [];
  const sql = {
    game: null,
    exec(query, ...args) {
      if (query.trim().startsWith("CREATE TABLE")) return;
      if (query.trim().startsWith("SELECT * FROM game")) {
        return { toArray: () => this.game ? [this.game] : [] };
      }
      if (query.includes("INSERT INTO game")) {
        const [id, channel, state, active, starts_at, ends_at, version] = args;
        this.game = { id, channel, state, active, starts_at, ends_at, version };
        return;
      }
      throw new Error(`Unexpected SQL: ${query}`);
    },
  };
  const ctx = { id: { name: "friends" }, storage: { sql }, getWebSockets: () => sockets };
  return { room: new GameRoom(ctx, {}), sockets, sql };
}

test("two players join, start a game, and reject a conflicting move", async () => {
  const { room, sockets, sql } = makeRoom();
  const alice = new Socket();
  const bob = new Socket();
  sockets.push(alice, bob);
  const presence = { cursor: [0, 0], provisional_tiles: [], rack: ["a"] };

  await room.webSocketMessage(alice, JSON.stringify({ type: "join", username: "Alice", presence }));
  await room.webSocketMessage(bob, JSON.stringify({ type: "join", username: "Bob", presence }));
  assert.equal(alice.last("roster").players.length, 2);
  assert.equal(alice.last("roster").players[0].payload.rack, undefined);
  assert.equal(bob.last("welcome").game, null);

  await room.webSocketMessage(bob, JSON.stringify({ type: "start_game", request_id: 1 }));
  assert.equal(bob.last("result").ok, false);
  await room.webSocketMessage(alice, JSON.stringify({ type: "start_game", request_id: 2 }));
  assert.equal(alice.last("result").ok, true);
  assert.equal(bob.last("game_created").game.channel, "friends");
  const game = alice.last("result").game;
  assert.ok(Date.parse(game.starts_at) - Date.now() <= 3000);
  assert.equal(Date.parse(game.ends_at) - Date.parse(game.starts_at), 240000);

  sql.game.starts_at = new Date(Date.now() - 1000).toISOString();
  await room.webSocketMessage(alice, JSON.stringify({
    type: "commit_move", request_id: 3, version: 0,
    state: { score: 2, placed_tiles: [0, 0, "a", "Alice"], pickups: [] },
  }));
  assert.equal(alice.last("result").ok, true);
  assert.equal(bob.last("game_updated").game.version, 1);
  await room.webSocketMessage(bob, JSON.stringify({
    type: "commit_move", request_id: 4, version: 0,
    state: { score: 2, placed_tiles: [1, 0, "b", "Bob"], pickups: [] },
  }));
  assert.equal(bob.last("result").ok, false);
  assert.equal(bob.last("result").game.version, 1);
});
