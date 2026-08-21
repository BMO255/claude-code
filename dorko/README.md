# DORKO

A pseudo-3D point-and-click adventure about a turtle who was supposed to be
somewhere. Built in Godot 4 (GDScript only). Surreal, saturated, deadpan —
and something is quietly wrong underneath the cheerfulness.

Every texture, sprite, sound effect, and music loop is **generated
procedurally at runtime** from code. There are no binary assets in this
repository.

---

## Running the game

1. Install [Godot 4.3+](https://godotengine.org/download) (4.3 and 4.4 both
   work; no C#/.NET build needed).
2. Open this folder (`dorko/`) in the Godot project manager (it imports in a
   few seconds), then press **F5** — or from a terminal:

   ```bash
   godot --path dorko            # play
   godot --path dorko --headless --import .          # CI import check
   godot --path dorko --headless -- --smoke          # full headless test pass
   godot --path dorko -- --room kitchen              # boot straight into a room
   ```

The smoke pass tours every room, unit-tests the puzzle math, plays the whole
battle and ending, and exits 0 printing `SMOKE OK`.

## Controls

| Input | Action |
| --- | --- |
| **WASD / arrows** | Walk (clamped to the room's floor) |
| **Left click** | Use current verb on a hotspot / walk to point |
| **Scroll wheel / right click** | Cycle verb: 👁 Eye → ✋ Hand → 👄 Mouth |
| **Click inventory item** | Wield it as the cursor; click a hotspot to use it |
| **Drag item onto item** | Combine (in the inventory bar) |
| **I / Tab** (or hover the bottom edge) | Toggle the inventory bar |
| **Space / Enter / click** | Advance dialogue (first press skips typing) |
| **1–4** | Pick dialogue choices |
| **Esc** | Put item away → close overlay → pause menu (in that order) |
| Battle: **A/D** dodge, **W** block, **LMB/RMB** jab, **Space** star uppercut | (three of these do anything; one of them ends the fight) |

---

## Full walkthrough (spoilers, obviously)

### Room 1 — The Orange Room
1. Dorko wakes up on the carpet. *"...I was supposed to be somewhere."*
2. **Hand** the **Wastebasket** → take the **Crumpled Birthday Card**
   (*"Happy 2nd Birthday Dorko — 07/14"*).
3. **Hand** the **Sun Poster** → the corner peels: a sticky note reads
   *"your birthday backwards"* (sets `saw_note`). The PC's `diary.txt` also
   hints at it.
4. **Hand** the **Keypad Door** and enter **4170** (07/14 backwards).
   Wrong codes get laughed at. The door opens to the Living Room.
5. Optional but load-bearing later:
   - **Mini-Fridge** → **Cold Cheese Slice** (one per game).
   - **PC** → the *Winders XD* desktop: `diary.txt`, `me.bmp`, `sun.bmp`
     (its eyes are open in this one), `hold_music.wav`, `voicemail_3.wav`
     (*"Don't go in the basement."*), the Recycle Bin, and `DO NOT OPEN.exe`
     — dismiss the error three times to reveal `basement_key.png` ("not
     yet.", sets `pc_curiosity`).
   - **Pizza Rolls** → the microwave rhythm game: click when the pink ring
     lands on the gold one. The beat is **600 ms**; a hit is **±100 ms**
     (±40 ms is PERFECT). **10 hits in a row** wins the
     **Perfect Pizza Roll** (`pizza_win`). **3 misses** and the box
     detonates (`pizza_exploded`, permanent carpet stain, box respawns).
     You need the roll for the kitchen cabinet — win eventually.

### Room 2 — The Living Room
1. **Mouth** the **Couch Guy** → *"Could you make me a sandwich."*
   (`knows_sandwich`). Hand on the TV tunes **channel F** (the barks begin).
2. The **Lever** is behind him. He is load-bearing. You are not reaching over.

### Room 2b — The Kitchen (right doorway)
1. **Bread Box** → **Bread**. **Fridge** → **"Meat"** and **Lettuce**
   (the magnets spell EAT; later they spell ATE. Nobody moved them).
2. Use **"Meat"** on the **Cutting Board** → **Sliced "Meat"**.
3. Optional: use **Bread** on the **Toaster** (3 s) → **Toast** — a toasted
   sandwich gets a better reaction.
4. Combine in the inventory: **bread/toast + sliced meat → Sandwich**;
   **+ cold cheese slice → Good Sandwich**; **+ lettuce → Great Sandwich**.
   Any tier works; higher tiers change his thank-you line.
5. Use the **Perfect Pizza Roll** on the **High Cabinet** — its impossible
   heat melts the childproof latch (`cabinet_open`). The roll survives,
   still perfect. Inside: the full **Ramune Bottle** (for the basement).

### Back to the Living Room — Puzzle 2
Use any **sandwich** on the **Couch Guy**. He turns his head for the first
time, takes one bite (*"...Thank you, Will."*), cranks the lever without
looking, the rug snaps open (`couch_fed`) — and down you go.

### Room 3 — The Basement — Puzzle 3 (defuse the Blue Bomb)
1. **Hand** the **Boombox** once (a child's tape: *"dorko dorko dorko"*),
   then again → take the **Cassette Tape**.
2. **Use the Cassette Tape on the Blue Bomb** → jams his wind-up key
   (`key_jammed`). *"Is this what lighter feels like."*
3. Wet the fuse (`fuse_wet`) with **either**:
   - the **Ramune Bottle** (kitchen cabinet), or
   - the **Wet Rag**: take the **Plastic Trophy** (stool by the arcade),
     use it on the **Water Heater** panel (`heater_open`) → **Wet Rag**.
4. **Hand** the **Blue Bomb** → the wire panel. The **VHS shelf** has the
   manual: *CUT RED FIRST* → *"then the one that isn't there"* (there is no
   orange wire — skip straight on) → **YELLOW** → *"blue last obviously"* →
   **BLUE**. So: **RED → YELLOW → BLUE**. GREEN is a trick: a 5-second fake
   countdown that ends in a party horn. Other wrong cuts: bwomp, reset.
5. Defused (`bomb_defused`), he stands, wobbles, and gives you the
   **Wind-Up Key**, mentioning the humming room behind the arcade machine.
6. **Use the Wind-Up Key on GALAXY NIBBLER** → the coin door unlocks, the
   cabinet slides (`arcade_moved`), revealing the **Crawlspace**. Enter it.
   - Flavor: the rotary phone's dial tone becomes the hold music; the
     exercise bike briefly flashes *IT'S DOWN THE HALL.* on the wall; the
     floppies are labeled TAXES, TAXES 2, do not, TAXES 3.

### Room 4 — The Turquoise Room
The Turquoise One delivers its monologue (15 nodes, click through it — it
has *opinions* about the 600 ms interval), then: **ROUND 1**.

**The battle:** it winds up for three dramatic seconds at a time. Click once.
Any jab. It dies in one hit (*"...oh."*), falls like a plank, and the count
runs 1–10… and keeps going to **600**. Ding. **WINER** (then it corrects
itself). If you never attack for 30 seconds, its punch stops an inch from
your visor — *"I can't."* — and it falls anyway.

### The Conclusion
The stairs go up past three windows (the Bomb waves; the Couch Guy is
standing, laughing, eating; the PC plays `voicemail_4.wav`: *"You did it.
Come home."*). At the top: the same door, no keypad. The real Orange Room:
morning light, a real window, a sun with zero teeth, an unopened box, a
birthday card dated **today** — and Dorko takes the shades off. We never see
his eyes. The afro stays. It was never the problem.

**Credits:** the pulse ticks at 600 ms and the credits are clickable — land
**10 on-beat clicks** (±100 ms) before they end and stay for the post-credits
line. Esc skips (and forfeits it).

---

## Every flag

| Flag | Set by |
| --- | --- |
| `intro_done` | Orange Room wake-up beat finished |
| `saw_note` | Peeled the sun poster |
| `orange_card_taken` / `orange_fridge_taken` | One-shot pickups, Room 1 |
| `room1_door_open` | Keypad solved (4170) |
| `pc_curiosity` | Found `basement_key.png` on the PC |
| `pizza_win` / `pizza_exploded` | Pizza roll minigame outcome |
| `knows_sandwich` | Couch Guy asked for a sandwich |
| `sandwich_toasted` | The sandwich was built on toast |
| `couch_fed` | Sandwich delivered; trapdoor open |
| `fridge_opened` | Kitchen fridge opened (EAT → ATE) |
| `kitchen_bread_taken` / `kitchen_meat_taken` / `kitchen_lettuce_taken` / `kitchen_ramune_taken` | One-shot pickups, Kitchen |
| `cabinet_open` | Latch melted by the perfect pizza roll |
| `basement_landed` / `basement_boombox_played` / `basement_tape_taken` / `basement_trophy_taken` / `basement_rag_taken` | Basement beats |
| `key_jammed` → `fuse_wet` → `bomb_defused` | The three defuse steps |
| `heater_open` | Water heater panel pried (wet rag path) |
| `arcade_moved` | GALAXY NIBBLER slid aside |
| `monologue_done` | The Turquoise One finished talking |
| `battle_won` | The fight ended (either path) |
| `game_completed` | Credits finished ("Play Again" on the menu) |

## Every item id

`cold_cheese_slice`, `crumpled_card`, `perfect_pizza_roll`, `bread`, `toast`,
`mystery_meat`, `sliced_meat`, `lettuce`, `sandwich`, `good_sandwich`,
`great_sandwich`, `ramune_bottle`, `cassette_tape`, `plastic_trophy`,
`wet_rag`, `wind_up_key`.

Combinations (`data/items.json`): bread/toast + sliced_meat → sandwich;
sandwich + cold_cheese_slice → good_sandwich; good_sandwich + lettuce →
great_sandwich.

## Project layout

```
scenes/        thin .tscn wrappers (rooms, ui, minigames)
scripts/
  autoload/    the singletons: AssetLib, GameState, Inventory, AudioBus,
               SceneRouter, UILayer, DialogueManager, CursorManager, Fx, Boot
  core/        Painter (pixel canvas), SfxSynth/MusicGen (audio synthesis),
               BaseRoom (pseudo-3D floor + depth sorting + hotspot picking),
               Hotspot, DorkoSprites (generated spritesheet)
  rooms/       one script per room (extend BaseRoom)
  minigames/   keypad, Winders XD desktop, pizza roll, wire panel, battle
  ui/          main menu, ending, credits
actors/        Dorko, Couch Guy, Blue Bomb, The Turquoise One
data/          items.json + dialogue/*.json trees
assets/        the VHS shader (everything else is generated at runtime)
tests/         the headless smoke runner
docs/          CONTRACT.md — the internal API reference
```

Non-obvious math is commented where it lives: the pizza roll's
`Time.get_ticks_msec()` beat window in `scripts/minigames/pizza_roll.gd`,
the perspective floor projection in `scripts/autoload/asset_lib.gd`, and the
depth-scaling formula (0.55 at the back wall → 1.1 at the front edge) in
`scripts/core/base_room.gd`.

## Options

Volume sliders (Master/Music/SFX), text speed, VHS filter toggle (vignette +
chromatic aberration + scanlines), and fullscreen — from the main menu or the
Esc pause menu. Settings persist to `user://settings.json`; the game
autosaves to `user://save.json` on every room change and puzzle flag.
