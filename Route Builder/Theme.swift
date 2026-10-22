import SwiftUI

enum Theme {
    static let ink = Color(hex: 0x16232E)
    static let teal = Color(hex: 0x0D6E76)
    static let muted = Color(hex: 0x6B7C8A)
    static let line = Color(hex: 0xDFE5E9)
    static let canvasStops = Color(hex: 0xEEF1F3)
    static let canvasInstructions = Color(hex: 0xCBD7DD)
    static let card = Color(hex: 0xF7FAFB)
    static let disabledFill = Color(hex: 0xD6DEE2)
    static let disabledText = Color(hex: 0x93A3AC)
    static let amber = Color(hex: 0xB4762A)
    static let amberText = Color(hex: 0x8A5A1E)
    static let remove = Color(hex: 0x33454F)
    static let chipFill = Color(hex: 0xE3F0F1)
    static let badge = Color(hex: 0xFFEDA8)
    static let indexDim = Color(hex: 0xBFCCD2)

    static let avatarPalette: [Color] = [
        Color(hex: 0xEAE3D8),
        Color(hex: 0xE1E6EF),
        Color(hex: 0xE6EADF),
        Color(hex: 0xDCEAEA),
        Color(hex: 0xEFE2E4)
    ]

    static func avatarColor(for id: String) -> Color {
        let hash = abs(id.hashValue)
        return avatarPalette[hash % avatarPalette.count]
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
