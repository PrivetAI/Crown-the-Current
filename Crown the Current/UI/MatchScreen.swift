import SwiftUI

/// The live match: a pan/zoom river map, top HUD with income ticker, a
/// node action panel, the End Turn banner, and all match overlays.
struct MatchScreen: View {
    @ObservedObject var controller: MatchController
    @ObservedObject var store = CTCStore.shared
    @Environment(\.horizontalSizeClass) private var hSize
    let onExit: () -> Void

    @State private var camera = CTCCamera()
    @State private var pinch: CGFloat = 1
    @State private var dragT: CGSize = .zero
    @State private var pinchEndedAt = Date.distantPast
    @State private var showMenu = false
    @State private var damPickerNode: Int? = nil
    @State private var showOnboard = false

    private var state: GameState { controller.state }

    private var layout: CTCLayout { CTCLayout(hSize) }

    /// Width of the docked action rail on a regular-width landscape screen.
    private let railWidth: CGFloat = 360

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CTCTheme.parchment.ignoresSafeArea()

                mapLayer(geo.size)

                if useSideRail(geo.size) {
                    VStack(spacing: 0) {
                        hud
                        HStack(alignment: .top, spacing: 0) {
                            Spacer(minLength: 0)
                            sideRail(geo.size)
                                .frame(width: railWidth)
                                .padding(.trailing, 12)
                                .padding(.vertical, 12)
                        }
                        .frame(maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        hud
                        Spacer(minLength: 0)
                        bottomArea(geo.size.height)
                    }
                }

                overlays
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            if controller.mode == "campaign" && controller.scenarioID == 1 && !store.root.onboardingDone {
                showOnboard = true
            }
        }
    }

    // MARK: - Map + gestures

    /// On a regular-width landscape screen the action panel docks into a side
    /// rail; in portrait it stays at the bottom, capped and centred.
    private func useSideRail(_ size: CGSize) -> Bool {
        layout.regular && size.width > size.height
    }

    /// Chrome the river must stay clear of. All zero on compact width, so the
    /// iPhone camera fit is exactly what shipped: the map is framed against the
    /// full screen. On iPad the fit is taken against the *usable* rectangle
    /// instead, so the whole river frames sensibly beside the HUD and the panel
    /// rather than running underneath them.
    private func mapInset(_ size: CGSize) -> CTCMapInset {
        guard layout.regular else { return CTCMapInset() }
        if useSideRail(size) {
            return CTCMapInset(top: 104, bottom: 32, trailing: railWidth + 24)
        }
        return CTCMapInset(top: 104, bottom: 288)
    }

    private func effectiveCamera(_ size: CGSize) -> CTCCamera {
        var c = camera
        c.scale = min(3.5, max(0.55, camera.scale * pinch))
        c.offset = CGSize(width: camera.offset.width + dragT.width,
                          height: camera.offset.height + dragT.height)
        c.inset = mapInset(size)
        return c
    }

    private func mapLayer(_ size: CGSize) -> some View {
        MapCanvasView(state: state, screenSize: size, camera: effectiveCamera(size),
                      selectedNodeID: controller.selectedNodeID, reachable: controller.reachable)
            .contentShape(Rectangle())
            .gesture(mapGesture(size))
            .ignoresSafeArea()
    }

    private func mapGesture(_ size: CGSize) -> some Gesture {
        let drag = DragGesture(minimumDistance: 0)
            .onChanged { v in
                if abs(v.translation.width) + abs(v.translation.height) > 6 { dragT = v.translation }
            }
            .onEnded { v in
                let dist = hypot(v.translation.width, v.translation.height)
                if Date().timeIntervalSince(pinchEndedAt) < 0.3 { dragT = .zero; return }
                if dist < 10 {
                    handleTap(v.location, size)
                } else {
                    camera.offset.width += v.translation.width
                    camera.offset.height += v.translation.height
                }
                dragT = .zero
            }
        let mag = MagnificationGesture()
            .onChanged { pinch = $0 }
            .onEnded { val in
                camera.scale = min(3.5, max(0.55, camera.scale * val))
                pinch = 1
                pinchEndedAt = Date()
            }
        return drag.simultaneously(with: mag)
    }

    private func handleTap(_ p: CGPoint, _ size: CGSize) {
        let cam = effectiveCamera(size)
        let mapW = CGFloat(state.mapW), mapH = CGFloat(state.mapH)
        var best: Int? = nil
        var bestD = CGFloat.greatestFiniteMagnitude
        for n in state.nodes where state.isDiscovered(n.id) {
            let sp = cam.toScreen(CGPoint(x: n.x, y: n.y), screen: size, mapW: mapW, mapH: mapH)
            let d = hypot(sp.x - p.x, sp.y - p.y)
            if d < bestD { bestD = d; best = n.id }
        }
        let scale = cam.totalScale(screen: size, mapW: mapW, mapH: mapH)
        damPickerNode = nil
        if let id = best, bestD < max(30, 36 * scale) {
            controller.tapNode(id)
        } else {
            controller.deselect()
        }
    }

    private func recenter() {
        store.tap()
        withAnimation(.easeInOut(duration: 0.25)) {
            camera = CTCCamera()
        }
    }

    // MARK: - HUD

    private var hud: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Button { store.tap(); showMenu = true } label: {
                    CTCPennantIcon().fill(CTCTheme.navy)
                        .frame(width: 20, height: 22)
                        .padding(9)
                        .background(Circle().fill(CTCTheme.card).overlay(Circle().strokeBorder(CTCTheme.cardBorder, lineWidth: 1)))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Turn \(state.turn) / \(state.turnCap)")
                        .font(CTCTheme.num(12)).foregroundColor(CTCTheme.ink)
                    HStack(spacing: 5) {
                        Circle().fill(statusColor).frame(width: 9, height: 9)
                        Text(statusText).font(CTCTheme.body(13)).foregroundColor(CTCTheme.inkSoft)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        CTCCoinIcon(size: 15)
                        Text("\(humanFlorins)").font(CTCTheme.num(16)).foregroundColor(CTCTheme.ink)
                    }
                    Text("+\(controller.humanIncome)/turn")
                        .font(CTCTheme.numLight(11)).foregroundColor(CTCTheme.good)
                }

                Button { recenter() } label: {
                    CTCCompassGlyph().stroke(CTCTheme.navy, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 20, height: 20)
                        .padding(9)
                        .background(Circle().fill(CTCTheme.card).overlay(Circle().strokeBorder(CTCTheme.cardBorder, lineWidth: 1)))
                }
                .buttonStyle(.plain)
            }
            if CTCEngine.floodActive(state) {
                HStack(spacing: 5) {
                    Text("Flood season — upstream travel costs 1 move this turn")
                        .font(CTCTheme.body(11)).foregroundColor(CTCTheme.riverDeep)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(CTCTheme.riverLight.opacity(0.22)))
            }
        }
        .ctcColumn(layout.gridWidth)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            CTCTheme.card.opacity(0.94)
                .overlay(Rectangle().frame(height: 1).foregroundColor(CTCTheme.cardBorder), alignment: .bottom)
                .edgesIgnoringSafeArea(.top)
        )
    }

    private var humanFlorins: Int {
        state.players.indices.contains(0) ? state.players[0].florins : 0
    }

    private var statusText: String {
        if state.winner != -9 { return "The match is decided" }
        if controller.aiThinking { return "The barons are moving..." }
        if controller.humanTurn { return "Your move" }
        if state.players.indices.contains(state.currentPlayer) {
            return state.players[state.currentPlayer].name
        }
        return "..."
    }

    private var statusColor: Color {
        if controller.humanTurn { return CTCTheme.good }
        if state.players.indices.contains(state.currentPlayer) {
            return CTCTheme.ownerColor(state.currentPlayer, players: state.players)
        }
        return CTCTheme.inkSoft
    }

    // MARK: - Bottom (action panel + end turn / ai banner)

    /// The action panel is capped against the live screen height: in landscape
    /// (or on a 375×667 phone) a full-height panel would otherwise slide up
    /// under the HUD and cover the map controls.
    private func panelCap(_ screenHeight: CGFloat) -> CGFloat {
        let chrome: CGFloat = 178   // HUD + End Turn banner + paddings
        // On iPad the map reserves a fixed bottom band (see `mapInset`), so the
        // panel is held to that band instead of growing over the river.
        if layout.regular { return max(160, min(220, screenHeight - chrome)) }
        return max(120, min(250, screenHeight - chrome))
    }

    private func bottomArea(_ screenHeight: CGFloat) -> some View {
        VStack(spacing: 8) {
            if let sel = controller.selectedNodeID, let node = state.node(sel) {
                MatchActionPanel(controller: controller, node: node,
                                 damPickerNode: $damPickerNode,
                                 maxPanelHeight: panelCap(screenHeight),
                                 onClose: { controller.deselect() })
                    .padding(.horizontal, 10)
                    .ctcColumn(layout.panelWidth)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if controller.aiThinking {
                banner(text: "The barons are moving...", fill: CTCTheme.navy.opacity(0.85), enabled: false) {}
            } else if controller.humanTurn {
                banner(text: "End Turn", fill: CTCTheme.navy, enabled: true) {
                    withAnimation { controller.endTurn() }
                }
            }
        }
        .padding(.bottom, 10)
    }

    private func banner(text: String, fill: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { if enabled { action() } }) {
            HStack {
                Spacer()
                Text(text).font(CTCTheme.display(18)).foregroundColor(.white)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(CTCTheme.goldLine.opacity(0.7), lineWidth: 1.4))
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.horizontal, 14)
        .ctcColumn(layout.panelWidth)
    }

    // MARK: - Side rail (regular width, landscape)

    /// The docked rail: the tapped landing's action panel (or a standing hint
    /// when nothing is selected) above the End Turn banner.
    private func sideRail(_ size: CGSize) -> some View {
        VStack(spacing: 10) {
            if let sel = controller.selectedNodeID, let node = state.node(sel) {
                MatchActionPanel(controller: controller, node: node,
                                 damPickerNode: $damPickerNode,
                                 maxPanelHeight: max(200, size.height - 340),
                                 onClose: { controller.deselect() })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                railHint
            }

            Spacer(minLength: 0)

            if controller.aiThinking {
                banner(text: "The barons are moving...", fill: CTCTheme.navy.opacity(0.85), enabled: false) {}
            } else if controller.humanTurn {
                banner(text: "End Turn", fill: CTCTheme.navy, enabled: true) {
                    withAnimation { controller.endTurn() }
                }
            }
        }
    }

    private var railHint: some View {
        CTCCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("The River").font(CTCTheme.display(16)).foregroundColor(CTCTheme.navy)
                Text("Tap a landing to read it and to order the fleet standing there. Downstream costs 1 move, upstream 2.")
                    .font(CTCTheme.body(13)).foregroundColor(CTCTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Overlays

    @ViewBuilder private var overlays: some View {
        if showMenu {
            MatchMenuOverlay(
                onResume: { showMenu = false },
                onLeave: { showMenu = false; onExit() },
                onResign: { showMenu = false; controller.resign() }
            )
        }
        if !controller.battleReview.isEmpty {
            BattleReviewOverlay(reports: controller.battleReview,
                                detail: store.root.settings.battleDetail,
                                players: state.players,
                                onDismiss: { controller.dismissBattleReview() })
        }
        if controller.showTurnSummary {
            TurnSummaryOverlay(notices: controller.turnNotices,
                               reports: controller.reportQueue,
                               detail: store.root.settings.battleDetail,
                               players: state.players,
                               onDismiss: { controller.dismissSummary() })
        }
        if showOnboard {
            OnboardingOverlay(onDone: {
                showOnboard = false
                store.root.onboardingDone = true
                store.save()
            })
        }
        if controller.showResult {
            ResultOverlay(state: state, stars: controller.resultStars,
                          mode: controller.mode, scenarioID: controller.scenarioID,
                          onExit: onExit)
        }
    }
}

// MARK: - Small shared helpers

func ctcRoman(_ n: Int) -> String {
    switch n {
    case 1: return "I"
    case 2: return "II"
    case 3: return "III"
    default: return "\(n)"
    }
}

func ctcKindName(_ k: CTCNodeKind) -> String {
    switch k {
    case .harbor: return "Harbor"
    case .island: return "Island"
    case .confluence: return "Confluence"
    case .mouth: return "The Mouth"
    }
}

/// A little compass rose for the recenter button.
struct CTCCompassGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08))
        p.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.16))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.16))
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.midY))
        return p
    }
}
