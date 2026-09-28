export const EMPTY_STATE = Object.freeze({
  score: 0,
  placed_tiles: [],
  pickups: [],
});

export function validRoomName(value) {
  return typeof value === "string" && value.length > 0 && value.length <= 16 &&
    !/[\x00-\x1f\x7f]/.test(value) && value.trim() === value;
}

export function validUsername(value) {
  return typeof value === "string" && value.length > 0 && value.length <= 16 &&
    !/[\x00-\x1f\x7f]/.test(value) && value.trim() === value;
}

export function cleanPresence(value) {
  if (!value || typeof value !== "object") return null;
  const cursor = value.cursor;
  const tiles = value.provisional_tiles;
  if (!Array.isArray(cursor) || cursor.length !== 2 ||
      !cursor.every((n) => Number.isInteger(n) && Math.abs(n) <= 10000) ||
      !Array.isArray(tiles) || tiles.length > 90 || tiles.length % 3 !== 0) {
    return null;
  }
  for (let i = 0; i < tiles.length; i += 3) {
    if (!Number.isInteger(tiles[i]) || !Number.isInteger(tiles[i + 1]) ||
        Math.abs(tiles[i]) > 10000 || Math.abs(tiles[i + 1]) > 10000 ||
        typeof tiles[i + 2] !== "string" || !/^[a-z]$/.test(tiles[i + 2])) {
      return null;
    }
  }
  return { cursor: [...cursor], provisional_tiles: [...tiles] };
}

export function cleanBroadcast(event, payload, sender) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload) ||
      JSON.stringify(payload).length > 4096) return null;
  if (event === "assist") {
    if (!Array.isArray(payload.usernames) || payload.usernames.length > 20 ||
        !payload.usernames.every(validUsername)) return null;
    return { sender, usernames: payload.usernames };
  }
  if (event !== "notification" || !payload.args ||
      typeof payload.args !== "object" || Array.isArray(payload.args)) return null;
  const { notiftype, args } = payload;
  if (notiftype === "word" && typeof args.word === "string" &&
      typeof args.qualifier === "string" && args.word.length <= 100 &&
      args.qualifier.length <= 100) {
    return { sender, notiftype, args: { username: sender, word: args.word, qualifier: args.qualifier } };
  }
  if (notiftype === "enclosed_area" && Number.isSafeInteger(args.area) &&
      args.area > 0 && args.area <= 40000) {
    return { sender, notiftype, args: { username: sender, area: args.area } };
  }
  if (notiftype === "tile_block" && typeof args.dimensions === "string" &&
      args.dimensions.length <= 30) {
    return { sender, notiftype, args: { username: sender, dimensions: args.dimensions } };
  }
  return null;
}

function placedTileMap(value) {
  if (!Array.isArray(value) || value.length > 40000 || value.length % 4 !== 0) return null;
  const tiles = new Map();
  for (let i = 0; i < value.length; i += 4) {
    const [x, y, letter, username] = value.slice(i, i + 4);
    if (!Number.isInteger(x) || !Number.isInteger(y) || Math.abs(x) > 10000 ||
        Math.abs(y) > 10000 || typeof letter !== "string" || !/^[a-z]$/.test(letter) ||
        !validUsername(username)) return null;
    const key = `${x},${y}`;
    if (tiles.has(key)) return null;
    tiles.set(key, { letter, username });
  }
  return tiles;
}

export function validMoveState(previous, next, username) {
  if (!next || typeof next !== "object" || Array.isArray(next) ||
      !Number.isSafeInteger(next.score) || next.score < previous.score ||
      !Array.isArray(next.pickups) || next.pickups.length > 30000 ||
      next.pickups.length % 3 !== 0) return false;
  const before = placedTileMap(previous.placed_tiles);
  const after = placedTileMap(next.placed_tiles);
  if (!before || !after || after.size <= before.size || after.size - before.size > 30) return false;
  for (const [key, tile] of before) {
    const updated = after.get(key);
    if (!updated || updated.letter !== tile.letter || updated.username !== tile.username) return false;
  }
  for (const [key, tile] of after) {
    if (!before.has(key) && tile.username !== username) return false;
  }
  for (let i = 0; i < next.pickups.length; i += 3) {
    const [x, y, type] = next.pickups.slice(i, i + 3);
    if (!Number.isInteger(x) || !Number.isInteger(y) || Math.abs(x) > 10000 ||
        Math.abs(y) > 10000 || type !== "wildcard") return false;
  }
  return JSON.stringify(next).length <= 262144;
}
