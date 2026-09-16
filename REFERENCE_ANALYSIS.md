# REFERENCE_ANALYSIS.md — Stage 2

Extraction of the visual language from the reference image at
`asesst/Screenshot 2026-09-17 at 12.48.00 AM.png`.

Source: a Dribbble concept — *"Concept design for korean-learning mobile
application by Marta Siedlecka"*. Three phone screens are visible: a gradient
hero/onboarding screen, a vocabulary home, and a word-detail screen.

**All values below are measured from the actual pixels**, not estimated by eye.
Colours are dominant-colour samples; geometry is edge-detected against the
background; type sizes are derived from measured glyph ink-heights divided by
the mockup scale (645 px ÷ 390 pt = **1.654 px/pt**).

---

## 0. Copyright boundary (REDESIGN.md §2, §34)

The reference contains material that must **not** be reproduced:

- Photographs of real K-pop artists in the "Featured videos" row — real people,
  copyrighted images.
- The 3D illustration set (books + apple, burger, alarm clock, wok) — the
  designer's copyrighted assets.
- The specific composition of the concept.

What is extracted instead is the **visual language**: palette relationships,
type hierarchy, spacing rhythm, corner geometry, and the flat/pastel depth
model. Lango's own icon set and emoji flags carry the imagery. No illustration
is copied, and no "Featured videos" media row is reproduced.

---

## 1. Colour — measured

### Brand

| Token             | Value     | Where measured                              |
| ----------------- | --------- | ------------------------------------------- |
| primary           | `#7213A8` | "start learning!" CTA fill (30% dominant)   |
| primary-deep      | `#580C8F` | darkest ink of the 한국어 display wordmark   |
| accent-pink       | `#F4B2EB` | poster background field (100% flat)         |

### Hero gradient (top → bottom)

Measured down the left edge of screen 1:

```
#BA82D8  →  #CDA1E7  →  #F0CFF1  →  #FDFDFF
```

A vertical violet→pink→white wash. This is the only large gradient in the UI.

### Pastel category tints (vocabulary cards)

| Token           | Value     | Reference use     |
| --------------- | --------- | ----------------- |
| tint-pink       | `#F9DAF9` | 안녕 / SCHOOL      |
| tint-cyan       | `#BFF5FD` | 음식 / FOOD        |
| tint-amber      | `#FAE6AA` | 시각 / TIME        |
| tint-sky        | `#D9F1FE` | screen-3 backdrop |

Each card is **not** a flat fill: it carries a subtle vertical gradient,
lighter at the top. Measured down the pink card at x=1850:

```
y1280 #FAEBFA   (top, lighter)
y1400 #F9DAF9   (bottom, saturated)
```

Delta is small (~17 in the green channel) — a soft sheen, not a bold gradient.

### Neutrals

| Token                | Value     | Notes                                |
| -------------------- | --------- | ------------------------------------ |
| background / surface | `#FEFEFE` | effectively white; 88% dominant      |
| foreground           | `#131313` | darkest ink of headings and body     |
| foreground-secondary | `#272727` | secondary ink sampled on screen 3    |
| foreground-muted     | `#6B6B6B` | chosen (see §7 contrast note)        |

### Contrast verification (REDESIGN.md §36)

| Pair                          | Ratio    | Verdict  |
| ----------------------------- | -------- | -------- |
| `#131313` on `#FEFEFE`        | 18.42:1  | AA       |
| `#7213A8` on `#FEFEFE`        | 8.77:1   | AA       |
| `#FEFEFE` on `#7213A8`        | 8.77:1   | AA       |
| `#580C8F` on `#FEFEFE`        | 11.17:1  | AA       |
| `#131313` on `#F9DAF9`        | 14.53:1  | AA       |
| `#131313` on `#BFF5FD`        | 15.66:1  | AA       |
| `#131313` on `#FAE6AA`        | 15.01:1  | AA       |
| `#131313` on `#D9F1FE`        | 15.89:1  | AA       |
| `#6B6B6B` on `#FEFEFE`        | 5.28:1   | AA       |
| `#8A8A8A` on `#FEFEFE`        | 3.42:1   | large-only |

**Deviation (§41):** the reference's caption grey reads lighter than `#6B6B6B`.
A lighter grey fails AA for body-size text, so muted foreground is pinned at
`#6B6B6B`. This is the minimum deviation that keeps accessibility.

---

## 2. Typography — measured

Glyph ink-heights measured, converted at 1.654 px/pt. Hangul fills ≈0.88 em;
Latin caps ≈0.72 em — both accounted for.

| Role            | Measured ink | Derived size | Reference instance      |
| --------------- | ------------ | ------------ | ----------------------- |
| display         | 61.1 pt      | **64**       | 치킨 (word detail hero) |
| h1              | —            | **28**       | 한국어 hero wordmark     |
| h2              | 24.8 pt      | **24**       | 안녕, Marta! greeting    |
| h3 / section    | 22.4 pt      | **22**       | "New vocabulary"        |
| card-native     | 22.4 pt      | **22**       | 안녕 inside card         |
| body            | —            | **16**       | body paragraph          |
| caption (caps)  | 13.3 pt cap  | **13**       | SCHOOL / CHICKEN        |
| nav label       | 7.3 pt cap   | **10**       | LISTEN / CHAT / VIDEOS  |

### Characteristics

- **Rounded geometric sans.** Even stroke weight, circular counters, soft
  terminals. Weights in use: regular (body), semibold (headings), bold (display).
- **Native-first hierarchy.** The Korean word is always the largest element on
  its surface; the English gloss sits beneath it in small **uppercase with
  generous letter-spacing** (~0.08em measured on SCHOOL / CHICKEN). This is the
  single most characteristic move of the reference and directly satisfies
  REDESIGN.md §7 ("the native sentence should not look like secondary metadata").
- **Latin captions are uppercase; native text never is** (Hangul/Kana have no
  case).

### CJK requirement (§7)

The reference renders Korean in a rounded sans with full Hangul coverage. Lango
currently ships **no** font and falls back to the platform default, which is
inconsistent between Android and iOS. The design system must bundle a family
with Latin + Hangul + Kana coverage.

---

## 3. Layout & spacing — measured

Screen width 645 px ÷ 1.654 = **390 pt** logical.

| Measurement        | Pixels | Points   | Token           |
| ------------------ | ------ | -------- | --------------- |
| card width         | 550    | 333      | —               |
| page gutter        | ~47    | **~28**  | space-7 (28)    |
| card height        | 167    | **101**  | —               |
| card vertical gap  | ~55    | **~33**  | space-8 (32)    |

Derived spacing scale (REDESIGN.md §8), with the measured values landing on
28 and 32:

```
4, 8, 12, 16, 20, 24, 28, 32, 40, 48, 64, 80
```

### Layout principles

- **Single column, one full-width card stack.** No grids, no multi-column.
- **Airy.** Large vertical gaps; content never crowds the edges.
- **Left-aligned** headings and body; the word-detail screen centres its hero.
- **Vertical rhythm** is driven by the 32 pt card gap and 28 pt gutter.
- **Density: low.** Screen 2 shows a greeting, one sentence, and three cards —
  roughly six elements on a full screen.

---

## 4. Shape — measured

Corner insets were traced row-by-row against the background:

| Element    | Measured radius | Token              |
| ---------- | --------------- | ------------------ |
| card       | 44 px → **27 pt** | radius-xl (28)   |
| CTA button | 22 px → **13 pt** | radius-md (14)   |

**Cards are twice as round as buttons.** This is specific and counter to the
common assumption that buttons are the pill element — the reference's CTA is a
moderately-rounded rectangle 57 pt tall, not a pill.

Scale:

```
radius-sm    8     chips, small controls
radius-md   14     buttons, inputs
radius-lg   20     sheets, dialogs
radius-xl   28     cards
radius-pill 999    avatars, page dots
```

---

## 5. Depth — measured, and decisive

Sampling the rows immediately below a card's bottom edge:

```
y1442 #FDF3FE   (last card pixel, antialiased)
y1443 #FEFAFF
y1445 #FFFCFE
y1450 #FFFFFA   ← pure background, no darkening
```

**There is no drop shadow.** No elevation, no scrim, no darkening anywhere
beneath the cards.

Nor are there borders — cards are distinguished from the background purely by
their pastel fill. Per REDESIGN.md §5 ("do not add shadows or gradients if the
reference does not use them"):

| Technique        | Present? | Use in Lango                          |
| ---------------- | -------- | ------------------------------------- |
| Drop shadow      | **No**   | Forbidden                             |
| Elevation        | **No**   | Forbidden                             |
| Borders          | **No**   | Only for focus rings (accessibility)  |
| Flat fill        | **Yes**  | The primary surface technique         |
| Subtle gradient  | **Yes**  | Card sheen + one full-screen hero wash|
| Layered surfaces | **Yes**  | Tinted card on white background       |

This means the existing `cardTheme` (elevation 0 **with a visible
`outlineVariant` border**) must drop its border, and the current app's reliance
on outlined cards is replaced by tinted fills.

---

## 6. Navigation

The reference uses a **flat bottom tab bar**, 4 items: icon above a very small
uppercase letterspaced label (10 pt). No pill indicator, no elevation, no
background tint — it sits directly on the white surface.

The reference's own tabs (LISTEN / CHAT / VIDEOS / MEMOS) are that product's
areas, not ours. Per §10 we keep the *philosophy* (flat bottom bar, icon +
tiny caps label) and substitute Lango's areas:

```
Home    Learn    Review    Tutor    Progress
```

Profile/Settings moves to an avatar in the header, mirroring the reference's
top-right avatar on screen 2.

This replaces Lango's current model, which has **no persistent navigation at
all** (see UI_AUDIT.md §2) and therefore requires a shell route.

---

## 7. Interaction patterns observed

- **Card = one vocabulary item**, tappable as a whole, illustration right-aligned.
- **Page dots** on the word-detail screen — a horizontally paged study flow,
  not a scrolling list. This maps well onto Lango's flashcard/review screens.
- **Prominent audio affordance** — a speaker control sits with the word.
- **Single primary CTA per screen**, full-width, bottom-anchored.
- Screen 3 is a **one-task-at-a-time** layout: word, reading, gloss, example,
  audio — exactly the model REDESIGN.md §13 asks for.

---

## 8. Token summary → Stage 3 input

```
colour    primary #7213A8 · primary-deep #580C8F · accent #F4B2EB
          tints pink #F9DAF9 / cyan #BFF5FD / amber #FAE6AA / sky #D9F1FE
          surface #FEFEFE · fg #131313 · fg-secondary #272727 · fg-muted #6B6B6B
          gradient #BA82D8 → #CDA1E7 → #F0CFF1 → #FDFDFF
type      display 64 · h1 28 · h2 24 · h3 22 · body 16 · caption 13 · nav 10
          rounded geometric sans, CJK-capable; caps+tracking on Latin captions
space     4 8 12 16 20 24 28 32 40 48 64 80   (gutter 28, card gap 32)
radius    sm 8 · md 14 · lg 20 · xl 28 · pill 999
depth     flat only — no shadows, no borders, no elevation
```

---

## 9. Open question — dark mode (§30)

The reference is light-only. REDESIGN.md §30 says to implement dark mode *only
if it fits the design direction*, and explicitly forbids inverting colours. The
pastel-tint system does not invert meaningfully: `#F9DAF9` on a dark background
becomes a glaring block.

Recommendation: ship **light-only** for this redesign, and treat dark mode as a
separate piece of design work where the tints are re-derived as low-luminance
chromatic surfaces rather than inverted. Flagged for the product owner.
