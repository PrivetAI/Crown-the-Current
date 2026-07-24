import SwiftUI
import AudioToolbox
import UIKit

// MARK: - Persistent root state (single Codable blob under rvb.state.v1)

struct RBStats: Codable {
    var matchesPlayed: Int = 0
    var matchesWon: Int = 0
    var battles: Int = 0
    var fleetsSunk: Int = 0
    var fleetsLost: Int = 0
    var damsBuilt: Int = 0
    var damsBreached: Int = 0
    var piratesSunk: Int = 0
    var skirmishWins: Int = 0
    var campaignWins: Int = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        matchesPlayed = try c.decodeIfPresent(Int.self, forKey: .matchesPlayed) ?? 0
        matchesWon = try c.decodeIfPresent(Int.self, forKey: .matchesWon) ?? 0
        battles = try c.decodeIfPresent(Int.self, forKey: .battles) ?? 0
        fleetsSunk = try c.decodeIfPresent(Int.self, forKey: .fleetsSunk) ?? 0
        fleetsLost = try c.decodeIfPresent(Int.self, forKey: .fleetsLost) ?? 0
        damsBuilt = try c.decodeIfPresent(Int.self, forKey: .damsBuilt) ?? 0
        damsBreached = try c.decodeIfPresent(Int.self, forKey: .damsBreached) ?? 0
        piratesSunk = try c.decodeIfPresent(Int.self, forKey: .piratesSunk) ?? 0
        skirmishWins = try c.decodeIfPresent(Int.self, forKey: .skirmishWins) ?? 0
        campaignWins = try c.decodeIfPresent(Int.self, forKey: .campaignWins) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case matchesPlayed, matchesWon, battles, fleetsSunk, fleetsLost
        case damsBuilt, damsBreached, piratesSunk, skirmishWins, campaignWins
    }
}

struct RBSettingsState: Codable {
    var sound: Bool = true
    var haptics: Bool = true
    var battleDetail: Bool = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? true
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        battleDetail = try c.decodeIfPresent(Bool.self, forKey: .battleDetail) ?? true
    }

    private enum CodingKeys: String, CodingKey { case sound, haptics, battleDetail }
}

struct RootState: Codable {
    var scenarioStars: [Int: Int] = [:]      // scenario id -> best stars (1...3)
    var achievements: [String] = []
    var stats: RBStats = RBStats()
    var selectedBanner: Int = 0
    var settings: RBSettingsState = RBSettingsState()
    var activeMatch: MatchState? = nil
    var onboardingDone: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scenarioStars = try c.decodeIfPresent([Int: Int].self, forKey: .scenarioStars) ?? [:]
        achievements = try c.decodeIfPresent([String].self, forKey: .achievements) ?? []
        stats = try c.decodeIfPresent(RBStats.self, forKey: .stats) ?? RBStats()
        selectedBanner = try c.decodeIfPresent(Int.self, forKey: .selectedBanner) ?? 0
        settings = try c.decodeIfPresent(RBSettingsState.self, forKey: .settings) ?? RBSettingsState()
        activeMatch = try c.decodeIfPresent(MatchState.self, forKey: .activeMatch)
        onboardingDone = try c.decodeIfPresent(Bool.self, forKey: .onboardingDone) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case scenarioStars, achievements, stats, selectedBanner, settings, activeMatch, onboardingDone
    }

    var totalStars: Int { scenarioStars.values.reduce(0, +) }

    func isScenarioUnlocked(_ id: Int) -> Bool {
        if id <= 1 { return true }
        return (scenarioStars[id - 1] ?? 0) > 0
    }

    func isActComplete(_ act: Int) -> Bool {
        let ids = RBScenarios.all.filter { $0.act == act }.map { $0.id }
        return !ids.isEmpty && ids.allSatisfy { (scenarioStars[$0] ?? 0) > 0 }
    }

    func isBannerUnlocked(_ id: Int) -> Bool {
        switch id {
        case 0: return true
        case 1: return !scenarioStars.isEmpty
        case 2: return isActComplete(1)
        case 3: return isActComplete(2)
        case 4: return stats.skirmishWins > 0
        default: return totalStars >= 20
        }
    }

    static func bannerHint(_ id: Int) -> String {
        switch id {
        case 0: return "Your house colors."
        case 1: return "Win a campaign scenario."
        case 2: return "Complete Act I."
        case 3: return "Complete Act II."
        case 4: return "Win a skirmish."
        default: return "Earn 20 campaign stars."
        }
    }
}

// MARK: - Achievements

struct RBAchievement: Identifiable {
    let id: String
    let title: String
    let detail: String
}

enum RBAchievements {
    static let all: [RBAchievement] = [
        RBAchievement(id: "first_win", title: "First Colors", detail: "Win your first match."),
        RBAchievement(id: "delta_lord", title: "Lord of the Delta", detail: "Complete Act I of the campaign."),
        RBAchievement(id: "twin_baron", title: "Baron of Twin Rivers", detail: "Complete Act II of the campaign."),
        RBAchievement(id: "basin_crown", title: "Crown of the Basin", detail: "Complete Act III of the campaign."),
        RBAchievement(id: "mouth_rush", title: "Swift Current", detail: "Win by holding the Mouth on or before turn 12."),
        RBAchievement(id: "node_baron", title: "Landlord", detail: "Win by holding the most landings at the turn cap."),
        RBAchievement(id: "clean_sweep", title: "Clean Sweep", detail: "Win by eliminating every rival baron."),
        RBAchievement(id: "no_dams", title: "Free Waters", detail: "Win a match without building a single dam."),
        RBAchievement(id: "dam_builder", title: "Stonewright", detail: "Build your first dam."),
        RBAchievement(id: "dam_breaker", title: "Breaker of Walls", detail: "Breach an enemy dam."),
        RBAchievement(id: "full_sail", title: "Full Sail", detail: "Field a fleet of strength 12."),
        RBAchievement(id: "rich_baron", title: "Vault of Florins", detail: "Hold 60 florins at once."),
        RBAchievement(id: "confluence_crown", title: "Confluence Crown", detail: "Control every confluence on the map at once."),
        RBAchievement(id: "pirate_bane", title: "Pirate's Bane", detail: "Sink a pirate fleet."),
        RBAchievement(id: "untouched", title: "Untouched Hulls", detail: "Win a match without losing a fleet."),
        RBAchievement(id: "corsair_slayer", title: "Corsair Slayer", detail: "Win a match against a Hard Corsair."),
        RBAchievement(id: "star_12", title: "Twelve Stars", detail: "Earn 12 campaign stars."),
        RBAchievement(id: "star_all", title: "Every Star on the Water", detail: "Earn all 42 campaign stars."),
        RBAchievement(id: "skirmish_large", title: "Admiral of the Basin", detail: "Win a skirmish on a large river."),
        RBAchievement(id: "sunk_50", title: "Fifty Fathoms", detail: "Sink 50 enemy fleets in your career.")
    ]
}

// MARK: - Store

final class RBStore: ObservableObject {
    static let shared = RBStore()
    static let storageKey = "rvb.state.v1"

    @Published var root: RootState
    @Published var toast: String? = nil

    private init() {
        if let data = UserDefaults.standard.data(forKey: RBStore.storageKey),
           let decoded = try? JSONDecoder().decode(RootState.self, from: data) {
            root = decoded
        } else {
            root = RootState()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(root) {
            UserDefaults.standard.set(data, forKey: RBStore.storageKey)
        }
    }

    func resetAll() {
        root = RootState()
        UserDefaults.standard.removeObject(forKey: RBStore.storageKey)
    }

    /// Unlocks an achievement; shows a toast the first time.
    func unlock(_ id: String) {
        guard !root.achievements.contains(id) else { return }
        root.achievements.append(id)
        if let a = RBAchievements.all.first(where: { $0.id == id }) {
            showToast("Achievement — \(a.title)")
        }
        save()
    }

    func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.25)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            withAnimation(.easeIn(duration: 0.3)) {
                if self?.toast == text { self?.toast = nil }
            }
        }
    }

    // MARK: feedback

    func tap() {
        if root.settings.sound { AudioServicesPlaySystemSound(1104) }
        if root.settings.haptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func thud() {
        if root.settings.sound { AudioServicesPlaySystemSound(1105) }
        if root.settings.haptics {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    func fanfare() {
        if root.settings.sound { AudioServicesPlaySystemSound(1025) }
        if root.settings.haptics {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Match completion bookkeeping

    /// Applies results of a finished match: stats, stars, achievements, banner
    /// unlock toasts. Returns earned stars for campaign matches (0 for loss).
    @discardableResult
    func applyMatchResult(state: GameState, mode: String, scenarioID: Int, skirmish: SkirmishConfig) -> Int {
        let won = state.winner == 0
        root.stats.matchesPlayed += 1
        root.stats.battles += state.battlesCount
        if !state.sunk.isEmpty { root.stats.fleetsSunk += state.sunk[0] }
        if !state.lostFleet.isEmpty && state.lostFleet[0] { root.stats.fleetsLost += 1 }
        if !state.damsBuiltCount.isEmpty { root.stats.damsBuilt += state.damsBuiltCount[0] }
        if !state.breachedDam.isEmpty && state.breachedDam[0] { root.stats.damsBreached += 1 }

        var stars = 0
        if won {
            root.stats.matchesWon += 1
            if mode == "campaign" {
                root.stats.campaignWins += 1
                if let meta = RBScenarios.meta(scenarioID) {
                    stars = 1
                    if state.turn <= meta.starTurn { stars += 1 }
                    if !state.lostShipyard.isEmpty && !state.lostShipyard[0] { stars += 1 }
                    let prev = root.scenarioStars[scenarioID] ?? 0
                    root.scenarioStars[scenarioID] = max(prev, stars)
                }
            } else {
                root.stats.skirmishWins += 1
            }
        }

        // Match-scoped achievements.
        if won {
            unlock("first_win")
            if state.winKind == "mouth" && state.turn <= 12 { unlock("mouth_rush") }
            if state.winKind == "nodes" { unlock("node_baron") }
            if state.winKind == "elimination" { unlock("clean_sweep") }
            if !state.damsBuiltCount.isEmpty && state.damsBuiltCount[0] == 0 { unlock("no_dams") }
            if !state.lostFleet.isEmpty && !state.lostFleet[0] { unlock("untouched") }
            if state.players.contains(where: { !$0.isHuman && $0.persona == "corsair" && $0.difficulty == "hard" }) {
                unlock("corsair_slayer")
            }
            if mode == "skirmish" && skirmish.size == 2 { unlock("skirmish_large") }
            if root.isActComplete(1) { unlock("delta_lord") }
            if root.isActComplete(2) { unlock("twin_baron") }
            if root.isActComplete(3) { unlock("basin_crown") }
        }
        if !state.damsBuiltCount.isEmpty && state.damsBuiltCount[0] > 0 { unlock("dam_builder") }
        if !state.breachedDam.isEmpty && state.breachedDam[0] { unlock("dam_breaker") }
        if !state.maxStack.isEmpty && state.maxStack[0] >= RBEngine.maxStackSize { unlock("full_sail") }
        if !state.maxFlorins.isEmpty && state.maxFlorins[0] >= 60 { unlock("rich_baron") }
        if state.heldAllConfluences { unlock("confluence_crown") }

        // Career achievements.
        if root.totalStars >= 12 { unlock("star_12") }
        if root.totalStars >= 42 { unlock("star_all") }
        if root.stats.fleetsSunk >= 50 { unlock("sunk_50") }

        root.activeMatch = nil
        save()
        return stars
    }

    /// Called when the human sinks a pirate fleet (observed via battle reports).
    func notePirateSunk() {
        root.stats.piratesSunk += 1
        unlock("pirate_bane")
        save()
    }
}
