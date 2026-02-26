#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_PATH="${CONFIG_PATH:-$REPO_ROOT/deploy.config.json}"

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Deploy config not found at '$CONFIG_PATH'. Copy deploy.config.example.json to deploy.config.json and set wowDir." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to parse deploy config JSON." >&2
  exit 1
fi

WOW_DIR_INPUT="${1:-}"

mapfile -t CONFIG_LINES < <(python3 - "$CONFIG_PATH" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

print(cfg.get("wowDir", ""))
print(cfg.get("addonRelativePath", "Interface\\AddOns\\CogwheelRecruiter"))
for item in cfg.get("include", []):
    print(item)
PY
)

CONFIG_WOW_DIR="${CONFIG_LINES[0]:-}"
ADDON_RELATIVE_PATH="${CONFIG_LINES[1]:-Interface\\AddOns\\CogwheelRecruiter}"
INCLUDE_PATHS=("${CONFIG_LINES[@]:2}")

if [[ -z "$WOW_DIR_INPUT" ]]; then
  WOW_DIR_INPUT="$CONFIG_WOW_DIR"
fi

if [[ -z "$WOW_DIR_INPUT" ]]; then
  echo "Missing WoW directory. Pass it as argument or set wowDir in deploy.config.json." >&2
  exit 1
fi

if [[ ${#INCLUDE_PATHS[@]} -eq 0 ]]; then
  INCLUDE_PATHS=(
    "CogwheelRecruiter.lua"
    "CogwheelRecruiter.toc"
    "CogwheelRecruiter_Constants.lua"
    "CogwheelRecruiter_Defaults.lua"
    "CogwheelRecruiter_Utils.lua"
    "CogwheelRecruiter_Analytics.lua"
    "CogwheelRecruiter_Permissions.lua"
    "CogwheelRecruiter_Messaging.lua"
    "CogwheelRecruiter_QuickScanner.lua"
    "CogwheelRecruiter_Scanner.lua"
    "CogwheelRecruiter_Bootstrap.lua"
    "CogwheelRecruiter_ScanController.lua"
    "CogwheelRecruiter_ScannerQuickViewsController.lua"
    "CogwheelRecruiter_ScannerView.lua"
    "CogwheelRecruiter_QuickScannerView.lua"
    "CogwheelRecruiter_Minimap.lua"
    "CogwheelRecruiter_FrameShell.lua"
    "CogwheelRecruiter_WindowRouting.lua"
    "CogwheelRecruiter_TabShellController.lua"
    "CogwheelRecruiter_TabController.lua"
    "CogwheelRecruiter_WhispersFlash.lua"
    "CogwheelRecruiter_WhispersInbox.lua"
    "CogwheelRecruiter_HistoryWhispersController.lua"
    "CogwheelRecruiter_SettingsStatsGuildController.lua"
    "CogwheelRecruiter_WhispersView.lua"
    "CogwheelRecruiter_TemplatePreview.lua"
    "CogwheelRecruiter_StatsView.lua"
    "CogwheelRecruiter_GuildView.lua"
    "CogwheelRecruiter_SettingsFiltersView.lua"
    "CogwheelRecruiter_HistoryView.lua"
    "CogwheelRecruiter_GuildReports.lua"
    "Media"
  )
fi

to_unix_path() {
  local p="$1"
  if [[ "$p" =~ ^[A-Za-z]:\\ ]] || [[ "$p" == *\\* ]]; then
    if ! command -v wslpath >/dev/null 2>&1; then
      echo "wslpath is required to convert Windows paths in WSL." >&2
      exit 1
    fi
    wslpath -u "$p"
  else
    echo "$p"
  fi
}

WOW_DIR_UNIX="$(to_unix_path "$WOW_DIR_INPUT")"
ADDON_RELATIVE_UNIX="${ADDON_RELATIVE_PATH//\\//}"
DEST_ROOT="$WOW_DIR_UNIX/$ADDON_RELATIVE_UNIX"

mkdir -p "$DEST_ROOT"

echo "Deploying addon files to: $DEST_ROOT"

for rel in "${INCLUDE_PATHS[@]}"; do
  rel_unix="${rel//\\//}"
  src="$REPO_ROOT/$rel_unix"
  dst="$DEST_ROOT/$rel_unix"

  if [[ ! -e "$src" ]]; then
    echo "Configured path '$rel' does not exist in repo." >&2
    exit 1
  fi

  if [[ -d "$src" ]]; then
    rm -rf "$dst"
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
  else
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
  fi

  echo "  copied: $rel"
done

echo "Deployment complete."











