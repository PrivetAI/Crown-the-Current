import SwiftUI

struct MoreView: View {
    @ObservedObject var store = RBStore.shared
    @State private var showPrivacy = false
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RBRibbonHeader(title: "More").padding(.top, 6)

                NavigationLink(destination: AlmanacView()) {
                    RBCard {
                        HStack(spacing: 12) {
                            RBBookIcon().stroke(RBTheme.navy, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .frame(width: 26, height: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("The Baron's Almanac").font(RBTheme.display(16)).foregroundColor(RBTheme.ink)
                                Text("Every rule of the river, explained").font(RBTheme.body(12)).foregroundColor(RBTheme.inkSoft)
                            }
                            Spacer()
                            RBChevron(pointRight: true).stroke(RBTheme.inkSoft, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 10, height: 16)
                        }
                    }
                }
                .buttonStyle(.plain)

                RBCard {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Settings").font(RBTheme.display(16)).foregroundColor(RBTheme.navy)
                        settingToggle("Sound", isOn: store.root.settings.sound) {
                            store.root.settings.sound.toggle(); store.save()
                        }
                        divider
                        settingToggle("Haptics", isOn: store.root.settings.haptics) {
                            store.root.settings.haptics.toggle(); store.save()
                        }
                        divider
                        settingToggle("Battle detail", isOn: store.root.settings.battleDetail) {
                            store.root.settings.battleDetail.toggle(); store.save()
                        }
                        Text("Battle detail shows the full attacker-versus-defender math in every report.")
                            .font(RBTheme.body(11)).foregroundColor(RBTheme.inkSoft)
                            .padding(.top, 2)
                    }
                }

                RBCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Privacy").font(RBTheme.display(16)).foregroundColor(RBTheme.navy)
                        Button { store.tap(); showPrivacy = true } label: {
                            HStack {
                                Text("Privacy Policy").font(RBTheme.body(14)).foregroundColor(RBTheme.ink)
                                Spacer()
                                RBChevron(pointRight: true).stroke(RBTheme.inkSoft, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .frame(width: 9, height: 15)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                RBCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Progress").font(RBTheme.display(16)).foregroundColor(RBTheme.navy)
                        if confirmReset {
                            Text("This erases all stars, honours, records and your current match. It cannot be undone.")
                                .font(RBTheme.body(12)).foregroundColor(RBTheme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 10) {
                                Button { confirmReset = false } label: {
                                    Text("Cancel").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(RBButtonStyle(fill: RBTheme.bankGreenDeep))
                                Button {
                                    store.thud(); store.resetAll(); confirmReset = false
                                    store.showToast("Progress reset")
                                } label: {
                                    Text("Erase").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(RBButtonStyle(fill: RBTheme.danger))
                            }
                        } else {
                            Button { store.tap(); confirmReset = true } label: {
                                HStack {
                                    Text("Reset All Progress").font(RBTheme.body(14)).foregroundColor(RBTheme.danger)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                RBCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("River Baron").font(RBTheme.display(16)).foregroundColor(RBTheme.navy)
                        Text("A turn-based strategy of trade and conquest on a living river. Version 1.0.")
                            .font(RBTheme.body(12)).foregroundColor(RBTheme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
        }
        .background(RBTheme.parchment.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showPrivacy) {
            RiverBaronWebPanel(urlString: "https://example.com")
                .edgesIgnoringSafeArea(.bottom)
                .background(Color.black.ignoresSafeArea())
        }
    }

    private var divider: some View {
        Rectangle().fill(RBTheme.cardBorder.opacity(0.5)).frame(height: 1)
    }

    private func settingToggle(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button { store.tap(); action() } label: {
            HStack {
                Text(label).font(RBTheme.body(15)).foregroundColor(RBTheme.ink)
                Spacer()
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule().fill(isOn ? RBTheme.good : RBTheme.inkSoft.opacity(0.3))
                        .frame(width: 46, height: 27)
                    Circle().fill(.white).frame(width: 22, height: 22).padding(2)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Baron's Almanac (codex)

struct AlmanacView: View {
    private struct Entry: Identifiable { let id = UUID(); let title: String; let body: String }

    private let entries: [Entry] = [
        Entry(title: "The River", body: "The map is a living river: landings joined by reaches. Every reach flows one way. Sailing with the current (downstream) is easy; fighting it (upstream) is slow and costly. Learn the arrows and the whole board opens up."),
        Entry(title: "Landings", body: "Harbors yield 3 florins a turn and defend a little better. Islands yield 2. Confluences, where waters meet, yield 4. The Mouth yields 6 and is the ultimate prize. Hold landings to fund your war."),
        Entry(title: "Florins & Income", body: "At the start of each of your turns you collect income from every landing you hold, plus a florin for each dock level. Florins buy ships, docks, shipyards, watchtowers and dams."),
        Entry(title: "Fleets & Movement", body: "Each fleet has 3 moves a turn. A downstream reach costs 1 move; an upstream reach costs 2. A fleet that gives battle spends the rest of its turn. Fleets sharing a landing can merge into one stronger stack, up to strength 12."),
        Entry(title: "Combat", body: "Attacker strength plus a downstream bonus of +2 (or an upstream penalty of -1) and a small seeded roll of -1 to +1, against defender strength plus +1 in a friendly harbor and any dock bonus. Higher total wins; ties go to the defender. The winner keeps the field but loses half the loser's strength, rounded up."),
        Entry(title: "Docks", body: "Dock I, II and III each add income and, from level II, defense. Fortify your border landings and your rivals will break upon them."),
        Entry(title: "Shipyards", body: "A shipyard lets you recruit one ship each turn for 8 florins. Lose every shipyard and every fleet, and you are driven from the river. Guard your yards well."),
        Entry(title: "Dams", body: "A dam seals a reach against every baron but its builder. You may hold at most two. An enemy fleet can besiege an adjacent dam and breach it in a single hard turn. Engineers love them."),
        Entry(title: "Watchtowers", body: "Under fog, a watchtower on one of your landings reveals the water two reaches out. Without fog they do nothing — spend elsewhere."),
        Entry(title: "Floods", body: "In some waters a flood comes every sixth turn. While it crests, even upstream travel costs only 1 move. Plan your upstream strikes for the flood."),
        Entry(title: "Toll Bridges", body: "A toll reach costs 2 florins each time a fleet crosses it. A shortcut you cannot pay for is no shortcut at all."),
        Entry(title: "Pirates", body: "Neutral raiders fly no banner. Each round they drift toward the richest baron and sack an unguarded landing, carrying off florins. Sink them, or make sure you are not the richest and the softest."),
        Entry(title: "The Three Barons", body: "The Merchant builds economy first and expands by purchase. The Corsair recruits fast and rams downstream at every chance. The Engineer walls the water with dams and turtles until a late push for the Mouth."),
        Entry(title: "Winning", body: "Three paths to the crown: hold the Mouth at the end of three of your own turns in a row; sink every rival's fleets and shipyards; or simply hold the most landings when the turn cap is reached.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                RBRibbonHeader(title: "The Baron's Almanac").padding(.top, 6)
                ForEach(entries) { e in
                    RBCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(e.title).font(RBTheme.display(16)).foregroundColor(RBTheme.navy)
                            Text(e.body).font(RBTheme.body(14)).foregroundColor(RBTheme.ink)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
        }
        .background(RBTheme.parchment.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
