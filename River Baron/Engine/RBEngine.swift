import Foundation

/// Reachability info for one destination node.
struct RBRoute: Equatable {
    var cost: Int          // MP spent
    var tolls: Int         // florins in toll fees along the path
    var path: [Int]        // node ids from start (inclusive) to destination (inclusive)
}

/// All rules of the river. Pure functions over GameState — no UI imports.
enum RBEngine {

    // MARK: - Tunables (kept simple and visible; mirrored in the Codex)

    static let recruitCost = 8
    static let recruitStrength = 3
    static let dockCosts = [6, 10, 14]      // to reach level 1 / 2 / 3
    static let yardCost = 12
    static let towerCost = 5
    static let damCost = 10
    static let maxDamsPerPlayer = 2
    static let maxStackSize = 12
    static let fleetMP = 3
    static let tollFee = 2
    static let mouthHoldNeeded = 3
    static let pirateStealAmount = 5
    static let garrisonOwner = -2   // static neutral defenders (the Harbor Garrison)

    static func ownerName(_ owner: Int, in s: GameState) -> String {
        if owner == -1 { return "Pirates" }
        if owner == garrisonOwner { return "Harbor Garrison" }
        guard owner >= 0 && owner < s.players.count else { return "Neutral" }
        return s.players[owner].name
    }

    static func baseIncome(_ kind: RBNodeKind) -> Int {
        switch kind {
        case .harbor: return 3
        case .island: return 2
        case .confluence: return 4
        case .mouth: return 6
        }
    }

    static func dockIncome(_ level: Int) -> Int { max(0, min(3, level)) }          // +1/+2/+3
    static func dockDefense(_ level: Int) -> Int { max(0, min(2, level - 1)) }     // +0/+1/+2

    static func income(of player: Int, in s: GameState) -> Int {
        var total = 0
        for n in s.nodes where n.owner == player {
            total += baseIncome(n.kind) + dockIncome(n.dock)
        }
        return total
    }

    static func floodActive(_ s: GameState) -> Bool {
        s.floodEvery > 0 && s.turn % s.floodEvery == 0
    }

    static func upCost(_ s: GameState) -> Int { floodActive(s) ? 1 : 2 }

    // MARK: - Turn cycle

    /// Call once after building a fresh state: grants turn-1 income to player 0
    /// and seeds fog discovery.
    static func setupMatch(_ s: inout GameState) {
        s.normalizeTallies()
        updateDiscovery(&s)
        beginTurn(&s)
    }

    /// Income + MP refresh + shipyard reset for the current player.
    static func beginTurn(_ s: inout GameState) {
        let p = s.currentPlayer
        guard p >= 0 && p < s.players.count else { return }
        if s.players[p].eliminated { return }
        let inc = income(of: p, in: s)
        s.players[p].florins += inc
        trackFlorins(&s, p)
        for i in s.fleets.indices where s.fleets[i].owner == p {
            s.fleets[i].mp = fleetMP
        }
        for i in s.nodes.indices where s.nodes[i].owner == p {
            s.nodes[i].yardUsed = false
        }
        if floodActive(s) && p == firstAlive(s) {
            s.notices.append("Flood season! The current is gentle — upstream travel costs 1 MP this turn.")
            s.log.append("T\(s.turn) flood")
        }
        s.log.append("T\(s.turn) P\(p) income +\(inc) -> \(s.players[p].florins)")
    }

    static func firstAlive(_ s: GameState) -> Int {
        for p in s.players where !p.eliminated { return p.idx }
        return 0
    }

    /// Ends the current player's turn: mouth counter, eliminations, victory
    /// checks, pirate phase on round wrap, then begins the next player's turn.
    static func endTurn(_ s: inout GameState) {
        guard s.winner == -9 else { return }
        let p = s.currentPlayer
        guard p >= 0 && p < s.players.count else { return }

        // Mouth hold counter — counted at the end of the holder's own turn.
        if let mouth = s.node(s.mouthID), mouth.owner == p, !s.players[p].eliminated {
            s.players[p].mouthTurns += 1
            let held = s.players[p].mouthTurns
            s.log.append("T\(s.turn) P\(p) holds Mouth (\(held)/\(mouthHoldNeeded))")
            if held < mouthHoldNeeded {
                s.notices.append("\(s.players[p].name) holds the Mouth (\(held)/\(mouthHoldNeeded) turns).")
            }
            if held >= mouthHoldNeeded {
                declareWinner(&s, p, kind: "mouth")
                return
            }
        } else {
            s.players[p].mouthTurns = 0
        }

        checkEliminations(&s)
        if checkLastStanding(&s) { return }

        // Advance to the next living player; pirates + new round on wrap.
        var next = p
        var hops = 0
        repeat {
            next += 1
            hops += 1
            if next >= s.players.count {
                next = 0
                piratePhase(&s)
                checkEliminations(&s)
                if checkLastStanding(&s) { return }
                s.turn += 1
                if s.turn > s.turnCap {
                    resolveTurnCap(&s)
                    return
                }
            }
        } while s.players[next].eliminated && hops <= s.players.count * 2

        s.currentPlayer = next
        beginTurn(&s)
        updateDiscovery(&s)
    }

    static func declareWinner(_ s: inout GameState, _ p: Int, kind: String) {
        s.winner = p
        s.winKind = kind
        let name = (p >= 0 && p < s.players.count) ? s.players[p].name : "Nobody"
        s.log.append("WINNER P\(p) by \(kind)")
        s.notices.append("\(name) rules the river (\(kind)).")
    }

    /// Most nodes at the turn cap; ties: florins, then seat order.
    static func resolveTurnCap(_ s: inout GameState) {
        var best = -1
        var bestKey: (Int, Int, Int) = (-1, -1, 0)
        for pl in s.players where !pl.eliminated {
            let count = s.nodes.filter { $0.owner == pl.idx }.count
            let key = (count, pl.florins, -pl.idx)
            if best == -1 || key > bestKey {
                best = pl.idx
                bestKey = key
            }
        }
        declareWinner(&s, best, kind: "nodes")
    }

    /// A baron with no fleets and no shipyard can never fight again — out.
    static func checkEliminations(_ s: inout GameState) {
        for i in s.players.indices where !s.players[i].eliminated {
            let p = s.players[i].idx
            let hasFleet = s.fleets.contains { $0.owner == p }
            let hasYard = s.nodes.contains { $0.owner == p && $0.yard }
            if !hasFleet && !hasYard {
                s.players[i].eliminated = true
                s.players[i].mouthTurns = 0
                for j in s.nodes.indices where s.nodes[j].owner == p {
                    s.nodes[j].owner = -1
                }
                for j in s.edges.indices where s.edges[j].damOwner == p {
                    s.edges[j].damOwner = -1
                }
                s.log.append("T\(s.turn) P\(p) eliminated")
                s.notices.append("\(s.players[i].name) has been driven from the river!")
            }
        }
    }

    @discardableResult
    static func checkLastStanding(_ s: inout GameState) -> Bool {
        guard s.winner == -9 else { return true }
        let alive = s.players.filter { !$0.eliminated }
        if alive.count == 1, let last = alive.first {
            declareWinner(&s, last.idx, kind: "elimination")
            return true
        }
        if alive.isEmpty {
            declareWinner(&s, -1, kind: "elimination")
            return true
        }
        return false
    }

    // MARK: - Building

    enum BuildKind: String {
        case dock, yard, tower, dam
    }

    static func dockUpgradeCost(_ current: Int) -> Int {
        guard current >= 0 && current < dockCosts.count else { return Int.max }
        return dockCosts[current]
    }

    static func standingDams(of player: Int, in s: GameState) -> Int {
        s.edges.filter { $0.damOwner == player }.count
    }

    /// Candidate dam edges for a player at a node: adjacent reaches without a dam.
    static func damCandidates(at nodeID: Int, for player: Int, in s: GameState) -> [RBEdge] {
        guard standingDams(of: player, in: s) < maxDamsPerPlayer else { return [] }
        return s.edges
            .filter { ($0.from == nodeID || $0.to == nodeID) && $0.damOwner == -1 }
            .sorted { $0.id < $1.id }
    }

    @discardableResult
    static func build(_ kind: BuildKind, at nodeID: Int, damEdge: Int = -1, in s: inout GameState) -> Bool {
        guard s.winner == -9 else { return false }
        let p = s.currentPlayer
        guard p >= 0 && p < s.players.count else { return false }
        guard let ni = s.nodeIndex(nodeID), s.nodes[ni].owner == p else { return false }
        switch kind {
        case .dock:
            let cost = dockUpgradeCost(s.nodes[ni].dock)
            guard s.nodes[ni].dock < 3, s.players[p].florins >= cost else { return false }
            s.players[p].florins -= cost
            s.nodes[ni].dock += 1
            s.log.append("T\(s.turn) P\(p) dock L\(s.nodes[ni].dock) at \(nodeID)")
        case .yard:
            guard !s.nodes[ni].yard, s.players[p].florins >= yardCost else { return false }
            s.players[p].florins -= yardCost
            s.nodes[ni].yard = true
            s.nodes[ni].yardUsed = true   // opens next turn
            s.log.append("T\(s.turn) P\(p) shipyard at \(nodeID)")
        case .tower:
            guard !s.nodes[ni].tower, s.players[p].florins >= towerCost else { return false }
            s.players[p].florins -= towerCost
            s.nodes[ni].tower = true
            s.log.append("T\(s.turn) P\(p) watchtower at \(nodeID)")
        case .dam:
            guard s.players[p].florins >= damCost else { return false }
            guard standingDams(of: p, in: s) < maxDamsPerPlayer else { return false }
            guard let ei = s.edgeIndex(damEdge) else { return false }
            let e = s.edges[ei]
            guard e.damOwner == -1, (e.from == nodeID || e.to == nodeID) else { return false }
            s.players[p].florins -= damCost
            s.edges[ei].damOwner = p
            if p >= 0 && p < s.damsBuiltCount.count { s.damsBuiltCount[p] += 1 }
            s.log.append("T\(s.turn) P\(p) dam on edge \(damEdge)")
        }
        updateDiscovery(&s)
        return true
    }

    @discardableResult
    static func recruit(at nodeID: Int, in s: inout GameState) -> Bool {
        guard s.winner == -9 else { return false }
        let p = s.currentPlayer
        guard p >= 0 && p < s.players.count else { return false }
        guard let ni = s.nodeIndex(nodeID) else { return false }
        guard s.nodes[ni].owner == p, s.nodes[ni].yard, !s.nodes[ni].yardUsed else { return false }
        guard s.players[p].florins >= recruitCost else { return false }
        // A new keel joins an existing friendly stack when possible.
        let mine = s.fleetsAt(nodeID).filter { $0.owner == p }
        if let host = mine.first, host.strength + recruitStrength <= maxStackSize {
            if let fi = s.fleetIndex(host.id) {
                s.fleets[fi].strength += recruitStrength
                trackStack(&s, p, s.fleets[fi].strength)
            }
        } else if mine.isEmpty {
            let f = RBFleet(id: s.nextFleetID, owner: p, node: nodeID, strength: recruitStrength, mp: 0)
            s.nextFleetID += 1
            s.fleets.append(f)
            trackStack(&s, p, recruitStrength)
        } else {
            return false  // stack full
        }
        s.players[p].florins -= recruitCost
        s.nodes[ni].yardUsed = true
        s.log.append("T\(s.turn) P\(p) recruit at \(nodeID)")
        updateDiscovery(&s)
        return true
    }

    // MARK: - Movement

    /// True if `player` may traverse this reach (dams block everyone else).
    static func canTraverse(_ e: RBEdge, player: Int) -> Bool {
        e.damOwner == -1 || e.damOwner == player
    }

    /// Dijkstra over the river graph for one fleet. Enemy-occupied nodes are
    /// terminal (you can attack in, never sail through). Own stacks can be
    /// passed through; ending on one requires the merged stack to fit.
    static func routes(for fleetID: Int, in s: GameState) -> [Int: RBRoute] {
        guard let f = s.fleet(fleetID), f.mp > 0 else { return [:] }
        let p = f.owner
        let up = upCost(s)
        var dist: [Int: (cost: Int, tolls: Int, path: [Int])] = [f.node: (0, 0, [f.node])]
        var frontier: [(cost: Int, tolls: Int, node: Int)] = [(0, 0, f.node)]
        var results: [Int: RBRoute] = [:]

        while !frontier.isEmpty {
            frontier.sort { ($0.cost, $0.tolls, $0.node) < ($1.cost, $1.tolls, $1.node) }
            let cur = frontier.removeFirst()
            guard let entry = dist[cur.node], entry.cost == cur.cost else { continue }

            // Expand — unless standing on a hostile node (only the start can be).
            let hostileHere = s.fleetsAt(cur.node).contains { $0.owner != p } && cur.node != f.node
            if hostileHere { continue }

            for e in s.edges.sorted(by: { $0.id < $1.id }) {
                var nextNode = -1
                var stepCost = 0
                if e.from == cur.node { nextNode = e.to; stepCost = 1 }
                else if e.to == cur.node { nextNode = e.from; stepCost = up }
                else { continue }
                guard canTraverse(e, player: p) else { continue }
                let newCost = cur.cost + stepCost
                guard newCost <= f.mp else { continue }
                let newTolls = cur.tolls + (e.toll ? tollFee : 0)
                guard newTolls <= playerFlorins(p, s) else { continue }
                if let old = dist[nextNode], (old.cost, old.tolls) <= (newCost, newTolls) { continue }
                let newPath = entry.path + [nextNode]
                dist[nextNode] = (newCost, newTolls, newPath)
                frontier.append((newCost, newTolls, nextNode))
            }
        }

        for (nodeID, entry) in dist where nodeID != f.node {
            // Ending on an over-full friendly stack is not allowed.
            let friendly = s.fleetsAt(nodeID).filter { $0.owner == p }
            let friendlyStr = friendly.reduce(0) { $0 + $1.strength }
            if friendlyStr > 0 && friendlyStr + f.strength > maxStackSize { continue }
            results[nodeID] = RBRoute(cost: entry.cost, tolls: entry.tolls, path: entry.path)
        }
        return results
    }

    static func playerFlorins(_ p: Int, _ s: GameState) -> Int {
        guard p >= 0 && p < s.players.count else { return 0 }
        return s.players[p].florins
    }

    /// Executes a legal move (validated against `routes`). Handles tolls,
    /// pass-through captures, merges and battle at the destination.
    @discardableResult
    static func moveFleet(_ fleetID: Int, to dest: Int, in s: inout GameState) -> Bool {
        guard s.winner == -9 else { return false }
        guard let f = s.fleet(fleetID) else { return false }
        let all = routes(for: fleetID, in: s)
        guard let route = all[dest] else { return false }
        let p = f.owner

        var battled = false
        for step in 1..<route.path.count {
            let a = route.path[step - 1]
            let b = route.path[step]
            guard let fi = s.fleetIndex(fleetID) else { return false }
            guard let e = s.edgeBetween(a, b) else { return false }
            let stepCost = (e.from == a) ? 1 : upCost(s)
            if e.toll {
                if playerFlorins(p, s) < tollFee { break }
                if p >= 0 && p < s.players.count { s.players[p].florins -= tollFee }
                s.log.append("T\(s.turn) P\(p) toll -\(tollFee) edge \(e.id)")
            }
            s.fleets[fi].mp = max(0, s.fleets[fi].mp - stepCost)
            s.fleets[fi].node = b

            let hostiles = s.fleetsAt(b).filter { $0.owner != p }
            if !hostiles.isEmpty {
                let downstream = (e.from == a)
                resolveBattle(attackerID: fleetID, at: b, downstream: downstream, upstream: !downstream, in: &s)
                battled = true
                break
            } else {
                captureIfNeeded(b, by: p, in: &s)
            }
        }

        if battled, let fi = s.fleetIndex(fleetID) {
            s.fleets[fi].mp = 0   // striking ends the fleet's turn
        }

        // Merge with friendly stack at the final position.
        if let fi = s.fleetIndex(fleetID) {
            let here = s.fleets[fi].node
            let friends = s.fleetsAt(here).filter { $0.owner == p && $0.id != fleetID }
            if !friends.isEmpty {
                var total = s.fleets[fi].strength
                var minMP = s.fleets[fi].mp
                for fr in friends {
                    total += fr.strength
                    minMP = min(minMP, fr.mp)
                }
                if total <= maxStackSize {
                    s.fleets.removeAll { fl in friends.contains { $0.id == fl.id } }
                    if let fi2 = s.fleetIndex(fleetID) {
                        s.fleets[fi2].strength = total
                        s.fleets[fi2].mp = minMP
                        trackStack(&s, p, total)
                    }
                    s.log.append("T\(s.turn) P\(p) merge at \(here) -> \(total)")
                }
            }
        }

        checkEliminations(&s)
        checkLastStanding(&s)
        updateDiscovery(&s)
        return true
    }

    static func captureIfNeeded(_ nodeID: Int, by p: Int, in s: inout GameState) {
        guard let ni = s.nodeIndex(nodeID) else { return }
        let prev = s.nodes[ni].owner
        guard prev != p else { return }
        s.nodes[ni].owner = p
        if prev >= 0 {
            if s.nodes[ni].yard, prev < s.lostShipyard.count { s.lostShipyard[prev] = true }
            if prev < s.players.count { s.players[prev].mouthTurns = (nodeID == s.mouthID) ? 0 : s.players[prev].mouthTurns }
        }
        let nm = s.nodes[ni].name
        if p >= 0 && p < s.players.count {
            s.notices.append("\(s.players[p].name) claims \(nm).")
        }
        s.log.append("T\(s.turn) P\(p) capture \(nodeID)")
        checkConfluenceCrown(&s)
    }

    static func checkConfluenceCrown(_ s: inout GameState) {
        let conf = s.nodes.filter { $0.kind == .confluence }
        guard conf.count >= 2 else { return }
        if conf.allSatisfy({ $0.owner == 0 }) {
            s.heldAllConfluences = true
        }
    }

    // MARK: - Combat

    /// Deterministic core + bounded seeded roll. The full math is captured in
    /// a battle report for the popup.
    static func resolveBattle(attackerID: Int, at nodeID: Int, downstream: Bool, upstream: Bool, in s: inout GameState) {
        guard let ai = s.fleetIndex(attackerID), let ni = s.nodeIndex(nodeID) else { return }
        let attacker = s.fleets[ai]
        let p = attacker.owner
        let defenders = s.fleetsAt(nodeID).filter { $0.owner != p }
        guard let firstDef = defenders.first else { return }
        let dOwner = firstDef.owner
        let defStr = defenders.reduce(0) { $0 + $1.strength }
        let node = s.nodes[ni]

        let flowMod = downstream ? 2 : (upstream ? -1 : 0)
        let harborMod = (node.kind == .harbor && node.owner == dOwner) ? 1 : 0
        let dockMod = (node.owner == dOwner) ? dockDefense(node.dock) : 0
        let roll = s.rng.int(in: -1...1)

        let atkTotal = attacker.strength + flowMod + roll
        let defTotal = defStr + harborMod + dockMod
        let attackerWon = atkTotal > defTotal   // ties go to the defender

        var report = RBBattleReport()
        report.id = s.nextReportID
        s.nextReportID += 1
        report.turn = s.turn
        report.nodeID = nodeID
        report.nodeName = node.name
        report.attacker = p
        report.defender = dOwner
        report.atkStr = attacker.strength
        report.atkFlow = flowMod
        report.atkRoll = roll
        report.atkTotal = atkTotal
        report.defStr = defStr
        report.defHarbor = harborMod
        report.defDock = dockMod
        report.defTotal = defTotal
        report.attackerWon = attackerWon

        s.battlesCount += 1

        if attackerWon {
            let loss = (defStr + 1) / 2   // ceil(loser/2)
            report.winnerLoss = min(loss, attacker.strength - 1)
            // Sink every defending fleet.
            let sunkCount = defenders.count
            s.fleets.removeAll { fl in defenders.contains { $0.id == fl.id } }
            if p >= 0 && p < s.sunk.count { s.sunk[p] += sunkCount }
            if dOwner >= 0 && dOwner < s.lostFleet.count { s.lostFleet[dOwner] = true }
            if let ai2 = s.fleetIndex(attackerID) {
                s.fleets[ai2].strength = max(1, attacker.strength - loss)
            }
            if p == -1 {
                // Pirate raid: loot and torch, the landing reverts to neutral.
                if node.owner >= 0 && node.owner < s.players.count {
                    let stolen = min(pirateStealAmount, s.players[node.owner].florins)
                    s.players[node.owner].florins -= stolen
                    s.notices.append("Pirates sack \(node.name) and carry off \(stolen) florins!")
                    if s.nodes[ni].yard, node.owner < s.lostShipyard.count { s.lostShipyard[node.owner] = true }
                }
                s.nodes[ni].owner = -1
            } else {
                captureIfNeeded(nodeID, by: p, in: &s)
            }
        } else {
            let loss = (attacker.strength + 1) / 2
            report.winnerLoss = min(loss, max(0, defStr - 1))
            s.fleets.removeAll { $0.id == attackerID }
            if dOwner >= 0 && dOwner < s.sunk.count { s.sunk[dOwner] += 1 }
            if p >= 0 && p < s.lostFleet.count { s.lostFleet[p] = true }
            // Spread the winner's loss across defenders, never below 1 total.
            var remaining = report.winnerLoss
            for d in defenders {
                guard remaining > 0 else { break }
                guard let di = s.fleetIndex(d.id) else { continue }
                let take = min(remaining, s.fleets[di].strength - 1)
                s.fleets[di].strength -= take
                remaining -= take
            }
        }

        s.pendingReports.append(report)
        let aName = ownerName(p, in: s)
        let dName = ownerName(dOwner, in: s)
        s.notices.append("Battle at \(node.name): \(aName) \(atkTotal) vs \(dName) \(defTotal) — \(attackerWon ? aName : dName) prevails.")
        s.log.append("T\(s.turn) battle at \(nodeID) A\(p) \(atkTotal) vs D\(dOwner) \(defTotal) \(attackerWon ? "A" : "D") roll \(roll)")
    }

    // MARK: - Dams

    /// Fleet spends its whole turn besieging an adjacent enemy dam; it breaks.
    @discardableResult
    static func breachDam(_ fleetID: Int, edgeID: Int, in s: inout GameState) -> Bool {
        guard s.winner == -9 else { return false }
        guard let fi = s.fleetIndex(fleetID) else { return false }
        let f = s.fleets[fi]
        guard f.mp > 0 else { return false }
        guard let ei = s.edgeIndex(edgeID) else { return false }
        let e = s.edges[ei]
        guard e.damOwner != -1, e.damOwner != f.owner else { return false }
        guard e.from == f.node || e.to == f.node else { return false }
        s.edges[ei].damOwner = -1
        s.fleets[fi].mp = 0
        if f.owner >= 0 && f.owner < s.breachedDam.count { s.breachedDam[f.owner] = true }
        s.notices.append("A dam on the river has been breached!")
        s.log.append("T\(s.turn) P\(f.owner) breach dam edge \(edgeID)")
        updateDiscovery(&s)
        return true
    }

    /// Enemy dams adjacent to this fleet's node (breach candidates).
    static func adjacentEnemyDams(for fleetID: Int, in s: GameState) -> [RBEdge] {
        guard let f = s.fleet(fleetID) else { return [] }
        return s.edges
            .filter { ($0.from == f.node || $0.to == f.node) && $0.damOwner != -1 && $0.damOwner != f.owner }
            .sorted { $0.id < $1.id }
    }

    // MARK: - Pirates (neutral raiders, owner == -1)

    /// After the last player each round: every pirate fleet drifts toward the
    /// richest baron's nearest landing and raids what it reaches.
    static func piratePhase(_ s: inout GameState) {
        guard s.piratesOn, s.winner == -9 else { return }
        let pirates = s.fleets.filter { $0.owner == -1 }.sorted { $0.id < $1.id }
        guard !pirates.isEmpty else { return }

        // Richest living baron is the target.
        var richest = -1
        var richestKey = (-1, 0)
        for pl in s.players where !pl.eliminated {
            let key = (pl.florins, -pl.idx)
            if richest == -1 || key > richestKey { richest = pl.idx; richestKey = key }
        }
        guard richest >= 0 else { return }
        let targets = s.nodes.filter { $0.owner == richest }.map { $0.id }.sorted()
        guard !targets.isEmpty else { return }

        for pf in pirates {
            guard s.winner == -9 else { return }
            guard let fi = s.fleetIndex(pf.id) else { continue }
            s.fleets[fi].mp = 2   // pirates get 2 MP
            // Nearest target by MP distance (pirates ignore dams — shallow hulls).
            let dist = distanceField(in: s, ignoreDams: true)
            var bestTarget = -1
            var bestD = Int.max
            for t in targets {
                let d = dist[key(pf.node, t)] ?? Int.max
                if d < bestD { bestD = d; bestTarget = t }
            }
            guard bestTarget >= 0, bestD < Int.max else { continue }
            // Step greedily toward the target.
            var guardCount = 0
            while guardCount < 4 {
                guardCount += 1
                guard let fi2 = s.fleetIndex(pf.id), s.fleets[fi2].mp > 0 else { break }
                let here = s.fleets[fi2].node
                if here == bestTarget { break }
                var stepped = false
                for e in s.edges.sorted(by: { $0.id < $1.id }) {
                    var nxt = -1
                    var cost = 0
                    if e.from == here { nxt = e.to; cost = 1 }
                    else if e.to == here { nxt = e.from; cost = upCost(s) }
                    else { continue }
                    let dHere = dist[key(here, bestTarget)] ?? Int.max
                    let dNext = dist[key(nxt, bestTarget)] ?? Int.max
                    guard dNext < dHere, cost <= s.fleets[fi2].mp else { continue }
                    // Never stack pirates on pirates from different fleets mid-move.
                    let friendly = s.fleetsAt(nxt).filter { $0.owner == -1 && $0.id != pf.id }
                    if !friendly.isEmpty { continue }
                    s.fleets[fi2].mp -= cost
                    let hostiles = s.fleetsAt(nxt).filter { $0.owner != -1 }
                    if !hostiles.isEmpty {
                        s.fleets[fi2].node = nxt
                        let downstream = (e.from == here)
                        resolveBattle(attackerID: pf.id, at: nxt, downstream: downstream, upstream: !downstream, in: &s)
                        stepped = true
                        break
                    }
                    s.fleets[fi2].node = nxt
                    // Raid an unguarded enemy landing.
                    if let ni = s.nodeIndex(nxt), s.nodes[ni].owner >= 0 {
                        let owner = s.nodes[ni].owner
                        let stolen = min(pirateStealAmount, s.players[owner].florins)
                        s.players[owner].florins -= stolen
                        if s.nodes[ni].yard, owner < s.lostShipyard.count { s.lostShipyard[owner] = true }
                        s.nodes[ni].owner = -1
                        s.notices.append("Pirates sack \(s.nodes[ni].name) and carry off \(stolen) florins!")
                        s.log.append("T\(s.turn) pirates raid \(nxt) steal \(stolen)")
                    }
                    stepped = true
                    break
                }
                if !stepped { break }
                if s.fleetIndex(pf.id) == nil { break }  // pirate sunk in battle
                if let fi3 = s.fleetIndex(pf.id), s.fleets[fi3].mp == 0 { break }
            }
        }
        updateDiscovery(&s)
    }

    // MARK: - Distances

    static func key(_ a: Int, _ b: Int) -> Int { a * 10_000 + b }

    /// All-pairs shortest MP distances (small graphs; BFS-style relaxation).
    /// `ignoreDams` lets pirates slip past everything.
    static func distanceField(in s: GameState, ignoreDams: Bool, player: Int = -99) -> [Int: Int] {
        var dist: [Int: Int] = [:]
        let up = upCost(s)
        let ids = s.nodes.map { $0.id }.sorted()
        for src in ids {
            dist[key(src, src)] = 0
            var frontier = [src]
            var seenCost: [Int: Int] = [src: 0]
            while !frontier.isEmpty {
                frontier.sort { (seenCost[$0] ?? 0, $0) < (seenCost[$1] ?? 0, $1) }
                let cur = frontier.removeFirst()
                let curCost = seenCost[cur] ?? 0
                for e in s.edges {
                    if !ignoreDams && e.damOwner != -1 && e.damOwner != player { continue }
                    var nxt = -1
                    var cost = 0
                    if e.from == cur { nxt = e.to; cost = 1 }
                    else if e.to == cur { nxt = e.from; cost = up }
                    else { continue }
                    let nc = curCost + cost
                    if let old = seenCost[nxt], old <= nc { continue }
                    seenCost[nxt] = nc
                    frontier.append(nxt)
                }
            }
            for (n, c) in seenCost { dist[key(src, n)] = c }
        }
        return dist
    }

    /// MP distance from every node to one target for a specific player
    /// (dam-aware). Deterministic Dijkstra.
    static func distancesTo(_ target: Int, for player: Int, in s: GameState) -> [Int: Int] {
        var out: [Int: Int] = [target: 0]
        let up = upCost(s)
        var frontier = [target]
        while !frontier.isEmpty {
            frontier.sort { (out[$0] ?? 0, $0) < (out[$1] ?? 0, $1) }
            let cur = frontier.removeFirst()
            let curCost = out[cur] ?? 0
            for e in s.edges {
                if e.damOwner != -1 && e.damOwner != player { continue }
                // Walking the field backwards: cost of stepping cur -> neighbor
                // must mirror neighbor -> cur travel cost.
                var nxt = -1
                var cost = 0
                if e.from == cur { nxt = e.to; cost = up }      // neighbor is downstream; travel up
                else if e.to == cur { nxt = e.from; cost = 1 }  // neighbor is upstream; travel down
                else { continue }
                let nc = curCost + cost
                if let old = out[nxt], old <= nc { continue }
                out[nxt] = nc
                frontier.append(nxt)
            }
        }
        return out
    }

    // MARK: - Fog of war

    /// Union-in newly visible nodes for the human seat (player 0).
    /// Visible: own nodes + fleet positions + their neighbors; watchtowers on
    /// owned nodes see two reaches out.
    static func updateDiscovery(_ s: inout GameState) {
        guard s.fogEnabled else { return }
        var visible = Set<Int>()
        var towers = Set<Int>()
        for n in s.nodes where n.owner == 0 {
            visible.insert(n.id)
            if n.tower { towers.insert(n.id) }
        }
        for f in s.fleets where f.owner == 0 { visible.insert(f.node) }
        var oneHop = Set<Int>()
        for e in s.edges {
            if visible.contains(e.from) { oneHop.insert(e.to) }
            if visible.contains(e.to) { oneHop.insert(e.from) }
        }
        var twoHop = Set<Int>()
        var towerHop = Set<Int>()
        for e in s.edges {
            if towers.contains(e.from) { towerHop.insert(e.to) }
            if towers.contains(e.to) { towerHop.insert(e.from) }
        }
        for e in s.edges {
            if towerHop.contains(e.from) { twoHop.insert(e.to) }
            if towerHop.contains(e.to) { twoHop.insert(e.from) }
        }
        let all = visible.union(oneHop).union(twoHop)
        var set = Set(s.discovered)
        set.formUnion(all)
        s.discovered = set.sorted()
    }

    // MARK: - Small helpers

    static func trackStack(_ s: inout GameState, _ p: Int, _ strength: Int) {
        guard p >= 0 && p < s.maxStack.count else { return }
        s.maxStack[p] = max(s.maxStack[p], strength)
    }

    static func trackFlorins(_ s: inout GameState, _ p: Int) {
        guard p >= 0 && p < s.maxFlorins.count else { return }
        s.maxFlorins[p] = max(s.maxFlorins[p], s.players[p].florins)
    }
}
