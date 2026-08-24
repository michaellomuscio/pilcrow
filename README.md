<div align="center">

# ¶ &nbsp;Pilcrow

**A book-writing app for macOS. Fiction and nonfiction are the same machine with two vocabularies.**

Your writing lives as plain Markdown files in a folder you choose.
No account, no database, no cloud, no subscription, nothing to lock you in.

[**Download the latest release →**](https://github.com/michaellomuscio/pilcrow/releases/latest)
&nbsp;·&nbsp;
[Getting started guide](docs/GUIDE.md)
&nbsp;·&nbsp;
[Terms](TERMS.md)
&nbsp;·&nbsp;
[Licence](LICENSE)

<br>

<img src="docs/screenshots/01-the-page.png" alt="The Pilcrow writing surface, showing a manuscript in Literata with the binder on the left and the studio panel on the right" width="100%">

</div>

<br>

## What it is

Most writing apps are built for fiction and bolt nonfiction on afterwards, or
they are a text editor with a folder tree. Pilcrow starts from a different
observation: **the nonfiction equivalent of plot is argument.** A plot line and
an argument thread are the same object — a promise made to the reader and
eventually paid off. Once you see that, one data model covers both, and a
novel and a monograph can share a grid.

It runs entirely on your Mac. It has no account system, no telemetry, and no
network connection for your manuscript content. Free, and open source under
Apache 2.0.

**Requirements:** macOS 14 (Sonoma) or later, Apple silicon or Intel.

---

## Install

1. Download `Pilcrow.dmg` from [Releases](https://github.com/michaellomuscio/pilcrow/releases/latest).
2. Open it and drag Pilcrow to Applications.
3. Launch it. You'll be asked to accept the terms once.

The app is signed with a Developer ID and notarised by Apple, so it opens
without a Gatekeeper warning.

---

## What a project is

A folder. That's the whole format.

```
The Cartographer's Error/
├── Pilcrow Project.json          order, metadata, threads, cast, notes
├── Manuscript/
│   ├── Chapter One/
│   │   ├── The Town That Moved.md
│   │   └── Mrs. Aiken's Ledger.md
│   └── Chapter Two/
│       └── What the Office Said.md
└── .pilcrow/
    ├── sessions.json
    └── snapshots/
```

Chapters are directories. Scenes are Markdown files you can open in any
editor. The manifest owns **order**; the files own **prose**; each file carries
its own id in front matter, so either side can rebuild the other. Drop a `.md`
into a chapter folder in Finder and it joins the book on next open.

Put the folder in Dropbox and it syncs. Put it in git and you get versioned
history of every draft you've ever written, free. Full spec:
[docs/FILE-FORMAT.md](docs/FILE-FORMAT.md).

There are two sample projects in [`examples/`](examples) — open either one
from the app to poke around before starting your own.

---

## The page

<img src="docs/screenshots/09-corkboard.png" alt="Corkboard view showing index cards for each scene" width="100%">

Six bundled typefaces, all open-licensed, all working offline: **Literata**
(default), Newsreader, Source Serif 4, EB Garamond, Charter, and iA Writer
Quattro for drafting.

The typography is set the way a book is, not the way a web page is: a measure
locked to 66 characters, 1.72 leading, first-line indents with no space
between paragraphs, warm off-white paper rather than pure white, and a caret
that **does not blink**.

The measure is solved by laying out a real paragraph and correcting, rather
than by multiplying an average character advance — an average is wrong by five
to ten percent, and differently wrong for every typeface.

Other things the page does: typewriter scrolling, paragraph and sentence focus
dimming, Draft and Revise modes, snapshots with restore, anchored comments,
and read-aloud with word-synced highlighting.

---

## One model, two vocabularies

| Fiction | Same object | Nonfiction |
|---|---|---|
| Plot lines | `Thread` | Argument threads |
| Characters | `Entity` | Sources & subjects |
| Story notes | `Note` | Concepts & frameworks |
| Continuity ledger | `Fact` | Evidence ledger |
| Beat sheets | `Structure` | Structure patterns |

Choosing Fiction or Nonfiction when you create a project sets a label pack and
turns a few modules on or off. **Hybrid** turns both on — memoir and narrative
nonfiction want both. It's a preset, not a prison.

### The Plot Grid, and the Argument Board

<img src="docs/screenshots/02-plot-grid.png" alt="Plot Grid with threads as columns and scenes as rows" width="100%">

One component, two label packs. Columns are threads, rows are scenes, cells are
what happens. Each thread carries a stated promise and payoff, and the board
flags threads that go quiet for a long stretch and promises that never pay off.

### Structure

<img src="docs/screenshots/03-structure.png" alt="Structure view showing Save the Cat beats against where they actually land" width="100%">

Eight fiction beat sheets — Save the Cat!, Hero's Journey, Story Circle,
Seven-Point, Three-Act, Freytag, Kishōtenketsu, Romancing the Beat — and eight
nonfiction patterns, including Problem→Solution, What/Why/How/What-If,
big-idea, narrative nonfiction, memoir arc, thesis→antithesis→synthesis,
IMRaD, and the braided essay.

The overlay measures where each beat **actually** lands, in words rather than
chapters, so a midpoint sitting in chapter twelve of twenty still reports 61%.
Drift is information, not a failure. Every template can be edited, partially
applied, or ignored.

### Evidence

<img src="docs/screenshots/10-evidence.png" alt="Evidence ledger listing claims with their support strength and fact-check status" width="100%">

Every claim your book makes, mapped to the sources that support it, with a
support strength and a fact-check status. Then one view — **Weak Links** —
shows which claims are carrying more weight than their evidence can bear.

Citations live in the prose as `[@citekey]` or `[@citekey, p. 316]`, which is
pandoc's syntax, so your manuscript stays legible to every other tool. Import
CSL-JSON from Zotero, and Compile turns the markers into numbered endnotes and
a bibliography in Chicago (notes or author-date), APA 7, or MLA 9. It warns you
about citation keys that match no source, and about quotes from anyone marked
*needs release*.

### Timeline, Characters, Notes

<div align="center">
<img src="docs/screenshots/04-timeline.png" alt="Timeline view with narrative order beside chronological order" width="49%">
<img src="docs/screenshots/05-characters.png" alt="Character card with arc fields" width="49%">
</div>

Timeline runs two tracks — the order the reader meets events against the order
they happened — and flags the ones that disagree. Character cards carry the arc
fields that matter (want, need, the lie they believe, the wound underneath) and
a strip showing which scenes they appear in. Notes are cards with tags, links,
and a mind-map canvas.

---

## Diagnostics, and the practice layer

<img src="docs/screenshots/07-diagnostics.png" alt="Diagnostics showing sentence rhythm, crutch words, filter words and a repetition radar" width="100%">

Revise mode measures sentence-length variance, your personal crutch words,
filter words, adverb rate, a passive-voice heuristic, dialogue share, a
repetition radar, and a pacing curve across the whole book.

**Every number is descriptive, not a score.** Cormac McCarthy would fail the
punctuation checks and Hemingway would fail the variance one. The point is to
show you patterns you cannot see from inside the sentence you are currently
writing.

<img src="docs/screenshots/08-progress.png" alt="Progress pane showing sessions, words added and words cut, and a rhythm report" width="100%">

### Why there is no streak counter

Nearly every writing app's streak counter traces back to Robert Boice's
intervention studies from the 1980s. Helen Sword audited those studies in 2016
and the audit does not go well for them: nine or ten self-selected subjects per
group, a 36% dropout rate, never replicated, and the famous "17 / 64 / 157
pages a year" figures appear nowhere in the original paper. Sword's own study
— 1,323 academics across fifteen countries — found only about **12%** write
daily, and that daily writing is neither a reliable marker nor a predictor of
productivity.

So Pilcrow tracks your rhythm instead of prescribing one. **No streak that can
break, no red numbers, no "you haven't written in six days."** The evidence
doesn't support the shame, and shame is what makes people stop opening the app.

What does hold up is built in:

- **Words cut count as work.** The Progress Log records both columns at equal
  weight. In revision, cutting *is* the work — a tracker that only counts words
  added punishes exactly the sessions where a book gets good.
  (Amabile & Kramer coded ~12,000 daily diaries: the strongest predictor of a
  good creative workday is a sense of progress.)
- **Appointments, not targets.** You schedule a time, a place, and a document —
  an if-then plan. Gollwitzer & Sheeran put implementation intentions at around
  *d* = 0.65 across hundreds of studies. It goes on your real calendar.
- **Session close asks what happens next**, and puts your answer above the
  cursor when you sit back down. Backed by the resumption half of the Zeigarnik
  literature — a 2025 meta-analysis found no recall advantage for interrupted
  tasks but a robust two-thirds unprompted resumption rate.
- **Draft and Revise are separate modes.** Draft hides spellcheck, counts, and
  every analysis panel. Planning, translating and reviewing compete for the
  same working memory; doing all three at once is what a blank page feels like.

---

## Getting it out

Compile to **standard manuscript format** (RTF or Word — Times 12pt, double
spaced, indented, scene breaks as `#`, title page with a rounded word count),
**EPUB 3**, a **typeset PDF** with real trim sizes, mirrored margins, running
heads, folios and chapters opening on a fresh right-hand page, or plain
Markdown, text, and HTML.

---

## Keys

| | |
|---|---|
| `⌘N` / `⌥⌘N` | New scene / new chapter |
| `⌘1`–`⌘9`, `⌘0` | Switch views |
| `⌘B` `⌘I` | Bold, italic |
| `⌥⌘1`–`⌥⌘3`, `⌥⌘0` | Title, heading, subheading, body |
| `⌘↩` | Scene break |
| `⇧⌘K` | Comment on the selection |
| `⇧⌘D` | Draft ⇄ Revise |
| `⇧⌘T` / `⌥⌘T` | Start a sprint / close the session |
| `⇧⌘L` | Read aloud |
| `⌘\` / `⇧⌘\` | Hide binder / hide studio |
| `⌥⌘F` | Nothing but the page |
| `⇧⌘S` | Snapshot |
| `⌘E` | Compile |

---

## Build from source

Needs Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```bash
git clone https://github.com/michaellomuscio/pilcrow.git
cd pilcrow
cp local.xcconfig.example local.xcconfig   # add your Team ID, or leave blank
make run                                   # debug build and launch
make test                                  # the full suite
make install                               # signed release into /Applications
```

`make test` runs five harnesses covering the Markdown round trip, the folder
read/write cycle, the craft engines, comment-anchor hardening, and a full
EPUB→PDF→RTF export — 143 assertions, no external dependencies.

---

## Licence and name

The **code** is [Apache 2.0](LICENSE). Use it, study it, modify it,
redistribute it — including modified versions.

The **name and identity** are not part of that grant. If you distribute a
modified build you must rename it, change the bundle identifier, and remove the
Lomuscio Labs name, the ¶ icon, and the brand colours first. Modification is
welcome; a changed build going out under this name gives the person
downloading it no way to tell whose software they are running. Full policy:
[TRADEMARKS.md](TRADEMARKS.md).

Pilcrow is provided **as is**, with no warranty and no liability. You are
responsible for your own backups. [Full terms](TERMS.md).

---

<div align="center">

Built by **Michael Lomuscio** · [michaellomuscio.com](https://michaellomuscio.com)

A Lomuscio Labs project

</div>
