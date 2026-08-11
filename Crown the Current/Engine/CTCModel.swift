import Foundation

// MARK: - Core enums

enum CTCNodeKind: String, Codable {
    case harbor      // income 3, defender +1
    case island      // income 2
    case confluence  // income 4
    case mouth       // income 6, victory point
}

// MARK: - Node

struct CTCNode: Codable, Identifiable, Equatable {
    var id: Int = 0
    var name: String = ""
    var kind: CTCNodeKind = .harbor
    var x: Double = 0
    var y: Double = 0
    var owner: Int = -1        // player index; -1 = neutral
    var dock: Int = 0          // 0...3 (Dock I/II/III)
    var yard: Bool = false     // shipyard
    var tower: Bool = false    // watchtower
    var yardUsed: Bool = false // one recruit per shipyard per turn

    init() {}

    init(id: Int, name: String, kind: CTCNodeKind, x: Double, y: Double) {
        self.id = id; self.name = name; self.kind = kind; self.x = x; self.y = y
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        kind = try c.decodeIfPresent(CTCNodeKind.self, forKey: .kind) ?? .harbor
        x = try c.decodeIfPresent(Double.self, forKey: .x) ?? 0
        y = try c.decodeIfPresent(Double.self, forKey: .y) ?? 0
        owner = try c.decodeIfPresent(Int.self, forKey: .owner) ?? -1
        dock = try c.decodeIfPresent(Int.self, forKey: .dock) ?? 0
        yard = try c.decodeIfPresent(Bool.self, forKey: .yard) ?? false
        tower = try c.decodeIfPresent(Bool.self, forKey: .tower) ?? false
        yardUsed = try c.decodeIfPresent(Bool.self, forKey: .yardUsed) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, x, y, owner, dock, yard, tower, yardUsed
    }
}

// MARK: - Edge (river reach, directed: from = upstream, to = downstream)

struct CTCEdge: Codable, Identifiable, Equatable {
    var id: Int = 0
    var from: Int = 0          // upstream node id
    var to: Int = 0            // downstream node id
    var damOwner: Int = -1     // -1 = no dam
    var toll: Bool = false     // toll bridge: 2 florins to cross

    init() {}

    init(id: Int, from: Int, to: Int, toll: Bool = false) {
        self.id = id; self.from = from; self.to = to; self.toll = toll
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        from = try c.decodeIfPresent(Int.self, forKey: .from) ?? 0
        to = try c.decodeIfPresent(Int.self, forKey: .to) ?? 0
        damOwner = try c.decodeIfPresent(Int.self, forKey: .damOwner) ?? -1
        toll = try c.decodeIfPresent(Bool.self, forKey: .toll) ?? false
    }

    private enum CodingKeys: String, CodingKey { case id, from, to, damOwner, toll }
}

// MARK: - Fleet

struct CTCFleet: Codable, Identifiable, Equatable {
    var id: Int = 0
    var owner: Int = 0       // player index; -1 = pirates
    var node: Int = 0
    var strength: Int = 1    // 1...12
    var mp: Int = 3          // move points remaining this turn

    init() {}

    init(id: Int, owner: Int, node: Int, strength: Int, mp: Int = 3) {
        self.id = id; self.owner = owner; self.node = node
        self.strength = strength; self.mp = mp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        owner = try c.decodeIfPresent(Int.self, forKey: .owner) ?? 0
        node = try c.decodeIfPresent(Int.self, forKey: .node) ?? 0
        strength = try c.decodeIfPresent(Int.self, forKey: .strength) ?? 1
        mp = try c.decodeIfPresent(Int.self, forKey: .mp) ?? 0
    }

    private enum CodingKeys: String, CodingKey { case id, owner, node, strength, mp }
}

// MARK: - Player

struct CTCPlayer: Codable, Equatable {
    var idx: Int = 0
    var name: String = ""
    var colorID: Int = 0       // banner color index
    var florins: Int = 0
    var isHuman: Bool = false
    var persona: String = "merchant"    // merchant / corsair / engineer
    var difficulty: String = "normal"   // easy / normal / hard
    var eliminated: Bool = false
    var mouthTurns: Int = 0    // consecutive own-turn-ends holding the Mouth

    init() {}

    init(idx: Int, name: String, colorID: Int, florins: Int,
         isHuman: Bool, persona: String, difficulty: String) {
        self.idx = idx; self.name = name; self.colorID = colorID
        self.florins = florins; self.isHuman = isHuman
        self.persona = persona; self.difficulty = difficulty
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        idx = try c.decodeIfPresent(Int.self, forKey: .idx) ?? 0
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        colorID = try c.decodeIfPresent(Int.self, forKey: .colorID) ?? 0
        florins = try c.decodeIfPresent(Int.self, forKey: .florins) ?? 0
        isHuman = try c.decodeIfPresent(Bool.self, forKey: .isHuman) ?? false
        persona = try c.decodeIfPresent(String.self, forKey: .persona) ?? "merchant"
        difficulty = try c.decodeIfPresent(String.self, forKey: .difficulty) ?? "normal"
        eliminated = try c.decodeIfPresent(Bool.self, forKey: .eliminated) ?? false
        mouthTurns = try c.decodeIfPresent(Int.self, forKey: .mouthTurns) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case idx, name, colorID, florins, isHuman, persona, difficulty, eliminated, mouthTurns
    }
}

// MARK: - Battle report (popup content: the math is shown)

struct CTCBattleReport: Codable, Identifiable, Equatable {
    var id: Int = 0
    var turn: Int = 0
    var nodeID: Int = 0
    var nodeName: String = ""
    var attacker: Int = 0      // player index or -1 pirates
    var defender: Int = -1
    var atkStr: Int = 0
    var atkFlow: Int = 0       // +2 downstream, -1 upstream, 0 cross
    var atkRoll: Int = 0       // seeded roll -1...+1
    var atkTotal: Int = 0
    var defStr: Int = 0
    var defHarbor: Int = 0     // +1 in harbor
    var defDock: Int = 0       // dock defense bonus
    var defTotal: Int = 0
    var attackerWon: Bool = false
    var winnerLoss: Int = 0    // strength the winner paid

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        turn = try c.decodeIfPresent(Int.self, forKey: .turn) ?? 0
        nodeID = try c.decodeIfPresent(Int.self, forKey: .nodeID) ?? 0
        nodeName = try c.decodeIfPresent(String.self, forKey: .nodeName) ?? ""
        attacker = try c.decodeIfPresent(Int.self, forKey: .attacker) ?? 0
        defender = try c.decodeIfPresent(Int.self, forKey: .defender) ?? -1
        atkStr = try c.decodeIfPresent(Int.self, forKey: .atkStr) ?? 0
        atkFlow = try c.decodeIfPresent(Int.self, forKey: .atkFlow) ?? 0
        atkRoll = try c.decodeIfPresent(Int.self, forKey: .atkRoll) ?? 0
        atkTotal = try c.decodeIfPresent(Int.self, forKey: .atkTotal) ?? 0
        defStr = try c.decodeIfPresent(Int.self, forKey: .defStr) ?? 0
        defHarbor = try c.decodeIfPresent(Int.self, forKey: .defHarbor) ?? 0
        defDock = try c.decodeIfPresent(Int.self, forKey: .defDock) ?? 0
        defTotal = try c.decodeIfPresent(Int.self, forKey: .defTotal) ?? 0
        attackerWon = try c.decodeIfPresent(Bool.self, forKey: .attackerWon) ?? false
        winnerLoss = try c.decodeIfPresent(Int.self, forKey: .winnerLoss) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, turn, nodeID, nodeName, attacker, defender
        case atkStr, atkFlow, atkRoll, atkTotal
        case defStr, defHarbor, defDock, defTotal, attackerWon, winnerLoss
    }
}

// MARK: - Game state (single Codable snapshot; every field decodeIfPresent)

struct GameState: Codable {
    var nodes: [CTCNode] = []
    var edges: [CTCEdge] = []
    var fleets: [CTCFleet] = []
    var players: [CTCPlayer] = []
    var turn: Int = 1
    var currentPlayer: Int = 0
    var turnCap: Int = 24
    var rng: CTCRandom = CTCRandom()
    var nextFleetID: Int = 1
    var nextReportID: Int = 1
    var mouthID: Int = 0
    var fogEnabled: Bool = false
    var discovered: [Int] = []      // node ids discovered by the human seat
    var floodEvery: Int = 0         // 0 = no floods; else every Nth turn upstream = 1 MP
    var piratesOn: Bool = false
    var winner: Int = -9            // -9 = none yet; else player index
    var winKind: String = ""        // mouth / elimination / nodes
    var pendingReports: [CTCBattleReport] = []
    var notices: [String] = []      // events since the human's last look (UI clears)
    var log: [String] = []          // deterministic action log (harness + debugging)
    var battlesCount: Int = 0
    var sunk: [Int] = []            // fleets sunk BY each player
    var lostShipyard: [Bool] = []   // per player: ever lost a shipyard node
    var lostFleet: [Bool] = []      // per player: ever lost a fleet
    var damsBuiltCount: [Int] = []  // per player: dams built (lifetime this match)
    var breachedDam: [Bool] = []    // per player: ever breached an enemy dam
    var maxStack: [Int] = []        // per player: biggest fleet fielded
    var maxFlorins: [Int] = []      // per player: richest moment
    var heldAllConfluences: Bool = false  // human held every confluence at once
    var mapW: Double = 1000
    var mapH: Double = 1400

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try c.decodeIfPresent([CTCNode].self, forKey: .nodes) ?? []
        edges = try c.decodeIfPresent([CTCEdge].self, forKey: .edges) ?? []
        fleets = try c.decodeIfPresent([CTCFleet].self, forKey: .fleets) ?? []
        players = try c.decodeIfPresent([CTCPlayer].self, forKey: .players) ?? []
        turn = try c.decodeIfPresent(Int.self, forKey: .turn) ?? 1
        currentPlayer = try c.decodeIfPresent(Int.self, forKey: .currentPlayer) ?? 0
        turnCap = try c.decodeIfPresent(Int.self, forKey: .turnCap) ?? 24
        rng = try c.decodeIfPresent(CTCRandom.self, forKey: .rng) ?? CTCRandom()
        nextFleetID = try c.decodeIfPresent(Int.self, forKey: .nextFleetID) ?? 1
        nextReportID = try c.decodeIfPresent(Int.self, forKey: .nextReportID) ?? 1
        mouthID = try c.decodeIfPresent(Int.self, forKey: .mouthID) ?? 0
        fogEnabled = try c.decodeIfPresent(Bool.self, forKey: .fogEnabled) ?? false
        discovered = try c.decodeIfPresent([Int].self, forKey: .discovered) ?? []
        floodEvery = try c.decodeIfPresent(Int.self, forKey: .floodEvery) ?? 0
        piratesOn = try c.decodeIfPresent(Bool.self, forKey: .piratesOn) ?? false
        winner = try c.decodeIfPresent(Int.self, forKey: .winner) ?? -9
        winKind = try c.decodeIfPresent(String.self, forKey: .winKind) ?? ""
        pendingReports = try c.decodeIfPresent([CTCBattleReport].self, forKey: .pendingReports) ?? []
        notices = try c.decodeIfPresent([String].self, forKey: .notices) ?? []
        log = try c.decodeIfPresent([String].self, forKey: .log) ?? []
        battlesCount = try c.decodeIfPresent(Int.self, forKey: .battlesCount) ?? 0
        sunk = try c.decodeIfPresent([Int].self, forKey: .sunk) ?? []
        lostShipyard = try c.decodeIfPresent([Bool].self, forKey: .lostShipyard) ?? []
        lostFleet = try c.decodeIfPresent([Bool].self, forKey: .lostFleet) ?? []
        damsBuiltCount = try c.decodeIfPresent([Int].self, forKey: .damsBuiltCount) ?? []
        breachedDam = try c.decodeIfPresent([Bool].self, forKey: .breachedDam) ?? []
        maxStack = try c.decodeIfPresent([Int].self, forKey: .maxStack) ?? []
        maxFlorins = try c.decodeIfPresent([Int].self, forKey: .maxFlorins) ?? []
        heldAllConfluences = try c.decodeIfPresent(Bool.self, forKey: .heldAllConfluences) ?? false
        mapW = try c.decodeIfPresent(Double.self, forKey: .mapW) ?? 1000
        mapH = try c.decodeIfPresent(Double.self, forKey: .mapH) ?? 1400
        normalizeTallies()
    }

    private enum CodingKeys: String, CodingKey {
        case nodes, edges, fleets, players, turn, currentPlayer, turnCap, rng
        case nextFleetID, nextReportID, mouthID, fogEnabled, discovered
        case floodEvery, piratesOn, winner, winKind, pendingReports, notices, log
        case battlesCount, sunk, lostShipyard, lostFleet, damsBuiltCount
        case breachedDam, maxStack, maxFlorins, heldAllConfluences, mapW, mapH
    }

    /// Ensures per-player tally arrays match the player count (safe indexing).
    mutating func normalizeTallies() {
        let n = players.count
        while sunk.count < n { sunk.append(0) }
        while lostShipyard.count < n { lostShipyard.append(false) }
        while lostFleet.count < n { lostFleet.append(false) }
        while damsBuiltCount.count < n { damsBuiltCount.append(0) }
        while breachedDam.count < n { breachedDam.append(false) }
        while maxStack.count < n { maxStack.append(0) }
        while maxFlorins.count < n { maxFlorins.append(0) }
    }

    // MARK: convenience lookups (all guarded)

    func node(_ id: Int) -> CTCNode? {
        for n in nodes where n.id == id { return n }
        return nil
    }

    func nodeIndex(_ id: Int) -> Int? {
        for (i, n) in nodes.enumerated() where n.id == id { return i }
        return nil
    }

    func edgeIndex(_ id: Int) -> Int? {
        for (i, e) in edges.enumerated() where e.id == id { return i }
        return nil
    }

    func fleet(_ id: Int) -> CTCFleet? {
        for f in fleets where f.id == id { return f }
        return nil
    }

    func fleetIndex(_ id: Int) -> Int? {
        for (i, f) in fleets.enumerated() where f.id == id { return i }
        return nil
    }

    func fleetsAt(_ nodeID: Int) -> [CTCFleet] {
        fleets.filter { $0.node == nodeID }.sorted { $0.id < $1.id }
    }

    func edgeBetween(_ a: Int, _ b: Int) -> CTCEdge? {
        for e in edges where (e.from == a && e.to == b) || (e.from == b && e.to == a) { return e }
        return nil
    }

    func ownedNodes(_ player: Int) -> [CTCNode] {
        nodes.filter { $0.owner == player }.sorted { $0.id < $1.id }
    }

    func ownedFleets(_ player: Int) -> [CTCFleet] {
        fleets.filter { $0.owner == player }.sorted { $0.id < $1.id }
    }

    func isDiscovered(_ nodeID: Int) -> Bool {
        if !fogEnabled { return true }
        return discovered.contains(nodeID)
    }
}

// MARK: - Match context (campaign/skirmish wrapper around a live game)

struct SkirmishConfig: Codable, Equatable {
    var size: Int = 1            // 0 S / 1 M / 2 L
    var opponents: Int = 2       // 1...3
    var personas: [String] = ["merchant", "corsair"]
    var difficulty: String = "normal"
    var fog: Bool = false
    var seed: UInt64 = 1

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        size = try c.decodeIfPresent(Int.self, forKey: .size) ?? 1
        opponents = try c.decodeIfPresent(Int.self, forKey: .opponents) ?? 2
        personas = try c.decodeIfPresent([String].self, forKey: .personas) ?? ["merchant", "corsair"]
        difficulty = try c.decodeIfPresent(String.self, forKey: .difficulty) ?? "normal"
        fog = try c.decodeIfPresent(Bool.self, forKey: .fog) ?? false
        seed = try c.decodeIfPresent(UInt64.self, forKey: .seed) ?? 1
    }

    private enum CodingKeys: String, CodingKey {
        case size, opponents, personas, difficulty, fog, seed
    }
}

struct MatchState: Codable {
    var mode: String = "skirmish"     // campaign / skirmish
    var scenarioID: Int = 0           // campaign only
    var skirmish: SkirmishConfig = SkirmishConfig()
    var game: GameState = GameState()

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = try c.decodeIfPresent(String.self, forKey: .mode) ?? "skirmish"
        scenarioID = try c.decodeIfPresent(Int.self, forKey: .scenarioID) ?? 0
        skirmish = try c.decodeIfPresent(SkirmishConfig.self, forKey: .skirmish) ?? SkirmishConfig()
        game = try c.decodeIfPresent(GameState.self, forKey: .game) ?? GameState()
    }

    private enum CodingKeys: String, CodingKey { case mode, scenarioID, skirmish, game }
}
