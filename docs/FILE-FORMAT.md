# The file format

Pilcrow's promise is that leaving is easy, which is the only real reason to
stay. This document exists so that promise is verifiable.

## Layout

```
<Project Folder>/
├── Pilcrow Project.json
├── Manuscript/
│   ├── <Chapter>/              a container node is a directory
│   │   ├── _chapter.md         the container's own prose, if it has any
│   │   └── <Scene>.md          a leaf node is a Markdown file
│   └── <Scene>.md              leaves can also sit at the top level
└── .pilcrow/
    ├── sessions.json           the writing log
    └── snapshots/<node-uuid>/<timestamp>.md
```

Everything outside `.pilcrow/` is meant to be read by a human.

## Two authorities, on purpose

- **`Pilcrow Project.json` is the authority on order and metadata** — the tree,
  threads, beats, cast, notes, claims, page settings.
- **The `.md` files are the authority on prose.**

Each file carries its own id in front matter, so either side can rebuild the
other. Lose the manifest and the prose is intact; lose a file and the rest of
the book is intact.

## Front matter

Minimal, and only written when there's something to write:

```markdown
---
pilcrow-id: 3F2A9C41-...
status: drafting
synopsis: Nell discovers Ardmore isn't where the survey says it is.
target: 2500
---

The village of Ardmore had been in the wrong place for eleven years.
```

`pilcrow-id` is always present. Everything else appears only when set. Values
escape newlines as `\n`; nothing else is transformed.

## The Markdown subset

Deliberately small, and total — every document round-trips exactly.

| Markup | Meaning |
|---|---|
| `*text*` or `_text_` | italic |
| `**text**` | bold |
| `***text***` | bold italic |
| `# ` `## ` `### ` | title, heading, subheading |
| `---` alone on a line | scene break (shown as ⁂) |
| `\*` `\_` `\#` | literal character |

Underscores only count at word boundaries, so `snake_case_name` survives.
Anything not in this table is stored as literal text — no silent rewriting.

`Scripts/test.sh` asserts the round trip on twenty cases, including the ones
that usually break: escaped delimiters, unmatched delimiters, adjacent runs,
trailing newlines, and empty files.

## Adoption

Any `.md` in a chapter folder that the manifest doesn't know about is adopted
into the book on next open, at the end of its folder. Dropping a file into a
chapter in Finder is a legitimate way to add a scene. If it has a `pilcrow-id`
in front matter, that identity is kept.

## Compatibility

Every persisted type decodes field by field with a fallback
(`Pilcrow/Store/LenientCoding.swift`). A project written by an older version
opens in a newer one; a project written by a newer version opens in an older
one and ignores what it doesn't understand. An unrecognised enum value falls
back rather than throwing.

This matters more than it sounds: the default Swift behaviour is to throw on
any missing key, which would mean "I added a field, now none of your books
open."

## Deletion

Deleting a node moves its file to the Trash via `NSFileManager.trashItem`.
Nothing is ever unlinked outright.

## Reading it without Pilcrow

```bash
# The whole book, in order, as one file
cat "Manuscript"/*/*.md

# Word count
cat Manuscript/*/*.md | sed '/^---$/,/^---$/d' | wc -w

# Version history for free
cd <project folder> && git init && git add -A && git commit -m "draft"
```
