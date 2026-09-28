# Grouptext

A cooperative word game built with Flutter web. Each room runs in a Cloudflare
Durable Object. The browser keeps the rack and rendering logic; the room stores
the confirmed board and relays live cursors, provisional tiles, and notifications.

## Run locally

Install Node.js and Flutter, then in this directory run:

```powershell
npm ci
npm run dev
```

In a second terminal, run `flutter run -d chrome`. The browser connects to the
local Worker at `ws://127.0.0.1:8787` by default. Room names are shared by
everyone entering the same name. Games begin after 3 seconds and last 4 minutes.

## Deploy

1. Set `CLOUDFLARE_API_TOKEN` and, if you use more than one Cloudflare account,
   `CLOUDFLARE_ACCOUNT_ID` in your own terminal environment. Do not put tokens
   in this repository or in a browser build.
2. Run `npm ci` and `npm run deploy`. Wrangler prints the Worker URL. Check
   `<Worker URL>/health`; it should return `ok`.
3. The GitHub Pages workflow builds the Flutter app with the deployed Worker URL
   `https://wordgame-rooms.caeonospam.workers.dev`. Push the changes to `main`
   to publish the new browser version.

For a manual web build, run:

```powershell
flutter build web --dart-define=ROOM_SERVER_URL=https://wordgame-rooms.example.workers.dev
```

The browser converts `https` to `wss` for its WebSocket connection. The Worker
and the site can use separate domains. This deployment starts with empty rooms;
old Supabase games are not imported.

## Server checks

Run `npm run test:server` to validate the room protocol's input checks.
