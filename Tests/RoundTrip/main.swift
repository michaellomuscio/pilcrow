import AppKit

@MainActor func run() {
    var style = PageStyle()
    style.mode = .revise
    style.faceID = "literata"

    let cases: [(String, String)] = [
        ("plain", "The house was quiet."),
        ("italic", "She was *utterly* still."),
        ("bold", "He said **no**."),
        ("both", "It was ***everything***."),
        ("multi", "A *one* and a **two** and a ***three***."),
        ("multiline", "First para.\nSecond para with *emphasis*.\nThird."),
        ("blank lines", "One.\n\nTwo.\n\nThree."),
        ("heading1", "# Chapter One\n\nBody text here."),
        ("heading2", "## A Section\n\nMore body."),
        ("scene break", "Before.\n\n---\n\nAfter."),
        ("escaped star", "A literal \\* star."),
        ("snake_case", "The snake_case_name stays intact."),
        ("underscore em", "An _underscored_ word."),
        ("apostrophe", "Nell\u{2019}s ledger \u{2014} it\u{2019}s hers."),
        ("empty", ""),
        ("trailing nl", "Line one.\n"),
        ("unmatched", "A lone * asterisk mid-line."),
        ("adjacent", "**bold**then*italic*"),
        ("space edges", "A ** spaced ** thing."),
        ("long", String(repeating: "Some prose with *emphasis* in it. ", count: 40)),
    ]

    var pass = 0, fail = 0
    for (name, input) in cases {
        let attr = MarkdownCodec.attributed(from: input, style: style)
        let out  = MarkdownCodec.markdown(from: attr)
        // Round trip twice — the second pass must be a fixed point.
        let attr2 = MarkdownCodec.attributed(from: out, style: style)
        let out2  = MarkdownCodec.markdown(from: attr2)

        let stable = (out == out2)
        // Text content (markup stripped) must survive exactly.
        let plainIn  = attr.string
        let plainOut = attr2.string
        let same = (plainIn == plainOut)

        if stable && same {
            pass += 1
            print("  ok    \(name)")
        } else {
            fail += 1
            print("  FAIL  \(name)")
            print("        in   \(input.debugDescription.prefix(90))")
            print("        out  \(out.debugDescription.prefix(90))")
            print("        out2 \(out2.debugDescription.prefix(90))")
            if !same {
                print("        plain drift: \(plainIn.debugDescription.prefix(70)) != \(plainOut.debugDescription.prefix(70))")
            }
        }
    }

    // Word count sanity
    let wc = MarkdownCodec.wordCount("The house was quiet in the way")
    print(wc == 7 ? "  ok    wordCount" : "  FAIL  wordCount = \(wc), want 7")
    if wc != 7 { fail += 1 } else { pass += 1 }

    print("\n\(pass) passed, \(fail) failed")
    exit(fail == 0 ? 0 : 1)
}
MainActor.assumeIsolated { run() }
