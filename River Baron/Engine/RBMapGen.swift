import Foundation

/// Seeded procedural river generator for Skirmish: one main channel flowing
/// north-to-south into the Mouth, 2–4 tributaries joining it at confluences.
/// Guarantees connectivity and Mouth reachability by construction, then
/// validates anyway and regenerates with a salted seed on any failure.
enum RBMapGen {

    static let namePrefixes = [
        "Alder", "Reed", "Gull", "Heron", "Willow", "Stone", "Ferry", "Marsh",
        "Otter", "Bram", "Ash", "Elm", "Salt", "Mill", "Wold", "Carp",
        "Pike", "Rush", "Fen", "Moss", "Thorn", "Eel", "Swan", "Crane",
        "Barge", "Copper", "Amber", "Grey", "Tarn", "Ledge"
    ]
    static let nameSuffixes = [
        "mere", "ford", "wick", "stead", "haven", "landing", "quay", "bank",
        "holm", "gate", "reach", "cross", "moor", "point", "shoal", "rest"
    ]

    static func makeName(_ rng: inout RBRandom, used: inout Set<String>) -> String {
        for _ in 0..<40 {
            let a = namePrefixes[rng.int(in: 0...(namePrefixes.count - 1))]
            let b = nameSuffixes[rng.int(in: 0...(nameSuffixes.count - 1))]
            let name = a + b
            if !used.contains(name) {
                used.insert(name)
                return name
            }
        }
        let fallback = "Landing \(used.count + 1)"
        used.insert(fallback)
        return fallback
    }

    /// Builds a validated skirmish state. Player is seat 0 at the main source.
    static func generate(config: SkirmishConfig, playerColor: Int) -> GameState {
        var salt: UInt64 = 0
        while salt < 24 {
            var s = attempt(config: config, salt: salt, playerColor: playerColor)
            if validate(&s, players: config.opponents + 1) {
                s.rng = RBRandom(seed: config.seed &* 31 &+ 977)
                RBEngine.setupMatch(&s)
                return s
            }
            salt += 1
        }
        // Construction guarantees validity; this path is unreachable in
        // practice, but never trap — fall back to the raw attempt.
        var s = attempt(config: config, salt: 0, playerColor: playerColor)
        s.rng = RBRandom(seed: config.seed &* 31 &+ 977)
        RBEngine.setupMatch(&s)
        return s
    }

    static func attempt(config: SkirmishConfig, salt: UInt64, playerColor: Int) -> GameState {
        var rng = RBRandom(seed: config.seed &+ salt &* 0x9E37)
        var s = GameState()
        var used = Set<String>()
        var nextNode = 1
        var nextEdge = 1

        let targetNodes: Int
        let mainLen: Int
        switch config.size {
        case 0: targetNodes = 14; mainLen = 6
        case 2: targetNodes = 24; mainLen = 8
        default: targetNodes = 18; mainLen = 7
        }
        let tribCount = min(4, max(2, config.opponents + rng.int(in: 0...1)))

        func addNode(_ kind: RBNodeKind, _ x: Double, _ y: Double, name: String? = nil) -> Int {
            var n = RBNode(id: nextNode, name: name ?? makeName(&rng, used: &used), kind: kind, x: x, y: y)
            if kind == .mouth { n.name = "The Mouth" }
            nextNode += 1
            s.nodes.append(n)
            return n.id
        }

        func addEdge(_ from: Int, _ to: Int) {
            s.edges.append(RBEdge(id: nextEdge, from: from, to: to))
            nextEdge += 1
        }

        // Main channel: source (top) down to the Mouth (bottom).
        var mainIDs: [Int] = []
        let topY = 130.0
        let bottomY = 1270.0
        for i in 0..<mainLen {
            let t = Double(i) / Double(mainLen - 1)
            let y = topY + (bottomY - topY) * t
            let meander = sin(t * 5.1 + Double(rng.int(in: 0...6))) * 150
            let x = 500.0 + meander + Double(rng.int(in: -40...40))
            let kind: RBNodeKind
            if i == mainLen - 1 { kind = .mouth }
            else if i == 0 { kind = .harbor }
            else { kind = rng.chance(0.4) ? .island : .harbor }
            mainIDs.append(addNode(kind, x, y))
        }
        for i in 1..<mainIDs.count {
            addEdge(mainIDs[i - 1], mainIDs[i])
        }
        s.mouthID = mainIDs[mainLen - 1]

        // Tributaries join interior main nodes, which become confluences.
        var tribHeads: [Int] = []
        var joinSlots = Array(1...(mainLen - 2))
        var remaining = targetNodes - mainLen
        for t in 0..<tribCount {
            guard !joinSlots.isEmpty else { break }
            let slotIdx = rng.int(in: 0...(joinSlots.count - 1))
            let slot = joinSlots.remove(at: slotIdx)
            let joinID = mainIDs[slot]
            if let ji = s.nodeIndex(joinID) { s.nodes[ji].kind = .confluence }

            let tribsLeft = tribCount - t
            let maxLen = max(2, min(4, remaining - (tribsLeft - 1) * 2))
            let len = max(2, min(maxLen, 2 + rng.int(in: 0...2)))
            remaining -= len

            guard let joinNode = s.node(joinID) else { continue }
            let side: Double = joinNode.x > 500 ? -1 : 1
            var prev = joinID
            var ids: [Int] = []
            for k in 0..<len {
                let dx = side * (120 + Double(k) * 130) + Double(rng.int(in: -35...35))
                let dy = -80 - Double(k) * 120 + Double(rng.int(in: -30...30))
                let kind: RBNodeKind = (k == len - 1) ? .harbor : (rng.chance(0.45) ? .island : .harbor)
                let id = addNode(kind, joinNode.x + dx, joinNode.y + dy)
                ids.append(id)
                addEdge(id, prev)   // flows downstream toward the join
                prev = id
            }
            if let head = ids.last { tribHeads.append(head) }
        }

        // Pad with extra islands hanging off random mid-channel nodes.
        var extraGuard = 0
        while s.nodes.count < targetNodes && extraGuard < 30 {
            extraGuard += 1
            let anchorPool = mainIDs.dropFirst().dropLast()
            guard !anchorPool.isEmpty else { break }
            let anchorID = anchorPool.sorted()[rng.int(in: 0...(anchorPool.count - 1))]
            guard let anchor = s.node(anchorID) else { continue }
            let side: Double = rng.chance(0.5) ? 1 : -1
            let id = addNode(.island, anchor.x + side * 170 + Double(rng.int(in: -30...30)),
                             anchor.y + Double(rng.int(in: -70...70)))
            addEdge(id, anchorID)
        }

        // Spread overlapping nodes apart (simple relaxation, deterministic).
        for _ in 0..<24 {
            var moved = false
            for i in s.nodes.indices {
                for j in s.nodes.indices where j > i {
                    let dx = s.nodes[j].x - s.nodes[i].x
                    let dy = s.nodes[j].y - s.nodes[i].y
                    let d = max(1.0, (dx * dx + dy * dy).squareRoot())
                    if d < 120 {
                        let push = (120 - d) / 2 + 2
                        let ux = dx / d
                        let uy = dy / d
                        s.nodes[i].x -= ux * push
                        s.nodes[i].y -= uy * push
                        s.nodes[j].x += ux * push
                        s.nodes[j].y += uy * push
                        moved = true
                    }
                }
            }
            if !moved { break }
        }
        // Clamp into the map frame.
        for i in s.nodes.indices {
            s.nodes[i].x = min(950, max(50, s.nodes[i].x))
            s.nodes[i].y = min(1330, max(70, s.nodes[i].y))
        }

        // Seats: player at the main source; barons at tributary heads.
        var startIDs = [mainIDs[0]]
        for h in tribHeads where startIDs.count <= config.opponents { startIDs.append(h) }
        // If tributaries were fewer than opponents, use far main nodes.
        var fallbackIdx = 1
        while startIDs.count < config.opponents + 1 && fallbackIdx < mainLen - 1 {
            let candidate = mainIDs[fallbackIdx]
            if !startIDs.contains(candidate) { startIDs.append(candidate) }
            fallbackIdx += 1
        }

        let baronNames = ["Baron Alder", "Baroness Wren", "Baron Coot", "Baroness Tarn"]
        var personas = config.personas
        while personas.count < config.opponents { personas.append("merchant") }

        var colorPool = [0, 1, 2, 3, 4, 5].filter { $0 != playerColor }
        for (seat, startID) in startIDs.enumerated() {
            guard seat <= config.opponents else { break }
            let isHuman = seat == 0
            let color: Int
            if isHuman {
                color = playerColor
            } else {
                color = colorPool.isEmpty ? seat : colorPool.removeFirst()
            }
            let persona = isHuman ? "merchant" : personas[min(seat - 1, personas.count - 1)]
            let name = isHuman ? "You" : baronNames[min(seat - 1, baronNames.count - 1)]
            var pl = RBPlayer(idx: seat, name: name, colorID: color, florins: 12,
                              isHuman: isHuman, persona: persona, difficulty: config.difficulty)
            pl.eliminated = false
            s.players.append(pl)
            if let ni = s.nodeIndex(startID) {
                s.nodes[ni].owner = seat
                s.nodes[ni].kind = .harbor
                s.nodes[ni].dock = 1
                s.nodes[ni].yard = true
            }
            let f = RBFleet(id: s.nextFleetID, owner: seat, node: startID, strength: 3, mp: RBEngine.fleetMP)
            s.nextFleetID += 1
            s.fleets.append(f)
        }

        s.turnCap = 24
        s.fogEnabled = config.fog
        s.mapW = 1000
        s.mapH = 1400
        s.normalizeTallies()
        return s
    }

    /// Connectivity + Mouth reachability + no isolated nodes + seat sanity.
    static func validate(_ s: inout GameState, players: Int) -> Bool {
        guard !s.nodes.isEmpty, s.node(s.mouthID) != nil else { return false }
        guard s.players.count == players else { return false }
        // Undirected reachability from the Mouth must cover every node
        // (upstream travel is legal, so undirected connectivity is the test).
        var seen = Set<Int>([s.mouthID])
        var frontier = [s.mouthID]
        while let cur = frontier.popLast() {
            for e in s.edges {
                if e.from == cur && !seen.contains(e.to) { seen.insert(e.to); frontier.append(e.to) }
                if e.to == cur && !seen.contains(e.from) { seen.insert(e.from); frontier.append(e.from) }
            }
        }
        guard seen.count == s.nodes.count else { return false }
        // Every node touches at least one reach.
        for n in s.nodes {
            let touched = s.edges.contains { $0.from == n.id || $0.to == n.id }
            if !touched { return false }
        }
        // Every seat has a start node with a yard and a fleet.
        for p in 0..<players {
            let hasNode = s.nodes.contains { $0.owner == p && $0.yard }
            let hasFleet = s.fleets.contains { $0.owner == p }
            if !hasNode || !hasFleet { return false }
        }
        // No two seats share a start.
        let starts = s.nodes.filter { $0.owner >= 0 }
        if Set(starts.map { $0.id }).count != starts.count { return false }
        return true
    }
}
