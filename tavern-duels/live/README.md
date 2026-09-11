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

### First-kill packs (September 11, 2026)

Each character earns **1 standard pack for the first credited kill of each named NPC**, or **5 packs for each raid boss**. Raid rewards replace the named reward. Repeat kills of the same NPC type, including another instance, do not grant more packs. Tracking begins with this release; earlier kills are not backfilled. Open `/tavern` and visit Packs after the reward message. No new player patch is required.

The global `EVENT_KILLED_MERIT` hook calls `EQDreamTavernRewards::killed_merit($client,$npc)` after existing Slayer credit. It uses the game's credited group/raid/self selection and `EQDreamRelease::role($npc,1)` to reuse encounter classification after death. The optional second argument only bypasses the positive-HP test; pets, charmed mobs, summons and noncombat classes remain excluded. Existing encounter calls keep their original behavior. Local boss quest handlers still execute alongside the global handler.

Install `EQDreamTavernRewards.pm` in the quest plugin directory and apply `rewards-integration.patch` to the existing live files. The live service configuration gains `rewards: /var/lib/eqdream-tavern/rewards`. Create that directory and its `pending` and `receipts` children as root, with group `eqdream-tavern` and mode `2770`. Rebuild the service, restart only the card service, then reload quests globally.

The trusted filesystem outbox publishes complete, synced events without replacing an existing event. The service processes up to 128 events every two seconds. A SQLite transaction inserts the unique `(character_id,npc_type_id)` ledger row and all reward packs together. Retries after service interruption or a crash cannot grant extra packs. Receipt files suppress repeat notifications; the database ledger is the authority. Rewards do not consume welcome packs. There is no public reward-grant API. Back up `cards.sqlite` **and the rewards directory** together; preserve pending events during recovery.

Checks: `node live/rewards-test.mjs`, `node live/test.mjs`, and `REWARD_PLUGIN_PATH=<staged plugin directory> perl live/rewards-test.pl` with the server's quest plugin dependencies on `PERL5LIB`. Live delivery and replay were verified using a reserved synthetic ID, then its test records were removed. Actual combat credit uses the existing EQ engine hook.

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
