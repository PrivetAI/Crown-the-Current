import SwiftUI

struct CampaignView: View {
    @ObservedObject var store = RBStore.shared
    let startMatch: (MatchState) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                RBRibbonHeader(title: "The Campaign", subtitle: "\(store.root.totalStars) of 42 stars earned")
                    .padding(.top, 6)

                if let match = store.root.activeMatch, match.mode == "campaign",
                   let meta = RBScenarios.meta(match.scenarioID) {
                    resumeCard(meta: meta, turn: match.game.turn) { startMatch(match) }
                }

                ForEach(1...3, id: \.self) { act in
                    actSection(act)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
        }
        .background(RBTheme.parchment.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func resumeCard(meta: RBScenarios.Meta, turn: Int, action: @escaping () -> Void) -> some View {
        Button(action: { store.tap(); action() }) {
            RBCard {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Resume Campaign").font(RBTheme.body(12)).foregroundColor(RBTheme.good)
                        Text(meta.title).font(RBTheme.display(18)).foregroundColor(RBTheme.ink)
                        Text("Turn \(turn) · \(meta.tagline)").font(RBTheme.body(12)).foregroundColor(RBTheme.inkSoft)
                    }
                    Spacer()
                    RBChevron(pointRight: true).stroke(RBTheme.navy, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        .frame(width: 13, height: 20)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func actSection(_ act: Int) -> some View {
        let metas = RBScenarios.all.filter { $0.act == act }
        return VStack(spacing: 12) {
            RBArtBanner(imageName: "rb_act\(act)",
                        title: RBScenarios.actTitles[act - 1],
                        subtitle: RBScenarios.actTaglines[act - 1],
                        height: 138)
                .padding(.top, 4)
            ForEach(metas) { meta in
                scenarioCard(meta)
            }
        }
    }

    @ViewBuilder private func scenarioCard(_ meta: RBScenarios.Meta) -> some View {
        let unlocked = store.root.isScenarioUnlocked(meta.id)
        let best = store.root.scenarioStars[meta.id] ?? 0
        if unlocked {
            NavigationLink(destination: ScenarioDetailView(meta: meta, startMatch: startMatch)) {
                scenarioCardBody(meta, best: best, locked: false)
            }
            .buttonStyle(.plain)
        } else {
            scenarioCardBody(meta, best: best, locked: true)
        }
    }

    private func scenarioCardBody(_ meta: RBScenarios.Meta, best: Int, locked: Bool) -> some View {
        RBCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(locked ? RBTheme.inkSoft.opacity(0.18) : RBTheme.navy)
                        .frame(width: 44, height: 44)
                    Text("\(meta.id)").font(RBTheme.display(20)).foregroundColor(locked ? RBTheme.inkSoft : .white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(meta.title).font(RBTheme.display(17)).foregroundColor(locked ? RBTheme.inkSoft : RBTheme.ink)
                    if locked {
                        Text("Win the previous scenario to unlock.")
                            .font(RBTheme.body(12)).foregroundColor(RBTheme.inkSoft)
                    } else {
                        Text(meta.tagline).font(RBTheme.body(12)).foregroundColor(RBTheme.inkSoft)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                RBStarIcon().fill(i < best ? RBTheme.goldLine : RBTheme.inkSoft.opacity(0.22))
                                    .frame(width: 13, height: 13)
                            }
                        }
                    }
                }
                Spacer()
                if !locked {
                    RBChevron(pointRight: true).stroke(RBTheme.inkSoft, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 10, height: 16)
                }
            }
        }
        .opacity(locked ? 0.85 : 1)
    }
}

struct ScenarioDetailView: View {
    @ObservedObject var store = RBStore.shared
    let meta: RBScenarios.Meta
    let startMatch: (MatchState) -> Void
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RBRibbonHeader(title: meta.title, subtitle: meta.tagline)
                    .padding(.top, 6)

                RBArtBanner(imageName: scenarioArt, height: 150)

                RBCard {
                    Text(meta.narration)
                        .font(RBTheme.body(15)).foregroundColor(RBTheme.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                RBCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("The Field").font(RBTheme.display(15)).foregroundColor(RBTheme.navy)
                        Text(meta.oppLine).font(RBTheme.body(13)).foregroundColor(RBTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            ruleChip("Turn cap \(meta.turnCap)")
                            if meta.fog { ruleChip("Fog") }
                            if meta.flood > 0 { ruleChip("Floods") }
                            if meta.pirates { ruleChip("Pirates") }
                        }
                    }
                }

                RBCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Stars").font(RBTheme.display(15)).foregroundColor(RBTheme.navy)
                        objective("Win the scenario")
                        objective("Win by turn \(meta.starTurn)")
                        objective("Win without losing a shipyard")
                    }
                }

                Button(action: setSail) {
                    Text("Set Sail").frame(maxWidth: .infinity)
                }
                .buttonStyle(RBButtonStyle())
                .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 26)
        }
        .background(RBTheme.parchment.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A vignette that reflects the scenario's flavor: pirate waters, dammed
    /// floods, or the act's own riverlands.
    private var scenarioArt: String {
        if meta.pirates { return "rb_vig_pirate" }
        if meta.flood > 0 { return "rb_vig_dam" }
        return "rb_act\(meta.act)"
    }

    private func ruleChip(_ text: String) -> some View {
        Text(text).font(RBTheme.body(12)).foregroundColor(RBTheme.navy)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(RBTheme.navy.opacity(0.10)))
    }

    private func objective(_ text: String) -> some View {
        HStack(spacing: 8) {
            RBStarIcon().fill(RBTheme.goldLine).frame(width: 14, height: 14)
            Text(text).font(RBTheme.body(13)).foregroundColor(RBTheme.ink)
        }
    }

    private func setSail() {
        store.tap()
        let seed = UInt64(truncatingIfNeeded: Int(Date().timeIntervalSince1970)) &+ UInt64(meta.id) &* 101
        guard let game = RBScenarios.make(id: meta.id, seed: seed, playerColor: store.root.selectedBanner) else { return }
        var ms = MatchState()
        ms.mode = "campaign"
        ms.scenarioID = meta.id
        ms.game = game
        presentationMode.wrappedValue.dismiss()
        startMatch(ms)
    }
}
