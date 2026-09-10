# EQ Dream Solo Assist — MacroQuest Lua integration

Source snapshot of the three installed Solo Assist scripts, shared for reviewing the existing UI integration and planning a `/bored` card-game prototype. The current addon is Lua, not a compiled MacroQuest plugin. It runs with the official MacroQuest RoF2 emulator build and MQ2Lua on our custom NMS/EQEMU server.

## Files

| File | Responsibility |
| --- | --- |
| `eqdream_control.lua` | Registers `/eqd`, renders the ImGui window, queues Start/Stop actions, and saves options. |
| `eqdream_solo.lua` | Runs stationary combat, pulling, pet assist, resting, optional healing/lifetaps and snaring. Registers `/eqdstop`. |
| `eqdream_settings.lua` | Normalizes settings, saves per-server/per-character configuration, and checks script status. |

## Install and run

Copy all three files into MacroQuest's `lua` directory. Start the RoF2 MacroQuest build before EverQuest, log into a character, and run:

```text
/lua run eqdream_control
/eqd
```

Optionally add `/lua run eqdream_control quiet` to `config/ingame.cfg`, preserving existing commands. This loads the controls at login; it does not start combat. Stop the assist before editing settings. `/eqd start` starts at the current position; `/eqd stop` or `/eqdstop` stops it. Closing the menu does not stop combat.

## Implemented features

- Distant Strike, spell-gem pulling, or defend-only mode. Spell-gem pulling replaced an earlier hotbar-button approach.
- Optional self-targeted healing or a single-target lifetap against an existing attacker; selected gem, HP threshold and retry interval.
- Optional snare with its own gem and retry interval. It checks visible target snare information and pauses retries after three unconfirmed attempts.
- Mana, cooldown, range and line-of-sight checks where applicable. Spell casts are serialized; healing has priority before a new snare.
- Existing pet assist and emergency Mend. Fresh pulls exclude named mobs and pets.
- Stops on death, zoning, changed character/server, moving away from camp, or timeouts. No roaming, resurrection, automatic login or full caster rotation.

These scripts use custom-server mechanics for multiclass combat. They are not a general-purpose configuration for every EverQuest server. NMS handles loot through its separate `/nmsloot` interface; these Lua files do not implement the NMS loot window or modify item ownership rules.

## Integration pattern for a card-game prototype

The control script demonstrates `require('mq')`, `require('ImGui')`, `mq.bind`, and `mq.imgui.init`. It keeps a visibility flag, draws buttons/checkboxes/dropdowns/sliders, and hands actions back to a main loop. Keep blocking work and `mq.delay` out of the ImGui draw callback. Reuse the pattern in a separate script with its own window identifier and `/bored` binding so opening a card game does not start or stop Solo Assist.

Current code proves basic in-game ImGui controls. It does **not** demonstrate card artwork loading, animated battlefields, browser embedding, networking, authentication, or a card-game service. Check those capabilities against the installed RoF2 build before choosing an Arena-style implementation. Card ownership, match outcomes and trades would need an authoritative service; local INI settings are only appropriate for UI preferences, not authoritative ownership.

## Verification and known limitation

Lua engine tests using mocked MacroQuest covered pulling retries, mana/cooldown/type/range checks, healing target handling, snare retry limits, cast serialization, stop/death/zoning, and settings. Menu callbacks were exercised with mocked ImGui. These tests are not a full in-game simulation.

The user reported a session where `/eqd` Start stopped responding to clicks and the NMS loot window would not open, while `/eqd start` still worked and NMS sales continued. Reloading the overlay did not recover it. Fully restarting EverQuest and MacroQuest restored both windows. The root cause has not been established; do not describe it as a proven script or DLL fix.

No account credentials, character settings, loot rules, game assets, server configuration or compiled client binaries are included in this handoff.
