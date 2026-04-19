# Lekmod: ground truth & low-error workflow (for AI agents)

---

## Repository layout

```
Lekmod/
├── LEKMOD/
│   ├── Override/
│   │   ├── CIV5Units.xml          ← MASTER DATA FILE (~300k lines). Final authority for all gameplay data.
│   │   └── CIV5Units_Mongol.xml   ← All display text (TXT_KEY_* strings). Use <Replace> tags.
│   ├── Art/
│   │   └── No Quitters Mod (v 11)/
│   │       ├── No Quitters Mod (v 11).modinfo   ← Lists all files loaded by the NQM layer
│   │       └── religion/pantheons/*.xml          ← NQM SOURCE files. Mostly dead code for yields (see below).
│   │   └── Lekmod (v 1)/
│   │       └── ...                ← LEKMOD-specific art, unit promotions, etc.
│   └── MPModsPack.Civ5Pkg         ← DLC package; scans Art/ and Lua/ for modinfos
├── LEKMOD_DLL/
│   └── CvGameCoreDLL_Expansion2/  ← C++ DLL source. Compiled separately by user.
└── changelog.txt                  ← Design notes per change. Not always runtime-accurate.
```

---

## Load order — how the game builds its database

**This is the most important thing to understand.**

1. **Base game XML** loads first (vanilla Civ5 BNW tables).
2. **NQM modinfo** (`No Quitters Mod (v 11).modinfo`) loads ~320 files in listed order.
   These include the individual NQM belief files, civ changes, building changes, etc.
   They INSERT and UPDATE rows into the database.
3. **`Override/CIV5Units.xml` loads last.** This is the LEKMOD master file.
   - It declares schema extensions (new columns for LEKMOD DLL features).
   - It opens every major belief yield table with `<Delete />`, wiping all prior rows.
   - It then reinserts the full canonical LEKMOD set for those tables.
   - **Result: CIV5Units.xml owns those tables completely.**

**Confirmed by player observation:** before any LEKMOD changes, Religious Idols showed
+1 faith +1 culture uniformly for gold/silver/copper. NQM's `ReligiousIdols.xml` only
had copper. CIV5Units.xml had all three. The uniform result proves CIV5Units.xml ran last.

---

## Tables fully owned by CIV5Units.xml (via `<Delete />`)

| Table | Line in CIV5Units.xml |
|---|---|
| `Beliefs` (main belief stats + DLL flag columns) | ~28860 |
| `Belief_FeatureYieldChanges` | ~27564 |
| `Belief_ImprovementYieldChanges` | ~27669 |
| `Belief_ResourceYieldChanges` | ~27914 |
| `Belief_BuildingClassYieldChanges` | ~26585 |
| `Belief_BuildingClassHappiness` | ~26514 |

For these tables: **edit only CIV5Units.xml**. Changes to NQM source files (e.g. `EarthMother.xml`,
`ReligiousIdols.xml`, `OceansBounty.xml`) for these tables are wiped at load time and have no effect.

---

## Implementation rules by change type

### Yield changes (belief, improvement, resource, feature, building)
→ **Edit `Override/CIV5Units.xml` only.**
Find the relevant table block, add/modify/remove rows there.
Never touch NQM source files for yields — they're dead code for these tables.

### Display text
→ **Edit `Override/CIV5Units_Mongol.xml` only.**
Use `<Replace Tag="TXT_KEY_...">` blocks.
Internal type keys (e.g. `BELIEF_TEARS_OF_NOOBS`) can differ from display names
("Tears of the Gods") — check `CIV5Units_Mongol.xml` for what the player sees.

### New DLL-gated belief feature
Wire 4 places, in this order:

1. **`LEKMOD_DLL/CvGameCoreDLL_Expansion2/_Defines.h`**
   Add: `#define LEKMOD_MY_FEATURE_BELIEF`

2. **`CvBeliefClasses.h`**
   Add getter declaration inside `CvBeliefEntry`: `bool IsMyFeature() const;`
   Add getter declaration inside `CvReligionBeliefs`: `bool IsMyFeature() const;`

3. **`CvBeliefClasses.cpp`**
   - Add private field `m_bMyFeature` (initialized false in constructor, inside `#ifdef`)
   - Add `CvBeliefEntry::IsMyFeature()` getter
   - Add `CvReligionBeliefs::IsMyFeature()` looping getter
   - Add to `CacheResults`: `m_bMyFeature = kResults.GetBool("MyFeature");`

4. **`Override/CIV5Units.xml`** — two places:
   - Schema: add `<Column name="MyFeature" type="boolean" default="0"/>` inside the
     `<Table name="Beliefs">` block (around line 28636)
   - Data: add `<MyFeature>true</MyFeature>` inside the belief's `<Row>` in `<Beliefs>`

5. **Hook location** (CvPlot.cpp, CvCity.cpp, CvUnit.cpp, etc.)
   Add `#ifdef LEKMOD_MY_FEATURE_BELIEF ... #endif` block where the feature fires.

### New belief from scratch (no NQM equivalent)
- Define it entirely in `CIV5Units.xml`: belief row + all yield rows.
- Add text in `CIV5Units_Mongol.xml`.
- No NQM source file needed.

### Existing NQM belief — changing yields
- Change the rows in `CIV5Units.xml` only (the tables with `<Delete />`).
- The NQM source file for that belief is irrelevant for yields.

---

## Yield audit — how to find what X actually yields

For a worked plot:
1. Search `CIV5Units.xml` for the relevant type keys (`RESOURCE_FOO`, `IMPROVEMENT_BAR`, `BELIEF_BAZ`).
2. Check these tables in order:
   - `Terrain_Yields` → `Feature_YieldChanges` → `Resource_YieldChanges`
   - `Improvement_ResourceType_Yields` (improvement + specific resource combo)
   - `Improvement_TechYieldChanges` (tech unlocks extra yield)
   - `Belief_ImprovementYieldChanges`, `Belief_ResourceYieldChanges`, `Belief_FeatureYieldChanges`
   - `Building_SeaResourceYieldChanges`, `Trait_ImprovementYieldChanges`
3. If changelog mentions a DLL hook (e.g. `LEKMOD_FISHING_BOATS_LIGHTHOUSE_PRODUCTION_BELIEF`),
   grep `_Defines.h` and the named DLL file to understand conditions.
4. **Tile yield = sum of all matching rows across all tables.** Never cite one table in isolation.

---

## Common gotchas

- **NQM source XML yield rows are dead code** for the tables listed above. Don't fix "stacking"
  there — the `<Delete />` in CIV5Units.xml already handles it.
- **Changelog ≠ runtime.** Changelog describes intent. If you suspect a mismatch, grep the XML.
- **`<Delete />` without a condition** wipes the entire table. `<Delete BeliefType="X" ...>` deletes
  a specific row. Know which one you're looking at.
- **DLL columns must be schema-declared in CIV5Units.xml** (`<Table name="Beliefs"><Column ...>`)
  or `kResults.GetBool("ColumnName")` silently returns 0 — the feature fires for no belief.
- **Game speeds**: all spec numbers assume Quick speed (67% of Standard). XML values are
  at Standard. Convert: `xml_value = spec_value × 100 / 67`.
- **`BELIEF_TEARS_OF_NOOBS`** is the internal key; display name is "Tears of the Gods". 
  Internal keys in `CIV5Units.xml` ≠ player-visible names in `CIV5Units_Mongol.xml`.
- **CIV5Units.xml has trailing spaces** on many closing tags — use exact surrounding context
  when using Edit tool to target the right block.
