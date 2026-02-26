# Cogwheel Recruiter - Changelog v1.2

## Highlights
- Optimized core logic through broad modularization of the addon runtime and UI orchestration.
- Improved scanner and quick-scanner stability and consistency.
- Refined onboarding/opening behavior and minimap routing.

## Core Improvements
- Split main addon logic into focused modules/controllers for bootstrap, scanning, tab shell, scanner views, history/whispers, and settings/stats/guild wiring.
- Reduced complexity of the main Lua entry file and improved maintainability for future features.
- Kept deploy/publish configuration in sync with all new modules.

## Scanner and Quick Scanner
- Improved WHO scan timeout handling and flow reliability.
- Improved quick queue refill and zone progression behavior.
- Simplified quick scanner wrappers and delegated more flow to dedicated engine/controller modules.
- Improved no-result and queue-ready state messaging behavior.

## Whispers and Messaging
- Modularized whisper inbox handling and unread flash behavior.
- Added/improved quick scanner whispers-tab flash behavior for unread replies.
- Centralized whisper sending and delayed welcome message logic in dedicated messaging module.
- Added debug self-reply routing hooks to support safer local testing workflows.

## Settings, Stats, Guild, and History
- Modularized settings/filters tab wiring and helper exports.
- Modularized stats and guild tab wiring and refresh/update hooks.
- Modularized history rendering/wiring and related actions.
- Modularized guild report generation/adapters and improved separation of concerns.

## UX and Flow Fixes
- Fixed welcome/minimap routing edge case so right-click flow returns to quick scanner path correctly.
- Improved tab/window routing separation for cleaner behavior across main/quick/welcome contexts.
- General cleanup and consistency refinements across scanner, whispers, history, and settings flows.
