import SwiftUI

extension Color {
    static let fridjBg     = Color(hex: "FEFAEB")
    static let fridjPeach  = Color(hex: "FBE5C7")
    static let fridjOrange = Color(hex: "EE7D4D")
    static let fridjCoral  = Color(hex: "EC5D62")
    static let fridjGreen  = Color(hex: "6F876A")
    static let fridjMint   = Color(hex: "D1D3B5")
    static let fridjText   = Color(hex: "2D2D2D")
    static let fridjDark   = Color(hex: "171717")
    static let fridjBlack  = Color(hex: "262626")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            .sRGB,
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double(int         & 0xFF) / 255
        )
    }
}

enum FridjFont {
    static func size(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func style(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

enum FridjRadius {
    static let recipeCard: CGFloat     = 26
    static let scanButton: CGFloat     = 35
    static let ingredientCard: CGFloat = 39
    static let sm: CGFloat             = 12
    static let md: CGFloat             = 16
}

enum FridjSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}
