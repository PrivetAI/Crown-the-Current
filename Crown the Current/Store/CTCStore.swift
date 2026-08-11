import SwiftUI
import AudioToolbox
import UIKit

// MARK: - Persistent root state (single Codable blob under rvb.state.v1)

struct CTCStats: Codable {
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

struct CTCSettingsState: Codable {
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
    var stats: CTCStats = CTCStats()
    var selectedBanner: Int = 0
    var settings: CTCSettingsState = CTCSettingsState()
    /// Campaign and skirmish keep separate save slots: starting one mode must
    /// never destroy an unfinished match of the other.
    var activeCampaignMatch: MatchState? = nil
    var activeSkirmishMatch: MatchState? = nil
    var onboardingDone: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scenarioStars = try c.decodeIfPresent([Int: Int].self, forKey: .scenarioStars) ?? [:]
        achievements = try c.decodeIfPresent([String].self, forKey: .achievements) ?? []
        stats = try c.decodeIfPresent(CTCStats.self, forKey: .stats) ?? CTCStats()
        selectedBanner = try c.decodeIfPresent(Int.self, forKey: .selectedBanner) ?? 0
        settings = try c.decodeIfPresent(CTCSettingsState.self, forKey: .settings) ?? CTCSettingsState()
        activeCampaignMatch = try c.decodeIfPresent(MatchState.self, forKey: .activeCampaignMatch)
        activeSkirmishMatch = try c.decodeIfPresent(MatchState.self, forKey: .activeSkirmishMatch)
        onboardingDone = try c.decodeIfPresent(Bool.self, forKey: .onboardingDone) ?? false

        // Saves written before the split kept one shared slot; carry whatever
        // it held into the slot its own mode owns so no progress is stranded.
        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
        if let old = try legacy.decodeIfPresent(MatchState.self, forKey: .activeMatch) {
            if old.mode == "campaign" {
                if activeCampaignMatch == nil { activeCampaignMatch = old }
            } else if activeSkirmishMatch == nil {
                activeSkirmishMatch = old
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case scenarioStars, achievements, stats, selectedBanner, settings
        case activeCampaignMatch, activeSkirmishMatch, onboardingDone
    }

    private enum LegacyCodingKeys: String, CodingKey { case activeMatch }

    /// The unfinished match saved for a mode, if any.
    func activeMatch(mode: String) -> MatchState? {
        mode == "campaign" ? activeCampaignMatch : activeSkirmishMatch
    }

    mutating func setActiveMatch(_ match: MatchState?, mode: String) {
        if mode == "campaign" { activeCampaignMatch = match } else { activeSkirmishMatch = match }
    }

    var totalStars: Int { scenarioStars.values.reduce(0, +) }

    func isScenarioUnlocked(_ id: Int) -> Bool {
        if id <= 1 { return true }
        return (scenarioStars[id - 1] ?? 0) > 0
    }

    func isActComplete(_ act: Int) -> Bool {
        let ids = CTCScenarios.all.filter { $0.act == act }.map { $0.id }
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

struct CTCAchievement: Identifiable {
    let id: String
    let title: String
    let detail: String
}

enum CTCAchievements {
    static let all: [CTCAchievement] = [
        CTCAchievement(id: "first_win", title: "First Colors", detail: "Win your first match."),
        CTCAchievement(id: "delta_lord", title: "Lord of the Delta", detail: "Complete Act I of the campaign."),
        CTCAchievement(id: "twin_baron", title: "Baron of Twin Rivers", detail: "Complete Act II of the campaign."),
        CTCAchievement(id: "basin_crown", title: "Crown of the Basin", detail: "Complete Act III of the campaign."),
        CTCAchievement(id: "mouth_rush", title: "Swift Current", detail: "Win by holding the Mouth on or before turn 12."),
        CTCAchievement(id: "node_baron", title: "Landlord", detail: "Win by holding the most landings at the turn cap."),
        CTCAchievement(id: "clean_sweep", title: "Clean Sweep", detail: "Win by eliminating every rival baron."),
        CTCAchievement(id: "no_dams", title: "Free Waters", detail: "Win a match without building a single dam."),
        CTCAchievement(id: "dam_builder", title: "Stonewright", detail: "Build your first dam."),
        CTCAchievement(id: "dam_breaker", title: "Breaker of Walls", detail: "Breach an enemy dam."),
        CTCAchievement(id: "full_sail", title: "Full Sail", detail: "Field a fleet of strength 12."),
        CTCAchievement(id: "rich_baron", title: "Vault of Florins", detail: "Hold 60 florins at once."),
        CTCAchievement(id: "confluence_crown", title: "Confluence Crown", detail: "Control every confluence on the map at once."),
        CTCAchievement(id: "pirate_bane", title: "Pirate's Bane", detail: "Sink a pirate fleet."),
        CTCAchievement(id: "untouched", title: "Untouched Hulls", detail: "Win a match without losing a fleet."),
        CTCAchievement(id: "corsair_slayer", title: "Corsair Slayer", detail: "Win a match against a Hard Corsair."),
        CTCAchievement(id: "star_12", title: "Twelve Stars", detail: "Earn 12 campaign stars."),
        CTCAchievement(id: "star_all", title: "Every Star on the Water", detail: "Earn all 42 campaign stars."),
        CTCAchievement(id: "skirmish_large", title: "Admiral of the Basin", detail: "Win a skirmish on a large river."),
        CTCAchievement(id: "sunk_50", title: "Fifty Fathoms", detail: "Sink 50 enemy fleets in your career.")
    ]
}

// MARK: - Store

final class CTCStore: ObservableObject {
    static let shared = CTCStore()
    static let storageKey = "rvb.state.v1"

    @Published var root: RootState
    @Published var toast: String? = nil

    private init() {
        if let data = UserDefaults.standard.data(forKey: CTCStore.storageKey),
           let decoded = try? JSONDecoder().decode(RootState.self, from: data) {
            root = decoded
        } else {
            root = RootState()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(root) {
            UserDefaults.standard.set(data, forKey: CTCStore.storageKey)
        }
    }

    func resetAll() {
        root = RootState()
        UserDefaults.standard.removeObject(forKey: CTCStore.storageKey)
    }

    /// Unlocks an achievement; shows a toast the first time.
    func unlock(_ id: String) {
        guard !root.achievements.contains(id) else { return }
        root.achievements.append(id)
        if let a = CTCAchievements.all.first(where: { $0.id == id }) {
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
                if let meta = CTCScenarios.meta(scenarioID) {
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
        if !state.maxStack.isEmpty && state.maxStack[0] >= CTCEngine.maxStackSize { unlock("full_sail") }
        if !state.maxFlorins.isEmpty && state.maxFlorins[0] >= 60 { unlock("rich_baron") }
        if state.heldAllConfluences { unlock("confluence_crown") }

        // Career achievements.
        if root.totalStars >= 12 { unlock("star_12") }
        if root.totalStars >= 42 { unlock("star_all") }
        if root.stats.fleetsSunk >= 50 { unlock("sunk_50") }

        root.setActiveMatch(nil, mode: mode)
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
