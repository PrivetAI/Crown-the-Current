import SwiftUI

/// A live match wrapped for fullScreenCover presentation.
struct MatchLaunchItem: Identifiable {
    let id = UUID()
    let controller: MatchController
}

/// Root shell: custom HStack tab bar (Campaign / Skirmish / Chronicle / More)
/// plus the fullscreen match router and the global achievement toast.
struct RootView: View {
    @ObservedObject var store = RBStore.shared
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var tab = 0
    @State private var session: MatchLaunchItem? = nil
    /// A brand-new match held back because an unfinished one of the same mode
    /// would be overwritten; launched only once the baron confirms.
    @State private var pendingStart: MatchState? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Group {
                    switch tab {
                    case 0:
                        NavigationView { CampaignView(startMatch: start) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 1:
                        NavigationView { SkirmishView(startMatch: start) }
                            .navigationViewStyle(StackNavigationViewStyle())
                    case 2:
                        NavigationView { ChronicleView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    default:
                        NavigationView { MoreView() }
                            .navigationViewStyle(StackNavigationViewStyle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }

            if let toast = store.toast {
                Text(toast)
                    .font(RBTheme.body(14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(
                        Capsule().fill(RBTheme.navy)
                            .overlay(Capsule().strokeBorder(RBTheme.goldLine.opacity(0.8), lineWidth: 1.2))
                    )
                    .padding(.bottom, 84)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(RBTheme.parchment.ignoresSafeArea())
        .fullScreenCover(item: $session) { item in
            MatchScreen(controller: item.controller, onExit: { session = nil })
        }
        .alert("Abandon the unfinished match?",
               isPresented: Binding(get: { pendingStart != nil },
                                    set: { if !$0 { pendingStart = nil } })) {
            Button("Cancel", role: .cancel) { pendingStart = nil }
            Button("Abandon & Sail", role: .destructive) {
                let match = pendingStart
                pendingStart = nil
                if let match = match { launch(match) }
            }
        } message: {
            Text(overwriteMessage)
        }
    }

    /// `isNew` marks a freshly generated match. Resuming passes false and always
    /// goes straight through; a new match first asks before discarding an
    /// unfinished save in the same mode.
    private func start(_ match: MatchState, isNew: Bool) {
        if isNew, store.root.activeMatch(mode: match.mode) != nil {
            pendingStart = match
            return
        }
        launch(match)
    }

    private func launch(_ match: MatchState) {
        store.root.setActiveMatch(match, mode: match.mode)
        store.save()
        let controller = MatchController(match: match, store: store)
        session = MatchLaunchItem(controller: controller)
    }

    private var overwriteMessage: String {
        guard let mode = pendingStart?.mode else { return "" }
        if mode == "campaign",
           let saved = store.root.activeCampaignMatch,
           let meta = RBScenarios.meta(saved.scenarioID) {
            return "\(meta.title) is still unfinished at turn \(saved.game.turn). Setting sail now abandons that match for good."
        }
        if let saved = store.root.activeSkirmishMatch {
            return "A skirmish is still unfinished at turn \(saved.game.turn). Generating a new river abandons that match for good."
        }
        return "An unfinished match will be abandoned for good."
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(0, "Campaign") { AnyView(RBPennantIcon().fill($0)) }
            tabButton(1, "Skirmish") { AnyView(RBOarsIcon().fill($0)) }
            tabButton(2, "Chronicle") { AnyView(RBStarIcon().fill($0)) }
            tabButton(3, "More") {
                AnyView(RBBookIcon().stroke($0, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)))
            }
        }
        .rbColumn(RBLayout(hSize).tabBarWidth)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            RBTheme.card
                .overlay(Rectangle().frame(height: 1).foregroundColor(RBTheme.cardBorder), alignment: .top)
                .edgesIgnoringSafeArea(.bottom)
        )
    }

    private func tabButton(_ index: Int, _ label: String,
                           _ icon: @escaping (Color) -> AnyView) -> some View {
        let active = tab == index
        let color = active ? RBTheme.navy : RBTheme.ink.opacity(0.4)
        return Button {
            store.tap()
            withAnimation(.easeInOut(duration: 0.15)) { tab = index }
        } label: {
            VStack(spacing: 4) {
                icon(color)
                    .frame(width: 24, height: 24)
                Text(label)
                    .font(RBTheme.body(11))
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
