import SwiftUI

/// Painterly riverlands palette — forced light, theme-independent.
enum CTCTheme {
    static let parchment = Color(red: 0.961, green: 0.937, blue: 0.886)   // #F5EFE2
    static let card = Color(red: 1.0, green: 0.976, blue: 0.925)
    static let cardBorder = Color(red: 0.788, green: 0.725, blue: 0.561)
    static let ink = Color(red: 0.169, green: 0.137, blue: 0.094)
    static let inkSoft = Color(red: 0.169, green: 0.137, blue: 0.094).opacity(0.62)
    static let riverLight = Color(red: 0.392, green: 0.565, blue: 0.702)  // #6490B3-ish
    static let riverMid = Color(red: 0.290, green: 0.498, blue: 0.647)    // #4A7FA5
    static let riverDeep = Color(red: 0.180, green: 0.369, blue: 0.502)   // #2E5E80
    static let bankGreen = Color(red: 0.478, green: 0.608, blue: 0.427)
    static let bankGreenDeep = Color(red: 0.365, green: 0.494, blue: 0.333)
    static let wheat = Color(red: 0.851, green: 0.769, blue: 0.541)
    static let navy = Color(red: 0.180, green: 0.298, blue: 0.431)
    static let goldLine = Color(red: 0.855, green: 0.702, blue: 0.325)
    static let danger = Color(red: 0.663, green: 0.231, blue: 0.196)
    static let good = Color(red: 0.243, green: 0.478, blue: 0.290)
    static let fog = Color(red: 0.42, green: 0.42, blue: 0.46)

    /// The six baron banner colors.
    static let banners: [Color] = [
        Color(red: 0.663, green: 0.231, blue: 0.196),   // 0 crimson
        Color(red: 0.180, green: 0.298, blue: 0.431),   // 1 navy
        Color(red: 0.243, green: 0.420, blue: 0.290),   // 2 forest
        Color(red: 0.753, green: 0.541, blue: 0.180),   // 3 ochre
        Color(red: 0.180, green: 0.478, blue: 0.447),   // 4 teal
        Color(red: 0.725, green: 0.584, blue: 0.196)    // 5 gold
    ]
    static let bannerNames = ["Crimson", "Navy", "Forest", "Ochre", "Teal", "Gold"]

    static func bannerColor(_ id: Int) -> Color {
        guard id >= 0 && id < banners.count else { return .gray }
        return banners[id]
    }

    static func ownerColor(_ owner: Int, players: [CTCPlayer]) -> Color {
        if owner == -1 { return Color(red: 0.25, green: 0.22, blue: 0.20) }       // pirates
        if owner == CTCEngine.garrisonOwner { return Color(red: 0.45, green: 0.44, blue: 0.42) }
        guard owner >= 0 && owner < players.count else { return Color(red: 0.62, green: 0.58, blue: 0.50) }
        return bannerColor(players[owner].colorID)
    }

    static func display(_ size: CGFloat) -> Font { .custom("Georgia-Bold", size: size) }
    static func body(_ size: CGFloat) -> Font { .custom("Georgia", size: size) }
    static func num(_ size: CGFloat) -> Font { .custom("Menlo-Bold", size: size) }
    static func numLight(_ size: CGFloat) -> Font { .custom("Menlo", size: size) }
}

// MARK: - Reusable chrome

/// Banner-ribbon section header.
struct CTCRibbonHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                CTCRibbonShape()
                    .fill(CTCTheme.navy)
                CTCRibbonShape()
                    .strokeBorder(CTCTheme.goldLine.opacity(0.85), lineWidth: 1.5)
                Text(title)
                    .font(CTCTheme.display(19))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 40)
            }
            .frame(height: 46)
            if let sub = subtitle {
                Text(sub)
                    .font(CTCTheme.body(13))
                    .foregroundColor(CTCTheme.inkSoft)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct CTCRibbonShape: InsettableShape {
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> CTCRibbonShape {
        var copy = self
        copy.inset += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let notch: CGFloat = min(18, r.width * 0.06)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - notch, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + notch, y: r.midY))
        p.closeSubpath()
        return p
    }
}

struct CTCCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(CTCTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(CTCTheme.cardBorder, lineWidth: 1.2)
                    )
            )
    }
}

/// A painterly hero-art banner: a catalog image under a bottom legibility
/// gradient, with an optional overlaid title/subtitle. Sized to a fixed height
/// and clipped, so it stays safe on a 375×667 screen.
struct CTCArtBanner: View {
    let imageName: String
    var title: String? = nil
    var subtitle: String? = nil
    var height: CGFloat = 132

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.58)
                ]),
                startPoint: .top, endPoint: .bottom)
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let t = title {
                        Text(t)
                            .font(CTCTheme.display(20))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.75), radius: 3, y: 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    if let s = subtitle {
                        Text(s)
                            .font(CTCTheme.body(12))
                            .foregroundColor(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.75), radius: 2, y: 1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(CTCTheme.cardBorder, lineWidth: 1.2))
    }
}

struct CTCButtonStyle: ButtonStyle {
    var fill: Color = CTCTheme.navy
    var textColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CTCTheme.display(15))
            .foregroundColor(textColor)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(fill.opacity(configuration.isPressed ? 0.72 : 1.0))
            )
    }
}

// MARK: - Custom icon shapes (no SF Symbols, no emoji)

/// A single meandering line — the app's crest motif.
struct CTCMeanderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: rect.minX + w * 0.15, y: rect.minY + h * 0.05))
        p.addCurve(to: CGPoint(x: rect.minX + w * 0.75, y: rect.minY + h * 0.38),
                   control1: CGPoint(x: rect.minX + w * 0.75, y: rect.minY + h * 0.02),
                   control2: CGPoint(x: rect.minX + w * 0.95, y: rect.minY + h * 0.28))
        p.addCurve(to: CGPoint(x: rect.minX + w * 0.30, y: rect.minY + h * 0.66),
                   control1: CGPoint(x: rect.minX + w * 0.45, y: rect.minY + h * 0.52),
                   control2: CGPoint(x: rect.minX + w * 0.12, y: rect.minY + h * 0.52))
        p.addCurve(to: CGPoint(x: rect.minX + w * 0.85, y: rect.minY + h * 0.97),
                   control1: CGPoint(x: rect.minX + w * 0.55, y: rect.minY + h * 0.84),
                   control2: CGPoint(x: rect.minX + w * 0.70, y: rect.minY + h * 0.98))
        return p
    }
}

/// Pennant flag on a pole (Campaign tab).
struct CTCPennantIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let poleX = rect.minX + rect.width * 0.18
        p.addRect(CGRect(x: poleX - rect.width * 0.035, y: rect.minY,
                         width: rect.width * 0.07, height: rect.height))
        p.move(to: CGPoint(x: poleX + rect.width * 0.06, y: rect.minY + rect.height * 0.06))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.22))
        p.addLine(to: CGPoint(x: poleX + rect.width * 0.06, y: rect.minY + rect.height * 0.44))
        p.closeSubpath()
        return p
    }
}

/// Two crossed oars (Skirmish tab).
struct CTCOarsIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        func oar(_ a: CGPoint, _ b: CGPoint, blade: Bool) {
            let dx = b.x - a.x
            let dy = b.y - a.y
            let len = max(1, (dx * dx + dy * dy).squareRoot())
            let ux = dx / len
            let uy = dy / len
            let px = -uy
            let py = ux
            let wHalf = rect.width * 0.035
            p.move(to: CGPoint(x: a.x + px * wHalf, y: a.y + py * wHalf))
            p.addLine(to: CGPoint(x: b.x + px * wHalf, y: b.y + py * wHalf))
            p.addLine(to: CGPoint(x: b.x - px * wHalf, y: b.y - py * wHalf))
            p.addLine(to: CGPoint(x: a.x - px * wHalf, y: a.y - py * wHalf))
            p.closeSubpath()
            if blade {
                let bw = rect.width * 0.13
                p.addEllipse(in: CGRect(x: b.x - bw, y: b.y - bw * 1.5, width: bw * 2, height: bw * 2))
            }
        }
        oar(CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.height * 0.05),
            CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.minY + rect.height * 0.16), blade: true)
        oar(CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY - rect.height * 0.05),
            CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.16), blade: true)
        return p
    }
}

/// Five-pointed star (Chronicle tab / campaign stars).
struct CTCStarIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rOuter = min(rect.width, rect.height) / 2
        let rInner = rOuter * 0.42
        var p = Path()
        for i in 0..<10 {
            let angle = (Double(i) * .pi / 5) - .pi / 2
            let r = i % 2 == 0 ? rOuter : rInner
            let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * r, y: c.y + CGFloat(sin(angle)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Open ledger book (More tab).
struct CTCBookIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midX = rect.midX
        p.move(to: CGPoint(x: midX, y: rect.minY + rect.height * 0.12))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.10),
                   control1: CGPoint(x: midX - rect.width * 0.22, y: rect.minY),
                   control2: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.12))
        p.addCurve(to: CGPoint(x: midX, y: rect.maxY),
                   control1: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.height * 0.10),
                   control2: CGPoint(x: midX - rect.width * 0.2, y: rect.maxY - rect.height * 0.06))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.12),
                   control1: CGPoint(x: midX + rect.width * 0.2, y: rect.maxY - rect.height * 0.06),
                   control2: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY - rect.height * 0.10))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.10))
        p.addCurve(to: CGPoint(x: midX, y: rect.minY + rect.height * 0.12),
                   control1: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY),
                   control2: CGPoint(x: midX + rect.width * 0.22, y: rect.minY))
        p.closeSubpath()
        p.move(to: CGPoint(x: midX, y: rect.minY + rect.height * 0.12))
        p.addLine(to: CGPoint(x: midX, y: rect.maxY))
        return p
    }
}

/// Small sail (fleet marker & shipyard pip).
struct CTCSailIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let hullTop = rect.maxY - rect.height * 0.22
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: hullTop))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: hullTop),
                       control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.1))
        p.closeSubpath()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: hullTop - rect.height * 0.04))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.16, y: hullTop - rect.height * 0.04))
        p.closeSubpath()
        p.move(to: CGPoint(x: rect.midX + rect.width * 0.06, y: rect.minY + rect.height * 0.08))
        p.addQuadCurve(to: CGPoint(x: rect.midX + rect.width * 0.06, y: hullTop - rect.height * 0.06),
                       control: CGPoint(x: rect.maxX + rect.width * 0.05, y: rect.minY + rect.height * 0.42))
        p.closeSubpath()
        return p
    }
}

/// Coin with inner ring (florins).
struct CTCCoinIcon: View {
    var size: CGFloat = 16
    var body: some View {
        ZStack {
            Circle().fill(CTCTheme.goldLine)
            Circle().strokeBorder(CTCTheme.ink.opacity(0.35), lineWidth: max(1, size * 0.07))
                .padding(size * 0.18)
        }
        .frame(width: size, height: size)
    }
}

/// Watchtower pip.
struct CTCTowerIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.minY + rect.height * 0.25))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.25))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.25))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.32, y: rect.minY + rect.height * 0.25))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Dam bar (two stacked blocks).
struct CTCDamIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let rows = 3
        for r in 0..<rows {
            let y = rect.minY + rect.height * CGFloat(r) / CGFloat(rows)
            let offset = r % 2 == 0 ? 0.0 : rect.width * 0.16
            var x = rect.minX - rect.width * 0.16 + offset
            while x < rect.maxX {
                p.addRect(CGRect(x: max(rect.minX, x), y: y + 1,
                                 width: min(rect.width * 0.3, rect.maxX - max(rect.minX, x)),
                                 height: rect.height / CGFloat(rows) - 2))
                x += rect.width * 0.32
            }
        }
        return p
    }
}

/// Simple left-pointing chevron (back / navigation).
struct CTCChevron: Shape {
    var pointRight: Bool = false
    func path(in rect: CGRect) -> Path {
        var p = Path()
        if pointRight {
            p.move(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.maxX - rect.width * 0.3, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.3, y: rect.maxY))
        }
        return p
    }
}

/// Cross / close glyph.
struct CTCCross: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return p
    }
}

/// Laurel-ish wreath arc pair for achievements.
struct CTCLaurelIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: rect.width * 0.42,
                 startAngle: .degrees(110), endAngle: .degrees(250), clockwise: false)
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: rect.width * 0.42,
                 startAngle: .degrees(-70), endAngle: .degrees(70), clockwise: false)
        for side in [-1.0, 1.0] {
            for i in 0..<3 {
                let angle = Double(120 + i * 55)
                let rad = angle * .pi / 180
                let cx = rect.midX + CGFloat(cos(rad)) * rect.width * 0.42 * CGFloat(side)
                let cy = rect.midY + CGFloat(sin(rad)) * rect.width * 0.42
                p.addEllipse(in: CGRect(x: cx - rect.width * 0.06, y: cy - rect.width * 0.1,
                                        width: rect.width * 0.12, height: rect.width * 0.2))
            }
        }
        return p
    }
}

// MARK: - Adaptive layout (iPhone / iPad)

/// Size-class driven layout metrics.
///
/// Every value is deliberately inert on `.compact`: `.infinity` measures and a
/// single column mean the modifiers below apply *nothing at all* on iPhone, so
/// the shipped phone layout is byte-identical. Only `.regular` (iPad) picks up
/// the wider treatment.
struct CTCLayout {
    let regular: Bool

    init(_ sizeClass: UserInterfaceSizeClass?) {
        regular = (sizeClass == .regular)
    }

    /// Measure for prose and forms — long lines are unreadable across 1000pt.
    var readingWidth: CGFloat { regular ? 720 : .infinity }
    /// Measure for card grids, which can afford to be wider than prose.
    var gridWidth: CGFloat { regular ? 920 : .infinity }
    /// The custom tab bar; a 1366pt-wide row of four tabs looks unmoored.
    var tabBarWidth: CGFloat { regular ? 640 : .infinity }
    /// The match action panel and End Turn banner.
    var panelWidth: CGFloat { regular ? 640 : .infinity }

    /// Columns for the scenario / banner / stat grids.
    var listColumns: Int { regular ? 2 : 1 }
    var tileColumns: Int { regular ? 4 : 2 }

    /// `spacing: nil` keeps SwiftUI's own default gap, so a grid that changes
    /// only its column *count* is otherwise untouched on iPhone.
    func columns(_ count: Int, spacing: CGFloat? = nil) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
    }
}

extension View {
    /// Centres the view inside a capped column. A `.infinity` cap (compact)
    /// applies no modifier whatsoever.
    @ViewBuilder func ctcColumn(_ maxWidth: CGFloat) -> some View {
        if maxWidth == .infinity {
            self
        } else {
            self.frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
        }
    }
}
