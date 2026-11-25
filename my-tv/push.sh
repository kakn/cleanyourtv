#!/usr/bin/env bash
# My TV (Vestel Cosmos170, Android TV 11): install the launcher built from this fork and push the dark-fantasy
# theme, with plain `adb` (already authorised on the TV) instead of tools/tv.py's own key.
#
#   TV_HOST=<tv ip> my-tv/push.sh            # build output -> TV, set as Home, theme pushed, Home restarted
#   TV_HOST=<tv ip> my-tv/push.sh --theme    # theme only
#
# Android 11 on this TV crashes system_server if a package is replaced or force-stopped while one of its
# accessibility services is bound ("Service not registered: AccessibilityServiceConnection", seen 2026-11-19).
# This launcher's own key helpers stay OFF here (a separate app does the remote buttons), and the script
# refuses to replace or restart the launcher while any com.gathin.tvhome service is enabled.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${TV_HOST:?set TV_HOST to the TV IP address}"
T="$TV_HOST:5555"; A="adb -s $T"; PKG=com.gathin.tvhome
APK=launcher/app/build/outputs/apk/release/app-release.apk
THEME=themes/dark-fantasy
DIR=/sdcard/Android/data/$PKG/files; URI=content://$PKG.theme; TMP=/data/local/tmp/cyt-theme
adb connect "$T" >/dev/null

if $A shell settings get secure enabled_accessibility_services </dev/null | grep -q "$PKG"; then
  echo "ERROR: a $PKG accessibility service is enabled; switch it off and wait for it to unbind first." >&2
  exit 1
fi

if [ "${1:-}" != "--theme" ]; then
  $A install -r --no-incremental "$APK" </dev/null | tail -1
  $A shell am start -W -a android.intent.action.MAIN -c android.intent.category.HOME -n $PKG/.MainActivity </dev/null | grep -E "Status|Error"
  $A shell cmd package compile -m speed -f $PKG </dev/null | tail -1
  $A shell cmd package set-home-activity --user 0 $PKG/.MainActivity </dev/null
  echo "Home: $($A shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME </dev/null | tail -1)"
fi

# Theme: stage each file in /data/local/tmp, write it through the launcher's ThemeProvider (so the launcher
# owns it), fall back to cp. Same layout as tools/theme.sh: files/config.json, files/wallpapers/*.jpg.
put() {   # put <relative path on TV> <local file>
  $A push "$2" "$TMP-${1//\//-}" </dev/null >/dev/null
  $A shell "rm -f $DIR/$1 2>/dev/null; o=\$(content write --uri $URI/$1 < $TMP-${1//\//-} 2>&1); case \"\$o\" in *Error*|*Unsupported*) mkdir -p \$(dirname $DIR/$1); cp $TMP-${1//\//-} $DIR/$1 ;; esac; rm -f $TMP-${1//\//-}" </dev/null
}
$A shell "rm -f $DIR/wallpapers/*.jpg 2>/dev/null; content delete --uri $URI/wallpapers 2>/dev/null" </dev/null || true
put config.json "$THEME/config.json"
for f in "$THEME"/wallpapers/*.jpg; do put "wallpapers/$(basename "$f")" "$f"; done
REV=$(python3 -I -c 'import uuid; print(uuid.uuid4().hex)'); printf '%s' "$REV" > /tmp/cyt-rev.$$
put theme_revision /tmp/cyt-rev.$$; rm -f /tmp/cyt-rev.$$
echo "Theme files on TV: $($A shell "ls $DIR/wallpapers 2>/dev/null | wc -l; content read --uri $URI/config.json 2>/dev/null | head -c 60" </dev/null | tr '\n' ' ')"

# Restart Home so it reads the theme (safe: no accessibility service of this package is enabled, checked above).
$A shell "am force-stop $PKG; am start -W -a android.intent.action.MAIN -c android.intent.category.HOME -n $PKG/.MainActivity" </dev/null | grep -E "Status|Error"
echo "Done."
