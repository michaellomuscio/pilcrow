//  Citations.swift
//  CSL-JSON in, Chicago / APA / MLA out.
//
//  Citations live in the prose as [@citekey] or [@citekey, p. 34]. That is
//  pandoc's syntax, so a Pilcrow manuscript stays legible to every other
//  tool in the chain. On compile they become numbered endnotes or
//  author-date parentheticals, plus a bibliography.
//
//  Endnotes rather than per-page footnotes on purpose: publishers ask for
//  endnotes in a submitted manuscript, and no export format we write
//  supports real page-bottom notes without lying about pagination.

import Foundation

// MARK: - CSL

struct CSLName: Codable, Hashable {
    var family: String = ""
    var given: String = ""

    var full: String {
        [given, family].filter { !$0.isEmpty }.joined(separator: " ")
    }
    var inverted: String {
        family.isEmpty ? given : (given.isEmpty ? family : "\(family), \(given)")
    }
    var initials: String {
        let parts = given.split(separator: " ").compactMap { $0.first }
        return parts.map { "\($0)." }.joined(separator: " ")
    }
}

struct CSLItem: Codable, Hashable, Identifiable {
    var id: String = ""                 // the citekey
    var type: String = "book"
    var title: String = ""
    var authors: [CSLName] = []
    var editors: [CSLName] = []
    var containerTitle: String = ""     // journal, or the book a chapter is in
    var publisher: String = ""
    var publisherPlace: String = ""
    var issued: String = ""             // year, usually
    var volume: String = ""
    var issue: String = ""
    var page: String = ""
    var doi: String = ""
    var url: String = ""
    var accessed: String = ""
    var edition: String = ""

    var year: String {
        // "2016-08-11" or "2016" or "n.d."
        let head = issued.split(separator: "-").first.map(String.init) ?? issued
        return head.isEmpty ? "n.d." : head
    }

    var isEmpty: Bool { title.isEmpty && authors.isEmpty }

    /// Deterministic key from author + year, e.g. `sword2016`.
    static func makeKey(_ authors: [CSLName], _ year: String, taken: Set<String>) -> String {
        let base = (authors.first?.family ?? "anon")
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .filter { $0.isLetter }
        var key = "\(base.isEmpty ? "anon" : base)\(year.filter(\.isNumber))"
        if key.isEmpty { key = "source" }
        guard taken.contains(key) else { return key }
        for suffix in "abcdefghijklmnopqrstuvwxyz" {
            let c = key + String(suffix)
            if !taken.contains(c) { return c }
        }
        return key + UUID().uuidString.prefix(4).lowercased()
    }
}

// MARK: - Import

enum CSLImport {
    /// Reads a CSL-JSON export from Zotero, Mendeley, or BibTeX-via-pandoc.
    static func parse(_ data: Data) throws -> [CSLItem] {
        let root = try JSONSerialization.jsonObject(with: data)
        let array: [[String: Any]]
        if let a = root as? [[String: Any]] { array = a }
        else if let o = root as? [String: Any] { array = [o] }
        else { return [] }
        return array.map { item($0) }
    }

    private static func item(_ d: [String: Any]) -> CSLItem {
        var c = CSLItem()
        c.id = str(d["id"])
        c.type = str(d["type"], default: "book")
        c.title = str(d["title"])
        c.authors = names(d["author"])
        c.editors = names(d["editor"])
        c.containerTitle = str(d["container-title"])
        c.publisher = str(d["publisher"])
        c.publisherPlace = str(d["publisher-place"])
        c.issued = date(d["issued"])
        c.volume = str(d["volume"])
        c.issue = str(d["issue"])
        c.page = str(d["page"])
        c.doi = str(d["DOI"], or: d["doi"])
        c.url = str(d["URL"], or: d["url"])
        c.accessed = date(d["accessed"])
        c.edition = str(d["edition"])
        return c
    }

    private static func str(_ v: Any?, or alt: Any? = nil, default def: String = "") -> String {
        if let s = v as? String, !s.isEmpty { return s }
        if let n = v as? NSNumber { return n.stringValue }
        if let alt { return str(alt, default: def) }
        return def
    }

    private static func names(_ v: Any?) -> [CSLName] {
        guard let arr = v as? [[String: Any]] else { return [] }
        return arr.map {
            CSLName(family: str($0["family"]), given: str($0["given"]))
        }.filter { !$0.full.isEmpty }
    }

    /// CSL dates are `{"date-parts": [[2016, 8, 11]]}` or a raw string.
    private static func date(_ v: Any?) -> String {
        if let d = v as? [String: Any] {
            if let parts = d["date-parts"] as? [[Any]], let first = parts.first {
                return first.compactMap { p -> String? in
                    if let n = p as? NSNumber { return n.stringValue }
                    return p as? String
                }.joined(separator: "-")
            }
            if let raw = d["raw"] as? String { return raw }
            if let lit = d["literal"] as? String { return lit }
        }
        return str(v)
    }
}

// MARK: - Styles

enum CitationStyle: String, Codable, CaseIterable, Identifiable {
    case chicagoNotes, chicagoAuthorDate, apa, mla
    var id: String { rawValue }

    var label: String {
        switch self {
        case .chicagoNotes:      return "Chicago (notes & bibliography)"
        case .chicagoAuthorDate: return "Chicago (author\u{2013}date)"
        case .apa:               return "APA 7"
        case .mla:               return "MLA 9"
        }
    }
    /// Notes styles put a number in the text; author-date styles put a
    /// parenthetical there instead.
    var isNumbered: Bool { self == .chicagoNotes }
    var bibliographyTitle: String {
        switch self {
        case .chicagoNotes, .chicagoAuthorDate: return "Bibliography"
        case .apa:                              return "References"
        case .mla:                              return "Works Cited"
        }
    }
}

enum CitationFormatter {

    // MARK: In text

    static func inText(_ c: CSLItem, locator: String, style: CitationStyle) -> String {
        let loc = locator.trimmingCharacters(in: .whitespaces)
        switch style {
        case .chicagoNotes:
            return ""   // handled as a numbered note
        case .chicagoAuthorDate:
            let a = surnames(c.authors, max: 3)
            return "(\(a) \(c.year)\(loc.isEmpty ? "" : ", \(loc)"))"
        case .apa:
            let a = surnames(c.authors, max: 2, amp: true)
            return "(\(a), \(c.year)\(loc.isEmpty ? "" : ", \(normalisePage(loc))"))"
        case .mla:
            let a = surnames(c.authors, max: 2)
            let bare = strip(loc)
            let page = bare.isEmpty ? "" : " " + bare
            return "(\(a)\(page))"
        }
    }

    /// A Chicago footnote, first or shortened form.
    static func note(_ c: CSLItem, locator: String, short: Bool) -> String {
        let loc = locator.trimmingCharacters(in: .whitespaces)
        if short {
            let a = c.authors.first?.family ?? c.title
            return "\(a), \(shortTitle(c.title))\(loc.isEmpty ? "" : ", \(strip(loc))")."
        }
        var out = c.authors.isEmpty ? "" : listed(c.authors, inverted: false) + ", "
        out += "\u{201C}\(c.title)\u{201D}"
        if !c.containerTitle.isEmpty { out += ", \(c.containerTitle)" }
        if !c.volume.isEmpty { out += " \(c.volume)" }
        if !c.issue.isEmpty { out += ", no. \(c.issue)" }
        var paren: [String] = []
        if !c.publisherPlace.isEmpty { paren.append(c.publisherPlace) }
        if !c.publisher.isEmpty { paren.append(c.publisher) }
        if !c.issued.isEmpty { paren.append(c.year) }
        if !paren.isEmpty { out += " (\(paren.joined(separator: ": ")))" }
        if !c.page.isEmpty { out += ", \(c.page)" }
        if !loc.isEmpty { out += ", \(strip(loc))" }
        if !c.doi.isEmpty { out += ", https://doi.org/\(c.doi)" }
        else if !c.url.isEmpty { out += ", \(c.url)" }
        return out + "."
    }

    // MARK: Bibliography

    static func bibliography(_ c: CSLItem, style: CitationStyle) -> String {
        switch style {
        case .chicagoNotes, .chicagoAuthorDate:
            var out = c.authors.isEmpty ? "" : listed(c.authors, inverted: true) + ". "
            if style == .chicagoAuthorDate { out += "\(c.year). " }
            out += c.containerTitle.isEmpty ? "*\(c.title)*. " : "\u{201C}\(c.title).\u{201D} "
            if !c.containerTitle.isEmpty {
                out += "*\(c.containerTitle)*"
                if !c.volume.isEmpty { out += " \(c.volume)" }
                if !c.issue.isEmpty { out += ", no. \(c.issue)" }
                if style == .chicagoNotes { out += " (\(c.year))" }
                if !c.page.isEmpty { out += ": \(c.page)" }
                out += ". "
            } else {
                if !c.publisherPlace.isEmpty { out += "\(c.publisherPlace): " }
                if !c.publisher.isEmpty { out += "\(c.publisher)" }
                if style == .chicagoNotes && !c.issued.isEmpty { out += ", \(c.year)" }
                out += ". "
            }
            if !c.doi.isEmpty { out += "https://doi.org/\(c.doi)." }
            else if !c.url.isEmpty { out += "\(c.url)." }
            return tidy(out)

        case .apa:
            var out = c.authors.isEmpty ? "" : apaNames(c.authors) + " "
            out += "(\(c.year)). "
            if c.containerTitle.isEmpty {
                out += "*\(c.title)*"
                if !c.edition.isEmpty { out += " (\(c.edition) ed.)" }
                out += ". "
                if !c.publisher.isEmpty { out += "\(c.publisher). " }
            } else {
                out += "\(c.title). *\(c.containerTitle)*"
                if !c.volume.isEmpty { out += ", *\(c.volume)*" }
                if !c.issue.isEmpty { out += "(\(c.issue))" }
                if !c.page.isEmpty { out += ", \(c.page)" }
                out += ". "
            }
            if !c.doi.isEmpty { out += "https://doi.org/\(c.doi)" }
            else if !c.url.isEmpty { out += c.url }
            return tidy(out)

        case .mla:
            var out = c.authors.isEmpty ? "" : mlaNames(c.authors) + " "
            out += c.containerTitle.isEmpty ? "*\(c.title)*. " : "\u{201C}\(c.title).\u{201D} "
            if !c.containerTitle.isEmpty {
                out += "*\(c.containerTitle)*"
                if !c.volume.isEmpty { out += ", vol. \(c.volume)" }
                if !c.issue.isEmpty { out += ", no. \(c.issue)" }
                if !c.issued.isEmpty { out += ", \(c.year)" }
                if !c.page.isEmpty { out += ", pp. \(c.page)" }
                out += ". "
            } else {
                if !c.publisher.isEmpty { out += "\(c.publisher), " }
                out += "\(c.year). "
            }
            if !c.url.isEmpty { out += "\(c.url). " }
            if !c.accessed.isEmpty { out += "Accessed \(c.accessed)." }
            return tidy(out)
        }
    }

    // MARK: Helpers

    private static func surnames(_ n: [CSLName], max: Int, amp: Bool = false) -> String {
        guard !n.isEmpty else { return "Anon." }
        let fams = n.map { $0.family.isEmpty ? $0.given : $0.family }
        if fams.count > max { return "\(fams[0]) et al." }
        if fams.count == 1 { return fams[0] }
        let joiner = amp ? " & " : " and "
        return fams.dropLast().joined(separator: ", ") + joiner + fams.last!
    }

    private static func listed(_ n: [CSLName], inverted: Bool) -> String {
        guard !n.isEmpty else { return "" }
        var parts = n.map { $0.full }
        if inverted, let first = n.first {
            parts[0] = first.inverted
        }
        if parts.count == 1 { return parts[0] }
        if parts.count > 10 {
            return parts.prefix(7).joined(separator: ", ") + ", et al."
        }
        return parts.dropLast().joined(separator: ", ") + ", and " + parts.last!
    }

    private static func apaNames(_ n: [CSLName]) -> String {
        let parts = n.map { name -> String in
            let i = name.initials
            return name.family.isEmpty ? name.given
                 : (i.isEmpty ? name.family : "\(name.family), \(i)")
        }
        if parts.count == 1 { return parts[0] + "." }
        if parts.count > 20 {
            return parts.prefix(19).joined(separator: ", ") + ", ... " + parts.last! + "."
        }
        return parts.dropLast().joined(separator: ", ") + ", & " + parts.last! + "."
    }

    private static func mlaNames(_ n: [CSLName]) -> String {
        guard let first = n.first else { return "" }
        if n.count == 1 { return first.inverted + "." }
        if n.count == 2 { return "\(first.inverted), and \(n[1].full)." }
        return first.inverted + ", et al."
    }

    private static func shortTitle(_ t: String) -> String {
        let words = t.split(separator: " ")
        return words.count <= 4 ? "*\(t)*"
             : "*\(words.prefix(4).joined(separator: " "))*"
    }
    private static func strip(_ loc: String) -> String {
        loc.replacingOccurrences(of: "p. ", with: "")
           .replacingOccurrences(of: "pp. ", with: "")
    }
    private static func normalisePage(_ loc: String) -> String {
        loc.hasPrefix("p.") || loc.hasPrefix("pp.") ? loc : "p. \(loc)"
    }
    private static func tidy(_ s: String) -> String {
        s.replacingOccurrences(of: "  ", with: " ")
         .replacingOccurrences(of: " .", with: ".")
         .replacingOccurrences(of: "..", with: ".")
         .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Finding citations in prose

struct CitationRef: Hashable {
    let key: String
    let locator: String
    let range: NSRange
}

enum CitationScanner {
    /// Matches `[@key]` and `[@key, p. 34]`.
    private static let pattern = try! NSRegularExpression(
        pattern: #"\[@([A-Za-z0-9_:.#$%&+?<>~/-]+)(?:,\s*([^\]]+))?\]"#)

    static func scan(_ text: String) -> [CitationRef] {
        let ns = text as NSString
        return pattern.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { m in
                let key = ns.substring(with: m.range(at: 1))
                let loc = m.range(at: 2).location == NSNotFound
                        ? "" : ns.substring(with: m.range(at: 2))
                return CitationRef(key: key, locator: loc, range: m.range)
            }
    }

    /// Replaces every marker using `render`, back to front so ranges hold.
    static func replace(in text: String,
                        render: (CitationRef) -> String) -> String {
        let ns = NSMutableString(string: text)
        for ref in scan(text).reversed() {
            ns.replaceCharacters(in: ref.range, with: render(ref))
        }
        return ns as String
    }
}
