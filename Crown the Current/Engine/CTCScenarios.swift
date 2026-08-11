import Foundation

/// The 14 authored campaign scenarios across 3 acts. Every map is hand-laid:
/// node ordinals are 1-based within a blueprint; edges run upstream -> downstream.
enum CTCScenarios {

    struct Meta: Identifiable {
        let id: Int
        let act: Int
        let title: String
        let tagline: String
        let narration: String
        let turnCap: Int
        let starTurn: Int      // 2nd star: win by this turn
        let fog: Bool
        let flood: Int         // 0 = none
        let pirates: Bool
        let oppLine: String
    }

    static let actTitles = ["Act I — The Delta", "Act II — Twin Rivers", "Act III — The Grand Basin"]
    static let actTaglines = [
        "Learn the water. Take your first landings.",
        "Two rivers, three barons, one crown of silt.",
        "All the great houses converge on the basin."
    ]

    static let all: [Meta] = [
        Meta(id: 1, act: 1, title: "First Waters",
             tagline: "The delta lies open.",
             narration: "The old baron of the delta is dead, and his heirs have scattered like gulls before a storm. Your grandfather's charter names you master of Reedmere and the waters below it. Baron Goldwater has already sent his barges south to stake his own claim. Take the landings, build your docks, and hold the Mouth — whoever rules it rules the trade of the whole coast.",
             turnCap: 20, starTurn: 12, fog: false, flood: 0, pirates: false,
             oppLine: "vs Baron Goldwater (Merchant, Easy)"),
        Meta(id: 2, act: 1, title: "The Quiet Fork",
             tagline: "Two channels, one crown.",
             narration: "Below Swancross the river splits into two quiet channels, and quiet water always hides teeth. Baroness Redwake has anchored her war-barges upriver and she does not trade — she takes. Her captains love to ride the current down onto slow merchants. Keep your strength together, watch the downstream reaches, and beat her to the Mouth.",
             turnCap: 22, starTurn: 13, fog: false, flood: 0, pirates: false,
             oppLine: "vs Baroness Redwake (Corsair, Easy)"),
        Meta(id: 3, act: 1, title: "Toll Waters",
             tagline: "Every crossing has its price.",
             narration: "The bridge-keepers of the middle river answer to no baron; they answer to florins. Two great toll bridges span the reaches below Ferrycross, and every hull that passes must pay. Baron Goldwater will try to buy his way south faster than you can sail. Mind your purse, scout the mists, and remember that a toll paid twice is a battle lost once.",
             turnCap: 22, starTurn: 14, fog: true, flood: 0, pirates: false,
             oppLine: "vs Baron Goldwater (Merchant, Easy) — toll bridges, fog"),
        Meta(id: 4, act: 1, title: "Reedbank Raiders",
             tagline: "The reeds are full of knives.",
             narration: "Pirates have wintered in the brackwater, and spring has made them bold. They fly no banner, owe no tithe, and raid whichever baron's coffers ring loudest. Baroness Redwake thinks she can use them against you. Sink the raiders or steer around them — but do not let them catch you rich and unguarded.",
             turnCap: 22, starTurn: 14, fog: false, flood: 0, pirates: true,
             oppLine: "vs Baroness Redwake (Corsair, Easy) — pirate raiders"),
        Meta(id: 5, act: 2, title: "Two Currents",
             tagline: "The twin rivers meet.",
             narration: "North of the Great Cross, two rivers run side by side and share one mouth. Baron Goldwater buys every dock his agents can reach, while Baroness Redwake burns the ones she cannot. You hold the western water between them. Two rivals means two fronts — choose which current carries you to the sea.",
             turnCap: 24, starTurn: 15, fog: false, flood: 0, pirates: false,
             oppLine: "vs Goldwater (Merchant) & Redwake (Corsair), Normal"),
        Meta(id: 6, act: 2, title: "The Flood Season",
             tagline: "Every sixth turn, the river forgives.",
             narration: "The spring floods are coming, and when they crest, the current slackens — for one turn in six, even upstream water is easy water. Baron Stonelock has planned his whole war around the flood calendar, and his dams are already rising. Strike upstream when the water rises, and never be caught below a dam when it falls.",
             turnCap: 24, starTurn: 15, fog: false, flood: 6, pirates: false,
             oppLine: "vs Stonelock (Engineer) & Goldwater (Merchant), Normal"),
        Meta(id: 7, act: 2, title: "The Long Portage",
             tagline: "A river that tests the patient.",
             narration: "The eastern reaches wind through mist and toll-gates on the longest water in the twin valleys. Baroness Redwake hunts the fog with fast keels; Baron Stonelock walls the narrows and waits. Every florin you spend on a toll is a florin he banks in stone. Scout with towers, pay only the crossings that shorten the war, and keep one strong fleet for the last reach.",
             turnCap: 24, starTurn: 15, fog: true, flood: 0, pirates: false,
             oppLine: "vs Redwake (Corsair) & Stonelock (Engineer), Normal — tolls, fog"),
        Meta(id: 8, act: 2, title: "Island Crowns",
             tagline: "Three jewels in the stream.",
             narration: "Pearlshoal, Crownholm, Silverbank — three island landings whose old docks still stand from the empire days. Whoever claims them inherits their income whole. Goldwater wants them bought; Redwake wants them burning. The islands sit in the middle water, far from every baron's keep, and the race begins at first light.",
             turnCap: 24, starTurn: 15, fog: false, flood: 0, pirates: false,
             oppLine: "vs Goldwater (Merchant) & Redwake (Corsair), Normal — rich neutral docks"),
        Meta(id: 9, act: 2, title: "The Broken Dam",
             tagline: "Stone against the stream.",
             narration: "Two engineer barons have walled the central water: twin dams seal both channels above Heroncross, and behind them their docks grow fat. A dam is only stone — a determined crew can breach one in a single hard turn. Break the river open, or find that the flood does it for you. Either way, the water remembers who freed it.",
             turnCap: 24, starTurn: 16, fog: false, flood: 6, pirates: false,
             oppLine: "vs Stonelock & Milldam (Engineers), Normal — standing dams"),
        Meta(id: 10, act: 3, title: "Baron's Gambit",
             tagline: "The corsair queen shows her hand.",
             narration: "Baroness Redwake has spent two seasons building the fastest war-fleet the basin has ever seen, and the mists of the lower river hide it well. Baron Goldwater plays both sides, selling grain to whoever is winning. Her gambit is simple: sink you before your docks can pay for a navy. Survive her opening, and her empire of speed becomes an empire of splinters.",
             turnCap: 24, starTurn: 15, fog: true, flood: 0, pirates: false,
             oppLine: "vs Redwake (Corsair, HARD) & Goldwater (Merchant, Normal) — fog"),
        Meta(id: 11, act: 3, title: "The Silted Maze",
             tagline: "Canals, tolls, and stone.",
             narration: "The old empire cut canals through the silt here, and the maze they left has a dozen doors. Baron Stonelock knows every one of them, and what he knows, he dams. The toll-canals cut hours off the passage south — for those who can pay. Out-build him, out-pay him, or out-sail him; the maze rewards all three, but only one baron leaves it crowned.",
             turnCap: 24, starTurn: 16, fog: false, flood: 0, pirates: false,
             oppLine: "vs Stonelock (Engineer, HARD) & Redwake (Corsair, Normal) — toll canals"),
        Meta(id: 12, act: 3, title: "Pirate Kings",
             tagline: "The brackwater crowns its own.",
             narration: "Three pirate crews have sworn a ragged crown between them and taken the central confluences for their own. They raid the richest baron first — and Baron Goldwater is very, very rich. Let the raiders bleed him while you build, but remember that gold flows toward the winner. Sooner or later, the richest baron on the river will be you.",
             turnCap: 24, starTurn: 16, fog: false, flood: 0, pirates: true,
             oppLine: "vs Goldwater (Merchant, HARD) & Redwake (Corsair, Normal) — pirate fleets"),
        Meta(id: 13, act: 3, title: "The Last Confluence",
             tagline: "Where all water argues.",
             narration: "They say the Last Confluence has drowned more ambitions than the sea itself. Stonelock and Goldwater have divided the upper rivers between them and mean to divide yours next. You hold two landings and the best shipwrights on the water. The flood comes every sixth turn; the barons come every turn. Hold the line, then break it.",
             turnCap: 24, starTurn: 16, fog: false, flood: 6, pirates: false,
             oppLine: "vs Stonelock & Goldwater (both HARD) — flood season"),
        Meta(id: 14, act: 3, title: "The Grand Basin",
             tagline: "All banners on the water.",
             narration: "It ends where every river ends: the Grand Basin, the Mouth, the sea-gate of the world. Stonelock's dams, Goldwater's florins, Redwake's rams — all three great houses sail against you at once, and the pirate crowns circle the middle water like gulls over a wreck. You have three landings, two shipyards, and the flood calendar on your side. Take the Mouth, hold it three turns, and the river is yours forever.",
             turnCap: 26, starTurn: 18, fog: true, flood: 6, pirates: true,
             oppLine: "vs all three barons (HARD) — fog, floods, pirates")
    ]

    static func meta(_ id: Int) -> Meta? {
        for m in all where m.id == id { return m }
        return nil
    }

    // MARK: - Blueprint plumbing

    private struct Blueprint {
        var nodes: [(String, Character, Double, Double)] = []   // name, kind h/i/c/m, x, y
        var edges: [(Int, Int)] = []                            // 1-based ordinals, up -> down
        var tolls: [Int] = []                                   // edge ordinals
        var dams: [(Int, Int)] = []                             // edge ordinal, seat
        var owners: [(Int, Int, Int, Bool)] = []                // node ordinal, seat, dock, yard
        var neutralDocks: [(Int, Int)] = []                     // node ordinal, dock level
        var fleets: [(Int, Int, Int)] = []                      // node ordinal, seat, strength
        var pirates: [(Int, Int)] = []                          // node ordinal, strength
        var barons: [(String, String, String, Int)] = []        // name, persona, difficulty, florins
        var playerFlorins: Int = 14
        var mouthGuard: Int = 8    // neutral Harbor Garrison strength at the Mouth
    }

    private static func kind(_ c: Character) -> CTCNodeKind {
        switch c {
        case "i": return .island
        case "c": return .confluence
        case "m": return .mouth
        default: return .harbor
        }
    }

    private static func assemble(_ bp: Blueprint, meta: Meta, seed: UInt64, playerColor: Int) -> GameState {
        var s = GameState()
        for (i, spec) in bp.nodes.enumerated() {
            let n = CTCNode(id: i + 1, name: spec.0, kind: kind(spec.1), x: spec.2, y: spec.3)
            s.nodes.append(n)
            if n.kind == .mouth { s.mouthID = n.id }
        }
        for (i, e) in bp.edges.enumerated() {
            var edge = CTCEdge(id: i + 1, from: e.0, to: e.1)
            edge.toll = bp.tolls.contains(i + 1)
            s.edges.append(edge)
        }
        for d in bp.dams {
            if let ei = s.edgeIndex(d.0) { s.edges[ei].damOwner = d.1 }
        }
        for o in bp.owners {
            if let ni = s.nodeIndex(o.0) {
                s.nodes[ni].owner = o.1
                s.nodes[ni].dock = o.2
                s.nodes[ni].yard = o.3
            }
        }
        for nd in bp.neutralDocks {
            if let ni = s.nodeIndex(nd.0) { s.nodes[ni].dock = nd.1 }
        }

        var colorPool = [1, 0, 2, 3, 4, 5].filter { $0 != playerColor }
        var human = CTCPlayer(idx: 0, name: "You", colorID: playerColor, florins: bp.playerFlorins,
                             isHuman: true, persona: "merchant", difficulty: "hard")
        human.eliminated = false
        s.players.append(human)
        for (i, b) in bp.barons.enumerated() {
            let color = colorPool.isEmpty ? i + 1 : colorPool.removeFirst()
            let pl = CTCPlayer(idx: i + 1, name: b.0, colorID: color, florins: b.3,
                              isHuman: false, persona: b.1, difficulty: b.2)
            s.players.append(pl)
        }
        for f in bp.fleets {
            s.fleets.append(CTCFleet(id: s.nextFleetID, owner: f.1, node: f.0, strength: f.2, mp: CTCEngine.fleetMP))
            s.nextFleetID += 1
        }
        for p in bp.pirates {
            s.fleets.append(CTCFleet(id: s.nextFleetID, owner: -1, node: p.0, strength: p.1, mp: 0))
            s.nextFleetID += 1
        }
        if bp.mouthGuard > 0 {
            s.fleets.append(CTCFleet(id: s.nextFleetID, owner: CTCEngine.garrisonOwner,
                                    node: s.mouthID, strength: bp.mouthGuard, mp: 0))
            s.nextFleetID += 1
        }

        s.turnCap = meta.turnCap
        s.fogEnabled = meta.fog
        s.floodEvery = meta.flood
        s.piratesOn = meta.pirates
        s.rng = CTCRandom(seed: seed &* 6364136223846793005 &+ UInt64(meta.id))
        s.mapW = 1000
        s.mapH = 1400
        s.normalizeTallies()
        CTCEngine.setupMatch(&s)
        return s
    }

    /// Builds a fresh scenario state, or nil for an unknown id.
    static func make(id: Int, seed: UInt64, playerColor: Int = 0) -> GameState? {
        guard let m = meta(id) else { return nil }
        let bp: Blueprint
        switch id {
        case 1: bp = map1()
        case 2: bp = map2()
        case 3: bp = map3()
        case 4: bp = map4()
        case 5: bp = map5()
        case 6: bp = map6()
        case 7: bp = map7()
        case 8: bp = map8()
        case 9: bp = map9()
        case 10: bp = map10()
        case 11: bp = map11()
        case 12: bp = map12()
        case 13: bp = map13()
        default: bp = map14()
        }
        return assemble(bp, meta: m, seed: seed, playerColor: playerColor)
    }

    // MARK: - Act I

    private static func map1() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Reedmere", "h", 250, 150), ("Willowford", "i", 300, 320),
            ("Otterbank", "h", 260, 500), ("Gullcross", "c", 480, 650),
            ("Alderquay", "h", 740, 160), ("Stonewick", "i", 700, 330),
            ("Marshgate", "h", 660, 500), ("Saltmoor", "i", 460, 820),
            ("Heronrest", "h", 660, 950), ("Fenholm", "i", 320, 950),
            ("Cranepoint", "c", 500, 1090), ("The Mouth", "m", 500, 1270)
        ]
        b.edges = [(1,2),(2,3),(3,4),(5,6),(6,7),(7,4),(4,8),(8,11),(9,11),(10,11),(11,12)]
        b.owners = [(1, 0, 1, true), (5, 1, 1, true)]
        b.fleets = [(1, 0, 3), (5, 1, 3)]
        b.barons = [("Baron Goldwater", "merchant", "easy", 10)]
        b.playerFlorins = 14
        b.mouthGuard = 6
        return b
    }

    private static func map2() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Bramstead", "h", 200, 140), ("Ashmere", "i", 260, 310),
            ("Eelbank", "h", 240, 480), ("Swancross", "c", 430, 630),
            ("Redwake Quay", "h", 780, 150), ("Thornholm", "i", 730, 320),
            ("Pikegate", "h", 770, 490), ("Mosswick", "i", 600, 560),
            ("Rushford", "h", 360, 810), ("Carpshoal", "i", 590, 800),
            ("Cranemoor", "c", 500, 980), ("Saltrest", "h", 480, 1130),
            ("The Mouth", "m", 500, 1290)
        ]
        b.edges = [(1,2),(2,3),(3,4),(5,6),(6,7),(7,8),(8,4),(4,9),(4,10),(9,11),(10,11),(11,12),(12,13)]
        b.owners = [(1, 0, 1, true), (5, 1, 1, true)]
        b.fleets = [(1, 0, 3), (5, 1, 4)]
        b.barons = [("Baroness Redwake", "corsair", "easy", 10)]
        b.playerFlorins = 14
        b.mouthGuard = 6
        return b
    }

    private static func map3() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Greymere", "h", 150, 150), ("Willowreach", "i", 230, 320),
            ("Otterholm", "h", 180, 500), ("Ferrycross", "c", 350, 660),
            ("Goldwater Quay", "h", 820, 180), ("Ambergate", "h", 760, 350),
            ("Saltshoal", "i", 800, 520), ("Woldbank", "i", 610, 610),
            ("Tarnford", "c", 420, 840), ("Millcross", "c", 560, 970),
            ("Fenrest", "i", 250, 900), ("Copperwick", "h", 730, 860),
            ("Eelmoor", "i", 500, 1130), ("The Mouth", "m", 500, 1290)
        ]
        b.edges = [(1,2),(2,3),(3,4),(5,6),(6,7),(7,8),(8,4),(4,9),(11,9),(9,10),(12,10),(10,13),(13,14)]
        b.tolls = [8, 12]   // Ferrycross->Tarnford, Millcross->Eelmoor
        b.owners = [(1, 0, 1, true), (5, 1, 1, true)]
        b.fleets = [(1, 0, 3), (5, 1, 3)]
        b.barons = [("Baron Goldwater", "merchant", "easy", 11)]
        b.playerFlorins = 15
        b.mouthGuard = 7
        return b
    }

    private static func map4() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Heronmere", "h", 200, 140), ("Reedford", "i", 280, 300),
            ("Marshbank", "h", 230, 470), ("Gullgate", "c", 450, 620),
            ("Redwake Roost", "h", 800, 150), ("Pikeholm", "i", 750, 320),
            ("Thornquay", "h", 780, 490), ("Brackwater", "i", 610, 560),
            ("Ottershoal", "i", 350, 800), ("Swanpoint", "h", 620, 830),
            ("Saltcross", "c", 490, 990), ("Cranebank", "h", 320, 1000),
            ("Rushrest", "i", 640, 1090), ("The Mouth", "m", 500, 1270)
        ]
        b.edges = [(1,2),(2,3),(3,4),(5,6),(6,7),(7,8),(8,4),(4,9),(4,10),(9,11),(10,11),(12,11),(11,14),(13,14)]
        b.owners = [(1, 0, 1, true), (5, 1, 1, true)]
        b.fleets = [(1, 0, 3), (5, 1, 3)]
        b.pirates = [(8, 4), (9, 4)]
        b.barons = [("Baroness Redwake", "corsair", "easy", 10)]
        b.playerFlorins = 14
        b.mouthGuard = 7
        return b
    }

    // MARK: - Act II

    private static func map5() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Aldermere", "h", 140, 140), ("Willowwick", "i", 200, 300),
            ("Stonebank", "h", 160, 470), ("Ferryholm", "i", 240, 640),
            ("Greatcross", "c", 420, 900), ("Goldwater Rest", "h", 860, 140),
            ("Amberford", "i", 800, 300), ("Wrenfork", "c", 730, 470),
            ("Saltgate", "h", 660, 660), ("Redwake Landing", "h", 560, 180),
            ("Mossmere", "i", 600, 350), ("Carpbank", "i", 540, 780),
            ("Fenpoint", "h", 300, 1050), ("Rushshoal", "i", 620, 1010),
            ("Swanrest", "c", 480, 1140), ("The Mouth", "m", 500, 1300)
        ]
        b.edges = [(1,2),(2,3),(3,4),(4,5),(6,7),(7,8),(8,9),(9,5),(10,11),(11,8),
                   (5,13),(5,14),(12,14),(13,15),(14,15),(15,16)]
        b.owners = [(1, 0, 1, true), (6, 1, 1, true), (10, 2, 1, true)]
        b.fleets = [(1, 0, 3), (6, 1, 3), (10, 2, 3)]
        b.barons = [("Baron Goldwater", "merchant", "normal", 11),
                    ("Baroness Redwake", "corsair", "normal", 11)]
        b.playerFlorins = 15
        return b
    }

    private static func map6() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Tarnmere", "h", 170, 150), ("Ashford", "i", 240, 310),
            ("Eelwick", "h", 200, 480), ("Bramcross", "c", 400, 650),
            ("Stonelock Keep", "h", 830, 160), ("Milldam Rise", "i", 780, 330),
            ("Woldgate", "h", 810, 500), ("Copperholm", "i", 640, 590),
            ("Goldwater Landing", "h", 520, 140), ("Amberbank", "i", 560, 320),
            ("Heronshoal", "i", 350, 850), ("Pikemoor", "h", 640, 830),
            ("Saltford", "c", 500, 1000), ("Cranewick", "h", 300, 1060),
            ("Rushpoint", "i", 680, 1060), ("The Mouth", "m", 500, 1280)
        ]
        b.edges = [(1,2),(2,3),(3,4),(9,10),(10,4),(5,6),(6,7),(7,8),(8,12),
                   (4,11),(11,13),(12,13),(14,13),(13,16),(15,16)]
        // Seat 0 opens a step ahead on the flood river: fortified home dock and a
        // stronger keel, so the merchant can contest the Mouth before the rivals.
        b.owners = [(1, 0, 2, true), (5, 1, 1, true), (9, 2, 1, true)]
        b.fleets = [(1, 0, 5), (5, 1, 3), (9, 2, 3)]
        b.barons = [("Baron Stonelock", "engineer", "normal", 10),
                    ("Baron Goldwater", "merchant", "normal", 10)]
        b.playerFlorins = 17
        b.mouthGuard = 7
        return b
    }

    private static func map7() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Greyreach", "h", 150, 140), ("Bramholm", "i", 260, 260),
            ("Willowmoor", "h", 340, 400), ("Ottercross", "c", 300, 560),
            ("Fenwick", "i", 180, 460), ("Saltmere", "h", 460, 700),
            ("Redwake Hold", "h", 850, 150), ("Thornbank", "i", 780, 300),
            ("Pikerest", "h", 830, 450), ("Stonelock Sluice", "h", 640, 140),
            ("Mosswold", "i", 690, 300), ("Eelcross", "c", 720, 590),
            ("Carpgate", "h", 600, 760), ("Ambershoal", "i", 420, 880),
            ("Heronmoor", "c", 560, 1000), ("Gullbank", "h", 250, 950),
            ("Swanwick", "i", 700, 1120), ("The Mouth", "m", 500, 1280)
        ]
        b.edges = [(1,2),(2,3),(3,4),(5,4),(4,6),(7,8),(8,9),(9,12),(10,11),(11,12),
                   (12,13),(6,14),(13,15),(14,15),(16,15),(15,18),(17,18)]
        b.tolls = [12, 13]   // Saltmere->Ambershoal, Carpgate->Heronmoor
        b.owners = [(1, 0, 1, true), (7, 1, 1, true), (10, 2, 1, true)]
        b.fleets = [(1, 0, 3), (7, 1, 3), (10, 2, 3)]
        b.barons = [("Baroness Redwake", "corsair", "normal", 12),
                    ("Baron Stonelock", "engineer", "normal", 12)]
        b.playerFlorins = 15
        return b
    }

    private static func map8() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Aldergate", "h", 180, 140), ("Reedholm", "i", 260, 300),
            ("Gullwick", "h", 220, 470), ("Ferrymere", "h", 420, 620),
            ("Goldwater Seat", "h", 820, 150), ("Amberrest", "i", 760, 310),
            ("Saltbank", "h", 800, 480), ("Wrencross", "c", 640, 620),
            ("Redwake Perch", "h", 520, 150), ("Mossford", "i", 560, 330),
            ("Pearlshoal", "i", 350, 800), ("Crownholm", "i", 640, 800),
            ("Silverbank", "i", 500, 900), ("Swanford", "c", 480, 1050),
            ("Otterpoint", "h", 300, 1000), ("Carpmoor", "i", 700, 1000),
            ("Rushgate", "h", 520, 1180), ("The Mouth", "m", 500, 1300)
        ]
        b.edges = [(1,2),(2,3),(3,4),(5,6),(6,7),(7,8),(9,10),(10,8),(4,11),(8,12),
                   (11,13),(12,13),(13,14),(15,14),(16,14),(14,17),(17,18)]
        b.owners = [(1, 0, 1, true), (5, 1, 1, true), (9, 2, 1, true)]
        b.neutralDocks = [(11, 1), (12, 1), (13, 2)]
        b.fleets = [(1, 0, 3), (5, 1, 3), (9, 2, 3)]
        b.barons = [("Baron Goldwater", "merchant", "normal", 12),
                    ("Baroness Redwake", "corsair", "normal", 12)]
        b.playerFlorins = 15
        return b
    }

    private static func map9() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Fenmere", "h", 160, 150), ("Ashbank", "i", 240, 310),
            ("Otterwold", "h", 200, 480), ("Bramgate", "c", 400, 650),
            ("Stonelock Sluice", "h", 840, 150), ("Copperdam", "i", 780, 320),
            ("Wickgate", "h", 820, 490), ("Milldike", "i", 650, 600),
            ("Milldam Keep", "h", 540, 150), ("Greyford", "i", 580, 330),
            ("Saltmoor", "i", 350, 850), ("Pikewick", "h", 640, 840),
            ("Heroncross", "c", 500, 1010), ("Swanshoal", "i", 300, 1050),
            ("Carprest", "h", 700, 1060), ("Eelpoint", "i", 420, 1160),
            ("Gullford", "h", 580, 1160), ("The Mouth", "m", 500, 1300)
        ]
        b.edges = [(1,2),(2,3),(3,4),(9,10),(10,4),(5,6),(6,7),(7,8),(8,12),(4,11),
                   (11,13),(12,13),(14,16),(16,18),(15,17),(17,18),(13,18)]
        b.dams = [(11, 1), (12, 2)]   // both channels above Heroncross are walled
        b.owners = [(1, 0, 1, true), (5, 1, 1, true), (9, 2, 1, true)]
        b.fleets = [(1, 0, 3), (5, 1, 3), (9, 2, 3)]
        b.barons = [("Baron Stonelock", "engineer", "normal", 12),
                    ("Baron Milldam", "engineer", "normal", 12)]
        b.playerFlorins = 16
        return b
    }

    // MARK: - Act III

    private static func map10() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Willowmere", "h", 150, 140), ("Alderford", "i", 230, 300),
            ("Stonewick", "h", 190, 470), ("Herongate", "h", 380, 630),
            ("Redwake Throne", "h", 850, 140), ("Thornrest", "i", 790, 300),
            ("Pikebank", "h", 830, 470), ("Mosscross", "c", 660, 620),
            ("Goldwater Hall", "h", 540, 150), ("Amberholm", "i", 580, 320),
            ("Saltford", "c", 340, 840), ("Carpgate", "c", 650, 830),
            ("Wrenshoal", "c", 500, 1000), ("Fenbank", "h", 260, 990),
            ("Rushmoor", "i", 700, 1030), ("Gullrest", "h", 180, 780),
            ("Swanpoint", "i", 420, 1140), ("Eelwick", "h", 580, 1140),
            ("Otterknoll", "i", 760, 900), ("The Mouth", "m", 500, 1300)
        ]
        b.edges = [(1,2),(2,3),(3,4),(5,6),(6,7),(7,8),(9,10),(10,8),(4,11),(16,11),
                   (8,12),(19,12),(11,13),(12,13),(14,13),(13,17),(13,18),(15,18),(17,20),(18,20)]
        b.owners = [(1, 0, 1, true), (5, 1, 1, true), (9, 2, 1, true)]
        b.fleets = [(1, 0, 4), (5, 1, 3), (7, 1, 3), (9, 2, 3)]
        b.barons = [("Baroness Redwake", "corsair", "hard", 13),
                    ("Baron Goldwater", "merchant", "normal", 12)]
        b.playerFlorins = 18
        b.mouthGuard = 9
        return b
    }

    private static func map11() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Greymoor", "h", 150, 140), ("Bramwick", "i", 240, 290),
            ("Fenholm", "h", 200, 450), ("Ottergate", "h", 380, 600),
            ("Stonelock Bastion", "h", 850, 140), ("Milldike", "i", 780, 300),
            ("Copperbank", "h", 820, 460), ("Wickcross", "c", 650, 600),
            ("Redwake Nest", "h", 530, 150), ("Mossmere", "i", 570, 320),
            ("Saltshoal", "c", 330, 800), ("Carpholm", "c", 650, 800),
            ("Tarncross", "c", 490, 960), ("Ashbank", "h", 250, 950),
            ("Rushrest", "i", 710, 990), ("Gullmoor", "h", 160, 730),
            ("Swanshoal", "i", 410, 1100), ("Eelgate", "h", 590, 1100),
            ("Pikepoint", "i", 780, 850), ("Heronwold", "i", 100, 560),
            ("Willowknoll", "h", 900, 700), ("The Mouth", "m", 500, 1290)
        ]
        b.edges = [(1,2),(2,3),(3,4),(5,6),(6,7),(7,8),(9,10),(10,8),(4,11),(8,12),
                   (20,16),(16,11),(21,19),(19,12),(11,13),(12,13),(14,13),(13,17),(13,18),
                   (15,18),(17,22),(18,22),(4,8),(11,12)]
        b.tolls = [23, 24]   // the two silt canals
        b.owners = [(1, 0, 1, true), (5, 1, 1, true), (9, 2, 1, true)]
        b.fleets = [(1, 0, 4), (5, 1, 3), (9, 2, 3)]
        b.barons = [("Baron Stonelock", "engineer", "hard", 14),
                    ("Baroness Redwake", "corsair", "normal", 12)]
        b.playerFlorins = 18
        b.mouthGuard = 9
        return b
    }

    private static func map12() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Alderholm", "h", 160, 140), ("Reedwick", "i", 240, 300),
            ("Ottermere", "h", 200, 470), ("Gullbend", "h", 390, 630),
            ("Goldwater Crown", "h", 850, 150), ("Amberwold", "i", 790, 310),
            ("Saltrest", "h", 830, 480), ("Wrengate", "c", 660, 630),
            ("Redwake Berth", "h", 540, 150), ("Mossbank", "i", 580, 320),
            ("Brackshoal", "c", 340, 830), ("Carpcross", "c", 660, 830),
            ("Heronford", "c", 500, 1000), ("Fenwick", "h", 260, 990),
            ("Rushholm", "i", 710, 1010), ("Swanmoor", "h", 170, 760),
            ("Eelshoal", "i", 420, 1130), ("Pikegate", "h", 590, 1130),
            ("Tarnpoint", "i", 780, 900), ("Willowbank", "h", 100, 570),
            ("Stonequay", "h", 900, 720), ("The Mouth", "m", 500, 1300)
        ]
        b.edges = [(1,2),(2,3),(3,4),(5,6),(6,7),(7,8),(9,10),(10,8),(4,11),(8,12),
                   (20,16),(16,11),(21,19),(19,12),(11,13),(12,13),(14,13),(13,17),(13,18),
                   (15,18),(17,22),(18,22)]
        b.owners = [(1, 0, 1, true), (5, 1, 1, true), (9, 2, 1, true)]
        b.fleets = [(1, 0, 4), (5, 1, 3), (9, 2, 3)]
        b.pirates = [(11, 5), (15, 5), (13, 5)]
        b.barons = [("Baron Goldwater", "merchant", "hard", 20),
                    ("Baroness Redwake", "corsair", "normal", 12)]
        b.playerFlorins = 16
        b.mouthGuard = 9
        return b
    }

    private static func map13() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Willowhall", "h", 150, 140), ("Aldermoor", "i", 230, 300),
            ("Stonebank", "h", 190, 470), ("Ferrygate", "h", 380, 630),
            ("Stonelock Citadel", "h", 860, 140), ("Copperwold", "i", 790, 300),
            ("Milldike", "h", 830, 470), ("Wickmoor", "c", 660, 630),
            ("Goldwater Palace", "h", 540, 150), ("Amberwick", "i", 580, 320),
            ("Saltcross", "c", 340, 830), ("Carpmere", "c", 660, 830),
            ("The Last Confluence", "c", 500, 1010), ("Fenrest", "h", 250, 990),
            ("Rushbank", "i", 710, 1020), ("Gullholm", "h", 170, 760),
            ("Swanwick", "i", 420, 1140), ("Eelford", "h", 590, 1140),
            ("Herongate", "i", 780, 900), ("Tarnmoor", "h", 100, 570),
            ("Pikeknoll", "h", 900, 710), ("Mosspoint", "i", 300, 1180),
            ("Otterknoll", "i", 700, 1180), ("The Mouth", "m", 500, 1300)
        ]
        b.edges = [(1,2),(2,3),(3,4),(5,6),(6,7),(7,8),(9,10),(10,8),(4,11),(8,12),
                   (20,16),(16,11),(21,19),(19,12),(11,13),(12,13),(14,13),(13,17),(13,18),
                   (15,18),(17,24),(18,24),(22,24),(23,24)]
        b.owners = [(1, 0, 2, true), (2, 0, 0, false), (5, 1, 1, true), (9, 2, 1, true)]
        b.fleets = [(1, 0, 4), (2, 0, 3), (5, 1, 3), (7, 1, 3), (9, 2, 3), (10, 2, 3)]
        b.barons = [("Baron Stonelock", "engineer", "hard", 14),
                    ("Baron Goldwater", "merchant", "hard", 14)]
        b.playerFlorins = 20
        b.mouthGuard = 9
        return b
    }

    private static func map14() -> Blueprint {
        var b = Blueprint()
        b.nodes = [
            ("Barons Rest", "h", 150, 140), ("Willowmarch", "i", 230, 300),
            ("Greyhaven", "h", 190, 470), ("Fordcross", "h", 380, 630),
            ("Stonelock Grand Sluice", "h", 870, 140), ("Copperreach", "i", 800, 300),
            ("Damgate", "h", 840, 470), ("Wickford", "c", 670, 630),
            ("Goldwater Grand Hall", "h", 550, 150), ("Ambermoor", "i", 590, 320),
            ("Saltmere", "c", 340, 840), ("Carpwold", "c", 660, 840),
            ("The Grand Basin", "c", 500, 1010), ("Fenholm", "h", 250, 990),
            ("Rushwick", "i", 720, 1020), ("Gullbank", "h", 170, 760),
            ("Swanshoal", "i", 420, 1150), ("Eelrest", "h", 590, 1150),
            ("Heronpoint", "c", 790, 910), ("Tarngate", "h", 100, 570),
            ("Pikemoor", "h", 910, 710), ("Redwake Grand Berth", "h", 930, 560),
            ("Mosskeep", "i", 300, 1190), ("Otterwold", "i", 700, 1190),
            ("Cranemarsh", "i", 500, 700), ("The Mouth", "m", 500, 1310)
        ]
        b.edges = [(1,2),(2,3),(3,4),(5,6),(6,7),(7,8),(9,10),(10,8),(4,11),(8,12),
                   (20,16),(16,11),(21,19),(22,19),(19,12),(11,13),(12,13),(14,13),(13,17),
                   (13,18),(15,18),(17,26),(18,26),(23,26),(24,26),(4,25),(25,12)]
        b.owners = [(1, 0, 2, true), (2, 0, 0, false), (3, 0, 1, true),
                    (5, 1, 1, true), (9, 2, 1, true), (22, 3, 1, true)]
        b.fleets = [(1, 0, 4), (3, 0, 3), (5, 1, 3), (7, 1, 3), (9, 2, 3), (10, 2, 3), (22, 3, 4)]
        b.pirates = [(13, 5), (25, 4)]
        b.barons = [("Baron Stonelock", "engineer", "hard", 15),
                    ("Baron Goldwater", "merchant", "hard", 16),
                    ("Baroness Redwake", "corsair", "hard", 14)]
        b.playerFlorins = 20
        b.mouthGuard = 10
        return b
    }
}
