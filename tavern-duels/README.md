# EQ Dream: Tavern Duels — Steel & Shadow

A server-authoritative, EQ-themed web card duel, built for later adaptation to MacroQuest RoF2.

## Rules implemented
- 40-card decks, 20 life, seven-card opening hands, first player skips first draw.
- One basic land per turn; Light/Shadow and generic costs; manual tapping and automatic payment; untapping; mana clears on phase changes.
- Main phase, attacker declaration, response window, blocker declaration, response window, simultaneous combat damage, second main and end step.
- Multi-blocking, attacker-controlled damage ordering, summoning sickness, tapping, vigilance, first strike, flying, trample, deathtouch and lifelink.
- Priority and last-in-first-out stack; two passes resolve one spell or advance an empty-stack phase. Counterspells and invalid-target fizzling.
- Creatures, instants, sorceries, enchantments and equipment. Equipment has a two-mana equip ability on the stack.
- Damage clears at cleanup; drawing an empty library loses. Hands above seven automatically discard rightmost cards at cleanup.
- AI respects priority and gives the player opportunities to respond and block.

## Persistence and compatibility
D1 stores collections, 40-card decks, practice matches, invite-code player matches and one-for-one trading. Basic lands are unlimited and non-tradable. Catalog upgrade grants new card types while keeping existing inventory ownership. Incompatible unfinished version-one duels are cleared once; saved decks start from the new 40-card starter lists. Existing account authentication retains dispatcher user-ID support plus the authenticated-email fallback.

`lib/game.ts` is framework-independent authoritative rules code. `app/api/game/route.ts` validates identity, ownership and actions. `app/page.tsx` is the React presentation, with land rows, illustrated card frames, a stack, blocker assignment lines and damage ordering. `public/card-art.png` is an original six-panel generated art atlas.

## Verification
`node --experimental-strip-types tests/rules.mjs` runs ten focused rules cases and twenty complete duels, including colored-mana rejection, land limits, countering, first strike, trample and multiple blockers, removed blockers, flying restrictions, summoning sickness, equipment and empty-library loss. TypeScript and production build are checked. Browser and live multi-user end-to-end validation remain outstanding.

## Scope
Original focused ruleset, not full MTG Arena parity. No mulligans, upkeep-trigger system, planeswalkers, exhaustive Magic interactions, card packs, rankings, payments or EQ account linking. `/bored` and the MacroQuest presentation adapter remain future work. All spell casting currently yields priority to the opponent automatically; holding priority is not exposed. The initial hosting audience is private.


## Expansion update
Twelve additional cards (32 total) introduce haste, entry healing, temporary toughness, tap-and-draw, enchantment/equipment destruction, creature destruction and graveyard recovery. Expansion deck presets complement the original decks. The update grants new copies without resetting saved decks, unfinished duels or prior trades.

AI scores combat results using only public board state, considers multiple blockers, avoids losing attacks, blocks lethal threats, prioritizes useful removal, and times combat tricks after blockers. Visual feedback now includes life deltas, creature hit flashes and death transitions; reduced-motion settings are respected. Mobile phase controls stay visible.

`lib/game-service.ts` is the actual server service, injected with the D1 binding in production. Integration tests exercise that service against isolated SQLite with a D1-shaped adapter: two-player joining and authorization, hand/library redaction, priority, stale-version rejection, table closure, inventory preservation, trade ownership, atomic rollback, replay rejection and concurrent acceptance. Reads no longer increment profile versions. Live two-device browser playtesting remains outstanding; no test accounts or test inventory were created in production.

## Packs and rarity
Every card now has a fixed rarity and an EQ monogram: white Common, metallic silver Uncommon, gold Rare, or platinum/prismatic Mythical Rare. The expanded set has 86 cards across five mana colors. Basic lands are common and excluded from booster pools.

Each account receives one welcome grant of 10 identical packs and a once-only choice of Warrior, Necromancer, Druid, Enchanter or Wizard basic starter deck (40 cards: 16 unlimited lands, 24 common/uncommon spells). New accounts no longer receive every card. Existing collections, saved decks and ongoing duels are retained. Each newly opened pack adds 10 tradable card instances: 7 common, 2 uncommon and 1 rare, with an exact 1-in-50 chance for the rare slot to become mythical. All wrappers are identical; rarity applies only to cards. Previously sealed packs use this same rule regardless of their legacy tier; already-opened receipts and owned cards are preserved. Duplicates are retained. No purchases or payments are implemented.

`lib/packs.ts` uses server-side crypto randomness, durable per-account grants and transactional pack opening. The same pack ID always returns the same saved contents after opening. Concurrent openings cannot grant multiple copies, and failed batches roll back both consumption and awards. Pack history lets users recover any interrupted reveal. The reveal UI uses the installed Dialog primitive, supports keyboard activation/reveal-all and reduced motion, and shows prismatic effects on mythical cards.

Validation: `tests/packs.mjs` covers welcome grant conservation, starter eligibility, all bonus probability boundaries, cross-account rejection, rollback, concurrent opening and claims, repeat requests, sealed-content redaction, full 10-pack exhaustion and history. `tests/integration.mjs` remains the two-account duel/trade regression suite. New schema is append-only migration `0001_glamorous_tattoo.sql`.

## Five Realms
White/W: protection and soldiers; Black/B: undeath and drain; Green/G: nature and growth; Blue/U: knowledge and control; Red/R: fire and haste. Each has a free basic land, a 40-card starter template, and cards at all four rarities. The once-only starter grant remains once-only; existing collections and duels are not reset. Mix owned cards of any colors in a deck. Mana symbols enforce exact colored requirements; numbers accept any color. Old W/B-only mana pools remain readable and playable.

Five named uncommons: Drelzna, D’Vinn, Grizzleknot, Najena, Fippy Darkpaw. Ten raid cards: The Avatar of War, Lord Mithaniel Marr, Venril Sathir, Innoruuk, Wuoshi, Tunare, Phinigel Autropos, Lady Vox, Lord Nagafen, Fennin Ro. Card abilities/costs and stylized artwork are fan-game adaptations, not reproductions of encounter mechanics. Additional generic spells and creatures remain in all rarity pools.

Tests: tests/colors.mjs covers matching/generic/double-color payment, legacy mana pools, five starters, named/raid rarity, blue draw, and AI casting. tests/packs.mjs additionally checks all starter grants and mixed-color owned decks through the actual service.
