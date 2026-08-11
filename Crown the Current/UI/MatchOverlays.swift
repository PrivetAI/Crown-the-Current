import SwiftUI

// MARK: - Shrink-to-fit scrolling body

/// A ScrollView fills whatever height it is offered, so a two-line summary was
/// rendering inside a 340pt slab of empty parchment. Measuring the content lets
/// the card hug short news while still capping and scrolling a long turn.
private struct CTCHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct CTCFittedScroll<Content: View>: View {
    let cap: CGFloat
    let content: Content
    @State private var contentHeight: CGFloat = 0

    init(cap: CGFloat, @ViewBuilder content: () -> Content) {
        self.cap = cap
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .background(GeometryReader { g in
                    Color.clear.preference(key: CTCHeightKey.self, value: g.size.height)
                })
        }
        .frame(height: contentHeight > 0 ? min(contentHeight, cap) : nil)
        .onPreferenceChange(CTCHeightKey.self) { contentHeight = $0 }
    }
}

// MARK: - Dim scrim wrapper

private struct CTCScrim<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        ZStack {
            Color.black.opacity(0.42).ignoresSafeArea()
            content
                .padding(20)
                .frame(maxWidth: 440)
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Battle math

struct BattleMathView: View {
    let report: CTCBattleReport
    let detail: Bool
    let players: [CTCPlayer]

    private func name(_ owner: Int) -> String {
        if owner == 0 { return "You" }
        if owner == -1 { return "Pirates" }
        if owner == CTCEngine.garrisonOwner { return "Garrison" }
        return players.indices.contains(owner) ? players[owner].name : "Rival"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Battle at \(report.nodeName)")
                .font(CTCTheme.display(15)).foregroundColor(CTCTheme.ink)
            if detail {
                mathLine(name(report.attacker), base: report.atkStr,
                         mods: [("flow", report.atkFlow), ("roll", report.atkRoll)],
                         total: report.atkTotal, win: report.attackerWon)
                mathLine(name(report.defender), base: report.defStr,
                         mods: [("harbor", report.defHarbor), ("dock", report.defDock)],
                         total: report.defTotal, win: !report.attackerWon)
            }
            let winnerOwner = report.attackerWon ? report.attacker : report.defender
            let winner = name(winnerOwner)
            HStack(spacing: 5) {
                Text("\(winner) \(CTCEngine.verb(winnerOwner, "prevail", "prevails"))")
                    .font(CTCTheme.body(13)).foregroundColor(CTCTheme.good)
                if report.winnerLoss > 0 {
                    Text("(lost \(report.winnerLoss) strength)")
                        .font(CTCTheme.body(12)).foregroundColor(CTCTheme.inkSoft)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 10).fill(CTCTheme.parchment))
    }

    private func mathLine(_ who: String, base: Int, mods: [(String, Int)], total: Int, win: Bool) -> some View {
        let parts = mods.filter { $0.1 != 0 }.map { "\($0.1 > 0 ? "+" : "")\($0.1) \($0.0)" }
        return HStack(spacing: 6) {
            Text(who).font(CTCTheme.body(13)).foregroundColor(win ? CTCTheme.ink : CTCTheme.inkSoft)
                .frame(width: 92, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
            Text("\(base)").font(CTCTheme.num(13)).foregroundColor(CTCTheme.ink)
            if !parts.isEmpty {
                Text(parts.joined(separator: " ")).font(CTCTheme.numLight(12)).foregroundColor(CTCTheme.inkSoft)
            }
            Spacer()
            Text("= \(total)").font(CTCTheme.num(14)).foregroundColor(win ? CTCTheme.good : CTCTheme.danger)
        }
    }
}

// MARK: - Battle review (human's own strike)

struct BattleReviewOverlay: View {
    let reports: [CTCBattleReport]
    let detail: Bool
    let players: [CTCPlayer]
    let onDismiss: () -> Void

    var body: some View {
        CTCScrim {
            VStack(spacing: 14) {
                CTCRibbonHeader(title: reports.count > 1 ? "Battle Reports" : "Battle Report")
                CTCFittedScroll(cap: 320) {
                    VStack(spacing: 10) {
                        ForEach(reports) { r in
                            BattleMathView(report: r, detail: detail, players: players)
                        }
                    }
                }
                Button(action: onDismiss) { Text("Continue").frame(maxWidth: .infinity) }
                    .buttonStyle(CTCButtonStyle())
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(CTCTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(CTCTheme.cardBorder, lineWidth: 1.4)))
        }
    }
}

// MARK: - Turn summary (after the AI barons move)

struct TurnSummaryOverlay: View {
    let notices: [String]
    let reports: [CTCBattleReport]
    let detail: Bool
    let players: [CTCPlayer]
    let onDismiss: () -> Void

    var body: some View {
        CTCScrim {
            VStack(spacing: 14) {
                CTCRibbonHeader(title: "The River Turns")
                CTCFittedScroll(cap: 340) {
                    VStack(alignment: .leading, spacing: 10) {
                        if !notices.isEmpty {
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(Array(notices.enumerated()), id: \.offset) { _, line in
                                    HStack(alignment: .top, spacing: 7) {
                                        Circle().fill(CTCTheme.goldLine).frame(width: 6, height: 6).padding(.top, 5)
                                        Text(line).font(CTCTheme.body(13)).foregroundColor(CTCTheme.ink)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if detail {
                            ForEach(reports) { r in
                                BattleMathView(report: r, detail: true, players: players)
                            }
                        }
                        if notices.isEmpty && reports.isEmpty {
                            Text("The barons bide their time.")
                                .font(CTCTheme.body(13)).foregroundColor(CTCTheme.inkSoft)
                        }
                    }
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button(action: onDismiss) { Text("To your turn").frame(maxWidth: .infinity) }
                    .buttonStyle(CTCButtonStyle())
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(CTCTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(CTCTheme.cardBorder, lineWidth: 1.4)))
        }
    }
}

// MARK: - Pause menu

struct MatchMenuOverlay: View {
    let onResume: () -> Void
    let onLeave: () -> Void
    let onResign: () -> Void
    @State private var confirmResign = false

    var body: some View {
        CTCScrim {
            VStack(spacing: 14) {
                CTCRibbonHeader(title: "Anchored")
                Button(action: onResume) { Text("Resume Match").frame(maxWidth: .infinity) }
                    .buttonStyle(CTCButtonStyle())
                Button(action: onLeave) { Text("Leave (saved for later)").frame(maxWidth: .infinity) }
                    .buttonStyle(CTCButtonStyle(fill: CTCTheme.bankGreenDeep))
                if confirmResign {
                    Text("Resigning records this match as a loss.")
                        .font(CTCTheme.body(12)).foregroundColor(CTCTheme.inkSoft)
                        .multilineTextAlignment(.center)
                    Button(action: onResign) { Text("Confirm Resign").frame(maxWidth: .infinity) }
                        .buttonStyle(CTCButtonStyle(fill: CTCTheme.danger))
                } else {
                    Button(action: { confirmResign = true }) { Text("Resign Match").frame(maxWidth: .infinity) }
                        .buttonStyle(CTCButtonStyle(fill: CTCTheme.danger.opacity(0.85)))
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18).fill(CTCTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(CTCTheme.cardBorder, lineWidth: 1.4)))
        }
    }
}

// MARK: - Result (victory / defeat + stars)

struct ResultOverlay: View {
    let state: GameState
    let stars: Int
    let mode: String
    let scenarioID: Int
    let onExit: () -> Void

    private var won: Bool { state.winner == 0 }

    var body: some View {
        CTCScrim {
            VStack(spacing: 15) {
                CTCRibbonHeader(title: won ? "Victory" : "Defeat")

                Text(headline)
                    .font(CTCTheme.body(14)).foregroundColor(CTCTheme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if mode == "campaign", let meta = CTCScenarios.meta(scenarioID) {
                    starRow
                    VStack(alignment: .leading, spacing: 6) {
                        starLine("Win the scenario", earned: won)
                        starLine("Win by turn \(meta.starTurn)", earned: won && state.turn <= meta.starTurn)
                        starLine("Never lose a shipyard", earned: won && !(state.lostShipyard.first ?? true))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(CTCTheme.parchment))
                } else if won {
                    HStack(spacing: 6) {
                        Text("Landings held:").font(CTCTheme.body(13)).foregroundColor(CTCTheme.inkSoft)
                        Text("\(state.nodes.filter { $0.owner == 0 }.count)").font(CTCTheme.num(14)).foregroundColor(CTCTheme.ink)
                        Text("· Turn \(state.turn)").font(CTCTheme.body(13)).foregroundColor(CTCTheme.inkSoft)
                    }
                }

                Button(action: onExit) { Text("Return to Port").frame(maxWidth: .infinity) }
                    .buttonStyle(CTCButtonStyle())
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18).fill(CTCTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(CTCTheme.cardBorder, lineWidth: 1.4)))
        }
    }

    private var headline: String {
        if won {
            switch state.winKind {
            case "mouth": return "You held the Mouth for three turns. The trade of the whole coast is yours."
            case "elimination": return "Every rival baron has been driven from the water."
            case "nodes": return "When the season closed, no baron held more of the river than you."
            default: return "The river is yours."
            }
        } else {
            let w = state.winner
            let name = (w >= 0 && state.players.indices.contains(w)) ? state.players[w].name : "A rival"
            return "\(name) has taken the river. Regroup and sail again."
        }
    }

    private var starRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { i in
                CTCStarIcon()
                    .fill(i < stars ? CTCTheme.goldLine : CTCTheme.inkSoft.opacity(0.22))
                    .frame(width: 40, height: 40)
                    .overlay(CTCStarIcon().stroke(CTCTheme.ink.opacity(0.25), lineWidth: 1).frame(width: 40, height: 40))
            }
        }
    }

    private func starLine(_ text: String, earned: Bool) -> some View {
        HStack(spacing: 8) {
            CTCStarIcon().fill(earned ? CTCTheme.goldLine : CTCTheme.inkSoft.opacity(0.22))
                .frame(width: 15, height: 15)
            Text(text).font(CTCTheme.body(13)).foregroundColor(earned ? CTCTheme.ink : CTCTheme.inkSoft)
        }
    }
}

// MARK: - Onboarding (scenario 1, first play)

struct OnboardingOverlay: View {
    let onDone: () -> Void
    @State private var step = 0

    private let steps: [(String, String)] = [
        ("Welcome, Baron",
         "The old master of the delta is dead and his waters lie open. Rule the river, and the trade of the coast is yours. Pinch to zoom, drag to pan the map."),
        ("Landings & Florins",
         "Tap a landing you own to build. Docks raise your income and defense; a shipyard lets you recruit ships. Florins arrive at the start of every one of your turns."),
        ("Fleets & the Current",
         "Tap one of your ships to see where it can sail. Sailing downstream costs 1 move, upstream costs 2. Sail onto a rival's landing to give battle."),
        ("Winning the River",
         "Hold the Mouth for three turns, sink every rival, or hold the most landings when the season ends. Tap End Turn when your moves are spent.")
    ]

    var body: some View {
        CTCScrim {
            VStack(spacing: 16) {
                CTCRibbonHeader(title: steps[step].0)
                Text(steps[step].1)
                    .font(CTCTheme.body(15)).foregroundColor(CTCTheme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                HStack(spacing: 7) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle().fill(i == step ? CTCTheme.navy : CTCTheme.inkSoft.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                Button(action: {
                    CTCStore.shared.tap()
                    if step < steps.count - 1 { withAnimation { step += 1 } } else { onDone() }
                }) {
                    Text(step < steps.count - 1 ? "Next" : "Set Sail").frame(maxWidth: .infinity)
                }
                .buttonStyle(CTCButtonStyle())
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 18).fill(CTCTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(CTCTheme.cardBorder, lineWidth: 1.4)))
        }
    }
}
