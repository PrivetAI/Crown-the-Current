import SwiftUI

// MARK: - Dim scrim wrapper

private struct RBScrim<Content: View>: View {
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
    let report: RBBattleReport
    let detail: Bool
    let players: [RBPlayer]

    private func name(_ owner: Int) -> String {
        if owner == 0 { return "You" }
        if owner == -1 { return "Pirates" }
        if owner == RBEngine.garrisonOwner { return "Garrison" }
        return players.indices.contains(owner) ? players[owner].name : "Rival"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Battle at \(report.nodeName)")
                .font(RBTheme.display(15)).foregroundColor(RBTheme.ink)
            if detail {
                mathLine(name(report.attacker), base: report.atkStr,
                         mods: [("flow", report.atkFlow), ("roll", report.atkRoll)],
                         total: report.atkTotal, win: report.attackerWon)
                mathLine(name(report.defender), base: report.defStr,
                         mods: [("harbor", report.defHarbor), ("dock", report.defDock)],
                         total: report.defTotal, win: !report.attackerWon)
            }
            let winner = report.attackerWon ? name(report.attacker) : name(report.defender)
            HStack(spacing: 5) {
                Text("\(winner) prevails")
                    .font(RBTheme.body(13)).foregroundColor(RBTheme.good)
                if report.winnerLoss > 0 {
                    Text("(lost \(report.winnerLoss) strength)")
                        .font(RBTheme.body(12)).foregroundColor(RBTheme.inkSoft)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 10).fill(RBTheme.parchment))
    }

    private func mathLine(_ who: String, base: Int, mods: [(String, Int)], total: Int, win: Bool) -> some View {
        let parts = mods.filter { $0.1 != 0 }.map { "\($0.1 > 0 ? "+" : "")\($0.1) \($0.0)" }
        return HStack(spacing: 6) {
            Text(who).font(RBTheme.body(13)).foregroundColor(win ? RBTheme.ink : RBTheme.inkSoft)
                .frame(width: 92, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
            Text("\(base)").font(RBTheme.num(13)).foregroundColor(RBTheme.ink)
            if !parts.isEmpty {
                Text(parts.joined(separator: " ")).font(RBTheme.numLight(12)).foregroundColor(RBTheme.inkSoft)
            }
            Spacer()
            Text("= \(total)").font(RBTheme.num(14)).foregroundColor(win ? RBTheme.good : RBTheme.danger)
        }
    }
}

// MARK: - Battle review (human's own strike)

struct BattleReviewOverlay: View {
    let reports: [RBBattleReport]
    let detail: Bool
    let players: [RBPlayer]
    let onDismiss: () -> Void

    var body: some View {
        RBScrim {
            VStack(spacing: 14) {
                RBRibbonHeader(title: reports.count > 1 ? "Battle Reports" : "Battle Report")
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(reports) { r in
                            BattleMathView(report: r, detail: detail, players: players)
                        }
                    }
                }
                .frame(maxHeight: 320)
                Button(action: onDismiss) { Text("Continue").frame(maxWidth: .infinity) }
                    .buttonStyle(RBButtonStyle())
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(RBTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(RBTheme.cardBorder, lineWidth: 1.4)))
        }
    }
}

// MARK: - Turn summary (after the AI barons move)

struct TurnSummaryOverlay: View {
    let notices: [String]
    let reports: [RBBattleReport]
    let detail: Bool
    let players: [RBPlayer]
    let onDismiss: () -> Void

    var body: some View {
        RBScrim {
            VStack(spacing: 14) {
                RBRibbonHeader(title: "The River Turns")
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if !notices.isEmpty {
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(Array(notices.enumerated()), id: \.offset) { _, line in
                                    HStack(alignment: .top, spacing: 7) {
                                        Circle().fill(RBTheme.goldLine).frame(width: 6, height: 6).padding(.top, 5)
                                        Text(line).font(RBTheme.body(13)).foregroundColor(RBTheme.ink)
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
                                .font(RBTheme.body(13)).foregroundColor(RBTheme.inkSoft)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(maxHeight: 340)
                Button(action: onDismiss) { Text("To your turn").frame(maxWidth: .infinity) }
                    .buttonStyle(RBButtonStyle())
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(RBTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(RBTheme.cardBorder, lineWidth: 1.4)))
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
        RBScrim {
            VStack(spacing: 14) {
                RBRibbonHeader(title: "Anchored")
                Button(action: onResume) { Text("Resume Match").frame(maxWidth: .infinity) }
                    .buttonStyle(RBButtonStyle())
                Button(action: onLeave) { Text("Leave (saved for later)").frame(maxWidth: .infinity) }
                    .buttonStyle(RBButtonStyle(fill: RBTheme.bankGreenDeep))
                if confirmResign {
                    Text("Resigning records this match as a loss.")
                        .font(RBTheme.body(12)).foregroundColor(RBTheme.inkSoft)
                        .multilineTextAlignment(.center)
                    Button(action: onResign) { Text("Confirm Resign").frame(maxWidth: .infinity) }
                        .buttonStyle(RBButtonStyle(fill: RBTheme.danger))
                } else {
                    Button(action: { confirmResign = true }) { Text("Resign Match").frame(maxWidth: .infinity) }
                        .buttonStyle(RBButtonStyle(fill: RBTheme.danger.opacity(0.85)))
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18).fill(RBTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(RBTheme.cardBorder, lineWidth: 1.4)))
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
        RBScrim {
            VStack(spacing: 15) {
                RBRibbonHeader(title: won ? "Victory" : "Defeat")

                Text(headline)
                    .font(RBTheme.body(14)).foregroundColor(RBTheme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if mode == "campaign", let meta = RBScenarios.meta(scenarioID) {
                    starRow
                    VStack(alignment: .leading, spacing: 6) {
                        starLine("Win the scenario", earned: won)
                        starLine("Win by turn \(meta.starTurn)", earned: won && state.turn <= meta.starTurn)
                        starLine("Never lose a shipyard", earned: won && !(state.lostShipyard.first ?? true))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(RBTheme.parchment))
                } else if won {
                    HStack(spacing: 6) {
                        Text("Landings held:").font(RBTheme.body(13)).foregroundColor(RBTheme.inkSoft)
                        Text("\(state.nodes.filter { $0.owner == 0 }.count)").font(RBTheme.num(14)).foregroundColor(RBTheme.ink)
                        Text("· Turn \(state.turn)").font(RBTheme.body(13)).foregroundColor(RBTheme.inkSoft)
                    }
                }

                Button(action: onExit) { Text("Return to Port").frame(maxWidth: .infinity) }
                    .buttonStyle(RBButtonStyle())
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18).fill(RBTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(RBTheme.cardBorder, lineWidth: 1.4)))
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
                RBStarIcon()
                    .fill(i < stars ? RBTheme.goldLine : RBTheme.inkSoft.opacity(0.22))
                    .frame(width: 40, height: 40)
                    .overlay(RBStarIcon().stroke(RBTheme.ink.opacity(0.25), lineWidth: 1).frame(width: 40, height: 40))
            }
        }
    }

    private func starLine(_ text: String, earned: Bool) -> some View {
        HStack(spacing: 8) {
            RBStarIcon().fill(earned ? RBTheme.goldLine : RBTheme.inkSoft.opacity(0.22))
                .frame(width: 15, height: 15)
            Text(text).font(RBTheme.body(13)).foregroundColor(earned ? RBTheme.ink : RBTheme.inkSoft)
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
        RBScrim {
            VStack(spacing: 16) {
                RBRibbonHeader(title: steps[step].0)
                Text(steps[step].1)
                    .font(RBTheme.body(15)).foregroundColor(RBTheme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                HStack(spacing: 7) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle().fill(i == step ? RBTheme.navy : RBTheme.inkSoft.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                Button(action: {
                    RBStore.shared.tap()
                    if step < steps.count - 1 { withAnimation { step += 1 } } else { onDone() }
                }) {
                    Text(step < steps.count - 1 ? "Next" : "Set Sail").frame(maxWidth: .infinity)
                }
                .buttonStyle(RBButtonStyle())
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 18).fill(RBTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(RBTheme.cardBorder, lineWidth: 1.4)))
        }
    }
}
