//  CitationGather.swift
//  Walks the compiled manuscript once, numbering citations in reading order
//  and building the note list and bibliography.

import Foundation

@MainActor
enum Citations {

    struct Note: Identifiable {
        let number: Int
        let key: String
        let locator: String
        let text: String
        var id: Int { number }
    }

    struct Gathered {
        var ordered: [Note] = []
        var items: [String: CSLItem] = [:]
        /// "key|locator" -> note number, so a repeat citation reuses its note.
        var numbers: [String: Int] = [:]
        /// Keys in first-appearance order, for the bibliography.
        var order: [String] = []
        /// Citations whose key matches no source in the cast.
        var unresolved: Set<String> = []

        func number(for ref: CitationRef) -> Int? {
            numbers["\(ref.key)|\(ref.locator)"]
        }

        func inTextString(for ref: CitationRef, style: CitationStyle) -> String {
            guard let item = items[ref.key] else { return "" }
            return CitationFormatter.inText(item, locator: ref.locator, style: style)
        }

        func bibliography(style: CitationStyle) -> [String] {
            order.compactMap { items[$0] }
                .map { CitationFormatter.bibliography($0, style: style) }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
    }

    static func gather(store: ProjectStore, options: CompileOptions) -> Gathered {
        var g = Gathered()

        // Everything in the cast that can be cited, by key.
        for e in store.manifest.cast {
            let key = e.citekey.isEmpty ? nil : e.citekey
            guard let key else { continue }
            var item = e.csl
            if item.isEmpty {
                // A source with no imported CSL still cites — fall back to
                // what the card actually holds.
                item.title = e.name
                item.id = key
                if !e.citation.isEmpty { item.containerTitle = e.citation }
                if !e.url.isEmpty { item.url = e.url }
            }
            item.id = key
            g.items[key] = item
        }

        var seenFirst = Set<String>()
        var next = 1

        func visit(_ node: Node) {
            for child in node.children {
                if options.onlyIncluded && !child.includeInCompile { continue }
                if child.status == .cut { continue }
                for ref in CitationScanner.scan(store.body(child.id)) {
                    guard g.items[ref.key] != nil else {
                        g.unresolved.insert(ref.key); continue
                    }
                    let slot = "\(ref.key)|\(ref.locator)"
                    if g.numbers[slot] == nil {
                        let short = seenFirst.contains(ref.key)
                        let text = CitationFormatter.note(g.items[ref.key]!,
                                                          locator: ref.locator, short: short)
                        g.numbers[slot] = next
                        g.ordered.append(Note(number: next, key: ref.key,
                                              locator: ref.locator, text: text))
                        next += 1
                    }
                    if !seenFirst.contains(ref.key) {
                        seenFirst.insert(ref.key)
                        g.order.append(ref.key)
                    }
                }
                visit(child)
            }
        }
        visit(store.manifest.root)
        return g
    }

    /// Assigns citekeys to any source that lacks one. Called before compile
    /// so a freshly imported library is immediately citable.
    static func ensureKeys(_ store: ProjectStore) {
        var taken = Set(store.manifest.cast.map(\.citekey).filter { !$0.isEmpty })
        var changed = false
        for i in store.manifest.cast.indices {
            let e = store.manifest.cast[i]
            guard e.citekey.isEmpty, e.kind == .source || e.kind == .person else { continue }
            let authors = e.csl.authors.isEmpty
                ? [CSLName(family: e.name, given: "")]
                : e.csl.authors
            let key = CSLItem.makeKey(authors, e.csl.year, taken: taken)
            taken.insert(key)
            store.manifest.cast[i].citekey = key
            store.manifest.cast[i].csl.id = key
            changed = true
        }
        if changed { store.touchManifest() }
    }
}
