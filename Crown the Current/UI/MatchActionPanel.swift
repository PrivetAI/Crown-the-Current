import SwiftUI

/// Bottom panel for the tapped node: its details, the fleets standing there,
/// and the legal build / recruit / dam / breach actions during the human turn.
struct MatchActionPanel: View {
    @ObservedObject var controller: MatchController
    let node: CTCNode
    @Binding var damPickerNode: Int?
    /// Capped by the parent from the live screen height so the panel can never
    /// grow up into the HUD on a short screen (landscape, or 375×667).
    var maxPanelHeight: CGFloat = 250
    let onClose: () -> Void

    private var state: GameState { controller.state }
    private var florins: Int { state.players.indices.contains(0) ? state.players[0].florins : 0 }
    private var humanTurn: Bool { controller.humanTurn }
    private var humanFleet: CTCFleet? { state.fleetsAt(node.id).first { $0.owner == 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    statRow
                    fleetSection
                    if humanTurn { actionSection }
                }
                .padding(.top, 8)
            }
            .frame(maxHeight: maxPanelHeight)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 16).fill(CTCTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(CTCTheme.cardBorder, lineWidth: 1.3))
                .shadow(color: CTCTheme.ink.opacity(0.12), radius: 8, y: -2)
        )
    }

    // MARK: header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name).font(CTCTheme.display(19)).foregroundColor(CTCTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 6) {
                    Text(ctcKindName(node.kind)).font(CTCTheme.body(12)).foregroundColor(CTCTheme.inkSoft)
                    Circle().fill(ownerColor).frame(width: 7, height: 7)
                    Text(ownerLabel).font(CTCTheme.body(12)).foregroundColor(CTCTheme.inkSoft)
                }
            }
            Spacer()
            Button { CTCStore.shared.tap(); onClose() } label: {
                CTCCross().stroke(CTCTheme.inkSoft, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 15, height: 15).padding(6)
            }
            .buttonStyle(.plain)
        }
    }

    private var ownerLabel: String {
        if node.owner == 0 { return "Your landing" }
        if node.owner < 0 { return "Unclaimed" }
        return state.players.indices.contains(node.owner) ? state.players[node.owner].name : "Rival"
    }

    private var ownerColor: Color {
        if node.owner < 0 { return Color(red: 0.6, green: 0.57, blue: 0.5) }
        return CTCTheme.ownerColor(node.owner, players: state.players)
    }

    // MARK: stat row

    private var statRow: some View {
        HStack(spacing: 8) {
            statChip(title: "Income", value: "\(CTCEngine.baseIncome(node.kind) + CTCEngine.dockIncome(node.dock))", coin: true)
            statChip(title: "Defense", value: "+\(defenseBonus)", coin: false)
            if node.dock > 0 { badge("Dock \(ctcRoman(node.dock))") }
            if node.yard { badge("Shipyard") }
            if node.tower { badge("Tower") }
            Spacer(minLength: 0)
        }
    }

    private var defenseBonus: Int {
        (node.kind == .harbor ? 1 : 0) + CTCEngine.dockDefense(node.dock)
    }

    private func statChip(title: String, value: String, coin: Bool) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 3) {
                if coin { CTCCoinIcon(size: 12) }
                Text(value).font(CTCTheme.num(14)).foregroundColor(CTCTheme.ink)
            }
            Text(title).font(CTCTheme.body(10)).foregroundColor(CTCTheme.inkSoft)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(CTCTheme.parchment))
    }

    private func badge(_ text: String) -> some View {
        Text(text).font(CTCTheme.body(11)).foregroundColor(CTCTheme.navy)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(CTCTheme.navy.opacity(0.10)))
    }

    // MARK: fleets

    @ViewBuilder private var fleetSection: some View {
        let fleets = state.fleetsAt(node.id)
        if !fleets.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(fleets) { f in
                    HStack(spacing: 8) {
                        CTCSailIcon().fill(CTCTheme.ownerColor(f.owner, players: state.players))
                            .frame(width: 16, height: 18)
                        Text(fleetOwnerName(f.owner)).font(CTCTheme.body(13)).foregroundColor(CTCTheme.ink)
                        Text("Strength \(f.strength)").font(CTCTheme.num(12)).foregroundColor(CTCTheme.inkSoft)
                        Spacer()
                        if f.owner == 0 {
                            HStack(spacing: 3) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle().fill(i < f.mp ? CTCTheme.good : CTCTheme.inkSoft.opacity(0.25))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                    }
                }
                if humanTurn, let f = humanFleet, f.mp > 0, !controller.reachable.isEmpty {
                    Text("Tap a glowing landing to sail there. Downstream costs 1 move, upstream 2.")
                        .font(CTCTheme.body(11)).foregroundColor(CTCTheme.riverDeep)
                } else if humanTurn, let f = humanFleet, f.mp == 0 {
                    Text("This fleet has used its moves for the turn.")
                        .font(CTCTheme.body(11)).foregroundColor(CTCTheme.inkSoft)
                }
            }
        }
    }

    private func fleetOwnerName(_ owner: Int) -> String {
        if owner == 0 { return "Your fleet" }
        return CTCEngine.ownerName(owner, in: state)
    }

    // MARK: actions

    @ViewBuilder private var actionSection: some View {
        VStack(spacing: 7) {
            if node.owner == 0 {
                if node.yard {
                    actionRow("Recruit ship  (+\(CTCEngine.recruitStrength) strength)",
                              cost: CTCEngine.recruitCost,
                              enabled: florins >= CTCEngine.recruitCost && !node.yardUsed && hasStackRoom) {
                        controller.recruit(at: node.id)
                    }
                    if node.yardUsed {
                        hint("This shipyard has already built a ship this turn.")
                    }
                } else {
                    actionRow("Build shipyard  (recruit ships here)",
                              cost: CTCEngine.yardCost, enabled: florins >= CTCEngine.yardCost) {
                        controller.build(.yard, at: node.id)
                    }
                }

                if node.dock < 3 {
                    actionRow("Dock \(ctcRoman(node.dock + 1))  (+1 income, +defense)",
                              cost: CTCEngine.dockUpgradeCost(node.dock),
                              enabled: florins >= CTCEngine.dockUpgradeCost(node.dock)) {
                        controller.build(.dock, at: node.id)
                    }
                }

                if state.fogEnabled && !node.tower {
                    actionRow("Watchtower  (reveals the fog)",
                              cost: CTCEngine.towerCost, enabled: florins >= CTCEngine.towerCost) {
                        controller.build(.tower, at: node.id)
                    }
                }

                let damCands = CTCEngine.damCandidates(at: node.id, for: 0, in: state)
                if !damCands.isEmpty {
                    actionRow("Build dam  (seals a reach)",
                              cost: CTCEngine.damCost,
                              enabled: florins >= CTCEngine.damCost) {
                        damPickerNode = (damPickerNode == node.id) ? nil : node.id
                    }
                    if damPickerNode == node.id {
                        ForEach(damCands) { e in
                            let far = (e.from == node.id) ? e.to : e.from
                            subRow("Wall the reach to \(state.node(far)?.name ?? "the water")") {
                                controller.build(.dam, at: node.id, damEdge: e.id)
                                damPickerNode = nil
                            }
                        }
                    }
                } else if CTCEngine.standingDams(of: 0, in: state) >= CTCEngine.maxDamsPerPlayer {
                    hint("You already hold the maximum of \(CTCEngine.maxDamsPerPlayer) dams.")
                }
            }

            if let f = humanFleet, f.mp > 0 {
                ForEach(CTCEngine.adjacentEnemyDams(for: f.id, in: state)) { e in
                    let far = (e.from == node.id) ? e.to : e.from
                    actionRow("Breach enemy dam toward \(state.node(far)?.name ?? "the water")",
                              cost: nil, enabled: true) {
                        controller.breachDam(fleetID: f.id, edgeID: e.id)
                    }
                }
            }
        }
    }

    private var hasStackRoom: Bool {
        let mine = state.fleetsAt(node.id).filter { $0.owner == 0 }
        if mine.isEmpty { return true }
        let sum = mine.reduce(0) { $0 + $1.strength }
        return sum + CTCEngine.recruitStrength <= CTCEngine.maxStackSize
    }

    private func actionRow(_ title: String, cost: Int?, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 8) {
                Text(title).font(CTCTheme.body(14))
                    .foregroundColor(enabled ? .white : .white.opacity(0.55))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                if let c = cost {
                    HStack(spacing: 3) {
                        CTCCoinIcon(size: 13)
                        Text("\(c)").font(CTCTheme.num(13)).foregroundColor(.white.opacity(enabled ? 1 : 0.55))
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(enabled ? CTCTheme.navy : CTCTheme.navy.opacity(0.35)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func subRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                CTCDamIcon().fill(Color(red: 0.45, green: 0.33, blue: 0.2)).frame(width: 16, height: 14)
                Text(title).font(CTCTheme.body(13)).foregroundColor(CTCTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(CTCTheme.goldLine.opacity(0.20))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(CTCTheme.goldLine.opacity(0.6), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(CTCTheme.body(11)).foregroundColor(CTCTheme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
