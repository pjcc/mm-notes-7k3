#!/usr/bin/env bash
# Encrypts source/index.html (plaintext, gitignored) into ./index.html with StaticCrypt.
# The password is read with hidden input, typed twice, and handed to StaticCrypt only via
# a one-command environment variable, so it never appears in argv, history or any file.
set -euo pipefail
cd "$(dirname "$0")"

SRC="source/index.html"
OUT="index.html"
STATICRYPT="staticrypt@3.5.4"

if [ ! -f "$SRC" ]; then
  echo "Missing $SRC - nothing to encrypt." >&2
  exit 1
fi

read -r -s -p "Password: " pw1; echo
read -r -s -p "Confirm password: " pw2; echo

if [ -z "$pw1" ]; then
  echo "Empty password - aborted." >&2
  exit 1
fi
if [ "$pw1" != "$pw2" ]; then
  unset pw1 pw2
  echo "Passwords do not match - aborted." >&2
  exit 1
fi
unset pw2

STATICRYPT_PASSWORD="$pw1" npx --yes "$STATICRYPT" "$SRC" \
  --directory . \
  --remember 30 \
  --template-title "Notes" \
  --template-instructions "Enter the password to continue." \
  --template-button "Open" \
  --template-placeholder "Password" \
  --template-remember "Remember me for 30 days" \
  --template-error "Incorrect password." \
  --template-color-primary "#1d63d6" \
  --template-color-secondary "#e9ecf0"
unset pw1

if [ ! -f "$OUT" ]; then
  echo "Expected $OUT was not produced." >&2
  exit 1
fi

# Keep search engines away from the login page itself
if ! grep -q 'name="robots"' "$OUT"; then
  sed -i 's|<meta charset="utf-8" />|<meta charset="utf-8" />\n        <meta name="robots" content="noindex, nofollow" />|' "$OUT"
fi
grep -q 'name="robots" content="noindex, nofollow"' "$OUT" || { echo "Could not add robots meta to $OUT." >&2; exit 1; }

# Plaintext leak check: none of these words may appear in the encrypted output
LEAKS=$(grep -i -c -E 'Jellyfin|qBittorrent|Tailscale|Sonarr|Radarr|Prowlarr|Beelink|CrystalDiskInfo|C:\\Media|C:\\Downloads' "$OUT" || true)
if [ "$LEAKS" != "0" ]; then
  echo "WARNING: $LEAKS line(s) in $OUT contain plaintext guide words. Do NOT commit." >&2
  exit 1
fi

echo "Done: $OUT encrypted, robots meta present, plaintext check passed (0 matches)."

# ---------------------------------------------------------------------------
# UPDATE
# 1. Edit source/index.html (plaintext, never committed)
# 2. Run ./encrypt.sh and enter the same password twice
# 3. Re-run the plaintext check (expect 0):
#      grep -i -c -E 'Jellyfin|qBittorrent|Tailscale|Sonarr|Radarr|Prowlarr|Beelink|CrystalDiskInfo|C:\\Media|C:\\Downloads' index.html
# 4. git status - confirm only index.html changed and nothing under source/ is staged
# 5. git add index.html && git commit -m "Update notes" && git push
# Keep .staticrypt.json committed and unchanged so 'Remember me' survives rebuilds.
# ---------------------------------------------------------------------------
