// Generated from shared/design-tokens/tokens.json. Run make generate.
import SwiftUI
import UIKit

enum GraceColor {
    static let canvas = adaptive(0xF7F6F0, 0x182B24, 0xF7F6F0, 0x182B24)
    static let ink = adaptive(0x253E32, 0xF4F1E8, 0x253E32, 0xF4F1E8)
    static let secondary = adaptive(0x65705F, 0xBDC7B8, 0x253E32, 0xF4F1E8)
    static let accent = adaptive(0x44634D, 0xB9C9A9, 0x44634D, 0xB9C9A9)
    static let wash = adaptive(0xE9ECDF, 0x243D32, 0xE9ECDF, 0x243D32)
    static let border = adaptive(0xDCDFD2, 0x405448, 0x65705F, 0xBDC7B8)
    static let gold = adaptive(0x977645, 0xD5C592, 0x977645, 0xD5C592)
    static let card = adaptive(0xFFFFFF, 0x20372D, 0xFFFFFF, 0x20372D)
    static let button = adaptive(0x253E32, 0xDCE4CE, 0x253E32, 0xDCE4CE)
    static let buttonText = adaptive(0xFFFFFF, 0x182B24, 0xFFFFFF, 0x182B24)

    private static func adaptive(_ light: UInt, _ dark: UInt, _ lightHigh: UInt, _ darkHigh: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            let high = traits.accessibilityContrast == .high
            let value = traits.userInterfaceStyle == .dark ? (high ? darkHigh : dark) : (high ? lightHigh : light)
            return UIColor(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, alpha: 1)
        })
    }
}

enum GraceLayout {
    static let margin: CGFloat = 24
    static let cardRadius: CGFloat = 24
    static let primaryHeight: CGFloat = 52
    static let minimumTarget: CGFloat = 44
    static let playTarget: CGFloat = 70
    static let readingWidth: CGFloat = 680
}
