import SwiftUI

/// Bottom panel for the tapped node: its details, the fleets standing there,
/// and the legal build / recruit / dam / breach actions during the human turn.
struct MatchActionPanel: View {
    @ObservedObject var controller: MatchController
    let node: RBNode
    @Binding var damPickerNode: Int?
    /// Capped by the parent from the live screen height so the panel can never
    /// grow up into the HUD on a short screen (landscape, or 375×667).
    var maxPanelHeight: CGFloat = 250
    let onClose: () -> Void

    private var state: GameState { controller.state }
    private var florins: Int { state.players.indices.contains(0) ? state.players[0].florins : 0 }
    private var humanTurn: Bool { controller.humanTurn }
    private var humanFleet: RBFleet? { state.fleetsAt(node.id).first { $0.owner == 0 } }

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
            RoundedRectangle(cornerRadius: 16).fill(RBTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(RBTheme.cardBorder, lineWidth: 1.3))
                .shadow(color: RBTheme.ink.opacity(0.12), radius: 8, y: -2)
        )
    }

    // MARK: header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name).font(RBTheme.display(19)).foregroundColor(RBTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 6) {
                    Text(rbKindName(node.kind)).font(RBTheme.body(12)).foregroundColor(RBTheme.inkSoft)
                    Circle().fill(ownerColor).frame(width: 7, height: 7)
                    Text(ownerLabel).font(RBTheme.body(12)).foregroundColor(RBTheme.inkSoft)
                }
            }
            Spacer()
            Button { RBStore.shared.tap(); onClose() } label: {
                RBCross().stroke(RBTheme.inkSoft, style: StrokeStyle(lineWidth: 2, lineCap: .round))
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
        return RBTheme.ownerColor(node.owner, players: state.players)
    }

    // MARK: stat row

    private var statRow: some View {
        HStack(spacing: 8) {
            statChip(title: "Income", value: "\(RBEngine.baseIncome(node.kind) + RBEngine.dockIncome(node.dock))", coin: true)
            statChip(title: "Defense", value: "+\(defenseBonus)", coin: false)
            if node.dock > 0 { badge("Dock \(rbRoman(node.dock))") }
            if node.yard { badge("Shipyard") }
            if node.tower { badge("Tower") }
            Spacer(minLength: 0)
        }
    }

    private var defenseBonus: Int {
        (node.kind == .harbor ? 1 : 0) + RBEngine.dockDefense(node.dock)
    }

    private func statChip(title: String, value: String, coin: Bool) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 3) {
                if coin { RBCoinIcon(size: 12) }
                Text(value).font(RBTheme.num(14)).foregroundColor(RBTheme.ink)
            }
            Text(title).font(RBTheme.body(10)).foregroundColor(RBTheme.inkSoft)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(RBTheme.parchment))
    }

    private func badge(_ text: String) -> some View {
        Text(text).font(RBTheme.body(11)).foregroundColor(RBTheme.navy)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(RBTheme.navy.opacity(0.10)))
    }

    // MARK: fleets

    @ViewBuilder private var fleetSection: some View {
        let fleets = state.fleetsAt(node.id)
        if !fleets.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(fleets) { f in
                    HStack(spacing: 8) {
                        RBSailIcon().fill(RBTheme.ownerColor(f.owner, players: state.players))
                            .frame(width: 16, height: 18)
                        Text(fleetOwnerName(f.owner)).font(RBTheme.body(13)).foregroundColor(RBTheme.ink)
                        Text("Strength \(f.strength)").font(RBTheme.num(12)).foregroundColor(RBTheme.inkSoft)
                        Spacer()
                        if f.owner == 0 {
                            HStack(spacing: 3) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle().fill(i < f.mp ? RBTheme.good : RBTheme.inkSoft.opacity(0.25))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                    }
                }
                if humanTurn, let f = humanFleet, f.mp > 0, !controller.reachable.isEmpty {
                    Text("Tap a glowing landing to sail there. Downstream costs 1 move, upstream 2.")
                        .font(RBTheme.body(11)).foregroundColor(RBTheme.riverDeep)
                } else if humanTurn, let f = humanFleet, f.mp == 0 {
                    Text("This fleet has used its moves for the turn.")
                        .font(RBTheme.body(11)).foregroundColor(RBTheme.inkSoft)
                }
            }
        }
    }

    private func fleetOwnerName(_ owner: Int) -> String {
        if owner == 0 { return "Your fleet" }
        return RBEngine.ownerName(owner, in: state)
    }

    // MARK: actions

    @ViewBuilder private var actionSection: some View {
        VStack(spacing: 7) {
            if node.owner == 0 {
                if node.yard {
                    actionRow("Recruit ship  (+\(RBEngine.recruitStrength) strength)",
                              cost: RBEngine.recruitCost,
                              enabled: florins >= RBEngine.recruitCost && !node.yardUsed && hasStackRoom) {
                        controller.recruit(at: node.id)
                    }
                    if node.yardUsed {
                        hint("This shipyard has already built a ship this turn.")
                    }
                } else {
                    actionRow("Build shipyard  (recruit ships here)",
                              cost: RBEngine.yardCost, enabled: florins >= RBEngine.yardCost) {
                        controller.build(.yard, at: node.id)
                    }
                }

                if node.dock < 3 {
                    actionRow("Dock \(rbRoman(node.dock + 1))  (+1 income, +defense)",
                              cost: RBEngine.dockUpgradeCost(node.dock),
                              enabled: florins >= RBEngine.dockUpgradeCost(node.dock)) {
                        controller.build(.dock, at: node.id)
                    }
                }

                if state.fogEnabled && !node.tower {
                    actionRow("Watchtower  (reveals the fog)",
                              cost: RBEngine.towerCost, enabled: florins >= RBEngine.towerCost) {
                        controller.build(.tower, at: node.id)
                    }
                }

                let damCands = RBEngine.damCandidates(at: node.id, for: 0, in: state)
                if !damCands.isEmpty {
                    actionRow("Build dam  (seals a reach)",
                              cost: RBEngine.damCost,
                              enabled: florins >= RBEngine.damCost) {
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
                } else if RBEngine.standingDams(of: 0, in: state) >= RBEngine.maxDamsPerPlayer {
                    hint("You already hold the maximum of \(RBEngine.maxDamsPerPlayer) dams.")
                }
            }

            if let f = humanFleet, f.mp > 0 {
                ForEach(RBEngine.adjacentEnemyDams(for: f.id, in: state)) { e in
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
        return sum + RBEngine.recruitStrength <= RBEngine.maxStackSize
    }

    private func actionRow(_ title: String, cost: Int?, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 8) {
                Text(title).font(RBTheme.body(14))
                    .foregroundColor(enabled ? .white : .white.opacity(0.55))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                if let c = cost {
                    HStack(spacing: 3) {
                        RBCoinIcon(size: 13)
                        Text("\(c)").font(RBTheme.num(13)).foregroundColor(.white.opacity(enabled ? 1 : 0.55))
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(enabled ? RBTheme.navy : RBTheme.navy.opacity(0.35)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func subRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RBDamIcon().fill(Color(red: 0.45, green: 0.33, blue: 0.2)).frame(width: 16, height: 14)
                Text(title).font(RBTheme.body(13)).foregroundColor(RBTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(RBTheme.goldLine.opacity(0.20))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(RBTheme.goldLine.opacity(0.6), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(RBTheme.body(11)).foregroundColor(RBTheme.inkSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
