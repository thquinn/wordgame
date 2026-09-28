import assert from "node:assert/strict";
import test from "node:test";
import { cleanBroadcast, cleanPresence, validMoveState, validRoomName, validUsername } from "./protocol.mjs";

test("room and player names are bounded and printable", () => {
  assert.equal(validRoomName("friends"), true);
  assert.equal(validUsername("Alice"), true);
  for (const value of ["", " ", "a".repeat(17), "a\nb"]) {
    assert.equal(validRoomName(value), false);
    assert.equal(validUsername(value), false);
  }
});

test("presence retains only visible cursor and provisional tiles", () => {
  assert.deepEqual(cleanPresence({
    cursor: [2, 3], provisional_tiles: [2, 3, "a"], rack: ["z"],
  }), { cursor: [2, 3], provisional_tiles: [2, 3, "a"] });
  assert.equal(cleanPresence({ cursor: [2], provisional_tiles: [] }), null);
  assert.equal(cleanPresence({ cursor: [0, 0], provisional_tiles: [0, 0, "*"] }), null);
});

test("broadcasts are shaped before reaching another player's browser", () => {
  assert.deepEqual(cleanBroadcast("assist", { usernames: ["Bob"], sender: "Eve" }, "Alice"),
    { sender: "Alice", usernames: ["Bob"] });
  assert.equal(cleanBroadcast("assist", { usernames: "Bob" }, "Alice"), null);
  assert.deepEqual(cleanBroadcast("notification", {
    notiftype: "enclosed_area", args: { username: "Eve", area: 4 },
  }, "Alice"), {
    sender: "Alice", notiftype: "enclosed_area", args: { username: "Alice", area: 4 },
  });
});

test("a move can add tiles while keeping the confirmed board intact", () => {
  const before = {
    score: 2, placed_tiles: [0, 0, "a", "Alice"], pickups: [],
  };
  const next = {
    score: 4, placed_tiles: [0, 0, "a", "Alice", 1, 0, "t", "Bob"], pickups: [],
  };
  assert.equal(validMoveState(before, next, "Bob"), true);
  assert.equal(validMoveState(before, { ...next, score: 1 }, "Bob"), false);
  assert.equal(validMoveState(before, { ...next, placed_tiles: [1, 0, "t", "Bob"] }, "Bob"), false);
  assert.equal(validMoveState(before, { ...next, placed_tiles: [0, 0, "x", "Alice", 1, 0, "t", "Bob"] }, "Bob"), false);
  assert.equal(validMoveState(before, { ...next, placed_tiles: [0, 0, "a", "Alice", 1, 0, "t", "Eve"] }, "Bob"), false);
});
