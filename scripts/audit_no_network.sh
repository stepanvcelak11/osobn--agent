#!/usr/bin/env bash
# Bezpečnostní audit sestavené aplikace: žádná analytika, žádné sockety, žádné cizí servery.
# Povolená síťová činnost: jednorázové stažení modelů z huggingface.co a NEPOVINNÝ online vypravěč
# (api.anthropic.com / generativelanguage.googleapis.com), jen když ho hráč sám zapne a vloží svůj klíč.
# Použití: scripts/audit_no_network.sh <cesta k PocketRealm.app>
set -euo pipefail
APP="$1"
NM="${NM:-nm}"
FAIL=0
FORBIDDEN_SYMBOLS='(_socket$|_connect$|_getaddrinfo|_gethostbyname|NSURLConnection|CFSocket|CFHTTP|CFReadStreamCreateForHTTP|_nw_connection|_nw_endpoint|_nw_parameters|_curl_|WebSocket|SFSafariViewController|WKWebView)'
FORBIDDEN_LIBS='(Network\.framework|libcurl|WebKit\.framework|FirebaseCore|Crashlytics|Sentry|Amplitude|Mixpanel|AppsFlyer|Adjust|GoogleMobileAds|FBSDK)'

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

# Adresy v aplikaci: huggingface.co (modely), API online vypravěče a stránky pro získání klíče
MAIN="${bins[0]}"
URLS="$(strings -a "$MAIN" | grep -oE 'https?://[A-Za-z0-9._~:/?#@!$&()*+,;=%-]+' | sort -u || true)"
echo "Adresy v binárce:"; echo "$URLS"
BAD="$(echo "$URLS" | grep -vE '^(https://huggingface\.co/|http://www\.apple\.com/DTDs/|https://api\.anthropic\.com/v1/messages$|https://generativelanguage\.googleapis\.com/v1beta/models/|https://console\.anthropic\.com/settings/keys$|https://aistudio\.google\.com/apikey$)' | grep -v '^$' || true)"
if [ -n "$BAD" ]; then echo "!! nepovolené adresy:"; echo "$BAD"; FAIL=1; fi
for b in "${bins[@]:1}"; do
  if [ -f "$b" ] && "$NM" -u "$b" 2>/dev/null | grep -E '(NSURLSession|URLSession)'; then echo "!! síťový kód v knihovně $b"; FAIL=1; fi
done

# Info.plist: žádné výjimky ATS, žádné background režimy, sdílení souborů vypnuto
PL="$APP/Info.plist"
if /usr/libexec/PlistBuddy -c 'Print NSAppTransportSecurity' "$PL" >/dev/null 2>&1; then echo "!! NSAppTransportSecurity výjimka"; FAIL=1; fi
# Hra nepotřebuje žádný běh na pozadí
if /usr/libexec/PlistBuddy -c 'Print UIBackgroundModes' "$PL" >/dev/null 2>&1; then echo "!! UIBackgroundModes není povoleno"; FAIL=1; fi
if [ "$(/usr/libexec/PlistBuddy -c 'Print UIFileSharingEnabled' "$PL" 2>/dev/null)" = "true" ]; then echo "!! UIFileSharingEnabled"; FAIL=1; fi

if [ $FAIL -ne 0 ]; then echo "AUDIT SELHAL"; exit 1; fi
echo "AUDIT OK: síť jen pro stažení modelů a volitelného online vypravěče, žádná analytika, žádné výjimky v Info.plist."
