# Tavern Duels — live EQ Dream release

## Players

1. Close EQ and run the EQ Dream launcher’s **Patch / Repair**.
2. Open **SoloAssist** inside your EQ folder, run **Install-Solo-Assist.cmd**, and select your MacroQuest folder. This installs Tavern Duels alongside Solo Assist and preserves your character settings.
3. Start MacroQuest, open EQ Dream, and log into your character.
4. Type **/tavern**. Claim a starter deck in Packs, open your welcome packs and start a practice duel. Host a table and share its code to play another player, or visit the Trading post to exchange cards.

The updated full MacroQuest bundle already includes Tavern Duels. Extract it into a new folder and run MacroQuest from there. Microsoft Edge WebView2 Runtime is required; if missing, install it from [Microsoft](https://developer.microsoft.com/en-us/microsoft-edge/webview2/).

`/tavern` opens/closes the card window; `/tavern close` closes it. If the command is unavailable, use `/lua run eqdream_tavern_live`. The window closes when you leave the character or zone. Closing it does not erase your duel or cards. Use windowed EQ.

Live cards are stored on the server and tied to the EQ character ID. All players use the same service for duels and trading. Test-server and original website collections are separate. Cards are not EQ inventory items and do not alter SSF, loot, AA or currency. Reopening requests a private, short-lived sign-in from the game server. No EQ account password is entered into the card window.

## Maintainers

`eqdream_tavern_live.lua` registers `/tavern`, requests `!tavern` via the existing player speech hook, consumes the private `[Tavern Access]` message and launches the WebView2 host. The native host embeds in the requesting EQ process and permits only the configured live HTTPS origin. Test clients use the separate `eq-test` bridge.

The server-only Perl plugin uses OS randomness, a 60-second ticket and the authenticated character's numeric ID. A root-created ticket directory with the service group gives the dedicated service access. HTTP redemption atomically claims a ticket and issues a secure, HTTP-only, same-site cookie. Session tokens are hashed at rest. The web service ignores client-provided identity headers, validates request origins, limits request size/rate and reuses the original authoritative game rules. All gameplay mutations are serialized, with SQLite transactions for card exchanges.

The service is `eqdream-tavern.service`; shared cards and sessions are in `/var/lib/eqdream-tavern/data/cards.sqlite`. Back up this database with SQLite's backup API, including a tested restore procedure. Short-lived tickets are under `/var/lib/eqdream-tavern/tickets`. Nginx routes `/tavern/` to loopback port 17867 and suppresses access logging on that route so launch tickets do not enter its access log. Other website authentication remains unchanged.

Build from the project directory:

```powershell
node node_modules/vite/bin/vite.js build --config live/vite.config.mjs
node live/build-service.mjs
node live/test.mjs
./live/build-window.ps1
```

The deployment script targets this EQ Dream installation and backs up the touched server files. It installs a separate Node runtime and service; it does not replace the system Node or restart gameplay services. After a quest/plugin change, activate it with a global quest reload or a scheduled zone-server restart.

Release checks cover server-issued tickets, expiry/replay, identity isolation, cross-origin rejection, multiplayer hands, shared trading, persistence, Lua launch arguments and actual HTTPS delivery. The original test window was confirmed working inside EQ by the server owner. Live end-to-end activation must also be checked after the quest reload.
