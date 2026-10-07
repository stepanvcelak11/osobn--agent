#!/usr/bin/env bash
# Bezpečnostní audit sestavené aplikace: nesmí obsahovat síťový kód ani analytiku.
# Použití: scripts/audit_no_network.sh <cesta k OsobniAgent.app>
set -euo pipefail
APP="$1"
NM="${NM:-nm}"
FAIL=0
FORBIDDEN_SYMBOLS='(_socket$|_connect$|_getaddrinfo|_gethostbyname|NSURLSession|NSURLConnection|URLSession|CFSocket|CFHTTP|CFReadStreamCreateForHTTP|_nw_connection|_nw_endpoint|_nw_parameters|_curl_|WebSocket|SFSafariViewController|WKWebView)'
FORBIDDEN_LIBS='(Network\.framework|CFNetwork\.framework|libcurl|WebKit\.framework|FirebaseCore|Crashlytics|Sentry|Amplitude|Mixpanel|AppsFlyer|Adjust|GoogleMobileAds|FBSDK)'

bins=("$APP/$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$APP/Info.plist" 2>/dev/null || basename "$APP" .app)")
while IFS= read -r -d '' fw; do
  name="$(basename "$fw" .framework)"; bins+=("$fw/$name")
done < <(find "$APP/Frameworks" -maxdepth 1 -name '*.framework' -print0 2>/dev/null)
while IFS= read -r -d '' ex; do
  name="$(basename "$ex" .appex)"; bins+=("$ex/$name")
done < <(find "$APP/PlugIns" -maxdepth 1 -name '*.appex' -print0 2>/dev/null)

for b in "${bins[@]}"; do
  [ -f "$b" ] || { echo "chybí binárka: $b"; continue; }
  echo "== $b"
  if "$NM" -u "$b" 2>/dev/null | grep -E "$FORBIDDEN_SYMBOLS" ; then
    echo "!! zakázané síťové symboly v $b"; FAIL=1
  fi
  if otool -L "$b" | grep -E "$FORBIDDEN_LIBS"; then
    echo "!! zakázaná knihovna v $b"; FAIL=1
  fi
done

# Info.plist: žádné výjimky ATS, žádné background režimy, sdílení souborů vypnuto
PL="$APP/Info.plist"
if /usr/libexec/PlistBuddy -c 'Print NSAppTransportSecurity' "$PL" >/dev/null 2>&1; then echo "!! NSAppTransportSecurity výjimka"; FAIL=1; fi
# Povolený je jen režim „audio“ (nahrávání přednášky při zamčeném telefonu)
MODES="$(/usr/libexec/PlistBuddy -c 'Print UIBackgroundModes' "$PL" 2>/dev/null | grep -vE '^(Array \{|\})$' | tr -d ' ' || true)"
for m in $MODES; do
  if [ "$m" != "audio" ]; then echo "!! nepovolený UIBackgroundModes: $m"; FAIL=1; fi
done
if [ "$(/usr/libexec/PlistBuddy -c 'Print UIFileSharingEnabled' "$PL" 2>/dev/null)" = "true" ]; then echo "!! UIFileSharingEnabled"; FAIL=1; fi

if [ $FAIL -ne 0 ]; then echo "AUDIT SELHAL"; exit 1; fi
echo "AUDIT OK: žádný síťový kód, žádná analytika, žádné výjimky v Info.plist."
