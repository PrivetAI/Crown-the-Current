import Foundation

/// AI barons. Each turn: enumerate candidate builds and moves, score them with
/// weighted heuristics shaped by personality, execute the best N. Difficulty
/// scales action breadth, aggression margin and mistake chance. Deterministic
/// given the state's seeded RNG (all iteration orders are sorted).
enum RBAI {

    struct Persona {
        var wIncome: Double
        var wAttack: Double
        var wCapture: Double
        var wMouth: Double
        var wRecruit: Double
        var wDam: Double
        var aggressionMargin: Int      // required (atk - def) estimate before attacking
        var desiredFleetBias: Int      // extra fleets beyond baseline
        var lateGameTurn: Int          // engineer: mouth push after this turn
    }

    static func persona(_ raw: String) -> Persona {
        switch raw {
        case "corsair":
            return Persona(wIncome: 1.1, wAttack: 2.4, wCapture: 1.2, wMouth: 1.2,
                           wRecruit: 1.6, wDam: 0.1, aggressionMargin: 0,
                           desiredFleetBias: 2, lateGameTurn: 0)
        case "engineer":
            return Persona(wIncome: 2.0, wAttack: 1.0, wCapture: 1.0, wMouth: 0.7,
                           wRecruit: 1.0, wDam: 2.6, aggressionMargin: 2,
                           desiredFleetBias: 0, lateGameTurn: 13)
        default: // merchant
            return Persona(wIncome: 2.8, wAttack: 0.8, wCapture: 1.7, wMouth: 1.0,
                           wRecruit: 1.1, wDam: 0.3, aggressionMargin: 2,
                           desiredFleetBias: 0, lateGameTurn: 0)
        }
    }

    struct Skill {
        var mistakeChance: Double
        var buildActions: Int
        var movePassesPerFleet: Int
        var marginRelief: Int      // easy AIs misjudge fights by this much
    }

    static func skill(_ raw: String) -> Skill {
        switch raw {
        case "easy":
            return Skill(mistakeChance: 0.25, buildActions: 2, movePassesPerFleet: 1, marginRelief: 2)
        case "hard":
            return Skill(mistakeChance: 0.02, buildActions: 4, movePassesPerFleet: 3, marginRelief: 0)
        default:
            return Skill(mistakeChance: 0.10, buildActions: 3, movePassesPerFleet: 2, marginRelief: 1)
        }
    }

    // MARK: - Turn driver

    /// Plays the entire turn for the current (AI) player. Caller ends the turn.
    static func playTurn(_ s: inout GameState) {
        let pIdx = s.currentPlayer
        guard pIdx >= 0 && pIdx < s.players.count else { return }
        let player = s.players[pIdx]
        guard !player.eliminated else { return }
        let pr = persona(player.persona)
        let sk = skill(player.difficulty)

        buildPhase(&s, pIdx, pr, sk)
        movePhase(&s, pIdx, pr, sk)
    }

    /// Runs AI turns until it's a human's turn or the match ended.
    static func runAITurns(_ s: inout GameState) {
        var guardCount = 0
        let limit = s.players.count * 3 + 6
        while s.winner == -9 && guardCount < limit {
            guard s.currentPlayer >= 0 && s.currentPlayer < s.players.count else { return }
            let cur = s.players[s.currentPlayer]
            if cur.isHuman && !cur.eliminated { return }
            if !cur.eliminated {
                playTurn(&s)
            }
            RBEngine.endTurn(&s)
            guardCount += 1
        }
    }

    // MARK: - Build phase

    private struct BuildOption {
        var score: Double
        var kind: RBEngine.BuildKind
        var node: Int
        var damEdge: Int
        var isRecruit: Bool
        var ordinal: Int
    }

    static func buildPhase(_ s: inout GameState, _ p: Int, _ pr: Persona, _ sk: Skill) {
        for _ in 0..<sk.buildActions {
            guard s.winner == -9 else { return }
            var options: [BuildOption] = []
            var ordinal = 0
            let florins = s.players[p].florins
            let owned = s.ownedNodes(p)
            let myFleets = s.ownedFleets(p)
            let enemies = s.players.filter { $0.idx != p && !$0.eliminated }.count
            let turnsLeft = max(1, s.turnCap - s.turn)
            let yards = owned.filter { $0.yard }
            let desired = enemies + 1 + pr.desiredFleetBias

            // Recruit at open shipyards.
            if florins >= RBEngine.recruitCost {
                for yard in yards where !yard.yardUsed {
                    let mine = s.fleetsAt(yard.id).filter { $0.owner == p }
                    let stackStr = mine.reduce(0) { $0 + $1.strength }
                    if !mine.isEmpty && stackStr + RBEngine.recruitStrength > RBEngine.maxStackSize { continue }
                    let need = Double(max(0, desired - myFleets.count))
                    let threatened = enemyThreatNear(yard.id, p, s) > 0
                    var sc = pr.wRecruit * (0.8 + need * 1.4) + (threatened ? 2.0 : 0)
                    if myFleets.isEmpty { sc += 6 }   // never sit fleetless
                    options.append(BuildOption(score: sc, kind: .yard, node: yard.id, damEdge: -1, isRecruit: true, ordinal: ordinal))
                    ordinal += 1
                }
            }

            // Dock upgrades: income payback over remaining turns.
            for n in owned where n.dock < 3 {
                let cost = RBEngine.dockUpgradeCost(n.dock)
                guard florins >= cost else { continue }
                let payback = Double(turnsLeft) / Double(cost)
                let sc = pr.wIncome * payback * 1.15
                options.append(BuildOption(score: sc, kind: .dock, node: n.id, damEdge: -1, isRecruit: false, ordinal: ordinal))
                ordinal += 1
            }

            // Shipyards: rebuild is existential; expansion is judgement.
            if florins >= RBEngine.yardCost {
                if yards.isEmpty {
                    // Prefer a defended, rear node.
                    let ranked = owned.sorted {
                        (enemyThreatNear($0.id, p, s), $0.id) < (enemyThreatNear($1.id, p, s), $1.id)
                    }
                    if let spot = ranked.first {
                        options.append(BuildOption(score: 9.0, kind: .yard, node: spot.id, damEdge: -1, isRecruit: false, ordinal: ordinal))
                        ordinal += 1
                    }
                } else if yards.count < 2 && owned.count >= 4 && florins >= RBEngine.yardCost + 6 {
                    let ranked = owned.filter { !$0.yard }.sorted {
                        (enemyThreatNear($0.id, p, s), $0.id) < (enemyThreatNear($1.id, p, s), $1.id)
                    }
                    if let spot = ranked.first {
                        options.append(BuildOption(score: 1.1 * pr.wRecruit, kind: .yard, node: spot.id, damEdge: -1, isRecruit: false, ordinal: ordinal))
                        ordinal += 1
                    }
                }
            }

            // Dams on threatened frontier reaches (Engineer's signature move).
            if pr.wDam > 0.4, florins >= RBEngine.damCost,
               RBEngine.standingDams(of: p, in: s) < RBEngine.maxDamsPerPlayer {
                for n in owned {
                    for e in RBEngine.damCandidates(at: n.id, for: p, in: s) {
                        let farEnd = (e.from == n.id) ? e.to : e.from
                        guard let farNode = s.node(farEnd), farNode.owner != p else { continue }
                        let threat = enemyThreatNear(farEnd, p, s)
                        guard threat > 0 else { continue }
                        let sc = pr.wDam * (0.8 + Double(threat) * 0.5)
                        options.append(BuildOption(score: sc, kind: .dam, node: n.id, damEdge: e.id, isRecruit: false, ordinal: ordinal))
                        ordinal += 1
                    }
                }
            }

            // Watchtowers only matter under fog.
            if s.fogEnabled, florins >= RBEngine.towerCost {
                for n in owned where !n.tower {
                    if enemyThreatNear(n.id, p, s) > 0 {
                        options.append(BuildOption(score: 0.55, kind: .tower, node: n.id, damEdge: -1, isRecruit: false, ordinal: ordinal))
                        ordinal += 1
                    }
                }
            }

            guard !options.isEmpty else { return }
            options.sort { ($0.score, -Double($0.ordinal)) > ($1.score, -Double($1.ordinal)) }
            var chosen = options[0]
            if options.count > 1 && s.rng.chance(sk.mistakeChance) {
                let cap = min(3, options.count - 1)
                chosen = options[s.rng.int(in: 1...cap)]
            }
            guard chosen.score > 0.6 else { return }

            let ok: Bool
            if chosen.isRecruit {
                ok = RBEngine.recruit(at: chosen.node, in: &s)
            } else {
                ok = RBEngine.build(chosen.kind, at: chosen.node, damEdge: chosen.damEdge, in: &s)
            }
            if !ok { return }
        }
    }

    /// Count of enemy fleets within ~1 reach of a node (simple threat probe).
    static func enemyThreatNear(_ nodeID: Int, _ p: Int, _ s: GameState) -> Int {
        var near = Set<Int>([nodeID])
        for e in s.edges {
            if e.from == nodeID { near.insert(e.to) }
            if e.to == nodeID { near.insert(e.from) }
        }
        var count = 0
        for f in s.fleets where f.owner != p && near.contains(f.node) {
            count += 1
        }
        return count
    }

    // MARK: - Move phase

    private struct MoveOption {
        var score: Double
        var dest: Int
        var ordinal: Int
    }

    static func movePhase(_ s: inout GameState, _ p: Int, _ pr: Persona, _ sk: Skill) {
        // Anti-stall pressure: the pull of the Mouth rises every turn, so the
        // AI always grinds toward a decision instead of shuffling forever.
        let pressure = 0.35 + 0.07 * Double(s.turn)
        let fleetIDs = s.ownedFleets(p).map { $0.id }

        for fid in fleetIDs {
            for _ in 0..<sk.movePassesPerFleet {
                guard s.winner == -9 else { return }
                guard let f = s.fleet(fid), f.mp > 0 else { break }
                let distMouth = RBEngine.distancesTo(s.mouthID, for: p, in: s)
                let routes = RBEngine.routes(for: fid, in: s)
                var options: [MoveOption] = []
                var ordinal = 0
                let dHere = distMouth[f.node] ?? 999

                let mouthWeight = effectiveMouthWeight(pr, turn: s.turn)

                for dest in routes.keys.sorted() {
                    guard let route = routes[dest], let destNode = s.node(dest) else { continue }
                    var score = 0.0
                    let hostiles = s.fleetsAt(dest).filter { $0.owner != p }

                    if !hostiles.isEmpty {
                        // Attack: estimate margin using the deterministic core.
                        let defStr = hostiles.reduce(0) { $0 + $1.strength }
                        let dOwner = hostiles[0].owner
                        let flowMod = attackFlowMod(route: route, in: s)
                        let harborMod = (destNode.kind == .harbor && destNode.owner == dOwner) ? 1 : 0
                        let dockMod = (destNode.owner == dOwner) ? RBEngine.dockDefense(destNode.dock) : 0
                        let margin = (f.strength + flowMod) - (defStr + harborMod + dockMod)
                        let needed = pr.aggressionMargin - sk.marginRelief
                        if margin >= needed {
                            score += pr.wAttack * (Double(defStr) * 0.9 + 1.2)
                            score += Double(margin) * 0.25
                            if flowMod > 0 { score += pr.wAttack * 0.5 }   // corsairs love the downstream ram
                            if destNode.owner == dOwner {
                                score += captureValue(destNode) * pr.wCapture * 0.4
                            }
                            if dest == s.mouthID { score += mouthWeight * 2.0 }
                        }
                    } else if destNode.owner != p {
                        // Free capture (neutral or undefended enemy ground).
                        score += captureValue(destNode) * pr.wCapture
                        if destNode.owner >= 0 { score += 1.0 }   // taking from a rival stings them too
                        if destNode.yard { score += 2.2 }
                        if dest == s.mouthID { score += mouthWeight * (2.2 + 0.12 * Double(s.turn)) }
                    } else {
                        // Reposition onto own ground: merging when outmatched.
                        let friends = s.fleetsAt(dest).filter { $0.owner == p }
                        if !friends.isEmpty {
                            let combined = f.strength + friends.reduce(0) { $0 + $1.strength }
                            let biggestEnemy = s.fleets.filter { $0.owner != p }.map { $0.strength }.max() ?? 0
                            if combined <= RBEngine.maxStackSize && biggestEnemy > f.strength {
                                score += 0.9 + Double(min(combined, biggestEnemy)) * 0.12
                            }
                        }
                        // Rush home when the shipyard is threatened.
                        if destNode.yard && enemyThreatNear(dest, p, s) > 0 {
                            score += 1.6
                        }
                    }

                    // Progress toward the Mouth (strictly closer only).
                    let dThere = distMouth[dest] ?? 999
                    if dThere < dHere {
                        score += pressure * mouthWeight * Double(dHere - dThere) * 0.55
                    }
                    // Toll discourages casual wandering.
                    score -= Double(route.tolls) * 0.25

                    if score > 0.01 {
                        options.append(MoveOption(score: score, dest: dest, ordinal: ordinal))
                        ordinal += 1
                    }
                }

                if options.isEmpty {
                    // Stuck behind an enemy dam? Spend the turn breaching it.
                    let dams = RBEngine.adjacentEnemyDams(for: fid, in: s)
                    if let dam = dams.first {
                        let farEnd = (dam.from == f.node) ? dam.to : dam.from
                        let dFar = distMouth[farEnd] ?? 999
                        if dFar < dHere || pr.wAttack > 1.5 {
                            _ = RBEngine.breachDam(fid, edgeID: dam.id, in: &s)
                        }
                    }
                    break
                }

                options.sort { ($0.score, -Double($0.ordinal)) > ($1.score, -Double($1.ordinal)) }
                var chosen = options[0]
                if options.count > 1 && s.rng.chance(sk.mistakeChance) {
                    let cap = min(3, options.count - 1)
                    chosen = options[s.rng.int(in: 1...cap)]
                }
                guard chosen.score > 0.45 else { break }
                let before = s.fleet(fid)?.node ?? -1
                _ = RBEngine.moveFleet(fid, to: chosen.dest, in: &s)
                let after = s.fleet(fid)?.node ?? -2
                if before == after { break }   // no progress — stop looping
            }
        }
    }

    static func effectiveMouthWeight(_ pr: Persona, turn: Int) -> Double {
        var w = pr.wMouth
        if pr.lateGameTurn > 0 && turn >= pr.lateGameTurn {
            w *= 2.2   // the Engineer's late push
        }
        return w
    }

    static func captureValue(_ n: RBNode) -> Double {
        Double(RBEngine.baseIncome(n.kind) + RBEngine.dockIncome(n.dock)) * 0.55
    }

    static func attackFlowMod(route: RBRoute, in s: GameState) -> Int {
        guard route.path.count >= 2 else { return 0 }
        let a = route.path[route.path.count - 2]
        let b = route.path[route.path.count - 1]
        guard let e = s.edgeBetween(a, b) else { return 0 }
        if e.from == a { return 2 }      // charging downstream
        if e.to == a { return -1 }       // clawing upstream
        return 0
    }
}
