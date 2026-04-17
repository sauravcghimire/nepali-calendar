# Rashifal data

Monthly rashifal (horoscope) predictions live here, one JSON file per BS month.

Path format:

```
rashifal/<bsYear>/<bsMonth>.json      e.g. rashifal/2082/01.json
```

The app accepts either of two shapes:

**Day-keyed** (recommended):

```json
{
  "1": { "mesh": "…", "brish": "…", "mithun": "…", "karkat": "…",
         "singha": "…", "kanya": "…", "tula": "…", "brischik": "…",
         "dhanu": "…", "makar": "…", "kumbha": "…", "meen": "…" },
  "2": { … }
}
```

**Sign-keyed** (also accepted):

```json
{
  "mesh":  { "1": "…", "2": "…", … },
  "brish": { … },
  …
}
```

Values may be a plain string **or** an object `{ "text": "…" }` — the loader
unwraps both.

Accepted sign keys (case-insensitive): `mesh/aries`, `brish/vrish/taurus`,
`mithun/gemini`, `karkat/cancer`, `singha/leo`, `kanya/virgo`, `tula/libra`,
`brischik/vrishchik/scorpio`, `dhanu/sagittarius`, `makar/capricorn`,
`kumbha/aquarius`, `meen/pisces`. Devanagari names (मेष, वृष, …) also work.

If a month file is missing, the UI still renders all 12 signs but shows empty
prediction text.
