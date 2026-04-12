# Manual testing: city-state quest influence (balance + UI)

This note is for **Windows LEKMOD** playtests (game speed **Quick** is the usual LEKMOD assumption in changelog copy). You cannot run the game on macOS for this; run through the checklist when you are back on a Windows install with LEKMOD loaded.

There are **two separate changes** in two commits:

1. **GlobalDefines** — `MINOR_QUEST_FRIENDSHIP_*` in `LEKMOD/Override/CIV5Units.xml` (quest completion influence).
2. **Lua UI** — `LEKMOD/Lua/UI/CityStateStatusHelper.lua` appends `+N [ICON_INFLUENCE]` next to each active-quest icon and on each quest bullet in the formal tooltip (reads the same values from **`GameDefines`**).

---

## A. Prerequisites

- **Build / install** the LEKMOD version that contains both commits (or at least the commits you intend to ship).
- Start a **new game** (or use a save from **after** loading this mod version) so XML defines and Lua are both current.
- **Quick** speed is enough; defines are **not** scaled by game speed in DLL for quest completion — the number you see in XML is the influence **added on complete** at any speed (changelog still describes “quick” as the design reference).

---

## B. GlobalDefines — did the reward actually change?

These checks confirm **`CvMinorCivQuest::GetInfluenceReward`** (DLL) still reads the same keys you edited in XML.

### B1. Route quest (fixed **40** in current tuning)

1. Meet a maritime (or any) city-state that can offer a **road connection** quest (capital not yet connected by road).
2. Note your **influence** with them (hover meter or diplo line).
3. Complete the quest (road/rail connection when the game counts it satisfied).
4. **Expect:** influence jumps by **exactly 40** (before other modifiers like Patronage, religion anchor, etc. — if you have stacking effects, isolate: fresh game, no policies, no religion).

### B2. Kill barbarian camp (**35**)

1. Get the **clear nearby encampment** quest (very common early).
2. Note influence, kill the camp (unit melee on camp tile as usual).
3. **Expect:** **+35** from that completion notification / before other same-turn changes.

### B3. Trade route quest (**35**)

1. When a CS asks for a **trade route** to them, note influence.
2. Send a caravan/cargo ship; wait until the quest completes (not just route established — follow the normal quest completion flow).
3. **Expect:** **+35**.

### B4. Contest culture / faith / tech (**35** each)

1. Wait for a **global contest** quest (culture / faith / tech). Multiple majors may be in it.
2. **Win** the contest (your delta highest when it resolves).
3. **Expect:** **+35** when the “you won the contest” resolution fires for that CS.

### B5. A generic “−5” line (sanity)

Pick something that used to be **50** and is now **45** (e.g. **bully city-state** quest if you can trigger it safely in a test game), or **connect resource** (**30** vs old **35**):

- Complete one such quest once.
- **Expect:** increment matches the **current** XML value for that `MINOR_QUEST_FRIENDSHIP_*` key (quick spreadsheet: open `CIV5Units.xml` and grep `MINOR_QUEST_FRIENDSHIP_`).

### B6. Invest quest (**0**)

- If you ever see **Invest** active: completing it should **not** grant flat influence from this define (still **0**). Other systems may still change gold-gift efficiency — that is separate.

### B7. Regression: other systems unchanged

- **War quests** (if any) use different defines — not part of this retune; just confirm nothing crashes.
- **No XML truncation:** if the game fails to load assets, verify `CIV5Units.xml` line count is still **~308k** lines and `Colors` / `PlayerColors` blocks intact (once burned by a bad patch — full file should load).

---

## C. Lua UI — do players see `+N` next to quest icons?

**Where:** **City-state diplomacy popup** — the line labeled like “Quests” with the **small icon strip** (`Controls.QuestInfo` in `CityStateDiploPopup.lua`, fed by `GetActiveQuestText`).

### C1. Icon strip (primary ask)

1. Open diplomacy with a CS that has **at least one** displayed quest for you.
2. Look at the **quest icon row** (connected / war / trade / etc.).
3. **Expect:** immediately after each quest-type icon, text like **`+35[ICON_INFLUENCE]`** (green `+` if `[COLOR_POSITIVE_TEXT]` works in that control) where **N** matches `GameDefines["MINOR_QUEST_FRIENDSHIP_*"]` for that quest.
4. If you have **two** active displayed quests, you should see **two** `+N` groups (order follows `ktQuestsDisplayOrder` in `CityStateStatusHelper.lua`).

### C2. Tooltip (same helper)

1. **Hover** the quest icon strip (or the “Information” / quest info control if that opens the same tooltip — follow whatever the popup uses).
2. **Expect:** each **bullet** line for a standard quest ends with the **same `+N [ICON_INFLUENCE]`** suffix before the “turns remaining” clause (if any).

### C3. `GameDefines` missing (fallback behaviour)

If `GameDefines["MINOR_QUEST_FRIENDSHIP_ROUTE"]` (etc.) is **nil** in your build (unlikely for BNW-style data):

- **Expect:** icons still show **without** numbers; no Lua error spam in `Lua.log` (or only a soft failure). If you see errors, copy the stack from `Documents/My Games/Sid Meier's Civilization 5/Logs/Lua.log`.

### C4. Events without define rewards

**Threatening barbarians** and **proxy war** lines still add icons in the strip but **no** `+N` suffix (no matching `MINOR_QUEST_FRIENDSHIP_*` row). Confirm no crash and tooltip still reads sensibly.

### C5. Invest quest (**0**)

- If Invest is displayed: **no** suffix (reward 0 — formatter hides non-positive).

### C6. Other UIs

Only **`CityStateDiploPopup`** includes `CityStateStatusHelper` in this repo path for those functions. If you use **another mod** that also includes the helper, sync the same file or merge manually.

---

## D. Order of operations when you test in three weeks

1. **Load mod** → confirm main menu / mod list shows expected version.
2. **Skim `CIV5Units.xml`** grep `MINOR_QUEST_FRIENDSHIP_` — values should match design (route 40, camp 35, trade 35, contests 35, …).
3. **Quick game** → spawn / meet CS → **UI (C)** first (fast feedback).
4. **Gameplay (B)** with **logging** or careful note of influence before/after one quest type at a time.
5. If anything disagrees: **Lua.log** for UI; **save + version** for DLL/XML mismatches.

---

## E. Files touched (for code review when you return)

| Commit | Files |
|--------|--------|
| Quest balance | `LEKMOD/Override/CIV5Units.xml`, `changelog.txt` |
| Quest UI | `LEKMOD/Lua/UI/CityStateStatusHelper.lua`, `changelog.txt`, `docs/MANUAL_TESTING_CITY_STATE_QUESTS.md` |
