'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter.js": "4b2350e14c6650ba82871f60906437ea",
"main.dart.js": "07a46205e8c0f06adb4451b0cb0367b1",
"assets/FontManifest.json": "a0ac142ff779a853c13bd6c3bbc126a2",
"assets/AssetManifest.bin": "c386fb1a92f9ac891c266cabd461e0cf",
"assets/fonts/MaterialIcons-Regular.otf": "dbf79956a67df658d9060664f782241d",
"assets/assets/fonts/Solway-ExtraBold.ttf": "1c26c736cbf72ec6ecd5f3c3a1d6c05a",
"assets/assets/fonts/KatahdinRound-Dekerned.otf": "1b2241d064ecaf4c9440673f62aefe81",
"assets/assets/fonts/Solway-Regular.ttf": "fd707ebcc2f737b63c8b4be9fd9875de",
"assets/assets/fonts/KatahdinRound.otf": "4152971ddc73ca84e84d39cd19297ab9",
"assets/assets/images/tile_outline.png": "2500e1ce002178b94202e4b011a3e82b",
"assets/assets/images/logo_shadow.png": "b9edd009d4900d181941e7801c82c054",
"assets/assets/images/tile_placed_edge.png": "3345cdc9c5f9dcec26aa09595362e19f",
"assets/assets/images/tile_placed_top.png": "13992f3091624bbfb6741c32f08fa356",
"assets/assets/images/cursor.png": "12cd6dd763626fdcc96d3e6f2e784013",
"assets/assets/images/circle.png": "48ce1a443c0a904154ae1b18f1e08c55",
"assets/assets/images/cursor_outside.png": "6d070e60d4465fe5dfbed7f830d69c96",
"assets/assets/images/ghost_arrow.png": "603e187a2ae9b756e2dd90aeed737476",
"assets/assets/images/tile_ghost.png": "1467ac99e15ff9cc45de0b07b5b3cbc2",
"assets/assets/images/areaglow_icorner.png": "c56b529bb088fa27c0bfbaf0ae3ad3b6",
"assets/assets/images/pickup_wildcard.png": "1a23c089b093fdeb2d8a08af6c1b0be0",
"assets/assets/images/pickup_stripes.png": "8595689ac0a79f9711eb39856ccf9fe8",
"assets/assets/images/areaglow_vertical.png": "899d01a323a0f55096cb2a10a6c6729e",
"assets/assets/images/panel.png": "734c61aeb2c8e543d9c6a75ea330e43d",
"assets/assets/images/tile_placed.png": "b520c47335a1975913ddb7721fe152fb",
"assets/assets/images/areaglow_horizontal.png": "2e4a83f29e36aa12e499155304eca057",
"assets/assets/images/ghost.png": "a7d3ce3a452bca1f9537bb808a840dcc",
"assets/assets/images/cursor_arrow.png": "2aba3998f68b7304bbfb84acc86ce7a0",
"assets/assets/images/rack_slot.png": "4b951fa269936aeeccebc980ebfa5e0e",
"assets/assets/images/grid.png": "a91a9e2ee2f5ae16e2998f496b7c6095",
"assets/assets/images/crown.png": "2f4e2a7805371e4d84df82f91532b3aa",
"assets/assets/images/rack.png": "6e71a6739f8eafda0154da26a050770f",
"assets/assets/images/logo.png": "8fa7954970be7f89c5e163f5e54ebbb1",
"assets/assets/images/tile.png": "8b07b865c8932263e0a54936a3fde2c7",
"assets/assets/images/areaglow_corner.png": "7253c6380570f5c1bf51515ad8109b47",
"assets/assets/tips/tip3.mp4": "6dbc2fca74b65f2532cfba058e759ba4",
"assets/assets/tips/tip5.mp4": "549136cdb47483ac1ef101cc1bf8f4dc",
"assets/assets/tips/tip4.mp4": "2db4b98cf734cd2713e9cc26245579c4",
"assets/assets/tips/tip2.mp4": "04965561175a157fe3d4c4aa7166f211",
"assets/assets/tips/tip6.mp4": "991623ec3222cad30a23f99abef3ec16",
"assets/assets/tips/tip8.mp4": "793a4232fb719a64d862ca11d6f788d3",
"assets/assets/tips/tip1.mp4": "f3fda1b41c61c704545f6fd9c152da35",
"assets/assets/tips/tip7.mp4": "d4e6179ff4dc23f9e92033c6ac72b7bd",
"assets/assets/words.txt": "8de718dba94e5453a626b41eceb107ea",
"assets/NOTICES": "c4e04cecdbcc18d98e325fdf0c664563",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.json": "93cdbac65dece22b46b945a8110d9953",
"assets/AssetManifest.bin.json": "979483fb7427df2e651f62e499881696",
"index.html": "578309f76fbc189fed9084b87617f2bf",
"/": "578309f76fbc189fed9084b87617f2bf",
"manifest.json": "0ce05b18913020751b7b3463033ecb8f",
"canvaskit/canvaskit.js": "26eef3024dbc64886b7f48e1b6fb05cf",
"canvaskit/canvaskit.js.symbols": "efc2cd87d1ff6c586b7d4c7083063a40",
"canvaskit/chromium/canvaskit.js": "b7ba6d908089f706772b2007c37e6da4",
"canvaskit/chromium/canvaskit.js.symbols": "e115ddcfad5f5b98a90e389433606502",
"canvaskit/chromium/canvaskit.wasm": "ea5ab288728f7200f398f60089048b48",
"canvaskit/skwasm.js": "ac0f73826b925320a1e9b0d3fd7da61c",
"canvaskit/skwasm.js.symbols": "96263e00e3c9bd9cd878ead867c04f3c",
"canvaskit/canvaskit.wasm": "e7602c687313cfac5f495c5eac2fb324",
"canvaskit/skwasm.wasm": "828c26a0b1cc8eb1adacbdd0c5e8bcfa",
"canvaskit/skwasm.worker.js": "89990e8c92bcb123999aa81f7e203b1c",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"version.json": "bd27517302d1c6c8a20e2c458042b51d",
"flutter_bootstrap.js": "449b708acf1abbd9ba4415045485934e"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
