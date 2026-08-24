#!/usr/bin/env bash
# Compiles the model + store layers standalone and runs the harnesses.
# These cover the two things that would quietly ruin a manuscript: the
# Markdown round trip, and the folder read/write cycle.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
SRC=(
  Pilcrow/Design/Palette.swift Pilcrow/Design/Typography.swift
  Pilcrow/Model/Project.swift Pilcrow/Model/Studio.swift
  Pilcrow/Model/Structure.swift Pilcrow/Model/Craft.swift
  Pilcrow/Model/Citations.swift Pilcrow/Analysis/Prose.swift
  Pilcrow/Store/MarkdownCodec.swift Pilcrow/Store/ProjectStore.swift
  Pilcrow/Store/LenientCoding.swift Pilcrow/Store/Appointments.swift
  Pilcrow/Export/Compiler.swift Pilcrow/Export/CitationGather.swift
  Pilcrow/Export/EPUB.swift Pilcrow/Export/PDFBook.swift
)
for harness in Tests/RoundTrip Tests/Store Tests/Craft Tests/Export; do
  name=$(basename "$harness")
  mkdir -p "$OUT/$name"
  cp "$harness/main.swift" "$OUT/$name/main.swift"
  swiftc -target arm64-apple-macos14.0 "${SRC[@]}" "$OUT/$name/main.swift" \
    -o "$OUT/$name/run" 2>&1 | grep -E "error:" && exit 1 || true
  echo "── $name"
  "$OUT/$name/run"
done
rm -rf "$OUT"
