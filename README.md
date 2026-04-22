# Nepali Calendar for macOS

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)](https://swift.org)
[![Homebrew](https://img.shields.io/badge/install-brew%20cask-fbb040?logo=homebrew)](https://github.com/sauravcghimire/homebrew-tap)
[![GitHub release](https://img.shields.io/github/v/release/sauravcghimire/nepali-calendar?display_name=tag&sort=semver)](https://github.com/sauravcghimire/nepali-calendar/releases)

A lightweight menu-bar app that shows **today's Nepali (Bikram Sambat) date**
in the macOS status bar. Click the icon for a full month view with events,
tithi, holidays, and a horizontal **rashifal** (horoscope) row — with the
ability to pin your sign as the default.

Built with Swift + SwiftUI. Distributed through a personal Homebrew tap.

## Install

```bash
brew tap sauravcghimire/tap
brew install --cask nepali-calendar
```

> First launch is automatic — the cask strips the `com.apple.quarantine`
> attribute and launches the app via `open` right after `brew install`.
> If you ever move the app bundle manually and hit Gatekeeper, run:
> `xattr -dr com.apple.quarantine /Applications/NepaliCalendar.app`

```
┌─ Menu bar: ३ बैशाख ─────────────────────────────────┐

     ← ←  बैशाख २०८३   →  →
     आइत सोम मंगल बुध बिही शुक्र शनि
       १    २    ३    ४    ५   ६    ७   ← today circled
       ...

     [3]  तृतीया
          2026-04-16 (AD)
          • स्वामी शशिधर जन्मजयन्ती

     राशिफल                      Default: मेष ★
     [♈][♉][♊][♋][♌][♍][♎][♏][♐][♑][♒][♓]  (scroll)

     ♈  मेष (Aries)                [★ Set as default]
     आज तपाईंको दिन शुभ रहनेछ। ...
```

## Project layout

```
.
├── NepaliCalendar/              # SwiftPM project (the app itself)
│   ├── Package.swift
│   └── Sources/NepaliCalendar/
│       ├── main.swift
│       ├── App/                 # AppDelegate + StatusBarController
│       ├── Models/              # CalendarStore, RashifalStore
│       ├── Utils/               # Numerals, month/weekday names, settings
│       ├── Views/               # SwiftUI views (grid, picker, horoscope)
│       └── Resources/
│           ├── calendar/        # Bundled BS year JSON (2081, 2082, 2083)
│           └── rashifal/        # Monthly rashifal JSON per BS year
├── scripts/
│   └── build-app.sh             # Build + package + sign + zip into .app
├── homebrew-tap/                # The homebrew-tap repo that ships the cask
│   ├── Casks/nepali-calendar.rb
│   └── README.md
└── README.md
```

## Building and running locally

```bash
cd NepaliCalendar
swift run
```

This launches the menu-bar icon immediately; press it to open the popover.

Or build a full `.app` bundle (universal, ad-hoc signed) and a distributable zip:

```bash
./scripts/build-app.sh
open build/NepaliCalendar.app
```

## Data sources

All calendar and rashifal data loads from local JSON files — the app works
fully offline.

### Calendar (events, tithi, holidays)

`Resources/calendar/<bsYear>.json` — one file per BS year, bundled inside the
app:

```json
{
  "bsYear": 2082,
  "months": {
    "1": {
      "1": {
        "events": ["नयाँ वर्ष", "मेष संक्रान्ति"],
        "tithi": "प्रतिपदा",
        "isHoliday": true,
        "adYear": 2025, "adMonth": 4, "adDay": 14
      }
    }
  }
}
```

### Rashifal (horoscope)

The app looks for `<bsYear>/<bsMonth>.json` in this order:

1. The path set in `UserDefaults` key `rashifalPath` (if you want a custom
   location)
2. `~/Desktop/Calendar/rashifal/` — default, matches your existing layout
3. `~/Library/Application Support/NepaliCalendar/rashifal/`
4. Bundled `Resources/rashifal/` (shipped with the .app)

This means you can update rashifal data on disk without rebuilding — the app
picks up the newest files automatically (on the next popover open).

Schema (the shape your files already use):

```json
{
  "bsYear": 2083,
  "bsMonth": 1,
  "days": {
    "1": {
      "mesh":      { "en": "...", "ne": "..." },
      "brish":     { "en": "...", "ne": "..." },
      "mithun":    { "en": "...", "ne": "..." },
      "karkat":    { "en": "...", "ne": "..." },
      "simha":     { "en": "...", "ne": "..." },
      "kanya":     { "en": "...", "ne": "..." },
      "tula":      { "en": "...", "ne": "..." },
      "vrishchik": { "en": "...", "ne": "..." },
      "dhanu":     { "en": "...", "ne": "..." },
      "makar":     { "en": "...", "ne": "..." },
      "kumbha":    { "en": "...", "ne": "..." },
      "min":       { "en": "...", "ne": "..." }
    }
  }
}
```

The loader prefers `ne` (Nepali) and falls back to `en`. Sign keys are
case-insensitive and support common alternate romanisations (`simha` ↔
`singha`, `vrishchik` ↔ `brischik`, `min` ↔ `meen`, etc.).

## Publishing via Homebrew

One command does the whole flow — build, tag, release, and push the tap:

```bash
./scripts/publish.sh                    # first release (1.0.0)
VERSION=1.0.1 ./scripts/publish.sh      # bump later
```

The script is idempotent — re-running it is safe. It creates the two GitHub
repos on first run if they don't exist (`sauravcghimire/nepali-calendar` for
the app + releases, `sauravcghimire/homebrew-tap` for the cask), uploads
`NepaliCalendar.zip` as a GitHub Release asset, and rewrites the cask formula
with the new version and SHA256.

Prerequisites on this Mac:

- `gh` CLI installed and authenticated (`gh auth login` → GitHub.com →
  HTTPS → scope includes `repo`)
- Xcode command-line tools (`xcode-select --install`)

End users then install with:

```bash
brew tap sauravcghimire/tap
brew install --cask nepali-calendar
```

More detail on the tap itself is in `homebrew-tap/README.md`.

## Known limitations / follow-ups

- Ad-hoc signing means first-launch requires right-click → Open, or running
  `xattr -dr com.apple.quarantine /Applications/NepaliCalendar.app`. Fix by
  signing with a Developer ID certificate and notarising.
- The app ships BS years **2081, 2082, and 2083**. Drop additional
  `<year>.json` files into `Resources/calendar/` to extend the range — the
  code discovers them automatically.
- Rashifal files are loaded per month; if a month file is missing the UI shows
  the signs but with empty prediction text.
