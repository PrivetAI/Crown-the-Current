import SwiftUI

struct CampaignView: View {
    @ObservedObject var store = CTCStore.shared
    @Environment(\.horizontalSizeClass) private var hSize
    let startMatch: (MatchState, Bool) -> Void

    private var layout: CTCLayout { CTCLayout(hSize) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                CTCRibbonHeader(title: "The Campaign", subtitle: "\(store.root.totalStars) of 42 stars earned")
                    .padding(.top, 6)

                if let match = store.root.activeCampaignMatch,
                   let meta = CTCScenarios.meta(match.scenarioID) {
                    resumeCard(meta: meta, turn: match.game.turn) { startMatch(match, false) }
                }

                ForEach(1...3, id: \.self) { act in
                    actSection(act)
                }
            }
            .ctcColumn(layout.gridWidth)
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
        }
        .background(CTCTheme.parchment.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func resumeCard(meta: CTCScenarios.Meta, turn: Int, action: @escaping () -> Void) -> some View {
        Button(action: { store.tap(); action() }) {
            CTCCard {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Resume Campaign").font(CTCTheme.body(12)).foregroundColor(CTCTheme.good)
                        Text(meta.title).font(CTCTheme.display(18)).foregroundColor(CTCTheme.ink)
                        Text("Turn \(turn) · \(meta.tagline)").font(CTCTheme.body(12)).foregroundColor(CTCTheme.inkSoft)
                    }
                    Spacer()
                    CTCChevron(pointRight: true).stroke(CTCTheme.navy, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        .frame(width: 13, height: 20)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func actSection(_ act: Int) -> some View {
        let metas = CTCScenarios.all.filter { $0.act == act }
        VStack(spacing: 12) {
            CTCArtBanner(imageName: "ctc_act\(act)",
                        title: CTCScenarios.actTitles[act - 1],
                        subtitle: CTCScenarios.actTaglines[act - 1],
                        height: layout.regular ? 190 : 138)
                .padding(.top, 4)
            if layout.regular {
                // Two scenario columns on iPad; the act's cards then read as a
                // block instead of a 900pt-wide ladder of single rows.
                LazyVGrid(columns: layout.columns(layout.listColumns, spacing: 12), spacing: 12) {
                    ForEach(metas) { meta in
                        scenarioCard(meta)
                    }
                }
            } else {
                ForEach(metas) { meta in
                    scenarioCard(meta)
                }
            }
        }
    }

    @ViewBuilder private func scenarioCard(_ meta: CTCScenarios.Meta) -> some View {
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

    private func scenarioCardBody(_ meta: CTCScenarios.Meta, best: Int, locked: Bool) -> some View {
        CTCCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(locked ? CTCTheme.inkSoft.opacity(0.18) : CTCTheme.navy)
                        .frame(width: 44, height: 44)
                    Text("\(meta.id)").font(CTCTheme.display(20)).foregroundColor(locked ? CTCTheme.inkSoft : .white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(meta.title).font(CTCTheme.display(17)).foregroundColor(locked ? CTCTheme.inkSoft : CTCTheme.ink)
                    if locked {
                        Text("Win the previous scenario to unlock.")
                            .font(CTCTheme.body(12)).foregroundColor(CTCTheme.inkSoft)
                    } else {
                        Text(meta.tagline).font(CTCTheme.body(12)).foregroundColor(CTCTheme.inkSoft)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                CTCStarIcon().fill(i < best ? CTCTheme.goldLine : CTCTheme.inkSoft.opacity(0.22))
                                    .frame(width: 13, height: 13)
                            }
                        }
                    }
                }
                Spacer()
                if !locked {
                    CTCChevron(pointRight: true).stroke(CTCTheme.inkSoft, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 10, height: 16)
                }
            }
        }
        .opacity(locked ? 0.85 : 1)
    }
}

struct ScenarioDetailView: View {
    @ObservedObject var store = CTCStore.shared
    @Environment(\.horizontalSizeClass) private var hSize
    let meta: CTCScenarios.Meta
    let startMatch: (MatchState, Bool) -> Void
    @Environment(\.presentationMode) private var presentationMode

    private var layout: CTCLayout { CTCLayout(hSize) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CTCRibbonHeader(title: meta.title, subtitle: meta.tagline)
                    .padding(.top, 6)

                CTCArtBanner(imageName: scenarioArt, height: layout.regular ? 220 : 150)

                CTCCard {
                    Text(meta.narration)
                        .font(CTCTheme.body(15)).foregroundColor(CTCTheme.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CTCCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("The Field").font(CTCTheme.display(15)).foregroundColor(CTCTheme.navy)
                        Text(meta.oppLine).font(CTCTheme.body(13)).foregroundColor(CTCTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            ruleChip("Turn cap \(meta.turnCap)")
                            if meta.fog { ruleChip("Fog") }
                            if meta.flood > 0 { ruleChip("Floods") }
                            if meta.pirates { ruleChip("Pirates") }
                        }
                    }
                }

                CTCCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Stars").font(CTCTheme.display(15)).foregroundColor(CTCTheme.navy)
                        objective("Win the scenario")
                        objective("Win by turn \(meta.starTurn)")
                        objective("Win without losing a shipyard")
                    }
                }

                Button(action: setSail) {
                    Text("Set Sail").frame(maxWidth: .infinity)
                }
                .buttonStyle(CTCButtonStyle())
                .padding(.top, 4)
            }
            .ctcColumn(layout.readingWidth)
            .padding(.horizontal, 14)
            .padding(.bottom, 26)
        }
        .background(CTCTheme.parchment.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A vignette that reflects the scenario's flavor: pirate waters, dammed
    /// floods, or the act's own riverlands.
    private var scenarioArt: String {
        if meta.pirates { return "ctc_vig_pirate" }
        if meta.flood > 0 { return "ctc_vig_dam" }
        return "ctc_act\(meta.act)"
    }

    private func ruleChip(_ text: String) -> some View {
        Text(text).font(CTCTheme.body(12)).foregroundColor(CTCTheme.navy)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(CTCTheme.navy.opacity(0.10)))
    }

    private func objective(_ text: String) -> some View {
        HStack(spacing: 8) {
            CTCStarIcon().fill(CTCTheme.goldLine).frame(width: 14, height: 14)
            Text(text).font(CTCTheme.body(13)).foregroundColor(CTCTheme.ink)
        }
    }

    private func setSail() {
        store.tap()
        let seed = UInt64(truncatingIfNeeded: Int(Date().timeIntervalSince1970)) &+ UInt64(meta.id) &* 101
        guard let game = CTCScenarios.make(id: meta.id, seed: seed, playerColor: store.root.selectedBanner) else { return }
        var ms = MatchState()
        ms.mode = "campaign"
        ms.scenarioID = meta.id
        ms.game = game
        presentationMode.wrappedValue.dismiss()
        startMatch(ms, true)
    }
}
