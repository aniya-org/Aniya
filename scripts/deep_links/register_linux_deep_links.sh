#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-linux-bundle>" >&2
  echo "Example: $0 build/linux/x64/release/bundle" >&2
  exit 1
fi

BUNDLE_DIR="$(realpath "$1")"
BIN_PATH="${BUNDLE_DIR}/aniya"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Could not find executable at: $BIN_PATH" >&2
  echo "Make sure you pass the folder that contains the built aniya binary." >&2
  exit 2
fi

DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/aniya-deeplinks.desktop"
SCHEMES=(aniyomi tachiyomi mangayomi dar cloudstreamrepo)

mkdir -p "$DESKTOP_DIR"

cat >"$DESKTOP_FILE" <<DESKTOP
[Desktop Entry]
Name=Aniya
Comment=Aniya deep link handler
Exec=${BIN_PATH} %u
Terminal=false
Type=Application
Categories=AudioVideo;Network;
MimeType=x-scheme-handler/aniyomi;x-scheme-handler/tachiyomi;x-scheme-handler/mangayomi;x-scheme-handler/dar;x-scheme-handler/cloudstreamrepo;
NoDisplay=true
DESKTOP

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
else
  echo "update-desktop-database not found; skipping cache refresh." >&2
fi

for scheme in "${SCHEMES[@]}"; do
  if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default "$(basename "$DESKTOP_FILE")" "x-scheme-handler/${scheme}" >/dev/null 2>&1 || true
  else
    echo "xdg-mime not found; register ${scheme} manually with your desktop environment." >&2
  fi
done

echo "Registered deep link handler at $DESKTOP_FILE"
echo "Schemes handled: ${SCHEMES[*]}"
echo "To uninstall, delete the desktop file and run 'xdg-mime default <other-handler> x-scheme-handler/<scheme>' as needed."
