# Cogwheel Recruiter Modularization Plan

## Objectives

- Reduce risk from a single large `CogwheelRecruiter.lua` file.
- Keep behavior 100% equivalent during refactors.
- Make future features easier to ship and review.
- Keep deployment/release scripts aligned with module changes.

## Non-Goals

- No UI redesign as part of modularization.
- No feature changes unless needed for safe extraction.
- No SavedVariables schema changes.

## Safety Rules

- Extract in small, testable slices.
- Preserve function signatures and call sites in main file via wrappers first.
- Commit after each pass.
- After each pass, run in-game smoke tests before continuing.
- If a pass causes runtime errors, rollback that pass only.

## Current Baseline

Already extracted modules:

- `CogwheelRecruiter_Constants.lua`
- `CogwheelRecruiter_Defaults.lua`
- `CogwheelRecruiter_Utils.lua`
- `CogwheelRecruiter_Analytics.lua`

Main file remains large and still owns most UI + scan flow orchestration.

## Target Module Layout

### Core and Data

- `CogwheelRecruiter_Constants.lua` (existing)
- `CogwheelRecruiter_Defaults.lua` (existing)
- `CogwheelRecruiter_Utils.lua` (existing)
- `CogwheelRecruiter_Analytics.lua` (existing)
- `CogwheelRecruiter_Permissions.lua` (planned)
  - Guild membership and invite permission checks
  - Recruitment capability checks
- `CogwheelRecruiter_Messaging.lua` (planned)
  - Whisper/welcome message building and send helpers

### Domain / Feature Modules

- `CogwheelRecruiter_GuildReports.lua` (planned)
  - Class/level distribution aggregation
  - Guild chat report line packing/sending
- `CogwheelRecruiter_QuickScanner.lua` (planned)
  - Queueing, zone priority, refill logic
- `CogwheelRecruiter_Scanner.lua` (planned)
  - Full scan sequencing and zone iteration
- `CogwheelRecruiter_History.lua` (planned)
  - Invite history formatting and update helpers
- `CogwheelRecruiter_Whispers.lua` (planned)
  - Whisper reply ingestion, unread state, tab pulse logic

### UI Modules (late phase)

- `CogwheelRecruiter_UI_Frame.lua` (planned)
  - Main frame, quick frame shell, top-level chrome
- `CogwheelRecruiter_UI_Settings.lua` (planned)
- `CogwheelRecruiter_UI_Filters.lua` (planned)
- `CogwheelRecruiter_UI_Stats.lua` (planned)
- `CogwheelRecruiter_UI_Guild.lua` (planned)
- `CogwheelRecruiter_UI_Scanner.lua` (planned)
- `CogwheelRecruiter_UI_QuickScanner.lua` (planned)
- `CogwheelRecruiter_UI_Whispers.lua` (planned)

## Ordered Pass Plan

### Pass 1 (Now): Guild report extraction (low risk)

- Create `CogwheelRecruiter_GuildReports.lua`.
- Move:
  - guild class/level count builders
  - report line chunking
  - report send helper
  - class/level segment builders
- Main file keeps wrapper functions so existing call sites remain unchanged.
- Add module to `.toc` and deploy includes.

In-game tests after pass:

1. Open addon and switch to `Guild` tab.
2. Toggle class/level views and verify charts/legends render.
3. Use both report buttons and verify guild chat lines appear with expected formatting.
4. Verify no Lua errors on tab switching.

### Pass 2: Permissions + messaging extraction

- Extract permission checks and recruit availability.
- Extract welcome/whisper send flow helpers with context injection.
- Keep UI gating logic unchanged.

In-game tests:

1. Splash behavior (has guild / no guild / no invite perms).
2. Scanner + Quick Scanner invite/whisper button enabled states.
3. Auto welcome message (2s delay) still works.

### Pass 3: Quick Scanner engine extraction

- Move queue, zone prioritization, refill logic into module.
- Keep quick UI in main file initially.

In-game tests:

1. `Scan Next` fills queue without double-press.
2. Candidate rotation works with level/class filters.
3. Faction/zone priority behavior remains correct.

### Pass 4: Full scanner flow extraction

- Move full scan sequence and WHO result handling into module.

In-game tests:

1. Zone scan runs and result list updates.
2. Invite/Whisper actions from Scanner list still work.

### Pass 5: UI split by tab/frame

- Move UI construction and tab-specific render/update code into UI modules.
- Keep one orchestration file that wires events and module contexts.

In-game tests:

1. Full navigation across all tabs.
2. Minimap open behavior (left main, right quick).
3. No visual regressions in header/footer/buttons.

## TOC and Deployment Discipline

Whenever a new module is added:

1. Add it to `CogwheelRecruiter.toc` in dependency-safe order.
2. Add it to deploy include defaults:
   - `deploy.config.example.json`
   - `scripts/deploy.ps1` fallback include list
   - `scripts/deploy.sh` fallback include list
3. Keep local `deploy.config.json` include list in sync (not committed).

## Definition of Done for Modularization

- Main file reduced to orchestration glue only.
- All major domain flows live in dedicated modules.
- No feature regressions across Scanner/Quick/Whispers/Invites/Settings/Filters/Stats/Guild.
- Addon loads without warnings or runtime errors.
- Deploy/publish paths include all required module files.