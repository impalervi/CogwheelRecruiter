# Debug Flags

This file documents temporary debug toggles used during development/testing.

## Location

All current flags are defined in:

- `CogwheelRecruiter.lua`

## Available Flags

| Flag | What It Does | Typical Test Value | Production Value |
|---|---|---|---|
| `FORCE_INVITE_PERMISSION_BYPASS` | Bypasses the guild membership and guild invite permission checks so recruit actions are enabled even without a guild or invite rights. | `true` | `false` |
| `DEBUG_ON_SELF` | Routes addon-generated whispers and guild report output to your own character for safe testing. Message content still resolves tokens for the intended target player. | `true` | `false` |
| `DEBUG_SKIP_INVITE` | Prints the guild invite to chat instead of sending it. | `true` | `false` |
| `DEBUG_ALWAYS_SHOW_WELCOME` | Forces the welcome screen to appear every time addon UI is opened. | `true` | `false` |
| `DEBUG_RESET_WELCOME_ON_LOAD` | Resets `splashSeen` during `ADDON_LOADED` so the welcome flow can be tested on next open. | `true` | `false` |

## Current Notes

- `DEBUG_ON_SELF` impacts:
  - Scanner/Quick Scanner whisper actions
  - Guild report buttons (`Report Class Stats`, `Report Level Stats`)
- `FORCE_INVITE_PERMISSION_BYPASS` affects guild and permission gating across Scanner/Quick Scanner/welcome checks.
- To test without being in a guild, enable `FORCE_INVITE_PERMISSION_BYPASS`, `DEBUG_ON_SELF` and `DEBUG_SKIP_INVITE` together.
- `DEBUG_RESET_WELCOME_ON_LOAD` is only for testing onboarding flow and should not be merged enabled.

## Merge Safety Checklist

Before merging to `main`, verify:

- `FORCE_INVITE_PERMISSION_BYPASS = false`
- `DEBUG_ON_SELF = false`
- `DEBUG_SKIP_INVITE = false`
- `DEBUG_ALWAYS_SHOW_WELCOME = false`
- `DEBUG_RESET_WELCOME_ON_LOAD = false`

