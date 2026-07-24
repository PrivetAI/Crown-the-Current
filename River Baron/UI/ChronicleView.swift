import SwiftUI

struct ChronicleView: View {
    @ObservedObject var store = RBStore.shared
    @State private var section = 0

    var body: some View {
        VStack(spacing: 0) {
            RBRibbonHeader(title: "Chronicle")
                .padding(.top, 6).padding(.horizontal, 14)

            RBArtBanner(imageName: "rb_chronicle", height: 104)
                .padding(.horizontal, 14).padding(.top, 10)

            HStack(spacing: 6) {
                tab("Records", 0)
                tab("Banners", 1)
                tab("Honours", 2)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            ScrollView {
                VStack(spacing: 14) {
                    switch section {
                    case 0: recordsSection
                    case 1: bannersSection
                    default: honoursSection
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
            }
        }
        .background(RBTheme.parchment.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func tab(_ label: String, _ i: Int) -> some View {
        let active = section == i
        return Button { store.tap(); section = i } label: {
            Text(label).font(RBTheme.body(13)).foregroundColor(active ? .white : RBTheme.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(active ? RBTheme.navy : RBTheme.card)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(RBTheme.cardBorder, lineWidth: active ? 0 : 1)))
        }
        .buttonStyle(.plain)
    }

    // MARK: records

    private var recordsSection: some View {
        let s = store.root.stats
        return VStack(spacing: 12) {
            RBCard {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statTile("Campaign Stars", "\(store.root.totalStars)/42")
                    statTile("Matches Won", "\(s.matchesWon)")
                    statTile("Matches Played", "\(s.matchesPlayed)")
                    statTile("Campaign Wins", "\(s.campaignWins)")
                    statTile("Skirmish Wins", "\(s.skirmishWins)")
                    statTile("Battles Fought", "\(s.battles)")
                    statTile("Fleets Sunk", "\(s.fleetsSunk)")
                    statTile("Pirates Sunk", "\(s.piratesSunk)")
                    statTile("Dams Built", "\(s.damsBuilt)")
                    statTile("Dams Breached", "\(s.damsBreached)")
                }
            }
        }
    }

    private func statTile(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(RBTheme.num(22)).foregroundColor(RBTheme.navy)
            Text(title).font(RBTheme.body(12)).foregroundColor(RBTheme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(RBTheme.parchment))
    }

    // MARK: banners

    private var bannersSection: some View {
        VStack(spacing: 12) {
            Text("Choose the colors you sail under. New banners unlock as you conquer the river.")
                .font(RBTheme.body(13)).foregroundColor(RBTheme.inkSoft)
                .multilineTextAlignment(.center)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<RBTheme.banners.count, id: \.self) { i in
                    bannerCard(i)
                }
            }
        }
    }

    private func bannerCard(_ i: Int) -> some View {
        let unlocked = store.root.isBannerUnlocked(i)
        let selected = store.root.selectedBanner == i
        return Button {
            guard unlocked else { return }
            store.tap()
            store.root.selectedBanner = i
            store.save()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RBBannerShape().fill(unlocked ? RBTheme.bannerColor(i) : RBTheme.inkSoft.opacity(0.25))
                        .frame(width: 54, height: 64)
                    RBBannerShape().strokeBorder(RBTheme.ink.opacity(0.25), lineWidth: 1.2)
                        .frame(width: 54, height: 64)
                }
                Text(RBTheme.bannerNames[i]).font(RBTheme.display(14))
                    .foregroundColor(unlocked ? RBTheme.ink : RBTheme.inkSoft)
                if unlocked {
                    Text(selected ? "Flying" : "Tap to fly")
                        .font(RBTheme.body(11)).foregroundColor(selected ? RBTheme.good : RBTheme.inkSoft)
                } else {
                    Text(RootState.bannerHint(i)).font(RBTheme.body(10)).foregroundColor(RBTheme.inkSoft)
                        .multilineTextAlignment(.center).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(RBTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? RBTheme.goldLine : RBTheme.cardBorder, lineWidth: selected ? 2.2 : 1)))
        }
        .buttonStyle(.plain)
    }

    // MARK: honours (achievements)

    private var honoursSection: some View {
        let earned = Set(store.root.achievements)
        return VStack(spacing: 10) {
            Text("\(earned.count) of \(RBAchievements.all.count) honours earned")
                .font(RBTheme.body(13)).foregroundColor(RBTheme.inkSoft)
            ForEach(RBAchievements.all) { a in
                let got = earned.contains(a.id)
                RBCard {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(got ? RBTheme.goldLine.opacity(0.22) : RBTheme.inkSoft.opacity(0.12))
                                .frame(width: 40, height: 40)
                            RBLaurelIcon().stroke(got ? RBTheme.goldLine : RBTheme.inkSoft.opacity(0.4),
                                                  style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                                .frame(width: 26, height: 26)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.title).font(RBTheme.display(15))
                                .foregroundColor(got ? RBTheme.ink : RBTheme.inkSoft)
                            Text(a.detail).font(RBTheme.body(12)).foregroundColor(RBTheme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                }
                .opacity(got ? 1 : 0.75)
            }
        }
    }
}

/// Simple swallowtail banner silhouette.
struct RBBannerShape: InsettableShape {
    var inset: CGFloat = 0
    func inset(by amount: CGFloat) -> RBBannerShape {
        var c = self; c.inset += amount; return c
    }
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.22))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}
