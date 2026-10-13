# DESIGN.md — how Connect-Ed should look

This file exists so visual choices are made once and then obeyed, instead of
being re-invented on every screen. The failure mode it prevents is specific:
an interface assembled from the defaults a model reaches for when nobody has an
opinion, which reads as "generated" even when every individual choice is
defensible. That look has a name — AI design slop — and its tells are
measurable, not a matter of taste.

**Read this before writing any UI. Run the checklist at the bottom before
saying a screen is done.**

---

## 1. This app's actual choices

Write them down here and reuse them. Do not introduce a new colour, a new
radius, or a new row treatment without adding it to this list deliberately.

| | |
|---|---|
| **Primary** | Appleby navy `#004270` in the light theme, pale blue `#A0CFEB` in the dark. The two are **deliberately swapped** between themes, so in the theme this app actually runs (dark), `colorScheme.primary` is the pale blue. Interactive and selected things: buttons, active controls, section titles, links, the completion circle. |
| **Secondary** | Whichever of that pair the current theme is not using. Fills and backgrounds behind primary. |
| **Surface** | White in light, `#101010` in dark. The canvas. |
| **Error** | `#A01F1F` light / `#F17272` dark. State only: overdue, destructive. |
| **Tertiary** | `#E7E7E7` light / `#303030` dark. Hairline dividers. |
| **Heading type** | Montserrat, `w600`–`w700`, for screen and card titles. |
| **Body type** | Platform default. Titles 15–17, secondary lines 12.5–13, meta 11–12.5. |
| **Radii** | 4 for schedule blocks, 12 for sheets/inputs, 16 for genuinely floating cards. Nothing else. |

Source of truth: [`lib/frontend/setup/styles.dart`](lib/frontend/setup/styles.dart).
If you need a new colour, add it there first.

### The one layout primitive

**A flat row on the canvas**: optional leading control, a title, an optional
secondary line, an optional right-aligned value, separated from the next row by
a hairline divider the full width minus a small indent — or by nothing, if
spacing alone separates rows. Section headers are plain text in `primary`,
never decorated.

Examples already correct in this codebase: the Calendar tab's assessment list
and the Home tab's Upcoming Assessments. Copy those. Do not build a new
container because a screen "needs" one.

---

## 2. The tells, and the rule for each

The most-cited list comes from Adrian Krebs' audit of **1,590 Show HN landing
pages**, scored with Playwright against sixteen DOM/CSS patterns designers
described as tells: **22% triggered four or more** (heavy), 32% two or three,
46% zero or one. The Fountain Institute's seven, and various field guides, agree
on the rest. What follows is that research translated into rules for this app.

### 2.1 Coloured left border / accent stripe — **never**

> *"Colored left borders are almost as reliable a sign of AI-generated design as
> em-dashes for text."* — a designer quoted in Krebs' write-up

This is the single most reliable tell, and this app shipped it: a 5px accent
spine down the left of every assignment row. **Rows do not get stripes.** If a
row needs to feel important, it is already first in the list, or it gets a
weight/colour change in its text.

### 2.2 Everything in a rectangle — **rows sit on the canvas**

The Fountain Institute: *"In AI-generated interface land, everything goes in a
card. Even cards themselves sometimes go in cards."* The model knows content
needs to be grouped, but has no cost function for visual weight, so every group
becomes a surface.

Rule: a list of like things is a **list**, not a stack of cards. A container has
to earn its place by doing something — separating unrelated regions, or holding
a real hero summary. Two nested containers around one line of text never do.

### 2.3 Icon in a rounded pastel square — **only when the icon is the content**

The icon-in-a-pale-chip, repeated above every feature, is a field-guide staple.
A generic glyph in a coloured square adds no information. Keep an icon chip only
where the image itself carries meaning (a team crest, a sport logo); otherwise
use a bare icon in a text colour, or nothing.

### 2.4 Status dots — **a dot must encode state**

The Fountain Institute: *"There was a time once when dots meant something like
'live' or 'connected.' To become a top slopper, add them to every UI element in
any colour you like."*

A dot before a heading is a bullet pretending to be information. Dots are for
live/overdue/unread — states a colour and a legend can explain.

### 2.5 Palette defaults — **no purple, no neon, no glow**

Lavender-purple accents, neon-on-dark, radial "aurora" glows and coloured
box-shadow halos are the defaults image and text models reach for. This app has
a real palette; use it. Accents are `primary`. There are **no glows**.

### 2.6 Chips and pills around single strings — **plain text**

A filled rounded pill around "In 3 days" is a container doing a text weight's
job. If a value needs to stand out, make it the right-aligned value in the row
and let weight and colour carry it. Pills are for filters and tags you can tap.

### 2.7 Everything else in the catalogue

Skip these unless the meaning is real: emoji as UI icons, all-caps section
labels, a badge floating above a title, numbered "1 → 2 → 3" step sequences,
stat banner rows, centred hero text on non-marketing screens, identical repeated
cards each with a different icon treatment.

---

## 3. Colour has to mean something

The rule that catches most of the above: **every use of colour either encodes a
state or is the single brand colour marking something interactive/selected.**

If a colour is identical on every row of a list, it carries no information and
is decoration — delete it or mute it to a secondary text tone. Overdue dates in
`error` is information. Every class name in blue is not.

Corollary: this is why the per-subject rainbow hash was removed. Eight hues,
none of them meaningful, is decoration at maximum volume.

---

## 4. Process rules that keep this from creeping back

1. **Look at it with real data before claiming it works.** Tests prove layout
   safety, not taste. Screenshot the screen, with the real feed, and look.
2. **Match the app before inventing.** If another tab already renders this kind
   of thing, it must look the same. Two different treatments of the same list
   is itself a tell.
3. **One primitive, repeated.** A screen with one row treatment used everywhere
   looks designed; a screen with five bespoke cards looks generated.
4. **Contrast is not optional.** Body text ≥ 4.5:1 against its surface; the
   dark theme is where this fails first.
5. **Prefer removing to adding.** Most fixes here were deletions.

### Checklist before calling a screen done

- [ ] Do list rows sit on the canvas, or is each one in its own box?
- [ ] Any coloured stripe/bar on the left or top edge of anything? Remove it.
- [ ] Any dot, emoji, or icon-in-a-rounded-square that isn't carrying meaning?
- [ ] Is every colour either a state or `primary`?
- [ ] Any pill/chip wrapping a single short string?
- [ ] Does it use the same row primitive as the rest of the app?
- [ ] Does it still read with all icons removed?
- [ ] Did I actually look at a screenshot with real data?

---

## 5. Known debt

Screens still violating the rules above, worth cleaning when they are next
touched (do not go on a spree — fix what you are already editing):

- `lib/frontend/calendar/open_event.dart` — icon in a 36px accent-coloured
  rounded square, plus a coloured glow shadow on the sheet (§2.3, §2.5).
- `lib/frontend/sports/*` — repeated 16px-radius cards with borders (§2.2).
- `lib/frontend/settings/*` — form fields and cards share a 12px radius with no
  system behind it (§1).

---

## Sources

- Adrian Krebs, *Design Slop* — 1,590 Show HN pages, 16 patterns, four buckets;
  the dataset behind the percentages quoted above.
- Developers Digest, *AI Design Slop: 16 Patterns That Mark a Site as
  Vibe-Coded* — Krebs' rubric in full, including the coloured-left-border quote.
- The Fountain Institute, *7 Tells that a UI is AI-Generated* — neon palettes,
  dark-mode glow, emoji, purple gradients, cards-on-cards, multicoloured side
  tabs, status dots.
- *impeccable.style/slop* — a slop detector emphasising the unglamorous ones
  (line length, measure, contrast) that no model is praised for getting right.
