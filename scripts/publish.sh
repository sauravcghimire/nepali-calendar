#!/usr/bin/env bash
# shellcheck shell=bash
# NOTE: works on macOS system bash 3.2 as well as brew-installed bash 5+.
# Avoid heredocs inside $(...) command substitution — bash 3.2 has a parser
# bug there. Use `mktemp` + files instead.
# =============================================================================
# publish.sh — one-command release for Nepali Calendar
#
# What this does (idempotent — safe to re-run):
#   1. Sanity checks: gh, swift, git, shasum, codesign
#   2. Initializes a git repo for the app (this folder) + the tap (homebrew-tap/)
#   3. Creates the GitHub repos (sauravcghimire/nepali-calendar,
#      sauravcghimire/homebrew-tap) via `gh repo create` if they don't exist
#   4. Builds NepaliCalendar.app and NepaliCalendar.zip via build-app.sh
#   5. Tags v$VERSION, pushes to GitHub, uploads the zip to a GitHub Release
#   6. Rewrites homebrew-tap/Casks/nepali-calendar.rb with the new version/sha
#   7. Commits + pushes the updated tap
#
# Usage:
#   ./scripts/publish.sh              # releases v1.0.0 (default)
#   VERSION=1.1.0 ./scripts/publish.sh   # bump version
# =============================================================================
set -euo pipefail

GH_USER="sauravcghimire"
APP_REPO="nepali-calendar"
TAP_REPO="homebrew-tap"
VERSION="${VERSION:-1.0.0}"
TAG="v$VERSION"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT"
TAP_DIR="$ROOT/homebrew-tap"
BUILD_DIR="$APP_DIR/build"
ZIP="$BUILD_DIR/NepaliCalendar.zip"
CASK="$TAP_DIR/Casks/nepali-calendar.rb"

c_step()  { printf "\n\033[1;34m==> %s\033[0m\n" "$*"; }
c_info()  { printf "    %s\n" "$*"; }
c_done()  { printf "\n\033[1;32m✔ %s\033[0m\n" "$*"; }
c_warn()  { printf "\033[1;33m! %s\033[0m\n" "$*"; }
die()     { printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# 1. Preflight
# -----------------------------------------------------------------------------
c_step "Preflight"
for cmd in gh swift git shasum codesign ditto; do
    command -v "$cmd" >/dev/null 2>&1 || die "missing required tool: $cmd"
done
gh auth status >/dev/null 2>&1 || die "gh is not authenticated — run: gh auth login"
c_info "Publishing as GitHub user: $GH_USER"
c_info "Version: $VERSION ($TAG)"

# -----------------------------------------------------------------------------
# 2. Init / sync the APP repo
# -----------------------------------------------------------------------------
c_step "Preparing app repo at $APP_DIR"
cd "$APP_DIR"
if [ ! -d .git ]; then
    git init -b main >/dev/null
    c_info "Initialized git repo"
fi

# Stage everything respected by .gitignore.
git add -A
if ! git diff --cached --quiet; then
    git commit -m "Publish $TAG" >/dev/null
    c_info "Committed staged changes"
fi

# Ensure the remote exists locally + on GitHub.
if ! git remote get-url origin >/dev/null 2>&1; then
    if gh repo view "$GH_USER/$APP_REPO" >/dev/null 2>&1; then
        git remote add origin "https://github.com/$GH_USER/$APP_REPO.git"
        c_info "Linked existing GitHub repo $GH_USER/$APP_REPO as origin"
    else
        c_info "Creating GitHub repo $GH_USER/$APP_REPO"
        gh repo create "$GH_USER/$APP_REPO" \
            --public \
            --source=. \
            --remote=origin \
            --description "Nepali Calendar for macOS — menu-bar BS date, events, rashifal"
    fi
fi

git branch -M main >/dev/null 2>&1 || true
git push -u origin main
c_done "App repo pushed"

# Polish the public-facing metadata on GitHub. Idempotent: running this
# repeatedly overwrites with the same values.
c_step "Updating GitHub repo metadata (topics, description, homepage)"
gh repo edit "$GH_USER/$APP_REPO" \
    --description "Nepali (BS) calendar menu-bar app for macOS — dates, events, tithi, rashifal" \
    --homepage "https://github.com/$GH_USER/$APP_REPO" \
    --add-topic macos \
    --add-topic menu-bar-app \
    --add-topic nepali-calendar \
    --add-topic bikram-sambat \
    --add-topic rashifal \
    --add-topic swift \
    --add-topic swiftui \
    --add-topic homebrew-cask >/dev/null
c_info "Topics: macos, menu-bar-app, nepali-calendar, bikram-sambat, rashifal, swift, swiftui, homebrew-cask"

# -----------------------------------------------------------------------------
# 3. Build the .app bundle
# -----------------------------------------------------------------------------
c_step "Building NepaliCalendar.app ($VERSION, universal, ad-hoc signed)"
APP_VERSION="$VERSION" "$ROOT/scripts/build-app.sh"
[ -f "$ZIP" ] || die "expected $ZIP but it's missing after build"

SHA256=$(shasum -a 256 "$ZIP" | awk '{print $1}')
SIZE_MB=$(du -h "$ZIP" | awk '{print $1}')
c_info "Built zip: $SIZE_MB ($ZIP)"
c_info "SHA256: $SHA256"

# -----------------------------------------------------------------------------
# 4. Tag + GitHub Release
# -----------------------------------------------------------------------------
c_step "Creating tag and GitHub Release"
cd "$APP_DIR"
if git rev-parse "$TAG" >/dev/null 2>&1; then
    c_info "Tag $TAG already exists locally"
else
    git tag -a "$TAG" -m "Release $VERSION"
    c_info "Tagged $TAG"
fi
git push origin "$TAG" 2>/dev/null || c_info "Tag push skipped (already on remote)"

# Write release notes to a temp file. macOS's system bash is 3.2, which has
# a known parser bug with heredocs inside $(...) command substitution — avoid
# by going through a file and passing --notes-file to gh.
NOTES_FILE=$(mktemp -t nepali-calendar-release-notes)
trap 'rm -f "$NOTES_FILE"' EXIT

# Use a quoted heredoc ('EOF') so bash doesn't try to interpret backticks or
# expand placeholders; sed substitutes them afterwards.
cat > "$NOTES_FILE" <<'NOTES'
## Nepali Calendar __VERSION__

macOS menu-bar app showing today's Nepali (BS) date, with calendar grid,
events, tithi, holidays, and daily rashifal.

### Install

    brew tap __GH_USER__/tap
    brew install --cask nepali-calendar

### First launch

Right-click the app in /Applications and choose **Open** once to bypass
Gatekeeper (the binary is ad-hoc signed; a Developer ID build is coming).
NOTES
/usr/bin/sed -i '' "s/__VERSION__/$VERSION/g" "$NOTES_FILE"
/usr/bin/sed -i '' "s|__GH_USER__|$GH_USER|g" "$NOTES_FILE"

if gh release view "$TAG" --repo "$GH_USER/$APP_REPO" >/dev/null 2>&1; then
    c_info "Release $TAG exists — re-uploading asset"
    gh release upload "$TAG" "$ZIP" --repo "$GH_USER/$APP_REPO" --clobber
else
    gh release create "$TAG" "$ZIP" \
        --repo "$GH_USER/$APP_REPO" \
        --title "Nepali Calendar $VERSION" \
        --notes-file "$NOTES_FILE"
fi
c_done "Release $TAG published with NepaliCalendar.zip"

# -----------------------------------------------------------------------------
# 5. Update the cask formula
# -----------------------------------------------------------------------------
c_step "Updating cask formula"
[ -f "$CASK" ] || die "cask file not found: $CASK"
# BSD sed (macOS) needs '' as backup-extension arg.
/usr/bin/sed -i '' "s/^  version \".*\"/  version \"$VERSION\"/" "$CASK"
/usr/bin/sed -i '' "s/^  sha256 \".*\"/  sha256 \"$SHA256\"/" "$CASK"
c_info "version → $VERSION"
c_info "sha256  → $SHA256"

# -----------------------------------------------------------------------------
# 6. Init / sync the TAP repo
# -----------------------------------------------------------------------------
c_step "Preparing homebrew-tap repo at $TAP_DIR"
cd "$TAP_DIR"
if [ ! -d .git ]; then
    git init -b main >/dev/null
    c_info "Initialized git repo"
fi

git add -A
if ! git diff --cached --quiet; then
    git commit -m "Publish nepali-calendar $TAG (sha256: ${SHA256:0:12}…)" >/dev/null
    c_info "Committed tap update"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    if gh repo view "$GH_USER/$TAP_REPO" >/dev/null 2>&1; then
        git remote add origin "https://github.com/$GH_USER/$TAP_REPO.git"
        c_info "Linked existing GitHub repo $GH_USER/$TAP_REPO as origin"
    else
        c_info "Creating GitHub repo $GH_USER/$TAP_REPO"
        gh repo create "$GH_USER/$TAP_REPO" \
            --public \
            --source=. \
            --remote=origin \
            --description "Personal Homebrew tap — casks by $GH_USER"
    fi
fi

git branch -M main >/dev/null 2>&1 || true
git push -u origin main
c_done "Tap repo pushed"

# Tag the tap repo so Homebrew can identify it clearly in the marketplace.
c_step "Updating GitHub metadata on the tap repo"
gh repo edit "$GH_USER/$TAP_REPO" \
    --description "Homebrew tap for $GH_USER's macOS apps" \
    --homepage "https://github.com/$GH_USER/$TAP_REPO" \
    --add-topic homebrew-tap \
    --add-topic homebrew-cask \
    --add-topic macos >/dev/null
c_info "Topics: homebrew-tap, homebrew-cask, macos"

# -----------------------------------------------------------------------------
# 7. Done
# -----------------------------------------------------------------------------
c_step "Published!"
cat <<EOF

  Anyone can now install the app with:

    brew tap $GH_USER/tap
    brew install --cask nepali-calendar

  Release:   https://github.com/$GH_USER/$APP_REPO/releases/tag/$TAG
  Tap:       https://github.com/$GH_USER/$TAP_REPO
  Cask file: $CASK

  To publish a bump later:

    VERSION=1.0.1 ./scripts/publish.sh

EOF
