EMBER — Game Design Document

**EMBER**

*Working Title*

**Game Design Document**

A reverse-survivor arena game where you ARE the fire.

Version 0.3  •  Engine: LÖVE2D (Lua)  •  Single-player

# 1. High Concept

You are a fire. Your goal is to burn the town to the ground before it can be extinguished. You hop from building to building, growing larger and more dangerous as you consume the town, while waves of defenders — first startled occupants with buckets, then organized neighbors, then the fire department — try to put you out.

Structurally this inverts the Vampire Survivors formula. Instead of a lone survivor mowing down an endless horde, the player is the overwhelming force and the world is trying to stop them. The core skill is choosing which building to burn next and when to commit to the hop.

## Pillars

- Growth as power — bigger fire means more reach, more douse resistance, faster catch. Higher level is always better.

- Every hop is a decision — there is no automatic spread. Every building that burns is one the player chose to burn. The path of destruction is the player's authorship.

- Escalating response — the more you burn, the faster and harder the town reacts. Burning fast brings the fire department sooner.

- Short, replayable runs — a run lasts 10–20 minutes and ends in total burn or the fire going out.

# 2. Core Gameplay Loop

- Hop — the player chooses a target building and jumps to it. This is the only action.

- Feed — the fire burns the building, climbing in Fire Level up to that building's cap.

- Earn — burning buildings and NPCs awards Heat.

- Level up — accumulated Heat triggers an upgrade pick.

- Escalate — defenders respond with increasing force as the town burns.

- Resolve — the run ends when the whole town is ash (win) or the fire burns out (loss).

The minute-to-minute decision is which building to hop to next and when. Hopping drops a Fire Level, so committing to a large building first — even if it's slow — is often smarter than chaining small ones and staying weak. The fire is constantly losing Intensity to water, so every idle moment is dangerous.

# 3. The Player: The Ember

The player is a single ember. The fire exists on exactly one building at a time. There is no automatic spread — every building that burns is one the player hopped to. When the current building finishes burning, the player must hop or the fire dies.

## Fire Levels

The fire's power is expressed as discrete Fire Levels (1, 2, 3). The prototype uses 3 levels; treat the ceiling as a configurable value, not a hard-coded constant.

- Level 1 is the floor. The fire can never drop below level 1.

- Hopping always drops the fire one level (3→2, 2→1). At level 1, hopping keeps you at level 1.

- The fire climbs back up by burning through a building. A building's size caps how high you can climb: shack = 1, medium house = 2, mansion = 3.

- A level-1 ember hopping into a mansion can climb all the way to 3 as it burns, but the mansion is slow — you're exposed for a long time getting there.

## What Each Level Governs

| **Property** | **Effect of higher level** |
| --- | --- |
| Hop range | Bigger fire reaches further; only level 3 can leap a river. |
| Douse resistance | Higher level loses less Intensity to water. A level-1 fire near a river is in real danger. |
| Catch speed | Higher level catches a new building faster. |
| NPC flee threshold | Higher-level fires cause NPCs to abandon dousing and flee sooner. |

## Other Stats

| **Stat** | **Meaning** |
| --- | --- |
| Intensity | The fire's health. Drained by water, restored by burning fresh fuel. Hits 0 = fire goes out = loss. |
| Heat | Score currency earned from burning buildings and NPCs. Drives upgrade level-ups. |

Note: Fire Level (power, 1–3) and Heat level-ups (upgrades) are two separate systems. Fire Level changes every time you hop or feed; upgrade picks are permanent for the run.

## Controls

- Hop — aim at a valid nearby building and confirm the jump. This is the only action.

- Valid targets glow / show an ember arc; out-of-range targets are visually dimmed.

- While burning a building, the fire feeds automatically. No input needed while feeding.

# 4. The Town: The Arena

The map is a tile grid representing a town: houses of three sizes, a fuel depot, trees, roads, a river, and wells.

## Tile Materials

| **Material** | **Flammable?** | **Behaviour** |
| --- | --- | --- |
| Small house (shack) | Yes | Burns fast, caps at Fire Level 1. Quick Heat, little growth. |
| Medium house | Yes | Moderate burn time, caps at Fire Level 2. |
| Large house (mansion) | Yes | Slow burn, caps at Fire Level 3. Best growth, longest exposure. |
| Brick building | Slowly | Needs a higher Fire Level to catch. Big Heat payout. |
| Tree / brush | Yes | Cheap fuel and a hop stepping-stone between districts. |
| Road / pavement | No | Firebreak. The only way across is a hop. Roads are always passable — buildings burn in place and do not collapse onto roads. |
| River / water | No | Hard barrier. Only a level-3 fire can leap it. Fast defender refill along the waterline. |
| Well | No | Mid-map water source. Defenders refill here without walking to the river. Makes the town interior dangerous. See Section 6. |
| Fuel depot | Explosive | Chain-reaction explosion, huge Heat, ignites adjacent buildings instantly. |

## Catch Time

How long a building takes to start burning depends on both its size and the fire's current level. A mansion caught by a level-1 ember is painfully slow; the same fire at level 3 catches it quickly. This discourages hopping into a mansion while small without needing a hard rule against it.

## The River

- Defenders near the river refill effectively without limit, making the waterline very dangerous.

- A level-1 or level-2 fire near the river is at real risk of being extinguished. Douse resistance scales with Fire Level.

- Only a level-3 fire can hop across the river. The hop drops a level, so you land on the far side at level 2 — smaller, right next to fast-refilling defenders.

- The far bank should have a decent building nearby so a deliberate leap can recover; a panicked one strands you small by the water.

## Wells

- Wells give defenders in the town interior the same fast-refill advantage the river gives defenders on the waterline. Without wells, NPCs in the center have to make long trips to the river and are nearly harmless.

- Wells are placed on the map to create pockets of elevated danger inside each district.

- Wells are not flammable and cannot be destroyed. They are permanent map features.

- Wells enable bucket chains to form mid-map, not only along the river.

- Strategic implication: buildings near a well are harder to hold. The player may want to hop through them quickly before defenders can organize, or skip them and circle back at a higher level.

# 5. Hopping & Getting Trapped

Hopping is the entire game. There is no other movement.

- The player is a single ember on one building. When ready, the player hops to a valid nearby building.

- Every hop drops Fire Level by one (floor: level 1).

- The new building's size caps how high you can climb while burning it.

- There is no automatic spread. If the player never hops, the fire burns down the current building and then goes out.

## Getting Trapped

Because firebreaks (roads, rivers, burned-out ash) divide the map and hop range is limited by Fire Level, the fire can run out of reachable targets.

- A small fire with no building in hop range will drain Intensity with nothing to feed on. The fire will eventually go out — the same lose condition as being fully doused, just slower.

- Defenders can create this deliberately by dousing the one 'bridge' building that connects to the next district.

- Telegraphing is essential: reachable vs. unreachable targets must be visually distinct so a trap is something the player sees closing in, not a surprise.

- The escape valve: if you can finish your current building and climb a level, a previously unreachable target may come into range.

## Burning Out

When Intensity reaches 0 — whether from heavy dousing or from running out of fuel with nothing to burn — the fire simply goes out. No special lose state; the fire dies naturally. The results screen shows how much of the town burned.

# 6. Defenders

Defenders try to drain the fire's Intensity. They respond in escalating tiers that mirror how a real community reacts to a fire: panicked occupants first, then organized neighbors, then professionals with equipment.

## NPC Alert Escalation

**Tier 1 — The Occupant (Immediate)**

The moment a building catches fire, everyone inside comes out immediately. They grab whatever is close and try to douse the fire right away.

- Occupants come out at T+0 when their building starts burning.
- Occupancy scales with building size: shacks have 0–1 occupant, medium houses have 1–2, mansions have 3 or more.
- Occupants run to the nearest water source (nearest well, or the river if no well is close).
- At Fire Level 1 or 2, an occupant can meaningfully slow or threaten the fire, especially near a well. At Fire Level 3 they give up and flee.
- An occupant caught by the fire before escaping awards bonus Heat and is removed.

**Tier 2 — The Neighbor (Delayed)**

After a short delay (tunable, target: 5–15 seconds), people in nearby buildings hear or see the fire and come out to help.

- Neighbor response is based on proximity — a radius representing how far the fire's light and noise travel.
- Neighbors use the same bucket-and-refill loop but are calmer and slightly more effective than occupants.
- Neighbors prioritize the nearest water source. Wells in the neighborhood make this wave substantially more dangerous.
- Neighbors flee when the fire reaches level 3 in their immediate vicinity.

**Tier 3 — The Fire Department (Long Delay)**

After a longer delay (tunable, target: 60–120 seconds; shorter if the burn percentage is already high), a fire truck arrives.

- Telegraphed in advance: distant siren audio first, then the truck appears at the map edge on a road.
- The truck drives roads to the fire. Roads are always passable — buildings burn in place and do not block road tiles.
- The truck sprays a wide water cone with very high douse rate. It is the most dangerous single defender.
- A second truck can appear if the fire is very large (% burned threshold).
- A helicopter (late run, high burn %) drops large water payloads on the hottest area.

## Bucket Chains

Bucket chains self-organize. When 3 or more NPCs are within range of the same water source and at least one is actively dousing, they automatically form a relay line. No special trigger or counter needed beyond proximity and activity.

## Full Defender Table

| **Defender** | **Tier** | **Appears** | **Behaviour** | **Threat** |
| --- | --- | --- | --- | --- |
| Occupant | 1 | Immediately when their building burns | Runs to nearest water, douses, repeats until fire too big or caught. Count scales with building size. | Low-Medium — fast but limited. |
| Neighbor | 2 | 5–15s after nearby building catches | Same bucket loop; calmer; self-organizes into chains. | Medium — sustained pressure. |
| Bucket chain | 2 | Auto-forms when 3+ NPCs near same water source | Relay line from water to fire; steady sustained dousing. | Medium-High — sustained drain. |
| Fire truck | 3 | 60–120s after fire starts (sooner at high burn %) | Drives roads (always passable), sprays wide water cone. | High — area denial. |
| Helicopter | 3+ | Late run, high burn % | Drops large water payloads on hottest area. | High — burst damage. |

## Spawn Pressure

- Defender count and tier scale with % of town already burned, not just time. Burning fast brings the fire department sooner.

- Defenders target the highest-intensity fire (the ember), so the player can bait them away from the next target building by staying visible.

- Defenders can douse the 'bridge' building connecting two districts, cutting the player's route forward.

- NPCs caught in the fire award bonus Heat. Letting defenders close has a risk/reward.

- At Fire Level 3, NPCs flee rather than fight. Being huge is its own protection.

## Water Source Priority

NPCs always go to the nearest water source — well or river. NPCs near a well are significantly more dangerous (short refill trips). If a well is surrounded by burning buildings and unreachable, those NPCs fall back to the river and become much weaker. Burning the buildings around a well early can deny defenders that advantage.

# 7. Progression & Upgrades

Heat earned from burning fills an upgrade meter. On level-up the game pauses and the player picks one of three random upgrades. These are permanent for the run.

## Upgrade Pool (initial)

| **Upgrade** | **Effect** |
| --- | --- |
| Hotter Core | +Intensity max; faster catch on brick and resistant structures. |
| Long Jump | +Hop range at every Fire Level. |
| Backdraft | Finishing a building briefly restores Intensity. |
| Soft Landing | Every other hop does not drop Fire Level. |
| Heat Haze | Slows nearby defenders. |
| Greedy Flames | +Heat earned per building. |
| Fireproof Core | +Douse resistance; less Intensity lost to water. |
| Crowd Panic | NPCs flee at a lower Fire Level — defenders give up sooner. |
| Smoke Screen | After a hop, nearby NPCs lose their path briefly. |

## Level Curve

- Heat-to-next-level rises each pick (e.g. cost = base × level^1.4) so early upgrades come fast and later ones reward sustained burning.

- Post-MVP: persistent meta currency between runs to unlock starting upgrades or alternate fire types.

# 8. Win / Loss Conditions

- **Win** — 100% of flammable tiles reduced to ash. Results screen shows total Heat and time.

- **Loss** — Intensity hits 0. The fire goes out. Results screen shows the percentage of town burned.

- **Soft warnings** — when Intensity is critically low OR no building is in hop range, the screen desaturates and audio dampens.

Note: Letter grades are deferred. The results screen for MVP shows Heat and time only.

# 9. Art & Audio Direction

## Visual

- Top-down 2D, clean readable shapes. Tiles are simple silhouettes so fire, water, and smoke read clearly on top.

- Fire is the brightest, most saturated element; everything else is muted so the eye tracks the ember.

- Burn states per tile: intact → scorched → burning → ash. The map visibly darkens as the player wins.

- Particle layers: flame, smoke, embers, water spray. Shaders (heat distortion, glow) are a strong fit for LÖVE2D's GLSL support.

- Occupants (fleeing their own building) and neighbors (running in from nearby) should be visually distinct — different color, shape, or animation — so the player reads the situation at a glance.

- Fire truck: large, road-bound, impossible to miss. Siren light visual + audio before it's on screen.

## HUD: Power Bar

The main UI element is a power bar that shows the fire's current level and progression.

- The bar fills as the fire gains power (burns through the current building, accumulates Heat).
- Three flame icons sit along the bar, one per Fire Level. Each icon is dim/unlit at first and ignites visually when that level is reached.
- At Fire Level 1 the first flame is lit. At level 2 the second lights up. At level 3 all three burn.
- The bar itself should feel hot — orange-to-white gradient, glowing border that intensifies at higher levels.
- Position: bottom-center or bottom-left of screen. Needs to be readable at a glance during intense moments.
- Higher level means you burn buildings faster, so the bar doubling as a speed indicator is accurate.
- When Intensity is critically low (near death), the bar should pulse or dim to signal danger.

## Audio

- Fire roar that rises in pitch and volume with Intensity and Fire Level — the primary feedback for how powerful you are.

- Truck siren audible well before arrival. Helicopter rotor before the drop.

- 'Whoomph' on catching a new building. Explosion stinger for fuel depots.

- NPC audio: alarmed shouts on occupant exit, crowd noise as neighbors gather, a catch-sound when an NPC is consumed.

# 10. Technical Notes (LÖVE2D)

- Engine: LÖVE2D / Lua (LuaJIT). Target 60 FPS.

- Architecture: state-machine scene management (menu / run / results). main.lua thin; one module per system (fire, grid, defenders, upgrades, ui).

- Grid model: 2D array of tile structs (material, burnState, intensity). Since there is no auto-spread, the grid update loop is simple: one active burning tile, drain its burn timer per tick, done. No active-edge pass needed until auto-spread is added.

- NPC model: each NPC has a simple state machine — idle → alarmed → moving-to-water → dousing → moving-to-fire → dousing → flee. Transitions driven by proximity to the ember and current Fire Level. Cap active NPCs at 20–30 for performance and readability.

- Fire truck pathfinding: road tiles are always valid. Buildings burn in place; road tiles adjacent to burning buildings remain passable. Simple road-graph pathfinding is sufficient.

- Use middleclass for entity OOP. Consider STI + Tiled for the map.

- Collision: tile-coordinate checks only. No Box2D needed.

# 11. MVP Scope (First Playable)

| **In MVP** | **Deferred** |
| --- | --- |
| One hand-built town map | Procedural / multiple maps |
| Three house sizes + road + river + 2–3 wells | Brick, fuel depot, trees |
| Fire Levels 1–3 + hopping (level cost & regrowth) | Auto-spread (possible future mechanic) |
| Occupant + neighbor NPC escalation (Tiers 1 & 2) | Bucket chain visual polish |
| Fire truck (Tier 3) | Helicopter |
| River leap (level 3 only) + well douse-boost | Multiple simultaneous embers |
| 4 upgrades | Full upgrade pool + meta progression |
| Win/loss + basic results (Heat + time) | Letter grades, stats, unlocks |
| Placeholder shapes + particles | Polished art, shaders, full audio |

# 12. Suggested Build Order

- Grid + tile rendering; hand-built map with three house sizes, roads, river, and 2–3 wells.

- Single ember on one building; burn timer drains over time; building removed on completion.

- Fire Levels: climbing while burning, capped by building size; render level clearly at all times.

- Hopping: aim at valid target, confirm; drops one level (floor 1); telegraph valid vs. out-of-range targets.

- Intensity: drains from water (and optionally from time); restore by feeding on a building; fire goes out at 0.

- Occupant NPCs: come out immediately when their building burns; run to nearest water (well or river); douse loop.

- Neighbor NPCs: delayed response based on proximity radius; same bucket loop; self-organize into chains at 3+.

- Fire truck: arrives after tunable delay; shorter delay at high burn %; drives roads; high douse rate.

- Heat + upgrade level-up pause menu with 4 upgrades.

- Win (100% ash) + loss (Intensity = 0) + results screen (Heat, time, % burned).

- Juice pass: particles, screen shake, fire roar scaling with Fire Level, smoke.

# 13. Open Questions for the Build

- **Intensity time-drain** — Does Intensity drain slowly from time alone (fire always needs fuel), or only from water? Time-drain makes the fire feel hungry and prevents the player from stalling indefinitely. Recommendation: slow ambient drain + water drain.

- **NPC flee threshold** — At what Fire Level do NPCs abandon their buckets? Starting point: flee when the fire on their current tile is level 3, or when a level-3 fire is adjacent to them.

- **Hop range definition** — Tile radius per Fire Level, or a list of valid target types? Recommendation: tile radius. Simple and visually readable.

- **Map format** — Tiled + STI, or Lua table? Recommendation: Tiled for faster visual iteration on layout.

- **River leap landing** — Is a safe landing guaranteed by map design, or is stranding possible? Recommendation: authored map ensures a decent building on the far bank for MVP.

- **Auto-spread (future)** — Not in MVP. When added later, it will need its own design pass on cost, level interaction, and what "the player tile" means in that context.

# 14. Remaining Design Gaps

**1. NPC count cap**
With occupants scaling to building size and neighbors also responding, active NPC count can spike near a dense block with a well. Set a cap (recommended: 20–30 active NPCs) and an overflow rule (new NPCs do not spawn until one is caught or flees off-map).

**2. Map layout principles**
Lock these in before building the map: (a) first district has no wells, sparse defenders — the player learns the hop loop; (b) wells appear in the second district; (c) the river divides the map roughly in half, making the level-3 leap a late-mid-game decision; (d) the fire truck arrives after the player has enough road cleared for it to realistically pathfind in.

**3. Bucket chain visual**
Self-organizing chains need a clear visual read. When a chain forms, the relay line (NPCs positioned between water and fire) should be immediately recognizable as a coordinated threat, not just a crowd of individuals.
