import SwiftUI

/// The live match: a pan/zoom river map, top HUD with income ticker, a
/// node action panel, the End Turn banner, and all match overlays.
struct MatchScreen: View {
    @ObservedObject var controller: MatchController
    @ObservedObject var store = RBStore.shared
    let onExit: () -> Void

    @State private var camera = RBCamera()
    @State private var pinch: CGFloat = 1
    @State private var dragT: CGSize = .zero
    @State private var pinchEndedAt = Date.distantPast
    @State private var showMenu = false
    @State private var damPickerNode: Int? = nil
    @State private var showOnboard = false

    private var state: GameState { controller.state }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RBTheme.parchment.ignoresSafeArea()

                mapLayer(geo.size)

                VStack(spacing: 0) {
                    hud
                    Spacer(minLength: 0)
                    bottomArea
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

    private func effectiveCamera(_ size: CGSize) -> RBCamera {
        var c = camera
        c.scale = min(3.5, max(0.55, camera.scale * pinch))
        c.offset = CGSize(width: camera.offset.width + dragT.width,
                          height: camera.offset.height + dragT.height)
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
            camera = RBCamera()
        }
    }

    // MARK: - HUD

    private var hud: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Button { store.tap(); showMenu = true } label: {
                    RBPennantIcon().fill(RBTheme.navy)
                        .frame(width: 20, height: 22)
                        .padding(9)
                        .background(Circle().fill(RBTheme.card).overlay(Circle().strokeBorder(RBTheme.cardBorder, lineWidth: 1)))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Turn \(state.turn) / \(state.turnCap)")
                        .font(RBTheme.num(12)).foregroundColor(RBTheme.ink)
                    HStack(spacing: 5) {
                        Circle().fill(statusColor).frame(width: 9, height: 9)
                        Text(statusText).font(RBTheme.body(13)).foregroundColor(RBTheme.inkSoft)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        RBCoinIcon(size: 15)
                        Text("\(humanFlorins)").font(RBTheme.num(16)).foregroundColor(RBTheme.ink)
                    }
                    Text("+\(controller.humanIncome)/turn")
                        .font(RBTheme.numLight(11)).foregroundColor(RBTheme.good)
                }

                Button { recenter() } label: {
                    RBCompassGlyph().stroke(RBTheme.navy, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 20, height: 20)
                        .padding(9)
                        .background(Circle().fill(RBTheme.card).overlay(Circle().strokeBorder(RBTheme.cardBorder, lineWidth: 1)))
                }
                .buttonStyle(.plain)
            }
            if RBEngine.floodActive(state) {
                HStack(spacing: 5) {
                    Text("Flood season — upstream travel costs 1 move this turn")
                        .font(RBTheme.body(11)).foregroundColor(RBTheme.riverDeep)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(RBTheme.riverLight.opacity(0.22)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RBTheme.card.opacity(0.94)
                .overlay(Rectangle().frame(height: 1).foregroundColor(RBTheme.cardBorder), alignment: .bottom)
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
        if controller.humanTurn { return RBTheme.good }
        if state.players.indices.contains(state.currentPlayer) {
            return RBTheme.ownerColor(state.currentPlayer, players: state.players)
        }
        return RBTheme.inkSoft
    }

    // MARK: - Bottom (action panel + end turn / ai banner)

    private var bottomArea: some View {
        VStack(spacing: 8) {
            if let sel = controller.selectedNodeID, let node = state.node(sel) {
                MatchActionPanel(controller: controller, node: node,
                                 damPickerNode: $damPickerNode, onClose: { controller.deselect() })
                    .padding(.horizontal, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if controller.aiThinking {
                banner(text: "The barons are moving...", fill: RBTheme.navy.opacity(0.85), enabled: false) {}
            } else if controller.humanTurn {
                banner(text: "End Turn", fill: RBTheme.navy, enabled: true) {
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
                Text(text).font(RBTheme.display(18)).foregroundColor(.white)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(fill)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(RBTheme.goldLine.opacity(0.7), lineWidth: 1.4))
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.horizontal, 14)
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

func rbRoman(_ n: Int) -> String {
    switch n {
    case 1: return "I"
    case 2: return "II"
    case 3: return "III"
    default: return "\(n)"
    }
}

func rbKindName(_ k: RBNodeKind) -> String {
    switch k {
    case .harbor: return "Harbor"
    case .island: return "Island"
    case .confluence: return "Confluence"
    case .mouth: return "The Mouth"
    }
}

/// A little compass rose for the recenter button.
struct RBCompassGlyph: Shape {
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
