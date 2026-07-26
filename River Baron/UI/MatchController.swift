import SwiftUI

/// Owns a live match: drives the engine, queues battle reports and notices,
/// autosaves after every turn, and applies results when the match ends.
final class MatchController: ObservableObject {
    @Published var state: GameState
    @Published var selectedNodeID: Int? = nil
    @Published var reachable: [Int: RBRoute] = [:]
    @Published var reportQueue: [RBBattleReport] = []
    @Published var turnNotices: [String] = []
    @Published var battleReview: [RBBattleReport] = []   // human's own strike, shown at once
    @Published var showTurnSummary = false
    @Published var aiThinking = false
    @Published var showResult = false
    @Published var resultStars = 0

    let mode: String
    let scenarioID: Int
    let skirmish: SkirmishConfig
    private let store: RBStore
    private var finished = false

    init(match: MatchState, store: RBStore) {
        self.state = match.game
        self.mode = match.mode
        self.scenarioID = match.scenarioID
        self.skirmish = match.skirmish
        self.store = store
        // A resumed save may already contain unseen events.
        drainEvents()
        finishIfOver()
        // A save captured mid-round (app killed between End Turn and the AI's
        // move) resumes on a rival's seat — kick the AI so it never deadlocks.
        if !finished && state.winner == -9 && !currentIsHuman {
            runAI(delay: 0.5)
        }
    }

    var currentIsHuman: Bool {
        state.players.indices.contains(state.currentPlayer)
            && state.players[state.currentPlayer].isHuman
            && !state.players[state.currentPlayer].eliminated
    }

    var humanTurn: Bool {
        state.winner == -9 && !aiThinking && !state.players.isEmpty
            && state.currentPlayer == 0 && !state.players[0].eliminated
    }

    var humanPlayer: RBPlayer? {
        state.players.first
    }

    var humanIncome: Int {
        RBEngine.income(of: 0, in: state)
    }

    func ownFleet(at nodeID: Int) -> RBFleet? {
        state.fleetsAt(nodeID).first { $0.owner == 0 }
    }

    // MARK: - Selection & movement

    func tapNode(_ id: Int) {
        guard humanTurn else {
            selectedNodeID = (selectedNodeID == id) ? nil : id
            reachable = [:]
            return
        }
        store.tap()
        if let sel = selectedNodeID, sel != id,
           let fleet = ownFleet(at: sel), fleet.mp > 0, reachable[id] != nil {
            performMove(fleetID: fleet.id, to: id)
            return
        }
        if selectedNodeID == id {
            selectedNodeID = nil
            reachable = [:]
        } else {
            select(id)
        }
    }

    func deselect() {
        selectedNodeID = nil
        reachable = [:]
    }

    private func select(_ id: Int) {
        selectedNodeID = id
        reachable = [:]
        if humanTurn, let fleet = ownFleet(at: id), fleet.mp > 0 {
            reachable = RBEngine.routes(for: fleet.id, in: state)
        }
    }

    private func performMove(fleetID: Int, to dest: Int) {
        _ = RBEngine.moveFleet(fleetID, to: dest, in: &state)
        let survivor = state.fleet(fleetID)
        let fresh = drainEvents()
        if !fresh.isEmpty {
            battleReview = fresh
            let ids = Set(fresh.map { $0.id })
            reportQueue.removeAll { ids.contains($0.id) }   // avoid echo in the next turn summary
        }
        if let f = survivor, f.mp > 0 {
            select(f.node)
        } else if let f = survivor {
            selectedNodeID = f.node
            reachable = [:]
        } else {
            deselect()
        }
        autosave()
        finishIfOver()
    }

    // MARK: - Building

    func build(_ kind: RBEngine.BuildKind, at nodeID: Int, damEdge: Int = -1) {
        guard humanTurn else { return }
        if RBEngine.build(kind, at: nodeID, damEdge: damEdge, in: &state) {
            store.thud()
            drainEvents()
            refreshSelection()
            autosave()
        }
    }

    func recruit(at nodeID: Int) {
        guard humanTurn else { return }
        if RBEngine.recruit(at: nodeID, in: &state) {
            store.thud()
            drainEvents()
            refreshSelection()
            autosave()
        }
    }

    func breachDam(fleetID: Int, edgeID: Int) {
        guard humanTurn else { return }
        if RBEngine.breachDam(fleetID, edgeID: edgeID, in: &state) {
            store.thud()
            drainEvents()
            refreshSelection()
            autosave()
        }
    }

    private func refreshSelection() {
        if let sel = selectedNodeID { select(sel) }
    }

    // MARK: - Turn flow

    func endTurn() {
        guard humanTurn else { return }
        store.tap()
        deselect()
        state.notices.removeAll()
        state.pendingReports.removeAll()
        RBEngine.endTurn(&state)
        autosave()
        if state.winner != -9 {
            drainEvents()
            finishIfOver()
            return
        }
        runAI(delay: 0.7)
    }

    /// Runs the rival barons' turns off the main run-loop, then surfaces the
    /// news and hands control back to the human. Shared by End Turn and resume.
    private func runAI(delay: Double) {
        aiThinking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            RBAI.runAITurns(&self.state)
            self.aiThinking = false
            self.drainEvents()
            let hasNews = !self.reportQueue.isEmpty || !self.turnNotices.isEmpty
            if hasNews && self.state.winner == -9 && !self.showResult {
                self.showTurnSummary = true
            }
            self.autosave()
            self.finishIfOver()
        }
    }

    /// Moves engine events into UI queues; spots pirate kills for achievements.
    /// Returns the battle reports produced by this drain (for immediate popups).
    @discardableResult
    private func drainEvents() -> [RBBattleReport] {
        let fresh = state.pendingReports
        if !fresh.isEmpty {
            for r in fresh {
                let humanSankPirate = (r.attacker == 0 && r.defender == -1 && r.attackerWon)
                    || (r.attacker == -1 && r.defender == 0 && !r.attackerWon)
                if humanSankPirate { store.notePirateSunk() }
            }
            reportQueue.append(contentsOf: fresh)
            state.pendingReports.removeAll()
        }
        if !state.notices.isEmpty {
            turnNotices.append(contentsOf: state.notices)
            state.notices.removeAll()
        }
        if reportQueue.count > 12 { reportQueue.removeFirst(reportQueue.count - 12) }
        if turnNotices.count > 14 { turnNotices.removeFirst(turnNotices.count - 14) }
        return fresh
    }

    func dismissBattleReview() {
        battleReview = []
    }

    func dismissSummary() {
        showTurnSummary = false
        reportQueue.removeAll()
        turnNotices.removeAll()
    }

    // MARK: - Persistence & completion

    func autosave() {
        guard !finished else { return }
        var ms = MatchState()
        ms.mode = mode
        ms.scenarioID = scenarioID
        ms.skirmish = skirmish
        ms.game = state
        store.root.setActiveMatch(ms, mode: mode)
        store.save()
    }

    func finishIfOver() {
        let humanOut = !state.players.isEmpty && state.players[0].eliminated
        guard state.winner != -9 || humanOut else { return }
        guard !finished else { return }
        finished = true
        showTurnSummary = false
        resultStars = store.applyMatchResult(state: state, mode: mode,
                                             scenarioID: scenarioID, skirmish: skirmish)
        if state.winner == 0 { store.fanfare() } else { store.thud() }
        showResult = true
    }

    /// Resign: the match is recorded as a loss and the save is cleared.
    func resign() {
        guard !finished else { return }
        state.winner = bestRival()
        state.winKind = "resignation"
        state.log.append("P0 resigns")
        finishIfOver()
    }

    private func bestRival() -> Int {
        var best = 1
        var bestNodes = -1
        for p in state.players where p.idx != 0 && !p.eliminated {
            let n = state.nodes.filter { $0.owner == p.idx }.count
            if n > bestNodes { bestNodes = n; best = p.idx }
        }
        return best
    }
}
