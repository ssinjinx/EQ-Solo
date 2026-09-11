# Tavern Duels in EQ — local test integration

This prototype keeps the original battlefield, decks, card art, packs and trading screens. `/tavern` opens them in a resizable WebView2 child window inside the **NMS-Local** EQ test client. Close the window with its X, or type `/tavern close` in EQ. Typing `/tavern` again toggles it.

## Setup on the test machine

Requires Windows, Node 24, the pinned pnpm version in package.json, Microsoft Edge WebView2 Runtime, the NMS-Local client and MacroQuest with MQ2Lua. WebView2 SDK files are downloaded from Microsoft's official NuGet package by the build script. No changes to EQ's dinput8.dll are needed.

From the `tavern-duels` directory:

```powershell
pnpm install --frozen-lockfile
node node_modules/vite/bin/vite.js build --config eq-test/vite.config.mjs
./eq-test/build-window.ps1
./eq-test/start-test.ps1
```

The launcher accepts `-NodePath`, `-ClientPath` and `-MacroQuestPath` if needed. It starts a hidden local game service and installs only the new `eqdream_tavern.lua` script. It does not change Solo Assist or MacroQuest startup settings. Start your EQ test server separately, then log into a character using NMS-Local in **windowed mode** and enter:

```text
/lua run eqdream_tavern
/tavern
```

Choose your starter in Packs. Open your welcome packs, select a deck and start a practice duel. The service saves after actions; closing the window does not erase your collection or duel. Zoning or leaving the character closes the window. To stop the bridge, close the window and use `/lua stop eqdream_tavern`.

## Test scope

This is a **single-machine test**, not a public multiplayer deployment. Local characters can test table codes and trades against each other; players on other PCs cannot connect to the loopback service. Profiles are named from the local character and are not authenticated against EQ's account database yet. Test cards have no EQ inventory or currency effects. The website's existing collections are separate.

Data is stored in `.eq-test-state/tavern.sqlite`; browser profiles and logs are also under `.eq-test-state`. Back this directory up to preserve test collections. The local config, database, browser profiles, downloaded SDK and built binaries are ignored by Git. Never deploy this local identity bridge as a public account service. A shared deployment needs server-issued character authentication and an HTTPS service.

The native host checks that the parent process is the configured NMS-Local/eqgame.exe. Its browser accepts only the local service origin. The service uses one-use launch tickets, HTTP-only same-site cookies, request-origin checks and the existing authoritative game rules. It ignores the hosted site's identity headers.

## Checks

```powershell
node eq-test/test.mjs
node --experimental-transform-types tests/game-request.mjs
# Other existing suites: rules, colors, expansion, integration, packs
node --experimental-strip-types tests/integration.mjs
```

The adapter test covers access checks, ticket replay, stale moves and saved state across restart. Inside-EQ rendering and focus still require testing against the actual windowed client; compilation and API tests alone do not establish that compatibility.
