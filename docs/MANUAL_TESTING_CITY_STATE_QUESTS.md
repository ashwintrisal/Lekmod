# Manual testing: city-state quest influence (balance + UI)

This note is for **Windows LEKMOD** playtests when you are back from macOS (roughly **three weeks** out). It ties together **two independent changes** so you do not have to reconstruct intent from memory.

---

## 0. Memory jog — what you are validating

**Problem we solved for players:** quest influence was opaque; tuning lived only in XML/DLL. **UI change:** every standard quest shown on the city-state diplo screen now shows **`+N`** next to the icon and in the formal tooltip, where **N** comes from **`GameDefines["MINOR_QUEST_FRIENDSHIP_*"]`** — the same keys the game uses when the quest **completes**.

**Problem we solved for balance:** those `MINOR_QUEST_FRIENDSHIP_*` numbers were retuned (separate commit). **Gameplay check:** when a quest completes, the **influence bar** should move by **N** from that define (subject to isolation; see §B0).

If **UI shows +40** but **completion only +20**, you have a **DLL vs XML vs Lua** mismatch (wrong mod load order, stale cache, or edited XML not in the build). If **UI matches XML** but **completion differs**, suspect **other systems** same turn (Patronage, religion resting anchor, multiple quests completing, etc.).

---

## A. Prerequisites

- **Build / install** the LEKMOD build that includes:
  - **Commit 1 (balance):** `7154d53` — `CIV5Units.xml` + changelog *CITY-STATE QUEST INFLUENCE REWARDS (GLOBALDEFINES)*.
  - **Commit 2 (UI):** `1f30ea3` (or later on `dev`) — `CityStateStatusHelper.lua` + changelog *CITY-STATE QUEST INFLUENCE (UI)* + this doc.
- Prefer a **new game** started **after** installing that build. Old saves can carry odd state; at minimum note the save’s mod fingerprint.
- **Game speed:** Quick is fine. Quest completion influence from these defines is **not** scaled by game speed in the usual BNW DLL pattern for this hook — the **integer in XML is the completion grant** regardless of Standard/Epic/Marathon. (Changelog still mentions Quick as the design language LEKMOD uses elsewhere.)

### A1. Where logs live (Windows)

Typical paths (Steam):

- **Lua:** `Documents\My Games\Sid Meier's Civilization 5\Logs\Lua.log`
- **Database / mod load issues:** same folder, `Database.log` if present

Before a session: delete or rename `Lua.log`, reproduce once, then open the fresh file — easier than scrolling a huge log.

### A2. Quick file sanity (no truncated XML)

If Civ V fails to load or assets vanish after a bad merge: `CIV5Units.xml` should still be on the order of **~308k+ lines**. A prior accident stripped most of the file — if line count is **~76k**, stop and restore from git before testing.

---

## B. Reference table — expected `MINOR_QUEST_FRIENDSHIP_*` (current tuning)

Use this when comparing **tooltip `+N`**, **XML**, and **observed influence delta** on quest complete.

| Global define | Value | Quest type (informal) |
|---------------|------:|------------------------|
| `MINOR_QUEST_FRIENDSHIP_ROUTE` | 40 | Connect capital by road |
| `MINOR_QUEST_FRIENDSHIP_KILL_CAMP` | 35 | Clear barbarian encampment |
| `MINOR_QUEST_FRIENDSHIP_CONNECT_RESOURCE` | 30 | Connect resource |
| `MINOR_QUEST_FRIENDSHIP_CONSTRUCT_WONDER` | 35 | Build specific wonder |
| `MINOR_QUEST_FRIENDSHIP_GREAT_PERSON` | 30 | Spawn specific GP |
| `MINOR_QUEST_FRIENDSHIP_KILL_CITY_STATE` | 75 | Eliminate target CS |
| `MINOR_QUEST_FRIENDSHIP_FIND_PLAYER` | 30 | Discover civ |
| `MINOR_QUEST_FRIENDSHIP_FIND_NATURAL_WONDER` | 30 | Discover natural wonder |
| `MINOR_QUEST_FRIENDSHIP_GIVE_GOLD` | 15 | Give gold to target major |
| `MINOR_QUEST_FRIENDSHIP_PLEDGE_TO_PROTECT` | 15 | Pledge to protect target |
| `MINOR_QUEST_FRIENDSHIP_CONTEST_CULTURE` | 35 | Win culture contest |
| `MINOR_QUEST_FRIENDSHIP_CONTEST_FAITH` | 35 | Win faith contest |
| `MINOR_QUEST_FRIENDSHIP_CONTEST_TECHS` | 35 | Win tech contest |
| `MINOR_QUEST_FRIENDSHIP_INVEST` | 0 | Invest (no suffix in UI) |
| `MINOR_QUEST_FRIENDSHIP_BULLY_CITY_STATE` | 45 | Bully target CS |
| `MINOR_QUEST_FRIENDSHIP_DENOUNCE_MAJOR` | 35 | Denounce target major |
| `MINOR_QUEST_FRIENDSHIP_SPREAD_RELIGION` | 35 | Spread religion |
| `MINOR_QUEST_FRIENDSHIP_TRADE_ROUTE` | 35 | Establish trade route to CS |

**War / special quests** may use other code paths; this table is the **standard** `MinorCivQuestTypes` set wired in `GetQuestInfluenceDefineKey` in Lua.

### B0. Isolating “exactly +N” on completion (important)

The **number on the UI** is the **raw define**. Your **visible influence** can still change for other reasons **the same turn**:

- **Another quest** completes the same turn → sum of rewards.
- **Patronage** (or other policies) changing resting influence or completion bonuses.
- **Religion / resting influence “anchor”** tooltip math (your other CS work) — the bar is not always a simple “old + quest only”.
- **First meeting** or **era** transitions unrelated to the quest.

**Clean test recipe:** tiny duel or pangaea, **Immortal or lower**, **no religion** (or ignore religion CS), **avoid opening Patronage**, meet **one** CS, **complete only one** quest type, **save the turn before** completion, note influence from the **diplo line or hover**, then **load → complete → re-check** same screen.

If you cannot isolate, still check: **UI `+N` equals XML**; then separately “completion feels in the ballpark” — file a bug with **save + mod list** if completion is wildly off with isolation.

---

## C. GlobalDefines — did the reward actually apply in-game?

These checks confirm the DLL still reads the same keys as XML (`CvMinorCivQuest::GetInfluenceReward` in LEKMOD DLL sources).

### C1. Route quest (**40**)

1. Meet a CS offering **road connection to capital** (often early maritime).
2. **Save** one turn before the last tile connects.
3. Note **influence** (write the integer down).
4. Complete connection; on the **quest complete** notification turn, note influence again.
5. **Expect:** **+40** delta from that quest alone under isolation (§B0).

### C2. Kill barbarian camp (**35**)

1. Early game CS with **clear encampment**.
2. Save adjacent to camp, note influence, melee the camp.
3. **Expect:** **+35**.

### C3. Trade route quest (**35**)

1. CS asks for **international trade route** to them.
2. Note influence before the game marks the quest **completed** (sometimes one turn after the unit arrives).
3. **Expect:** **+35** at completion.

### C4. Contest culture / faith / tech (**35** each)

1. Wait for a **global contest**; ensure you **win** when it resolves.
2. **Expect:** **+35** from that CS for that contest type.

### C5. Spot-check a “retuned” line

Examples: **connect resource 30**, **bully 45**, **denounce 35** — pick whichever you can trigger without breaking the test save.

### C6. Invest (**0**)

- UI: **no `+N` suffix** next to invest icon.
- Gameplay: no flat influence from this define on invest complete (other gold mechanics unchanged).

### C7. Regression smoke

- No CTD opening CS diplo with **0**, **1**, or **2+** quests.
- **Barbarian threat** / **proxy war** event icons still appear; no `+N` on those lines.

---

## D. Lua UI — icon strip and tooltip

**Surface:** **City-state diplomacy popup** — quest **icon row** (`GetActiveQuestText`) and **hover formal list** (`GetActiveQuestToolTip`), both in `CityStateStatusHelper.lua`.

### D1. Icon strip

1. Open diplomacy with a CS that has **at least one** displayed quest for you.
2. After each **standard** quest icon, expect a green **`+`** then **N** then **influence icon** (implementation: `[COLOR_POSITIVE_TEXT]+N[ENDCOLOR][ICON_INFLUENCE]`).
3. **Two quests** → two suffixes; order matches **`ktQuestsDisplayOrder`** in the helper (not necessarily quest-assignment order).

### D2. Tooltip bullets

1. Hover the control that shows the **formal** multi-line quest text (same popup).
2. Each **bullet** line for a standard quest should end with the **same `+N` suffix** as the strip for that type, **before** “(N turns remaining)” if that clause exists.

### D3. Events without defines

**Threatening barbarians** and **proxy war:** icons/tooltip lines **without** `+N` — by design (no `MINOR_QUEST_FRIENDSHIP_*` mapping in Lua).

### D4. Missing `GameDefines` (edge build)

If a define key were missing: suffix should be **empty**, icons still render; scan **Lua.log** for errors.

### D5. Other mods

Another mod that **overrides** `CityStateStatusHelper.lua` without merging will **hide** this feature. Check **Mods → installed** load order if numbers never appear.

---

## E. Order of operations (when you sit down in three weeks)

1. Confirm **git / build** has both commits above.
2. **Grep XML** (repo or installed override) for `MINOR_QUEST_FRIENDSHIP_` — values match §B table.
3. **New quick game** → meet CS → **UI (D)** first (30 seconds of feedback).
4. **Gameplay (C)** with **save before complete** for at least **camp** and **route** (fastest repro).
5. On mismatch: **Lua.log** + **save** + **screenshot** of diplo line (influence) before/after.

### E1. Repo grep (from dev machine)

From repo root:

```bash
grep -n "MINOR_QUEST_FRIENDSHIP_" LEKMOD/Override/CIV5Units.xml | head -40
```

On Windows without Git Bash, use findstr / PowerShell Select-String on the same path inside your checkout.

---

## F. Files touched (code review)

| Area | Files |
|------|--------|
| Quest balance | `LEKMOD/Override/CIV5Units.xml`, `changelog.txt` |
| Quest UI + doc | `LEKMOD/Lua/UI/CityStateStatusHelper.lua`, `changelog.txt`, `docs/MANUAL_TESTING_CITY_STATE_QUESTS.md` |

---

## G. Bug report template (paste into issue / notes)

- **Build / branch / commit:**  
- **Game speed:**  
- **Quest type:**  
- **XML value for that define (from installed file):**  
- **UI showed +N:**  
- **Influence before / after (if measured):**  
- **Policies / religion / other mods:**  
- **Lua.log excerpt (if any):**  
