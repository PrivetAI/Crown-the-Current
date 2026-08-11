import SwiftUI

struct SkirmishView: View {
    @ObservedObject var store = CTCStore.shared
    @Environment(\.horizontalSizeClass) private var hSize
    let startMatch: (MatchState, Bool) -> Void

    @State private var size = 1
    @State private var opponents = 2
    @State private var difficulty = "normal"
    @State private var fog = false
    @State private var personaSlots = ["merchant", "corsair", "engineer"]
    @State private var seedText = "1"

    private let personaOptions = ["merchant", "corsair", "engineer"]
    private let personaLabels = ["Merchant", "Corsair", "Engineer"]

    private var layout: CTCLayout { CTCLayout(hSize) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CTCRibbonHeader(title: "Free Skirmish", subtitle: "A fresh river, generated to your taste")
                    .padding(.top, 6)

                CTCArtBanner(imageName: "ctc_skirmish", height: layout.regular ? 180 : 118)

                if let match = store.root.activeSkirmishMatch {
                    resumeCard(turn: match.game.turn,
                               nodes: match.game.nodes.count) { startMatch(match, false) }
                }

                optionCard(title: "River Size") {
                    segmented(["Small", "Medium", "Large"], selection: size) { size = $0 }
                }

                optionCard(title: "Rival Barons") {
                    segmented(["1", "2", "3"], selection: opponents - 1) { opponents = $0 + 1 }
                }

                optionCard(title: "Rival Temper") {
                    VStack(spacing: 8) {
                        ForEach(0..<opponents, id: \.self) { i in
                            HStack {
                                Text("Baron \(i + 1)").font(CTCTheme.body(13)).foregroundColor(CTCTheme.inkSoft)
                                    .frame(width: 66, alignment: .leading)
                                segmented(personaLabels, selection: personaOptions.firstIndex(of: personaSlots[i]) ?? 0) {
                                    personaSlots[i] = personaOptions[$0]
                                }
                            }
                        }
                    }
                }

                optionCard(title: "Difficulty") {
                    segmented(["Easy", "Normal", "Hard"],
                              selection: ["easy", "normal", "hard"].firstIndex(of: difficulty) ?? 1) {
                        difficulty = ["easy", "normal", "hard"][$0]
                    }
                }

                optionCard(title: "Fog of War") {
                    HStack {
                        Text(fog ? "Hidden waters — scout with towers" : "The whole river in view")
                            .font(CTCTheme.body(13)).foregroundColor(CTCTheme.inkSoft)
                        Spacer()
                        toggle($fog)
                    }
                }

                optionCard(title: "River Seed") {
                    HStack(spacing: 10) {
                        TextField("seed", text: $seedText)
                            .keyboardType(.numberPad)
                            .font(CTCTheme.num(15))
                            .padding(.horizontal, 12).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 9).fill(CTCTheme.parchment)
                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(CTCTheme.cardBorder, lineWidth: 1)))
                        Button {
                            store.tap()
                            seedText = "\(UInt64.random(in: 1...9_999_999))"
                        } label: {
                            Text("Shuffle").font(CTCTheme.display(14)).foregroundColor(.white)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 9).fill(CTCTheme.bankGreenDeep))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(action: generate) {
                    Text("Generate & Sail").frame(maxWidth: .infinity)
                }
                .buttonStyle(CTCButtonStyle())
                .padding(.top, 4)
            }
            .ctcColumn(layout.readingWidth)
            .padding(.horizontal, 14)
            .padding(.bottom, 26)
        }
        .background(CTCTheme.parchment.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func resumeCard(turn: Int, nodes: Int, action: @escaping () -> Void) -> some View {
        Button(action: { store.tap(); action() }) {
            CTCCard {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Resume Skirmish").font(CTCTheme.body(12)).foregroundColor(CTCTheme.good)
                        Text("Turn \(turn) · \(nodes) landings").font(CTCTheme.display(16)).foregroundColor(CTCTheme.ink)
                    }
                    Spacer()
                    CTCChevron(pointRight: true).stroke(CTCTheme.navy, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        .frame(width: 13, height: 20)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func optionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        CTCCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(CTCTheme.display(15)).foregroundColor(CTCTheme.navy)
                content()
            }
        }
    }

    private func segmented(_ labels: [String], selection: Int, onSelect: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                let active = i == selection
                Button {
                    store.tap()
                    onSelect(i)
                } label: {
                    Text(label).font(CTCTheme.body(13))
                        .foregroundColor(active ? .white : CTCTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(active ? CTCTheme.navy : CTCTheme.parchment)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(CTCTheme.cardBorder, lineWidth: active ? 0 : 1)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ binding: Binding<Bool>) -> some View {
        Button {
            store.tap()
            binding.wrappedValue.toggle()
        } label: {
            ZStack(alignment: binding.wrappedValue ? .trailing : .leading) {
                Capsule().fill(binding.wrappedValue ? CTCTheme.good : CTCTheme.inkSoft.opacity(0.3))
                    .frame(width: 46, height: 27)
                Circle().fill(.white).frame(width: 22, height: 22).padding(2)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func generate() {
        store.tap()
        var config = SkirmishConfig()
        config.size = size
        config.opponents = opponents
        config.personas = Array(personaSlots.prefix(opponents))
        config.difficulty = difficulty
        config.fog = fog
        config.seed = UInt64(seedText) ?? UInt64.random(in: 1...9_999_999)
        let game = CTCMapGen.generate(config: config, playerColor: store.root.selectedBanner)
        var ms = MatchState()
        ms.mode = "skirmish"
        ms.skirmish = config
        ms.game = game
        startMatch(ms, true)
    }
}
