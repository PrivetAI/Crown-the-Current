import SwiftUI

/// Chrome the camera must keep clear of: the HUD band, the End Turn banner and
/// (on a regular-width side rail) the docked action panel. Every value is 0 on
/// iPhone, which makes the viewport below exactly the full screen — i.e. the
/// shipped phone camera math, unchanged.
struct CTCMapInset {
    var top: CGFloat = 0
    var bottom: CGFloat = 0
    var trailing: CGFloat = 0
}

/// Camera transform shared by drawing and hit-testing. All math is anchored to
/// the parent-passed screen size — never the Canvas closure's own size.
struct CTCCamera {
    var scale: CGFloat = 1
    var offset: CGSize = .zero
    /// Reserved chrome. Zero on compact width.
    var inset = CTCMapInset()

    /// The rectangle the river is fitted into and centred on. With zero insets
    /// this is the whole screen.
    func viewport(_ screen: CGSize) -> CGRect {
        let w = max(1, screen.width - inset.trailing)
        let h = max(1, screen.height - inset.top - inset.bottom)
        return CGRect(x: 0, y: inset.top, width: w, height: h)
    }

    func fitScale(screen: CGSize, mapW: CGFloat, mapH: CGFloat) -> CGFloat {
        guard mapW > 0, mapH > 0, screen.width > 0, screen.height > 0 else { return 1 }
        let v = viewport(screen)
        return min(v.width / mapW, v.height / mapH) * 0.94
    }

    func totalScale(screen: CGSize, mapW: CGFloat, mapH: CGFloat) -> CGFloat {
        fitScale(screen: screen, mapW: mapW, mapH: mapH) * scale
    }

    func toScreen(_ world: CGPoint, screen: CGSize, mapW: CGFloat, mapH: CGFloat) -> CGPoint {
        let s = totalScale(screen: screen, mapW: mapW, mapH: mapH)
        let v = viewport(screen)
        return CGPoint(
            x: (world.x - mapW / 2) * s + v.midX + offset.width,
            y: (world.y - mapH / 2) * s + v.midY + offset.height
        )
    }

    func toWorld(_ pt: CGPoint, screen: CGSize, mapW: CGFloat, mapH: CGFloat) -> CGPoint {
        let s = max(0.0001, totalScale(screen: screen, mapW: mapW, mapH: mapH))
        let v = viewport(screen)
        return CGPoint(
            x: (pt.x - v.midX - offset.width) / s + mapW / 2,
            y: (pt.y - v.midY - offset.height) / s + mapH / 2
        )
    }
}

struct MapCanvasView: View {
    let state: GameState
    let screenSize: CGSize
    let camera: CTCCamera
    let selectedNodeID: Int?
    let reachable: [Int: CTCRoute]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, _ in
                let t = timeline.date.timeIntervalSinceReferenceDate
                draw(context: context, time: t)
            }
        }
    }

    private func pt(_ n: CTCNode) -> CGPoint {
        camera.toScreen(CGPoint(x: n.x, y: n.y), screen: screenSize,
                        mapW: CGFloat(state.mapW), mapH: CGFloat(state.mapH))
    }

    private var s: CGFloat {
        camera.totalScale(screen: screenSize, mapW: CGFloat(state.mapW), mapH: CGFloat(state.mapH))
    }

    private func hash01(_ v: Int) -> CGFloat {
        var x = UInt64(bitPattern: Int64(v)) &* 0x9E3779B97F4A7C15
        x = (x ^ (x >> 31)) &* 0xBF58476D1CE4E5B9
        return CGFloat(x % 1000) / 1000.0
    }

    // MARK: - Drawing

    private func draw(context: GraphicsContext, time: TimeInterval) {
        let sc = s
        var ctx = context

        drawBanks(&ctx, sc: sc)
        drawEdges(&ctx, sc: sc, time: time)
        drawNodes(&ctx, sc: sc, time: time)
        drawFleets(&ctx, sc: sc)
        drawHighlights(&ctx, sc: sc, time: time)
    }

    /// Soft painterly bank vegetation: green and wheat blobs seeded by node id.
    private func drawBanks(_ ctx: inout GraphicsContext, sc: CGFloat) {
        for n in state.nodes {
            let p = pt(n)
            let h1 = hash01(n.id * 7 + 1)
            let h2 = hash01(n.id * 13 + 5)
            let h3 = hash01(n.id * 29 + 11)
            let side: CGFloat = h1 > 0.5 ? 1 : -1
            let grove = CGRect(
                x: p.x + side * (58 + h2 * 46) * sc - 34 * sc,
                y: p.y - (30 + h3 * 40) * sc,
                width: (66 + h2 * 40) * sc,
                height: (40 + h1 * 26) * sc)
            ctx.fill(Path(ellipseIn: grove),
                     with: .color(CTCTheme.bankGreen.opacity(0.16 + 0.08 * Double(h3))))
            let field = CGRect(
                x: p.x - side * (66 + h3 * 50) * sc - 30 * sc,
                y: p.y + (18 + h2 * 44) * sc,
                width: (58 + h1 * 36) * sc,
                height: (30 + h2 * 22) * sc)
            ctx.fill(Path(roundedRect: field, cornerRadius: 14 * sc),
                     with: .color(CTCTheme.wheat.opacity(0.16 + 0.08 * Double(h1))))
            if h2 > 0.55 {
                let copse = CGRect(x: p.x + side * 34 * sc, y: p.y + (52 + h1 * 30) * sc,
                                   width: 26 * sc, height: 26 * sc)
                ctx.fill(Path(ellipseIn: copse),
                         with: .color(CTCTheme.bankGreenDeep.opacity(0.2)))
            }
        }
    }

    private func edgeVisible(_ e: CTCEdge) -> Bool {
        state.isDiscovered(e.from) || state.isDiscovered(e.to)
    }

    private func edgePath(_ e: CTCEdge) -> Path? {
        guard let a = state.node(e.from), let b = state.node(e.to) else { return nil }
        let pa = pt(a)
        let pb = pt(b)
        let mid = CGPoint(x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2)
        let dx = pb.x - pa.x
        let dy = pb.y - pa.y
        let len = max(1, hypot(dx, dy))
        let bend = (hash01(e.id * 17 + 3) - 0.5) * 0.5 * len
        let ctrl = CGPoint(x: mid.x - dy / len * bend, y: mid.y + dx / len * bend)
        var p = Path()
        p.move(to: pa)
        p.addQuadCurve(to: pb, control: ctrl)
        return p
    }

    private func drawEdges(_ ctx: inout GraphicsContext, sc: CGFloat, time: TimeInterval) {
        for e in state.edges {
            guard let path = edgePath(e) else { continue }
            let discovered = edgeVisible(e)
            if !discovered {
                ctx.stroke(path, with: .color(CTCTheme.fog.opacity(0.30)),
                           style: StrokeStyle(lineWidth: 20 * sc, lineCap: .round))
                continue
            }
            // Banded water: deep base, mid band, light animated flow dashes.
            ctx.stroke(path, with: .color(CTCTheme.riverDeep),
                       style: StrokeStyle(lineWidth: 24 * sc, lineCap: .round))
            ctx.stroke(path, with: .color(CTCTheme.riverMid),
                       style: StrokeStyle(lineWidth: 15 * sc, lineCap: .round))
            let phase = -CGFloat(time.truncatingRemainder(dividingBy: 60)) * 26 * sc
            ctx.stroke(path, with: .color(CTCTheme.riverLight.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 3.2 * sc, lineCap: .round,
                                          dash: [9 * sc, 13 * sc], dashPhase: phase))

            if let a = state.node(e.from), let b = state.node(e.to) {
                let pa = pt(a)
                let pb = pt(b)
                let mid = CGPoint(x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2)
                if e.toll {
                    var diamond = Path()
                    let r = 9 * sc
                    diamond.move(to: CGPoint(x: mid.x, y: mid.y - r))
                    diamond.addLine(to: CGPoint(x: mid.x + r, y: mid.y))
                    diamond.addLine(to: CGPoint(x: mid.x, y: mid.y + r))
                    diamond.addLine(to: CGPoint(x: mid.x - r, y: mid.y))
                    diamond.closeSubpath()
                    ctx.fill(diamond, with: .color(CTCTheme.goldLine))
                    ctx.stroke(diamond, with: .color(CTCTheme.ink.opacity(0.5)),
                               style: StrokeStyle(lineWidth: 1.2 * sc))
                }
                if e.damOwner != -1 {
                    let dx = pb.x - pa.x
                    let dy = pb.y - pa.y
                    let len = max(1, hypot(dx, dy))
                    let px = -dy / len
                    let py = dx / len
                    var bar = Path()
                    let half = 20 * sc
                    bar.move(to: CGPoint(x: mid.x + px * half, y: mid.y + py * half))
                    bar.addLine(to: CGPoint(x: mid.x - px * half, y: mid.y - py * half))
                    ctx.stroke(bar, with: .color(Color(red: 0.45, green: 0.33, blue: 0.2)),
                               style: StrokeStyle(lineWidth: 10 * sc, lineCap: .round))
                    ctx.stroke(bar, with: .color(CTCTheme.ownerColor(e.damOwner, players: state.players)),
                               style: StrokeStyle(lineWidth: 3.4 * sc, lineCap: .round))
                }
            }
        }
    }

    private func drawNodes(_ ctx: inout GraphicsContext, sc: CGFloat, time: TimeInterval) {
        for n in state.nodes {
            let p = pt(n)
            let discovered = state.isDiscovered(n.id)
            let r = (n.kind == .mouth ? 30.0 : 24.0) * sc

            if !discovered {
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(CTCTheme.fog.opacity(0.55)))
                ctx.stroke(Path(ellipseIn: rect), with: .color(CTCTheme.fog.opacity(0.8)),
                           style: StrokeStyle(lineWidth: 2 * sc, dash: [4 * sc, 4 * sc]))
                continue
            }

            let ring = CTCTheme.ownerColor(n.owner, players: state.players)
            let tokenRect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: tokenRect.insetBy(dx: -3.5 * sc, dy: -3.5 * sc)),
                     with: .color(CTCTheme.ink.opacity(0.18)))
            ctx.fill(Path(ellipseIn: tokenRect), with: .color(CTCTheme.card))
            ctx.stroke(Path(ellipseIn: tokenRect), with: .color(ring),
                       style: StrokeStyle(lineWidth: (n.owner == -1 ? 2.4 : 4.2) * sc))

            drawKindGlyph(&ctx, node: n, at: p, r: r, sc: sc)
            drawBuildingPips(&ctx, node: n, at: p, r: r, sc: sc)

            // Node names once zoomed in enough to read them.
            if s > 0.42 {
                let label = Text(n.name)
                    .font(.custom("Georgia", size: max(8, 11.5 * sc)))
                    .foregroundColor(CTCTheme.ink.opacity(0.82))
                ctx.draw(label, at: CGPoint(x: p.x, y: p.y + r + 11 * sc), anchor: .center)
            }

            // Mouth hold progress.
            if n.kind == .mouth, n.owner >= 0, n.owner < state.players.count {
                let held = state.players[n.owner].mouthTurns
                if held > 0 {
                    let txt = Text("\(held)/\(CTCEngine.mouthHoldNeeded)")
                        .font(.custom("Menlo-Bold", size: max(8, 11 * sc)))
                        .foregroundColor(.white)
                    let chipRect = CGRect(x: p.x - 17 * sc, y: p.y - r - 22 * sc,
                                          width: 34 * sc, height: 16 * sc)
                    ctx.fill(Path(roundedRect: chipRect, cornerRadius: 8 * sc), with: .color(ring))
                    ctx.draw(txt, at: CGPoint(x: chipRect.midX, y: chipRect.midY), anchor: .center)
                }
            }
        }
    }

    private func drawKindGlyph(_ ctx: inout GraphicsContext, node n: CTCNode, at p: CGPoint, r: CGFloat, sc: CGFloat) {
        let glyphColor = CTCTheme.riverDeep.opacity(0.85)
        switch n.kind {
        case .harbor:
            var quay = Path()
            for i in 0..<3 {
                let y = p.y - 6 * sc + CGFloat(i) * 6 * sc
                quay.move(to: CGPoint(x: p.x - 9 * sc, y: y))
                quay.addLine(to: CGPoint(x: p.x + 9 * sc, y: y))
            }
            ctx.stroke(quay, with: .color(glyphColor), style: StrokeStyle(lineWidth: 2.4 * sc, lineCap: .round))
        case .island:
            var humps = Path()
            humps.addArc(center: CGPoint(x: p.x - 5 * sc, y: p.y + 4 * sc), radius: 6 * sc,
                         startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            humps.addArc(center: CGPoint(x: p.x + 6 * sc, y: p.y + 4 * sc), radius: 4.5 * sc,
                         startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            ctx.stroke(humps, with: .color(glyphColor), style: StrokeStyle(lineWidth: 2.4 * sc, lineCap: .round))
        case .confluence:
            var fork = Path()
            fork.move(to: CGPoint(x: p.x - 7 * sc, y: p.y - 7 * sc))
            fork.addLine(to: CGPoint(x: p.x, y: p.y + 1 * sc))
            fork.move(to: CGPoint(x: p.x + 7 * sc, y: p.y - 7 * sc))
            fork.addLine(to: CGPoint(x: p.x, y: p.y + 1 * sc))
            fork.move(to: CGPoint(x: p.x, y: p.y + 1 * sc))
            fork.addLine(to: CGPoint(x: p.x, y: p.y + 9 * sc))
            ctx.stroke(fork, with: .color(glyphColor), style: StrokeStyle(lineWidth: 2.6 * sc, lineCap: .round))
        case .mouth:
            let inner = CGRect(x: p.x - 10 * sc, y: p.y - 10 * sc, width: 20 * sc, height: 20 * sc)
            ctx.stroke(Path(ellipseIn: inner), with: .color(CTCTheme.goldLine),
                       style: StrokeStyle(lineWidth: 2.6 * sc))
            var waves = Path()
            waves.move(to: CGPoint(x: p.x - 6 * sc, y: p.y + 2 * sc))
            waves.addQuadCurve(to: CGPoint(x: p.x, y: p.y + 2 * sc),
                               control: CGPoint(x: p.x - 3 * sc, y: p.y - 2 * sc))
            waves.addQuadCurve(to: CGPoint(x: p.x + 6 * sc, y: p.y + 2 * sc),
                               control: CGPoint(x: p.x + 3 * sc, y: p.y + 6 * sc))
            ctx.stroke(waves, with: .color(glyphColor), style: StrokeStyle(lineWidth: 2.2 * sc, lineCap: .round))
        }
    }

    private func drawBuildingPips(_ ctx: inout GraphicsContext, node n: CTCNode, at p: CGPoint, r: CGFloat, sc: CGFloat) {
        // Dock pips: gold squares in a row under the token.
        if n.dock > 0 {
            let pip = 7 * sc
            let total = CGFloat(n.dock) * pip + CGFloat(n.dock - 1) * 3 * sc
            var x = p.x - total / 2
            for _ in 0..<n.dock {
                let rect = CGRect(x: x, y: p.y + r + 20 * sc, width: pip, height: pip)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 1.6 * sc), with: .color(CTCTheme.goldLine))
                ctx.stroke(Path(roundedRect: rect, cornerRadius: 1.6 * sc),
                           with: .color(CTCTheme.ink.opacity(0.4)), style: StrokeStyle(lineWidth: 1 * sc))
                x += pip + 3 * sc
            }
        }
        // Shipyard: sail pip top-right of the token.
        if n.yard {
            let rect = CGRect(x: p.x + r * 0.62, y: p.y - r - 10 * sc, width: 15 * sc, height: 15 * sc)
            var sail = Path()
            sail.move(to: CGPoint(x: rect.midX, y: rect.minY))
            sail.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            sail.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            sail.closeSubpath()
            ctx.fill(sail, with: .color(CTCTheme.navy))
            ctx.stroke(sail, with: .color(.white), style: StrokeStyle(lineWidth: 1.2 * sc))
        }
        // Watchtower: small tower pip top-left.
        if n.tower {
            let rect = CGRect(x: p.x - r * 0.62 - 14 * sc, y: p.y - r - 10 * sc, width: 13 * sc, height: 15 * sc)
            let tower = CTCTowerIcon().path(in: rect)
            ctx.fill(tower, with: .color(Color(red: 0.52, green: 0.4, blue: 0.26)))
        }
    }

    private func drawFleets(_ ctx: inout GraphicsContext, sc: CGFloat) {
        for n in state.nodes {
            guard state.isDiscovered(n.id) else { continue }
            let flts = state.fleetsAt(n.id)
            guard !flts.isEmpty else { continue }
            let p = pt(n)
            let r = (n.kind == .mouth ? 30.0 : 24.0) * sc
            for (i, f) in flts.enumerated() {
                let angle = -0.7 + Double(i) * 0.9
                let dist = r + 21 * sc
                let fp = CGPoint(x: p.x + CGFloat(cos(angle)) * dist,
                                 y: p.y + CGFloat(sin(angle)) * dist - 4 * sc)
                let color = CTCTheme.ownerColor(f.owner, players: state.players)
                let box = CGRect(x: fp.x - 11 * sc, y: fp.y - 12 * sc, width: 22 * sc, height: 22 * sc)
                ctx.fill(Path(ellipseIn: box.insetBy(dx: -3 * sc, dy: -3 * sc)),
                         with: .color(Color.white.opacity(0.75)))
                let sail = CTCSailIcon().path(in: box)
                ctx.fill(sail, with: .color(color))
                // Strength chip.
                let chip = CGRect(x: fp.x + 6 * sc, y: fp.y + 3 * sc, width: 17 * sc, height: 13 * sc)
                ctx.fill(Path(roundedRect: chip, cornerRadius: 4 * sc), with: .color(CTCTheme.ink))
                let txt = Text("\(f.strength)")
                    .font(.custom("Menlo-Bold", size: max(7, 9.5 * sc)))
                    .foregroundColor(.white)
                ctx.draw(txt, at: CGPoint(x: chip.midX, y: chip.midY), anchor: .center)
                // MP dots for the player's own fleets.
                if f.owner == 0 && f.mp > 0 {
                    for m in 0..<min(f.mp, 3) {
                        let dot = CGRect(x: fp.x - 10 * sc + CGFloat(m) * 7 * sc,
                                         y: fp.y + 12 * sc, width: 4.6 * sc, height: 4.6 * sc)
                        ctx.fill(Path(ellipseIn: dot), with: .color(CTCTheme.good))
                    }
                }
            }
        }
    }

    private func drawHighlights(_ ctx: inout GraphicsContext, sc: CGFloat, time: TimeInterval) {
        // Reachable destinations with MP cost chips.
        for (nodeID, route) in reachable {
            guard let n = state.node(nodeID) else { continue }
            let p = pt(n)
            let r = (n.kind == .mouth ? 30.0 : 24.0) * sc + 7 * sc
            let ring = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            let hostile = state.fleetsAt(nodeID).contains { $0.owner != 0 }
            let color = hostile ? CTCTheme.danger : CTCTheme.good
            ctx.fill(Path(ellipseIn: ring), with: .color(color.opacity(0.16)))
            ctx.stroke(Path(ellipseIn: ring), with: .color(color.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 2.6 * sc, dash: [6 * sc, 5 * sc]))
            let chip = CGRect(x: p.x - 10 * sc, y: ring.minY - 15 * sc, width: 20 * sc, height: 14 * sc)
            ctx.fill(Path(roundedRect: chip, cornerRadius: 5 * sc), with: .color(color))
            let txt = Text("\(route.cost)")
                .font(.custom("Menlo-Bold", size: max(7, 10 * sc)))
                .foregroundColor(.white)
            ctx.draw(txt, at: CGPoint(x: chip.midX, y: chip.midY), anchor: .center)
        }
        // Pulsing selection ring.
        if let sel = selectedNodeID, let n = state.node(sel) {
            let p = pt(n)
            let pulse = CGFloat(1 + 0.06 * sin(time * 5))
            let r = ((n.kind == .mouth ? 30.0 : 24.0) * sc + 10 * sc) * pulse
            let ring = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            ctx.stroke(Path(ellipseIn: ring), with: .color(CTCTheme.goldLine),
                       style: StrokeStyle(lineWidth: 3.4 * sc))
        }
    }
}
