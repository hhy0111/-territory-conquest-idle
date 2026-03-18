# Territory Conquest Idle Agent Control Document

## 1. Game Overview

**Project Name:** Territory Conquest Idle

**Genre:** 2D mobile idle roguelite territory expansion game

**Default Platform:** Android first, iOS second

**Default Engine:** Godot 4.3 stable

**Default Language:** GDScript

**Default Orientation:** Portrait, 1080x1920 reference resolution

**Camera:** Fixed top-down orthographic camera over a tile map board

**Session Target:** 5 to 10 minutes per run

**Core Promise:** Each run is a fast territory push where the player expands across a procedural board, chooses the next tile, auto-resolves combat, accepts risk for stronger rewards, dies, converts progress into permanent upgrades, and starts again stronger.

**Production Constraints**

- Offline-first single-player game loop
- 60 FPS target on mid-range mobile devices
- Deterministic run generation from a stored seed
- Data-driven balance through JSON content files
- Touch-first UI with one-thumb reach for core actions
- MVP must run with placeholder art and mocked ad services

**Default Development Standard**

- Build the game as a vertical slice first, then widen content
- Keep all systems deterministic where possible
- Separate pure simulation logic from rendering logic
- Store balance values in data files, not hardcoded scene scripts
- Do not add external dependencies unless a built-in Godot feature is insufficient

## 2. Core Gameplay Loop

1. Load persistent profile and meta upgrades.
2. Generate a run seed and initialize the starting map around a safe central tile.
3. Reveal adjacent tiles and allow the player to select one reachable tile.
4. Resolve the selected tile:
   - enter combat tile
   - trigger event tile
   - receive resource tile reward
   - activate special tile effect
5. Award territory capture progress, run resources, XP, and upgrade choices.
6. Increase danger based on tile difficulty and greedy decisions.
7. Trigger milestone bosses at fixed territory thresholds.
8. End the run on player death or final boss defeat.
9. Convert run results into permanent currencies.
10. Spend permanent currencies in the meta layer.
11. Start a new run with new seed, new choices, and stronger base account state.

**Run Pacing Targets**

- Decision cadence: one meaningful input every 3 to 8 seconds
- Combat duration per normal tile: 4 to 12 seconds
- Upgrade choice frequency: every 3 player levels or every 5 captured tiles
- Boss cadence: every 12 captured tiles
- Run failure window: commonly between 6 and 9 minutes

## 3. Player Experience Goals

- Deliver constant forward motion with minimal downtime.
- Make tile choice feel strategic even though combat is automatic.
- Show visible build growth every minute through stats, relics, or tile control bonuses.
- Create tension through a rising danger meter and greedy reward decisions.
- Make death feel productive because permanent progression is always earned.
- Support replayability through seeded layouts, different upgrade synergies, and boss variety.
- Keep all major outcomes readable from a small mobile screen without zooming.

## 4. System Architecture

### Map System

**Purpose**

Generate, reveal, and track a procedural territory board for each run.

**Default Design**

- Use a logical grid, not a freeform world map.
- Visible play board: 7 columns x 9 rows.
- Starting tile is always the center tile at `(0, 0)`.
- Only orthogonal movement is allowed.
- A tile becomes selectable only if:
  - it is revealed
  - it is not yet captured
  - it is orthogonally adjacent to a captured tile

**Generation Rules**

- Generate tiles by ring distance from the center.
- Store a single `run_seed`.
- Use separate RNG streams for map generation, combat rolls, event choices, and reward rolls.
- Guarantee one safe path to each boss milestone.
- Apply spawn weights by run phase:
  - early phase favors low-risk resource and combat tiles
  - mid phase increases event, elite, and market tiles
  - late phase increases corrupted, vault, and fortress tiles

**State Requirements**

- Tile coordinate
- Tile type
- Tile state: hidden, revealed, selectable, captured, locked, boss
- Threat rating
- Reward rating
- Occupant definition
- Event definition reference
- Ring index

### Tile System

**Purpose**

Define tile behavior, rewards, risks, and interaction rules.

**Default Design**

- All tile definitions live in `data/tiles.json`.
- Tile behavior is resolved by a `TileResolver` service.
- Each tile has:
  - `id`
  - `type`
  - `spawn_weight`
  - `min_ring`
  - `max_ring`
  - `base_threat`
  - `base_reward`
  - `risk_delta`
  - `resolver_mode`
  - `enemy_pool`
  - `event_pool`

**System Rules**

- Tile definitions are data-driven.
- Tile selection must never soft-lock the board.
- At least one new reachable tile must be revealed after each captured tile unless the run is at a boss gate.
- Special tiles must show risk and reward preview before selection.

### Combat System

**Purpose**

Resolve auto-battle encounters based on player stats, enemy stats, and temporary modifiers.

**Default Design**

- Combat runs on a fixed simulation tick of `0.1` seconds.
- Player attacks automatically using range and attack interval stats.
- Enemies follow simple AI states: approach, attack, cooldown, dead.
- Combat takes place in a contained arena scene that reuses tile theme art.
- Encounters are deterministic from combat RNG seed and state snapshot.

**System Rules**

- Combat logic must be separate from VFX and animation.
- Damage calculation must be pure and testable.
- Encounter results must output:
  - victory or defeat
  - remaining HP
  - total damage dealt
  - total damage taken
  - rewards earned
  - on-kill triggers

### Event System

**Purpose**

Provide short, high-impact risk/reward decisions between combats.

**Default Design**

- Events are card-based with 2 choices.
- Each choice applies immediate reward and persistent run modifier.
- Event pool is phase-aware and danger-aware.
- The event UI must always show:
  - immediate gain
  - immediate cost
  - long-term modifier
  - danger increase

**System Rules**

- No event may generate an unwinnable state by itself.
- High-value event choices must increase danger or add a curse.
- Event outcomes are deterministic once the player commits.

### Progression System

**Purpose**

Handle both run progression and permanent account growth.

**Default Design**

- Run progression:
  - XP levels
  - choice-based relics
  - temporary stat modifiers
  - boss rewards
- Meta progression:
  - permanent passive upgrades
  - start-of-run unlocks
  - new tile and event pool unlocks

**Persistence Rules**

- Save persistent progression after every meta purchase and completed run.
- Save active run snapshot on app background.
- On resume, restore run state if the run is less than 30 minutes old.
- Use versioned save data with migration support.

## 5. Game Mechanics (FULL DETAIL)

### Tile Types

| Tile Type | Default Behavior | Reward Profile | Risk Profile | Spawn Notes |
| --- | --- | --- | --- | --- |
| Plains | Standard low-threat combat | low gold, low XP | low danger | common in rings 1 to 3 |
| Forest | Combat with faster enemies | medium XP, attack speed relic chance | low-medium danger | common in rings 1 to 5 |
| Mine | Short combat or guarded cache | high gold | medium danger | common in rings 2 to 6 |
| Shrine | Event tile with blessing or curse choice | strong temporary buff | medium-high danger | common in rings 2 to 7 |
| Fortress | Elite combat tile | relic chest, high XP | high danger | common in rings 3 to 8 |
| Market | Non-combat utility tile | healing, reroll, cleanse | low danger, resource cost | common in rings 2 to 8 |
| Swamp | Combat with slow and poison effects | medium XP, corruption resist options | high danger | common in rings 4 to 8 |
| Vault | High-threat elite or trap event | high relic value, rare currency | high danger | rare in rings 4 to 9 |
| Portal | Teleport to another revealed frontier and reveal 2 hidden tiles | tempo and map control | medium danger spike | rare in rings 3 to 8 |
| Boss Gate | Milestone boss encounter | guaranteed sigil and relic | very high danger | fixed every 12 captures |
| Hidden Fog | Non-selectable unrevealed tile state | none | none | visual state, not generated as active content |

**Tile Resolution Rules**

- Normal combat tiles spawn 1 to 3 enemy waves.
- Elite tiles spawn one elite group with +35 percent HP and +20 percent attack.
- Shrine, Vault, and Portal tiles always show projected danger increase before confirmation.
- Market tiles never appear directly adjacent to a boss gate.
- Boss gates replace a normal tile at fixed territory thresholds: 12, 24, 36, 48, 60 captures.

### Combat Formulas

**Core Stats**

- `max_hp`
- `attack`
- `attack_speed`
- `armor`
- `crit_rate`
- `crit_damage`
- `evade`
- `lifesteal`
- `range`
- `move_speed`
- `luck`
- `territory_power`
- `corruption_resist`

**Base Formula Rules**

- `attack_interval = max(0.25, 1.0 / attack_speed)`
- `crit_multiplier = 1.5 + crit_damage`
- `armor_multiplier = 100.0 / (100.0 + max(-50, armor))`
- `damage_before_armor = attack * skill_multiplier`
- `critical_damage = damage_before_armor * (crit_multiplier if is_crit else 1.0)`
- `final_damage = max(1, floor(critical_damage * armor_multiplier * random_variance))`
- `random_variance` range: `0.95` to `1.05`
- `evade` hard cap: `0.35`
- `lifesteal_heal = floor(damage_dealt * lifesteal)`
- `regen_per_tick = floor(max_hp * hp_regen_percent * tick_delta)`

**Threat Scaling**

- `enemy_hp = base_hp * (1 + 0.18 * phase_index + 0.06 * danger_tier)`
- `enemy_attack = base_attack * (1 + 0.16 * phase_index + 0.07 * danger_tier)`
- `enemy_attack_speed = base_attack_speed * (1 + 0.05 * phase_index)`

**Player Territory Bonus**

- For every 5 captured tiles: `+2 percent attack`, `+2 percent max_hp`
- For every boss defeated: `+5 percent territory_power`
- `territory_power` converts to final damage with `1 + territory_power`

### Stat System

| Stat | Description | Default Start | Hard Rule |
| --- | --- | --- | --- |
| Max HP | Total survivability | 100 | can never drop below 1 |
| Attack | Base hit damage | 12 | additive from upgrades |
| Attack Speed | Attacks per second | 1.0 | minimum interval 0.25 seconds |
| Armor | Reduces incoming damage | 5 | effective floor -50 |
| Crit Rate | Chance to crit | 0.05 | cap 0.6 |
| Crit Damage | Bonus crit multiplier | 0.5 | additive |
| Evade | Chance to dodge hit | 0.02 | cap 0.35 |
| Lifesteal | Heal from damage dealt | 0.00 | cap 0.25 |
| Range | Attack reach in arena units | 1.2 | melee if less than 1.6 |
| Move Speed | Chase and kite speed | 80 | used in combat only |
| Luck | Improves rare reward odds | 0 | affects reward tables only |
| Territory Power | Bonus from captured map control | 0 | applied as final multiplier |
| Corruption Resist | Reduces danger penalties | 0 | reduces incoming danger gain by percent |

### Damage Model

**Resolution Order**

1. Check evade.
2. Roll crit.
3. Apply skill multiplier.
4. Apply territory power multiplier.
5. Apply attack buffs and debuffs.
6. Apply armor mitigation.
7. Apply final variance.
8. Apply on-hit effects.
9. Apply lifesteal and kill triggers.

**Status Effects**

- `Bleed`: damage over time for 3 seconds, stacks 3 times
- `Burn`: damage over time for 4 seconds, ignores 25 percent armor
- `Weaken`: target deals 15 percent less damage for 3 seconds
- `Fortify`: unit gains 20 armor for 3 seconds
- `Haste`: unit gains 20 percent attack speed for 3 seconds

**Default Damage Types**

- Physical: affected by armor
- Magic: ignores 50 percent armor
- True: ignores armor and evade, used rarely by bosses only

### Risk/Reward Logic

**Danger Meter**

- Run-wide value from `0` to `100`
- Starts at `0`
- Normal combat tile: `+2`
- Elite tile: `+6`
- Shrine greedy choice: `+8`
- Vault: `+10`
- Boss victory: `+4`
- Market cleanse: `-6`
- Corruption resist reduces incoming danger by its percentage value

**Danger Tiers**

- `0 to 19`: calm, no extra modifiers
- `20 to 39`: enemies gain `+8 percent HP`, rewards gain `+10 percent`
- `40 to 59`: enemies gain `+16 percent HP`, `+10 percent attack`, rewards gain `+22 percent`
- `60 to 79`: enemies gain `+28 percent HP`, `+18 percent attack`, event curse rate doubles, rewards gain `+38 percent`
- `80 to 100`: enemies gain `+45 percent HP`, `+30 percent attack`, elite chance doubles, rewards gain `+60 percent`

**Reward Multipliers**

- `gold_reward = base_gold * (1 + danger_reward_bonus + luck_bonus)`
- `xp_reward = base_xp * (1 + phase_bonus * 0.2)`
- `essence_reward = floor((captured_tiles * 4 + bosses_killed * 25 + run_minutes * 3) * completion_bonus)`
- `completion_bonus = 1.25` on final boss victory, otherwise `1.0`

**Greed Rule**

- At every Shrine, Vault, and some Event tiles, one choice must be higher power and higher danger.
- High-value choices must either:
  - raise danger
  - apply a curse
  - reduce current HP
  - lock one future upgrade reroll

## 6. Replayability Design

### Randomness System

- Every run stores one 64-bit seed.
- Use four deterministic RNG channels:
  - `map_rng`
  - `combat_rng`
  - `event_rng`
  - `reward_rng`
- Rerolls consume the next value from the correct RNG stream; they do not regenerate the stream.
- Tile generation uses weighted pools with ring restrictions.
- Boss order is fixed for the main path in MVP and can randomize after the first full clear in expansion content.
- Add a pity rule:
  - if the player has not seen a Market tile in 6 captures, force one in the next 3 revealed tiles
  - if the player has not seen a relic choice in 2 boss milestones, guarantee one at the next boss

### Build Diversity

**Primary Build Families**

- Vanguard: max HP, armor, retaliation, sustain
- Berserker: attack speed, lifesteal, low-HP bonuses
- Sharpshot: range, crit rate, crit damage
- Warden: territory_power, fortify, boss damage
- Corruptor: danger scaling, curse conversion, high-risk burst
- Tactician: event control, reward rerolls, market efficiency

**Upgrade Pool Rules**

- Offer 3 upgrade choices per level-up.
- Do not offer duplicate upgrade IDs in the same choice set.
- Weight offered upgrades toward the current build by tags already taken.
- Guarantee one defensive option in the first 3 upgrade choices of every run.
- Rare upgrades only appear after level 4 or first boss kill.

### Meta Progression

**Permanent Trees**

- Command Tree: base attack, base HP, attack speed, starting gold
- Logistics Tree: better Markets, cheaper rerolls, extra reveal radius
- Dominion Tree: more essence gain, boss sigil bonus, unlock special tiles

**Permanent Unlock Order**

1. Base stats and first revive token unlock
2. Market and Shrine upgrade depth
3. Fortress, Vault, and Portal tile unlock rates
4. Advanced event pool
5. New build-family relics

## 7. Difficulty Curve Design

| Phase | Target Time | Captures | Enemy Profile | Tile Distribution | Intended Feeling |
| --- | --- | --- | --- | --- | --- |
| Early | 0 to 2 minutes | 0 to 12 | low HP, simple melee and archer enemies | Plains, Forest, Mine, first Shrine | quick momentum, safe learning |
| Mid | 2 to 6 minutes | 13 to 36 | mixed ranged and elite enemies, more status effects | Fortress, Market, Swamp, Shrine, Mine | tactical pressure and build definition |
| Late | 6 to 10 minutes | 37 to 60 | dense waves, high burst, boss mechanics overlap with curses | Vault, Fortress, Portal, Swamp, Boss Gate | controlled chaos and greedy risk decisions |

**Phase Rules**

- Early phase must not kill a full-health player in less than 3 seconds without repeated greedy choices.
- Mid phase introduces meaningful sustain pressure and elite spikes.
- Late phase assumes the player has a coherent build and at least 2 relic synergies.
- Enemy burst grows faster than enemy HP after phase 2 to avoid slow, boring late fights.

**Default Scaling Curve**

- Per 12 captures:
  - enemy HP multiplier `x1.22`
  - enemy attack multiplier `x1.18`
  - gold multiplier `x1.20`
  - XP multiplier `x1.15`
- Bosses scale separately and must remain threatening even with high sustain builds.

## 8. Boss System (min 5 bosses)

| Boss | Spawn Threshold | Theme | Core Mechanics | Defeat Reward |
| --- | --- | --- | --- | --- |
| Border Warden | 12 captures | armored knight commander | shield stance every 6 seconds, frontal charge, summon 2 guards at 50 percent HP | 1 relic, 25 essence, 1 sigil |
| Root Colossus | 24 captures | corrupted tree titan | vine slam, root prison, seed pods that heal boss if not destroyed | 1 relic, 30 essence, 1 sigil |
| Iron Matriarch | 36 captures | siege machine queen | rotating cannon bursts, deploys 3 drones, armor plates break by phase | 1 relic, 35 essence, 1 sigil |
| Rift Bishop | 48 captures | void priest | teleports every 5 seconds, curse zones, converts one buff into weaken on transition | 1 relic, 40 essence, 2 sigils |
| Crownless King | 60 captures | final tyrant of the map | sword waves, clone dash, throne aura, final enrage below 25 percent HP | 2 relics, 60 essence, 3 sigils, run clear bonus |

**Boss Design Rules**

- Each boss has 3 readable signature attacks maximum.
- Each boss introduces one new pressure pattern:
  - shield break
  - summon control
  - zone denial
  - buff disruption
  - burst enrage
- Bosses must use larger silhouettes than normal enemies and unique floor telegraphs.
- Boss rewards must always feel run-defining.

## 9. Economy System

### Currencies

| Currency | Scope | Use | Source |
| --- | --- | --- | --- |
| Gold | run-only | Market purchases, heals, rerolls, cleanses | tile rewards, events, bosses |
| Essence | permanent | main meta upgrade tree | all run completions |
| Sigils | permanent rare | advanced meta nodes and late unlocks | boss kills and flawless boss bonuses |

### Reward Rules

- Plains reward: `8 to 12 gold`, `10 XP`
- Forest reward: `10 to 14 gold`, `12 XP`
- Mine reward: `18 to 26 gold`, `10 XP`
- Fortress reward: `20 to 30 gold`, `20 XP`, `relic chance 35 percent`
- Vault reward: `25 to 40 gold`, `25 XP`, `rare currency chance 40 percent`
- Boss reward: fixed essence and sigil payout plus relic

### Market Pricing

- Heal 30 percent HP: `20 gold`
- Cleanse one curse: `30 gold`
- Reroll next upgrade offer: `25 gold`
- Buy common relic: `45 gold`
- Buy rare relic: `70 gold`

### Scaling Rules

- Gold income increases faster than shop costs in early phase to create momentum.
- Shop costs scale by `+10 percent` after each purchase in the same Market.
- Essence income must average:
  - failed short run: `20 to 35`
  - mid run: `45 to 90`
  - full clear: `180+`
- Sigils must remain rare:
  - average failed run: `0 to 1`
  - mid run: `2 to 3`
  - full clear: `8`

## 10. Monetization Design

### Rewarded Ads

**Default Placements**

- One revive per run:
  - trigger only on death
  - restore 50 percent HP
  - remove 10 danger
  - cannot trigger in the final boss second phase
- Double essence reward:
  - shown on result screen only
  - doubles essence, not sigils
- Upgrade reroll:
  - one ad-based reroll per run after level 3
- Daily command crate:
  - home screen reward once per day
  - grants gold start bonus for next run and small essence

### Interstitials

**Default Rules**

- Never show during active combat.
- Never show during upgrade choice, event choice, or boss intro.
- Show only after result screen claim or returning to home.
- Minimum interval: 8 minutes since previous interstitial.
- Minimum session condition: player completed at least 2 runs or one run longer than 3 minutes.
- Skip interstitial if a rewarded ad was watched in the last 90 seconds.

### Placement Timing

- First session: no interstitials
- Second session onward: one interstitial at most per 2 completed runs
- After a final boss clear: prioritize reward summary first, then optional interstitial on return to home

### Technical Rules

- Implement `AdService` as an interface with:
  - `is_rewarded_ready()`
  - `show_rewarded(ad_slot_id)`
  - `is_interstitial_ready()`
  - `show_interstitial()`
- Ship MVP with mock editor-only ad service and no live SDK
- Keep monetization code isolated from core gameplay logic

## 11. UI/UX Structure

### Screen Flow

`Boot -> Load Profile -> Home -> Meta Upgrades -> Start Run -> Map/Combat Loop -> Result Screen -> Meta Spend -> Start Next Run`

### Home Screen

- Top: essence, sigils, daily crate state
- Center: hero statue art, current meta power summary
- Bottom:
  - `Start Run`
  - `Meta Upgrades`
  - `Compendium`
  - `Settings`

### Run HUD

- Top bar:
  - HP bar
  - danger meter
  - gold
  - capture count
  - boss progress
- Center:
  - tile map board
  - selected tile preview panel floating near bottom
- Bottom tray:
  - current relic summary
  - pause button
  - speed toggle is not included in MVP

### Upgrade Choice Modal

- Full-width lower-half card stack
- Show 3 upgrade cards
- Each card includes:
  - title
  - icon
  - one-line effect
  - tags
- Add reroll button under cards

### Event Modal

- Show event art panel at top
- Show two large touchable choices at bottom
- Each choice must display:
  - reward
  - penalty
  - danger change

### Result Screen

- Show captured tiles, bosses defeated, best damage stat, essence, sigils
- Show optional rewarded ad for double essence
- Show `Spend Later` and `Meta Upgrades` buttons

### UI Layout Logic

- All primary taps must fit within thumb zone in the bottom 45 percent of the screen.
- Use color coding:
  - green for healing
  - gold for reward
  - red for damage and danger
  - cyan for portals and corruption
- Font sizes must remain readable at 6.1 inch screen size:
  - title `48 px`
  - button label `32 px`
  - body `24 px`
- Use icon-plus-number pairs for fast scan.

## 12. Art Direction

### Style Definition

- Top-down stylized 2D mobile strategy look
- Clean silhouettes with chunky readable forms
- Flat-to-soft shading, not painterly
- High contrast palette with warm ground colors and cool corruption accents
- Consistent top-left lighting direction
- Bold shape language over fine detail
- No photorealism
- No text embedded in art

### Color Language

- Friendly and player-aligned: gold, blue steel, warm ivory
- Basic enemies: red-brown, charcoal, dull metal
- Elite enemies: crimson with gold trim
- Corruption and high danger: cyan, teal, black-violet accents
- Healing and blessings: green-cyan glow

### Readability Rules

- Every tile must be recognizable from silhouette and one dominant color.
- Bosses must occupy at least 1.8x the visual mass of normal enemies.
- Effects must use short-lived bright frames and fade quickly.
- UI art must use simple borders and low texture noise.
- Backgrounds must stay lower contrast than units and interactables.

### Legal and IP Safety Rules

- All generated art must be original and commercially safe by default.
- Do not reference, imitate, trace, or closely resemble any existing copyrighted game, film, anime, comic, toy, mascot, or branded visual property.
- Do not use artist names, studio names, franchise names, publisher names, or brand names in prompts.
- Do not include logos, trademarks, wordmarks, signature shapes strongly associated with a known IP, or recognizable branded costume patterns.
- Do not generate real-person likenesses, celebrity likenesses, or identifiable public figures.
- If any output resembles a known character, logo, studio style, or franchise visual identity, reject it and regenerate immediately.
- All final assets imported into production must pass an originality review before use.

### Asset Size Targets

- Tiles: `256 x 256`
- Characters: `192 x 192`
- Bosses: `384 x 384`
- Effects: `256 x 256`
- Icons: `128 x 128`
- UI panels and buttons: `512 x 512` source for 9-slice use
- Backgrounds: `2048 x 2048`

## 13. COMPLETE Asset List (CRITICAL)

**Planned Production Image Count:** `105`

**Recommended Generation Cadence:** `21 batches x 5 images`

### Tiles

| Filename | Purpose |
| --- | --- |
| `assets/tiles/tile_plains.png` | default low-risk combat tile |
| `assets/tiles/tile_forest.png` | fast-enemy combat tile |
| `assets/tiles/tile_mine.png` | gold-rich guarded tile |
| `assets/tiles/tile_shrine.png` | blessing and curse event tile |
| `assets/tiles/tile_fortress.png` | elite combat tile |
| `assets/tiles/tile_market.png` | utility and healing tile |
| `assets/tiles/tile_swamp.png` | poison and slow combat tile |
| `assets/tiles/tile_vault.png` | high-risk rare reward tile |
| `assets/tiles/tile_portal.png` | teleport and reveal tile |
| `assets/tiles/tile_boss_gate.png` | milestone boss entrance tile |
| `assets/tiles/tile_hidden_fog.png` | unrevealed tile state visual |
| `assets/tiles/tile_overlay_selectable.png` | selectable tile state overlay |
| `assets/tiles/tile_overlay_captured.png` | captured tile state overlay |
| `assets/tiles/tile_overlay_locked.png` | locked tile state overlay |
| `assets/tiles/tile_overlay_boss_warning.png` | boss warning tile overlay |
| `assets/tiles/tile_overlay_path_highlight.png` | path and route highlight overlay |

### Characters

| Filename | Purpose |
| --- | --- |
| `assets/characters/hero_conqueror.png` | player unit sprite |
| `assets/characters/enemy_raider.png` | basic melee enemy |
| `assets/characters/enemy_archer.png` | basic ranged enemy |
| `assets/characters/enemy_brute.png` | heavy slow enemy |
| `assets/characters/enemy_shaman.png` | support caster enemy |
| `assets/characters/enemy_assassin.png` | fast burst enemy |
| `assets/characters/enemy_turret.png` | stationary siege enemy |
| `assets/characters/enemy_guard.png` | boss summon guard enemy |
| `assets/characters/enemy_seed_pod.png` | root colossus summon enemy |
| `assets/characters/enemy_drone.png` | iron matriarch summon enemy |
| `assets/characters/enemy_void_clone.png` | crownless king clone enemy |

### Bosses

| Filename | Purpose |
| --- | --- |
| `assets/bosses/boss_border_warden.png` | first boss |
| `assets/bosses/boss_root_colossus.png` | second boss |
| `assets/bosses/boss_iron_matriarch.png` | third boss |
| `assets/bosses/boss_rift_bishop.png` | fourth boss |
| `assets/bosses/boss_crownless_king.png` | final boss |

### UI

| Filename | Purpose |
| --- | --- |
| `assets/ui/ui_panel_primary.png` | main framed panel |
| `assets/ui/ui_panel_secondary.png` | secondary panel |
| `assets/ui/ui_button_primary.png` | main CTA button |
| `assets/ui/ui_button_secondary.png` | alternate button |
| `assets/ui/ui_progress_fill.png` | progress bar fill |
| `assets/ui/ui_progress_frame.png` | progress bar frame |
| `assets/ui/ui_reward_card.png` | upgrade and reward card |
| `assets/ui/ui_popup_frame.png` | event and modal frame |
| `assets/ui/ui_button_primary_pressed.png` | pressed state for primary button |
| `assets/ui/ui_button_secondary_pressed.png` | pressed state for secondary button |
| `assets/ui/ui_tab_button.png` | tab navigation button |
| `assets/ui/ui_toggle_on.png` | enabled toggle control |
| `assets/ui/ui_toggle_off.png` | disabled toggle control |
| `assets/ui/ui_currency_pill.png` | currency display pill |
| `assets/ui/ui_stat_chip.png` | compact stat label chip |
| `assets/ui/ui_tile_preview_frame.png` | selected tile preview frame |

### Effects

| Filename | Purpose |
| --- | --- |
| `assets/effects/fx_slash.png` | melee attack arc |
| `assets/effects/fx_arrow_trail.png` | ranged projectile effect |
| `assets/effects/fx_impact_burst.png` | hit impact |
| `assets/effects/fx_crit_flash.png` | critical hit flash |
| `assets/effects/fx_heal_ring.png` | healing pulse |
| `assets/effects/fx_buff_up.png` | buff indicator |
| `assets/effects/fx_debuff_down.png` | debuff indicator |
| `assets/effects/fx_levelup_burst.png` | level up effect |
| `assets/effects/fx_tile_capture_wave.png` | territory capture pulse |
| `assets/effects/fx_portal_swirl.png` | portal activation effect |
| `assets/effects/fx_root_spike.png` | root spike boss attack effect |
| `assets/effects/fx_cannon_shell.png` | cannon shell projectile effect |
| `assets/effects/fx_void_bolt.png` | void bolt projectile effect |
| `assets/effects/fx_poison_cloud.png` | poison cloud area effect |
| `assets/effects/fx_shield_pulse.png` | shield stance pulse effect |
| `assets/effects/fx_danger_telegraph_circle.png` | boss telegraph warning circle |
| `assets/effects/fx_dash_smear.png` | fast dash trail effect |
| `assets/effects/fx_death_smoke.png` | enemy death smoke burst |
| `assets/effects/fx_reward_sparkle.png` | reward pickup sparkle |
| `assets/effects/fx_boss_enrage_aura.png` | boss enrage aura effect |

### Icons

| Filename | Purpose |
| --- | --- |
| `assets/icons/icon_hp.png` | HP stat icon |
| `assets/icons/icon_attack.png` | attack stat icon |
| `assets/icons/icon_attack_speed.png` | attack speed icon |
| `assets/icons/icon_armor.png` | armor icon |
| `assets/icons/icon_crit.png` | crit icon |
| `assets/icons/icon_lifesteal.png` | lifesteal icon |
| `assets/icons/icon_luck.png` | luck icon |
| `assets/icons/icon_risk.png` | danger icon |
| `assets/icons/icon_gold.png` | gold icon |
| `assets/icons/icon_essence.png` | essence icon |
| `assets/icons/icon_sigil.png` | sigil icon |
| `assets/icons/icon_boss.png` | boss progress icon |
| `assets/icons/icon_relic.png` | relic icon |
| `assets/icons/icon_curse.png` | curse icon |
| `assets/icons/icon_heal.png` | healing icon |
| `assets/icons/icon_shop.png` | shop icon |
| `assets/icons/icon_reroll.png` | reroll icon |
| `assets/icons/icon_reveal.png` | reveal icon |
| `assets/icons/icon_revive.png` | revive icon |
| `assets/icons/icon_chest.png` | chest reward icon |
| `assets/icons/icon_portal.png` | portal icon |
| `assets/icons/icon_event.png` | event icon |
| `assets/icons/icon_range.png` | range stat icon |
| `assets/icons/icon_move_speed.png` | move speed stat icon |
| `assets/icons/icon_corruption_resist.png` | corruption resist icon |
| `assets/icons/icon_territory_power.png` | territory power icon |

### Backgrounds

| Filename | Purpose |
| --- | --- |
| `assets/backgrounds/bg_main_menu.png` | home screen background |
| `assets/backgrounds/bg_run_board.png` | run scene backdrop |
| `assets/backgrounds/bg_boss_arena.png` | boss combat arena background |
| `assets/backgrounds/event_bg_blood_shrine.png` | blood shrine event background |
| `assets/backgrounds/event_bg_ruined_caravan.png` | ruined caravan event background |
| `assets/backgrounds/event_bg_cursed_banner.png` | cursed banner event background |
| `assets/backgrounds/event_bg_mercenary_camp.png` | mercenary camp event background |
| `assets/backgrounds/event_bg_sealed_vault.png` | sealed vault event background |
| `assets/backgrounds/event_bg_scout_tower.png` | scout tower event background |
| `assets/backgrounds/bg_meta_hall.png` | meta upgrade hall background |
| `assets/backgrounds/bg_result_summary.png` | result summary background |

## 14. Image Generation Prompts (CRITICAL)

**Prompt Mirror File:** `image_prompts.md`

**Execution Rule:** Generate assets in `21 batches x 5 images` using the standalone prompts in `image_prompts.md`. The prompts below remain the source-of-truth copy inside `agent.md`.

### Legal and Copyright Safety Rules

- Every prompt used for image generation must explicitly require original, non-infringing output.
- Every prompt must forbid imitation of existing games, characters, franchises, brands, logos, trademarks, and named artist styles.
- Never add references such as "in the style of", franchise comparisons, or brand-adjacent descriptors during prompt iteration.
- If a generated image contains recognizable IP, text, a watermark, a logo, or a celebrity likeness, discard it and regenerate with a stricter prompt.
- No asset may be accepted into the repository until it passes visual legal review.

### Tiles

- `assets/tiles/tile_plains.png`: "Top-down 2D mobile game tile, clean readable shapes, stylized grassy plains territory with short grass, compact dirt paths, a few small stones, warm earth palette with soft green highlights, centered square tile composition, high contrast edges, consistent top-left lighting, flat-to-soft shading, no text, no watermark, no characters, transparent background outside tile silhouette."
- `assets/tiles/tile_forest.png`: "Top-down 2D mobile game tile, clean readable shapes, stylized forest territory tile with clustered dark green trees, visible walkable clearings, crisp canopy silhouettes, warm soil, high contrast, consistent top-left lighting, flat-to-soft shading, readable from small size, no text, no watermark, no characters, transparent background outside tile silhouette."
- `assets/tiles/tile_mine.png`: "Top-down 2D mobile game tile, clean readable shapes, stylized mining territory with a wooden mineshaft entrance, ore cart, rocky ground, gold ore accents, warm brown stone, high contrast, consistent top-left lighting, flat-to-soft shading, top-down centered tile, no text, no watermark, no characters, transparent background outside tile silhouette."
- `assets/tiles/tile_shrine.png`: "Top-down 2D mobile game tile, clean readable shapes, stylized shrine territory with a glowing altar, carved stone ring, candles or braziers, soft cyan blessing glow against warm stone, strong silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, no characters, transparent background outside tile silhouette."
- `assets/tiles/tile_fortress.png`: "Top-down 2D mobile game tile, clean readable shapes, stylized fortress territory with thick walls, a central keep, armored gate, red banners without symbols, heavy stone forms, high contrast, consistent top-left lighting, flat-to-soft shading, top-down centered tile, no text, no watermark, no characters, transparent background outside tile silhouette."
- `assets/tiles/tile_market.png`: "Top-down 2D mobile game tile, clean readable shapes, stylized field market territory with two tents, crates, coin piles, merchant stall shapes, warm cloth colors, clear walkable center, high contrast, consistent top-left lighting, flat-to-soft shading, top-down centered tile, no text, no watermark, no characters, transparent background outside tile silhouette."
- `assets/tiles/tile_swamp.png`: "Top-down 2D mobile game tile, clean readable shapes, stylized swamp territory with murky pools, twisted roots, reeds, toxic teal puddle accents, muddy dark ground, readable silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, no characters, transparent background outside tile silhouette."
- `assets/tiles/tile_vault.png`: "Top-down 2D mobile game tile, clean readable shapes, stylized sealed vault territory with a heavy circular door, gold trims, chained locks, dark stone platform, treasure glow leaking through cracks, high contrast, consistent top-left lighting, flat-to-soft shading, top-down centered tile, no text, no watermark, no characters, transparent background outside tile silhouette."
- `assets/tiles/tile_portal.png`: "Top-down 2D mobile game tile, clean readable shapes, stylized magical portal territory with a circular stone frame, swirling cyan energy, rune-like shapes without readable text, dark base stones, strong focal center, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, no characters, transparent background outside tile silhouette."
- `assets/tiles/tile_boss_gate.png`: "Top-down 2D mobile game tile, clean readable shapes, stylized boss gate territory with a giant ominous archway, chained doors, crown motif, red and cyan glow, dark stone slabs, dramatic silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, top-down centered tile, no text, no watermark, no characters, transparent background outside tile silhouette."
- `assets/tiles/tile_hidden_fog.png`: "Top-down 2D mobile game tile state, clean readable shapes, stylized mysterious fog-covered territory, dark desaturated ground hidden under layered smoke, subtle cyan edge shimmer, minimal detail, strong readable square tile silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, no characters, transparent background outside tile silhouette."
- `assets/tiles/tile_overlay_selectable.png`: "Top-down 2D mobile game tile overlay, clean readable shapes, stylized selectable state marker with a glowing gold outline ring, faint corner brackets, soft cyan accent sparks, designed to sit over an existing tile without hiding it, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/tiles/tile_overlay_captured.png`: "Top-down 2D mobile game tile overlay, clean readable shapes, stylized captured territory marker with gold conquest border, subtle banner cloth corners, faint dust glow, designed to sit over an existing tile and communicate ownership, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/tiles/tile_overlay_locked.png`: "Top-down 2D mobile game tile overlay, clean readable shapes, stylized locked tile marker with crossed iron chains, dark seal, muted red warning glow, designed to sit over an existing tile without obscuring readability, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/tiles/tile_overlay_boss_warning.png`: "Top-down 2D mobile game tile overlay, clean readable shapes, stylized boss warning marker with ominous crown emblem, red and cyan warning aura, cracked circular frame, designed for a milestone boss tile, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/tiles/tile_overlay_path_highlight.png`: "Top-down 2D mobile game tile overlay, clean readable shapes, stylized path highlight marker with soft golden route lines, subtle arrow motion cues, readable over many tile colors, designed to indicate the current planned path, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."

### Characters

- `assets/characters/hero_conqueror.png`: "Top-down 2D mobile game character sprite, stylized armored conqueror hero with blue steel armor, gold trim, broad cape, sword and round shield, compact heroic silhouette, clean readable shapes, centered single character, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/characters/enemy_raider.png`: "Top-down 2D mobile game character sprite, stylized melee raider with rough armor, red-brown cloth, axe, aggressive forward pose, compact readable silhouette, clean shapes, centered single character, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/characters/enemy_archer.png`: "Top-down 2D mobile game character sprite, stylized enemy archer with hood, short bow, dark leather gear, red accents, clear ranged silhouette, centered single character, clean readable shapes, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/characters/enemy_brute.png`: "Top-down 2D mobile game character sprite, stylized heavy brute with oversized shoulders, hammer, thick armor plates, dark iron and crimson color scheme, slow powerful silhouette, centered single character, clean readable shapes, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/characters/enemy_shaman.png`: "Top-down 2D mobile game character sprite, stylized enemy shaman with staff, ritual mask, cloth robes, cyan corruption glow around hands, clear caster silhouette, centered single character, clean readable shapes, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/characters/enemy_assassin.png`: "Top-down 2D mobile game character sprite, stylized fast assassin with twin daggers, sleek dark armor, red scarf, low crouched pose, sharp readable silhouette, centered single character, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/characters/enemy_turret.png`: "Top-down 2D mobile game unit sprite, stylized stationary siege turret with rotating crossbow head, metal frame, wooden base, red hostile accents, clear top-down silhouette, centered single unit, clean readable shapes, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/characters/enemy_guard.png`: "Top-down 2D mobile game character sprite, stylized summoned guard enemy with spear and kite shield, disciplined armored stance, red-black military palette with dull steel trim, clear frontline silhouette, centered single character, clean readable shapes, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/characters/enemy_seed_pod.png`: "Top-down 2D mobile game character sprite, stylized living seed pod summon with rooted tendrils, woody shell, glowing cyan sap cracks, compact readable silhouette, centered single character, clean readable shapes, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/characters/enemy_drone.png`: "Top-down 2D mobile game character sprite, stylized mechanical drone summon with brass rotor arms, red sensor eye, compact flying body, industrial crimson and steel palette, centered single unit, clean readable shapes, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/characters/enemy_void_clone.png`: "Top-down 2D mobile game character sprite, stylized void clone enemy shaped like a shadow swordsman, black body with cyan edge glow, torn cape fragments, eerie readable silhouette, centered single character, clean readable shapes, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."

### Bosses

- `assets/bosses/boss_border_warden.png`: "Top-down 2D mobile game boss sprite, stylized armored commander called Border Warden, massive tower shield, long spear, blue steel and gold armor, intimidating heroic villain silhouette, larger scale than regular units, centered single boss, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/bosses/boss_root_colossus.png`: "Top-down 2D mobile game boss sprite, stylized corrupted tree giant called Root Colossus, huge trunk body, branch arms, glowing cyan sap cracks, heavy root feet, monstrous readable silhouette, centered single boss, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/bosses/boss_iron_matriarch.png`: "Top-down 2D mobile game boss sprite, stylized siege machine queen called Iron Matriarch, mechanical body, rotating cannons, armored legs, crimson metal and brass, large commanding silhouette, centered single boss, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/bosses/boss_rift_bishop.png`: "Top-down 2D mobile game boss sprite, stylized void priest called Rift Bishop, floating robes, tall staff, broken halo ring, cyan and black corruption energy, eerie readable silhouette, centered single boss, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/bosses/boss_crownless_king.png`: "Top-down 2D mobile game boss sprite, stylized final tyrant called Crownless King, regal black armor, torn red cape, oversized sword, empty crown frame above head, dramatic large silhouette, centered single boss, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."

### UI

- `assets/ui/ui_panel_primary.png`: "Top-down 2D mobile game UI asset, ornate primary panel frame with beveled stone and gold trim, clean symmetrical rectangle for 9-slice use, subtle texture, high contrast edges, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_panel_secondary.png`: "Top-down 2D mobile game UI asset, secondary panel frame with dark steel border and muted parchment center, clean readable rectangle for 9-slice use, lower emphasis than primary panel, high contrast edges, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_button_primary.png`: "Top-down 2D mobile game UI asset, primary action button with gold frame, blue center, slight bevel, large readable shape for touch interface, symmetrical front view, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_button_secondary.png`: "Top-down 2D mobile game UI asset, secondary action button with dark steel frame, muted ivory center, simpler shape than primary button, clean readable front view, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_progress_fill.png`: "Top-down 2D mobile game UI asset, glowing segmented progress bar fill with gold-to-cyan energy gradient, clean horizontal shape, readable at small size, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_progress_frame.png`: "Top-down 2D mobile game UI asset, framed horizontal progress bar container with dark metal border and inset groove, clean readable shape, high contrast edges, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_reward_card.png`: "Top-down 2D mobile game UI asset, stylized reward card frame with gold corners, parchment center, relic-like ornament, vertical rectangle, readable from small size, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_popup_frame.png`: "Top-down 2D mobile game UI asset, large modal popup frame with carved stone border, subtle gold details, darkened center area for content overlay, clean symmetrical rectangle, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_button_primary_pressed.png`: "Top-down 2D mobile game UI asset, pressed state primary action button with gold frame, blue center pushed inward, stronger shadow compression, large readable touch shape, symmetrical front view, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_button_secondary_pressed.png`: "Top-down 2D mobile game UI asset, pressed state secondary action button with dark steel frame, muted ivory center pushed inward, clear pressed feedback, readable front view, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_tab_button.png`: "Top-down 2D mobile game UI asset, stylized tab navigation button with beveled dark steel shell, gold accent trim, wide touch-friendly shape, readable active state silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_toggle_on.png`: "Top-down 2D mobile game UI asset, stylized toggle switch in ON state with glowing cyan knob, gold frame, readable mobile control shape, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_toggle_off.png`: "Top-down 2D mobile game UI asset, stylized toggle switch in OFF state with dark knob, muted steel frame, readable mobile control shape, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_currency_pill.png`: "Top-down 2D mobile game UI asset, stylized currency pill frame with rounded gold border, inset dark center, designed for icon plus number, readable at small size, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_stat_chip.png`: "Top-down 2D mobile game UI asset, stylized compact stat chip with metallic frame, small gem notch, pill-rectangle silhouette, readable for buff tags and stat labels, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/ui/ui_tile_preview_frame.png`: "Top-down 2D mobile game UI asset, stylized tile preview frame with dark stone border, gold corners, lower card-style panel composition for selected tile information, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."

### Effects

- `assets/effects/fx_slash.png`: "Top-down 2D mobile game effect sprite, bright curved slash arc with white core and gold edge, energetic clean shape, readable on small mobile screen, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_arrow_trail.png`: "Top-down 2D mobile game effect sprite, fast projectile streak with glowing arrow trail, white and cyan motion blur, compact clean shape, readable on small mobile screen, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_impact_burst.png`: "Top-down 2D mobile game effect sprite, sharp radial impact burst with dust and sparks, gold and white center, strong readable silhouette, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_crit_flash.png`: "Top-down 2D mobile game effect sprite, intense star-shaped critical hit flash, gold and crimson highlights, crisp pointed silhouette, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_heal_ring.png`: "Top-down 2D mobile game effect sprite, circular healing pulse ring with green-cyan glow, soft magical particles, clean readable shape, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_buff_up.png`: "Top-down 2D mobile game effect sprite, upward buff energy symbol made of gold light and small shards, clean readable shape, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_debuff_down.png`: "Top-down 2D mobile game effect sprite, downward debuff energy symbol made of dark red smoke and broken fragments, clean readable shape, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_levelup_burst.png`: "Top-down 2D mobile game effect sprite, celebratory level-up burst with gold rays and cyan particles, circular explosive composition, clean readable shape, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_tile_capture_wave.png`: "Top-down 2D mobile game effect sprite, expanding territory capture pulse with golden ring and dust ripple, clean circular shape, readable on board tiles, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_portal_swirl.png`: "Top-down 2D mobile game effect sprite, magical portal swirl with cyan spiral energy, sparks, and circular motion lines, clear readable silhouette, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_root_spike.png`: "Top-down 2D mobile game effect sprite, violent root spike eruption with jagged wooden thorns, dirt burst, cyan sap glow in cracks, strong upward silhouette, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_cannon_shell.png`: "Top-down 2D mobile game effect sprite, heavy cannon shell projectile with brass casing, smoke trail, small ember sparks, compact readable silhouette for top-down mobile play, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_void_bolt.png`: "Top-down 2D mobile game effect sprite, magical void bolt projectile with cyan-black core, trailing shards, eerie glow, compact readable silhouette, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_poison_cloud.png`: "Top-down 2D mobile game effect sprite, toxic poison cloud with layered green-teal smoke, drifting particles, soft circular silhouette readable in top-down view, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_shield_pulse.png`: "Top-down 2D mobile game effect sprite, protective shield pulse with bright gold ring, blue inner flare, clean circular burst readable on bosses and elites, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_danger_telegraph_circle.png`: "Top-down 2D mobile game effect sprite, warning telegraph circle for boss attacks with red ring, cyan edge accents, broken rune segments without readable text, clear top-down circle shape, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_dash_smear.png`: "Top-down 2D mobile game effect sprite, fast dash smear with white and red motion streaks, narrow directional silhouette, readable during quick enemy or boss movement, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_death_smoke.png`: "Top-down 2D mobile game effect sprite, compact death smoke burst with dark ash, ember sparks, fading center, readable at small scale, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_reward_sparkle.png`: "Top-down 2D mobile game effect sprite, reward sparkle burst with gold stars, crystal glints, small celebratory energy lines, compact readable silhouette, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/effects/fx_boss_enrage_aura.png`: "Top-down 2D mobile game effect sprite, intense boss enrage aura with red flame ring, black smoke shards, cyan underglow, circular threatening silhouette readable from top-down view, high contrast, consistent top-left lighting style, flat-to-soft shading, no text, no watermark, transparent background."

### Icons

- `assets/icons/icon_hp.png`: "Top-down 2D mobile game icon, stylized shielded heart symbol for health, gold border, red center, simple clean shape, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_attack.png`: "Top-down 2D mobile game icon, stylized crossed sword symbol for attack, steel blade with gold hilt, simple clean shape, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_attack_speed.png`: "Top-down 2D mobile game icon, stylized rapid blade symbol with motion streaks for attack speed, steel and cyan accents, simple clean shape, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_armor.png`: "Top-down 2D mobile game icon, stylized breastplate shield symbol for armor, blue steel and gold trim, simple clean shape, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_crit.png`: "Top-down 2D mobile game icon, stylized starburst blade symbol for critical hit, gold and crimson accents, simple clean shape, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_lifesteal.png`: "Top-down 2D mobile game icon, stylized fang and droplet symbol for lifesteal, dark red and ivory colors, simple clean shape, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_luck.png`: "Top-down 2D mobile game icon, stylized lucky coin and sparkle symbol, gold and teal accents, simple clean shape, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_risk.png`: "Top-down 2D mobile game icon, stylized danger flame with cyan corruption edge, red core, simple clean shape, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_gold.png`: "Top-down 2D mobile game icon, stylized stack of gold coins with sharp readable silhouette, warm metallic palette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_essence.png`: "Top-down 2D mobile game icon, stylized glowing crystal shard for essence, cyan core with gold frame, simple clean shape, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_sigil.png`: "Top-down 2D mobile game icon, stylized conquest sigil medallion with crown-like geometry, dark steel and gold, simple clean shape, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_boss.png`: "Top-down 2D mobile game icon, stylized horned crown marker for boss progress, red and black with gold edge, simple clean shape, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_relic.png`: "Top-down 2D mobile game icon, stylized ancient relic medallion with gold frame and cyan gem center, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_curse.png`: "Top-down 2D mobile game icon, stylized broken sigil and dark smoke symbol for curse, crimson and black palette with cyan crack, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_heal.png`: "Top-down 2D mobile game icon, stylized healing vial and glow symbol with green-cyan liquid, gold cap, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_shop.png`: "Top-down 2D mobile game icon, stylized market stall symbol with small awning and coin detail, warm cloth and gold palette, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_reroll.png`: "Top-down 2D mobile game icon, stylized circular arrows and gem spark symbol for reroll, gold and cyan palette, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_reveal.png`: "Top-down 2D mobile game icon, stylized eye and map sparkle symbol for reveal, gold frame with cyan center light, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_revive.png`: "Top-down 2D mobile game icon, stylized phoenix spark and heart symbol for revive, red-gold flame motif, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_chest.png`: "Top-down 2D mobile game icon, stylized treasure chest symbol with gold trim and dark wood, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_portal.png`: "Top-down 2D mobile game icon, stylized swirling portal ring with cyan energy and dark stone rim, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_event.png`: "Top-down 2D mobile game icon, stylized parchment and spark symbol for event tile, ivory scroll with gold seal and cyan accent, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_range.png`: "Top-down 2D mobile game icon, stylized target reticle and arrow symbol for range, steel and cyan palette, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_move_speed.png`: "Top-down 2D mobile game icon, stylized winged boot symbol for movement speed, steel and gold palette, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_corruption_resist.png`: "Top-down 2D mobile game icon, stylized ward shield against cyan corruption smoke, gold rim and teal center barrier, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."
- `assets/icons/icon_territory_power.png`: "Top-down 2D mobile game icon, stylized conquest banner planted on a glowing tile for territory power, gold and blue palette, clean compact silhouette, high contrast, consistent top-left lighting, flat-to-soft shading, no text, no watermark, transparent background."

### Backgrounds

- `assets/backgrounds/bg_main_menu.png`: "Top-down 2D mobile game background, stylized conquered frontier war room with map table, banners, candles, armor stands, warm earth colors with subtle cyan corruption at edges, clean readable composition for mobile menu backdrop, high contrast focal center, consistent top-left lighting, flat-to-soft shading, no text, no watermark."
- `assets/backgrounds/bg_run_board.png`: "Top-down 2D mobile game background, stylized open frontier battlefield seen from above with earth, grass, broken roads, distant ruins and subtle fog at edges, low-detail backdrop designed not to overpower UI or tiles, high contrast center-to-edge control, consistent top-left lighting, flat-to-soft shading, no text, no watermark."
- `assets/backgrounds/bg_boss_arena.png`: "Top-down 2D mobile game background, stylized dark throne-field arena seen from above with cracked stone circles, corrupted banners, red embers and cyan rifts at edges, dramatic but readable mobile backdrop, high contrast focal center, consistent top-left lighting, flat-to-soft shading, no text, no watermark."
- `assets/backgrounds/event_bg_blood_shrine.png`: "Top-down 2D mobile game background, stylized blood shrine event scene with ancient altar, cracked stone ring, braziers, warm red candlelight mixed with cyan corruption glow, designed for event panel backdrop, high contrast focal center, consistent top-left lighting, flat-to-soft shading, no text, no watermark."
- `assets/backgrounds/event_bg_ruined_caravan.png`: "Top-down 2D mobile game background, stylized ruined caravan event scene seen from above with broken wagons, spilled crates, torn cloth, gold glints in the dirt, designed for event panel backdrop, high contrast focal center, consistent top-left lighting, flat-to-soft shading, no text, no watermark."
- `assets/backgrounds/event_bg_cursed_banner.png`: "Top-down 2D mobile game background, stylized cursed banner event scene with a dark war banner, cracked flagstones, drifting black smoke, cyan runic glow without text, designed for event panel backdrop, high contrast focal center, consistent top-left lighting, flat-to-soft shading, no text, no watermark."
- `assets/backgrounds/event_bg_mercenary_camp.png`: "Top-down 2D mobile game background, stylized mercenary camp event scene with tents, weapon racks, campfire, coin chest, rugged military atmosphere, designed for event panel backdrop, high contrast focal center, consistent top-left lighting, flat-to-soft shading, no text, no watermark."
- `assets/backgrounds/event_bg_sealed_vault.png`: "Top-down 2D mobile game background, stylized sealed vault event scene with giant locked door, treasure glow through cracks, chained stone floor, dark luxury atmosphere, designed for event panel backdrop, high contrast focal center, consistent top-left lighting, flat-to-soft shading, no text, no watermark."
- `assets/backgrounds/event_bg_scout_tower.png`: "Top-down 2D mobile game background, stylized scout tower event scene seen from above with wooden watchtower, map table, signal fire, frontier terrain around it, designed for event panel backdrop, high contrast focal center, consistent top-left lighting, flat-to-soft shading, no text, no watermark."
- `assets/backgrounds/bg_meta_hall.png`: "Top-down 2D mobile game background, stylized dominion upgrade hall with banners, relic pedestals, glowing command map, noble stone architecture, warm gold and blue palette, high contrast focal center, consistent top-left lighting, flat-to-soft shading, no text, no watermark."
- `assets/backgrounds/bg_result_summary.png`: "Top-down 2D mobile game background, stylized post-battle results chamber with map table, reward chest, sigil banners, fading embers and crystal glow, designed for summary screen backdrop, high contrast focal center, consistent top-left lighting, flat-to-soft shading, no text, no watermark."

## 15. MVP Scope

**MVP Goal**

Ship one fully playable run loop with permanent progression and placeholder-compatible content.

**MVP Includes**

- Godot project bootstrapped for portrait mobile
- Home screen, run scene, result screen, meta upgrade screen
- Deterministic map generation
- 6 active tile types:
  - Plains
  - Forest
  - Mine
  - Shrine
  - Fortress
  - Market
- 4 enemy types:
  - Raider
  - Archer
  - Brute
  - Shaman
- 2 bosses:
  - Border Warden
  - Root Colossus
- Auto combat with stats, crit, armor, evade, lifesteal
- 24 run upgrades
- 12 event definitions
- 18 permanent upgrade nodes
- Gold, Essence, and Sigil economies
- Mock rewarded ad service for revive and double essence
- Save/load and run resume

**MVP Excludes**

- Live ad SDK integration
- iOS export pipeline
- More than one playable hero
- Online services
- Seasonal content

## 16. Expansion Roadmap

### Expansion 1: Content Depth

- Add Swamp, Vault, and Portal tiles
- Add Assassin and Turret enemies
- Add Iron Matriarch and Rift Bishop bosses
- Expand relic pool to 60 upgrades
- Add rare event chains and cursed relics

### Expansion 2: System Depth

- Add final boss Crownless King clear route
- Add hero class variants
- Add daily seeded challenge mode
- Add compendium and unlock tracking
- Add advanced meta tree branches using sigils

### Expansion 3: Retention

- Add achievement set
- Add limited-time challenge modifiers
- Add cosmetic unlocks from milestone clears
- Add no-ad purchase and premium starter pack if product strategy requires it

## 17. Development Plan (VERY IMPORTANT)

### PHASE 1 -> core playable

**Goal**

Produce a working vertical slice with full start-run-die-upgrade-restart loop.

**Deliverables**

- Project structure and autoload singletons
- Data loading and validation
- Map board generation and tile selection
- Arena combat loop
- Run HUD and upgrade choice UI
- Result screen and permanent save
- One boss encounter
- Placeholder art integration
- Headless tests for formulas and seed stability

### PHASE 2 -> content expansion

**Goal**

Expand the game from vertical slice into content-complete core experience.

**Deliverables**

- Full tile pool
- Full enemy pool
- All 5 bosses
- Expanded events and relics
- Meta tree completion
- Better map pacing and danger tuning
- Full visual asset pass and effect pass
- Balance simulation scripts

### PHASE 3 -> monetization + polish

**Goal**

Prepare the game for production mobile deployment.

**Deliverables**

- AdService adapter and production slot hooks
- Interstitial gating rules
- Haptics, transitions, polish VFX
- Mobile performance tuning
- Crash-safe save handling
- Analytics event hooks
- Accessibility pass for color contrast and text size
- Export presets for Android release builds

## 18. Technical Design

### State Structure

```json
{
  "profile": {
    "version": 1,
    "essence": 120,
    "sigils": 4,
    "meta_upgrades": {
      "cmd_attack_1": 1,
      "logistics_market_1": 1,
      "dominion_essence_1": 2
    },
    "unlocks": {
      "tile_fortress": true,
      "tile_vault": false,
      "boss_root_colossus": true
    },
    "best_run": {
      "captures": 31,
      "bosses_defeated": 2,
      "seed": 1284439221
    }
  },
  "active_run": {
    "seed": 48299112,
    "phase_index": 1,
    "captured_tiles": 9,
    "danger": 18,
    "gold": 44,
    "xp": 38,
    "level": 3,
    "player": {
      "current_hp": 76,
      "max_hp": 128,
      "attack": 18,
      "attack_speed": 1.2,
      "armor": 9,
      "crit_rate": 0.12,
      "crit_damage": 0.7,
      "evade": 0.05,
      "lifesteal": 0.04,
      "territory_power": 0.06,
      "corruption_resist": 0.10
    },
    "relics": ["relic_berserk_1", "relic_fortify_on_hit"],
    "curses": ["curse_fragile_1"],
    "map": {
      "selected_tile": "1,0",
      "tiles": {
        "0,0": { "type": "plains", "state": "captured", "ring": 0 },
        "1,0": { "type": "forest", "state": "selectable", "ring": 1 },
        "0,1": { "type": "mine", "state": "revealed", "ring": 1 }
      }
    }
  }
}
```

### Basic Data Models

**Tile Definition Example**

```json
{
  "id": "forest",
  "resolver_mode": "combat",
  "spawn_weight": 18,
  "min_ring": 1,
  "max_ring": 5,
  "base_threat": 1.2,
  "base_reward": {
    "gold": [10, 14],
    "xp": [12, 16]
  },
  "risk_delta": 3,
  "enemy_pool": ["raider", "archer", "assassin"],
  "event_pool": [],
  "tags": ["nature", "fast_enemies"]
}
```

**Enemy Definition Example**

```json
{
  "id": "raider",
  "role": "melee",
  "base_hp": 26,
  "base_attack": 5,
  "base_attack_speed": 1.0,
  "armor": 0,
  "move_speed": 78,
  "range": 1.0,
  "skills": ["gap_close_light"],
  "loot_weight": 10
}
```

**Event Definition Example**

```json
{
  "id": "blood_shrine",
  "title": "Blood Shrine",
  "description": "An ancient altar demands a price.",
  "phase_tags": ["early", "mid"],
  "choices": [
    {
      "id": "offer_hp",
      "label": "Offer Blood",
      "cost": { "current_hp_percent": 0.2 },
      "reward": { "attack_percent": 0.18 },
      "danger_delta": 6,
      "add_curse": null
    },
    {
      "id": "reject",
      "label": "Reject the Shrine",
      "cost": {},
      "reward": { "essence_on_run_end": 6 },
      "danger_delta": 0,
      "add_curse": "curse_silence_1"
    }
  ]
}
```

**Permanent Upgrade Definition Example**

```json
{
  "id": "cmd_attack_1",
  "tree": "command",
  "cost_essence": 25,
  "cost_sigils": 0,
  "max_rank": 5,
  "effect": {
    "base_attack_flat": 2
  },
  "prerequisites": []
}
```

### Core Loop Logic

```text
BOOT
-> load profile
-> validate save version
-> open home screen

START RUN
-> build run state from profile bonuses
-> generate seeded map
-> reveal center neighbors
-> wait for tile selection

ON TILE SELECT
-> preview tile risk and reward
-> commit selection
-> resolve tile by mode
   -> combat: run arena simulation, apply rewards or death
   -> event: present 2 choices, apply chosen outcome
   -> utility: grant reward, heal, shop, reveal
-> mark tile captured if successful
-> update danger, XP, currencies, boss threshold
-> if level-up threshold reached, show upgrade choice
-> if boss threshold reached, place or open next boss gate
-> reveal new frontier tiles
-> if player dead: end run
-> if final boss dead: clear run
-> loop

END RUN
-> calculate essence and sigils
-> save profile
-> show result screen
-> optionally show rewarded ad
-> return to home or meta
```

**Default Repository Structure**

```text
project.godot
agent.md
image_prompts.md
assets/
  backgrounds/
  bosses/
  characters/
  effects/
  icons/
  tiles/
  ui/
data/
  bosses.json
  enemies.json
  events.json
  relics.json
  tiles.json
  upgrades_meta.json
scenes/
  app/
  combat/
  map/
  meta/
  ui/
scripts/
  autoload/
  combat/
  data/
  map/
  meta/
  ui/
tests/
  test_runner.gd
  test_combat_math.gd
  test_map_generation.gd
  test_save_load.gd
```

## 19. Agent Execution Plan (CRITICAL)

### Agent Workflow Rules

- Start by reading `agent.md` and inspecting the current repository tree.
- Implement one vertical slice at a time.
- Do not create art-generation scripts before the gameplay loop is running with placeholders.
- Never combine system creation, balance tuning, and monetization changes in one pass.
- Keep pure logic in service scripts and scene behavior in controller scripts.
- Before modifying an existing file, read the whole file and preserve public interfaces unless a migration is included.
- After every completed task, run the smallest relevant test set immediately.
- If a system is unfinished, leave it behind a stable stub, not a broken partial integration.

### Task Execution Loop

1. Inspect impacted files and related data definitions.
2. Define the smallest shippable subtask.
3. Implement the subtask completely.
4. Run targeted validation.
5. Fix failures before moving to the next subtask.
6. Commit only when the game still boots and tests pass.
7. Repeat until the current phase deliverable is complete.

### File Generation Strategy

**Build First**

1. Create project skeleton and autoload services.
2. Create data files for tiles, enemies, events, bosses, relics, and meta upgrades.
3. Create the profile save system and run state container.
4. Create the home screen and scene router.
5. Create the map scene and tile selection loop.
6. Create the combat resolver and arena scene.
7. Create the result screen and meta upgrade screen.
8. Create tests and simulation helpers.
9. Integrate placeholder assets.
10. Add production content in layers.

**Files To Create First**

```text
project.godot
image_prompts.md
scenes/app/main.tscn
scripts/autoload/game_state.gd
scripts/autoload/save_service.gd
scripts/autoload/data_service.gd
scripts/autoload/rng_service.gd
scripts/autoload/ad_service.gd
data/tiles.json
data/enemies.json
data/events.json
data/bosses.json
data/relics.json
data/upgrades_meta.json
scenes/ui/home_screen.tscn
scripts/ui/home_screen.gd
scenes/map/run_scene.tscn
scripts/map/run_controller.gd
scripts/map/map_generator.gd
scripts/map/tile_resolver.gd
scenes/combat/combat_scene.tscn
scripts/combat/combat_resolver.gd
scripts/combat/combat_actor.gd
scenes/meta/meta_screen.tscn
scripts/meta/meta_screen.gd
scenes/ui/result_screen.tscn
scripts/ui/result_screen.gd
tests/test_runner.gd
tests/test_combat_math.gd
tests/test_map_generation.gd
tests/test_save_load.gd
```

### Validation Strategy

**How To Test**

- Boot test:
  - run `godot4 --headless --path . --quit`
- Unit tests:
  - run `godot4 --headless --path . --script res://tests/test_runner.gd`
- Simulation test:
  - simulate 50 seeded runs without rendering
  - assert no crash, no soft-lock, no negative currency, no empty selectable frontier before boss gate
- Save test:
  - serialize and reload profile and active run snapshot
- Combat test:
  - compare deterministic damage outputs for fixed seeds
- UI smoke test:
  - ensure Home -> Run -> Result -> Meta -> Home navigation works without null references

**Validation Gates Per Task**

- New data file: schema load test must pass
- New combat mechanic: combat math test and one seeded arena simulation must pass
- New map rule: map generation test must pass for 100 seeds
- New UI screen: navigation smoke test must pass
- Monetization change: mock `AdService` integration test must pass and gameplay must still function with ads disabled

**Asset Legal Review Gate**

- Check every generated asset for resemblance to known copyrighted characters, franchise props, logos, or branded symbols.
- Check every generated asset for accidental text, watermark, signature, or hidden mark artifacts.
- Reject any asset that looks too close to an existing commercial game UI, icon set, boss silhouette, or faction design.
- Record rejected outputs and the reason for rejection so the next prompt revision becomes stricter, not looser.

### How To Iterate

1. Finish the current phase with placeholder art first.
2. Replace placeholders only after logic and tests are stable.
3. Tune balance through data files, not script rewrites.
4. When adding content, prefer extending existing pools over adding new systems.
5. If a change risks save compatibility, add a version migration before writing new save data.
6. If a feature breaks tests, revert only the feature branch changes and keep the stable base.
7. After each feature set, run one full manual mobile-sized smoke pass in portrait layout.

## 20. Pre-Development Checklist

- [ ] Install Godot 4.3 stable and confirm `godot4` CLI is available.
- [ ] Create the default repository folder structure from Section 18.
- [ ] Configure portrait orientation and mobile stretch settings in `project.godot`.
- [ ] Register autoload singletons: `GameState`, `SaveService`, `DataService`, `RngService`, `AdService`.
- [ ] Create JSON schema expectations for all data files.
- [ ] Add placeholder shapes for tiles, player, enemies, and bosses before real art.
- [ ] Implement save versioning before writing the first save file.
- [ ] Add `tests/test_runner.gd` before phase 1 feature work expands.
- [ ] Approve a legal-safe art policy before generating production art.
- [ ] Ban artist names, franchise names, brand names, logo references, and character references from all image prompts.
- [ ] Require originality review on every generated asset before import into `assets/`.
- [ ] Reject and regenerate any asset containing recognizable IP, text, watermark, signature, or real-person likeness.
- [ ] Define naming conventions:
  - scene files `snake_case.tscn`
  - scripts `snake_case.gd`
  - data IDs `lower_snake_case`
- [ ] Set deterministic fixed combat tick to `0.1`.
- [ ] Confirm all reward and danger values come from data or constants, not scattered literals.
- [ ] Stub `AdService` with editor-safe behavior.
- [ ] Verify the game can boot to Home screen before map work starts.
- [ ] Verify the game can complete one full dummy run before content expansion begins.
