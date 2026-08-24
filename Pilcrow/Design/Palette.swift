//  Palette.swift
//  Lomuscio Labs brand tokens, plus the manuscript page surface.
//
//  Governing rule (see docs/DESIGN.md §10):
//  The brand owns the chrome. The book owns the page.
//  Brand purple never appears inside the manuscript pane except as the
//  caret, the selection, and comment anchors.

import SwiftUI
import AppKit

enum LL {

    // MARK: - Dynamic color helper

    /// Builds a color that resolves differently in light and dark appearance.
    static func dyn(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }

    static func nsdyn(_ light: NSColor, _ dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    // MARK: - Raw brand palette (brand kit v1.0)

    static let black      = NSColor(hex: 0x0A0A0B)
    static let deepBlack  = NSColor(hex: 0x050506)
    static let white      = NSColor(hex: 0xF8F8F8)
    static let pureWhite  = NSColor(hex: 0xFFFFFF)
    static let midGray    = NSColor(hex: 0x6B6B73)
    static let lightGray  = NSColor(hex: 0xB8B8BF)
    static let paleGray   = NSColor(hex: 0xE2E2E6)
    static let offWhite   = NSColor(hex: 0xEDEDEE)

    static let purple      = NSColor(hex: 0x7B2FBE)
    static let purpleDark  = NSColor(hex: 0x5A1F8E)
    static let purpleLight = NSColor(hex: 0xA96BDB)
    static let purpleMuted = NSColor(hex: 0x9B7BBF)
    static let purpleGhost = NSColor(hex: 0xF3EEFA)

    // Chart palette, in the priority order the brand kit specifies.
    static let chart: [NSColor] = [
        NSColor(hex: 0x7B2FBE), NSColor(hex: 0x1DB9A0), NSColor(hex: 0xE8634F),
        NSColor(hex: 0xD4A843), NSColor(hex: 0x5A6B7E), NSColor(hex: 0x4DA3D4),
        NSColor(hex: 0xD4648A), NSColor(hex: 0x7CBB4F)
    ]

    static func chartColor(_ i: Int) -> Color { Color(nsColor: chart[i % chart.count]) }
    static func chartNS(_ i: Int) -> NSColor { chart[i % chart.count] }

    // MARK: - Semantic chrome (the app frame)

    /// Window background behind panels.
    static let ground   = dyn(NSColor(hex: 0xF3F3F4), NSColor(hex: 0x121214))
    /// Panel / card surfaces.
    static let surface  = dyn(pureWhite,              NSColor(hex: 0x1A1A1D))
    /// Slightly recessed surface (list headers, wells).
    static let recessed = dyn(NSColor(hex: 0xEDEDEE), NSColor(hex: 0x1F1F23))
    /// Raised surface (popovers, hovered rows).
    static let raised   = dyn(pureWhite,              NSColor(hex: 0x24242A))

    static let ink      = dyn(black,     NSColor(hex: 0xE9E7E2))
    static let ink2     = dyn(NSColor(hex: 0x56565E), NSColor(hex: 0xA3A3AB))
    static let ink3     = dyn(NSColor(hex: 0x8A8A93), NSColor(hex: 0x75757E))

    static let rule       = dyn(paleGray,             NSColor(hex: 0x2C2C31))
    static let ruleStrong = dyn(NSColor(hex: 0xC9C9D1), NSColor(hex: 0x41414A))

    /// Brand purple, lightened in dark mode so it holds contrast.
    static let accent     = dyn(purple,               NSColor(hex: 0xB47CE4))
    static let accentNS   = nsdyn(purple,             NSColor(hex: 0xB47CE4))
    static let accentInk  = dyn(purpleDark,           NSColor(hex: 0xCBA3F0))
    static let accentSoft = dyn(purpleGhost,          NSColor(hex: 0x241A33))
    static let onAccent   = dyn(pureWhite,            NSColor(hex: 0x17111F))

    // Status scale — deliberately NOT purple, so status never reads as intent.
    static let ok    = dyn(NSColor(hex: 0x146B59), NSColor(hex: 0x43C4A6))
    static let warn  = dyn(NSColor(hex: 0x8F5E12), NSColor(hex: 0xD4A843))
    static let crit  = dyn(NSColor(hex: 0xAD3A28), NSColor(hex: 0xEE7460))

    // MARK: - The page (manuscript surface)

    /// Warm off-white. Never pure white — harsh at 19pt for hours.
    /// Dark is a warm near-black. Never pure black with pure white text:
    /// halation blurs the letterforms.
    static func paper(_ theme: PageTheme) -> NSColor {
        switch theme {
        case .paper:  return nsdyn(NSColor(hex: 0xFCFBF8), NSColor(hex: 0x1C1B19))
        case .sepia:  return nsdyn(NSColor(hex: 0xF6EFE1), NSColor(hex: 0x211D16))
        case .slate:  return nsdyn(NSColor(hex: 0xF2F3F5), NSColor(hex: 0x17191C))
        }
    }

    static func pageInk(_ theme: PageTheme) -> NSColor {
        switch theme {
        case .paper:  return nsdyn(NSColor(hex: 0x1A1917), NSColor(hex: 0xE4E1DA))
        case .sepia:  return nsdyn(NSColor(hex: 0x2A2318), NSColor(hex: 0xE6DCC8))
        case .slate:  return nsdyn(NSColor(hex: 0x16181B), NSColor(hex: 0xDDE1E6))
        }
    }

    static func pageEdge(_ theme: PageTheme) -> NSColor {
        switch theme {
        case .paper:  return nsdyn(NSColor(hex: 0xEFEDE6), NSColor(hex: 0x2A2825))
        case .sepia:  return nsdyn(NSColor(hex: 0xE7DCC6), NSColor(hex: 0x322B20))
        case .slate:  return nsdyn(NSColor(hex: 0xE3E5E9), NSColor(hex: 0x24272B))
        }
    }
}

enum PageTheme: String, Codable, CaseIterable, Identifiable {
    case paper, sepia, slate
    var id: String { rawValue }
    var label: String {
        switch self {
        case .paper: return "Paper"
        case .sepia: return "Sepia"
        case .slate: return "Slate"
        }
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green:   CGFloat((hex >> 8) & 0xFF) / 255,
                  blue:    CGFloat(hex & 0xFF) / 255,
                  alpha:   1)
    }
}
