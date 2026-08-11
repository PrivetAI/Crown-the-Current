import SwiftUI

struct ChronicleView: View {
    @ObservedObject var store = CTCStore.shared
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var section = 0

    private var layout: CTCLayout { CTCLayout(hSize) }

    var body: some View {
        VStack(spacing: 0) {
            CTCRibbonHeader(title: "Chronicle")
                .padding(.top, 6)
                .ctcColumn(layout.gridWidth)
                .padding(.horizontal, 14)

            CTCArtBanner(imageName: "ctc_chronicle", height: layout.regular ? 170 : 104)
                .ctcColumn(layout.gridWidth)
                .padding(.horizontal, 14).padding(.top, 10)

            HStack(spacing: 6) {
                tab("Records", 0)
                tab("Banners", 1)
                tab("Honours", 2)
            }
            .ctcColumn(layout.readingWidth)
            .padding(.horizontal, 14).padding(.vertical, 10)

            ScrollView {
                VStack(spacing: 14) {
                    switch section {
                    case 0: recordsSection
                    case 1: bannersSection
                    default: honoursSection
                    }
                }
                .ctcColumn(layout.gridWidth)
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
            }
        }
        .background(CTCTheme.parchment.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func tab(_ label: String, _ i: Int) -> some View {
        let active = section == i
        return Button { store.tap(); section = i } label: {
            Text(label).font(CTCTheme.body(13)).foregroundColor(active ? .white : CTCTheme.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(active ? CTCTheme.navy : CTCTheme.card)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(CTCTheme.cardBorder, lineWidth: active ? 0 : 1)))
        }
        .buttonStyle(.plain)
    }

    // MARK: records

    private var recordsSection: some View {
        let s = store.root.stats
        return VStack(spacing: 12) {
            CTCCard {
                LazyVGrid(columns: layout.columns(layout.tileColumns), spacing: 12) {
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
            Text(value).font(CTCTheme.num(22)).foregroundColor(CTCTheme.navy)
            Text(title).font(CTCTheme.body(12)).foregroundColor(CTCTheme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(CTCTheme.parchment))
    }

    // MARK: banners

    private var bannersSection: some View {
        VStack(spacing: 12) {
            Text("Choose the colors you sail under. New banners unlock as you conquer the river.")
                .font(CTCTheme.body(13)).foregroundColor(CTCTheme.inkSoft)
                .multilineTextAlignment(.center)
            LazyVGrid(columns: layout.columns(layout.regular ? 3 : 2), spacing: 12) {
                ForEach(0..<CTCTheme.banners.count, id: \.self) { i in
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
                    CTCBannerShape().fill(unlocked ? CTCTheme.bannerColor(i) : CTCTheme.inkSoft.opacity(0.25))
                        .frame(width: 54, height: 64)
                    CTCBannerShape().strokeBorder(CTCTheme.ink.opacity(0.25), lineWidth: 1.2)
                        .frame(width: 54, height: 64)
                }
                Text(CTCTheme.bannerNames[i]).font(CTCTheme.display(14))
                    .foregroundColor(unlocked ? CTCTheme.ink : CTCTheme.inkSoft)
                if unlocked {
                    Text(selected ? "Flying" : "Tap to fly")
                        .font(CTCTheme.body(11)).foregroundColor(selected ? CTCTheme.good : CTCTheme.inkSoft)
                } else {
                    Text(RootState.bannerHint(i)).font(CTCTheme.body(10)).foregroundColor(CTCTheme.inkSoft)
                        .multilineTextAlignment(.center).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(CTCTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? CTCTheme.goldLine : CTCTheme.cardBorder, lineWidth: selected ? 2.2 : 1)))
        }
        .buttonStyle(.plain)
    }

    // MARK: honours (achievements)

    private var honoursSection: some View {
        let earned = Set(store.root.achievements)
        return VStack(spacing: 10) {
            Text("\(earned.count) of \(CTCAchievements.all.count) honours earned")
                .font(CTCTheme.body(13)).foregroundColor(CTCTheme.inkSoft)
            ForEach(CTCAchievements.all) { a in
                let got = earned.contains(a.id)
                CTCCard {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(got ? CTCTheme.goldLine.opacity(0.22) : CTCTheme.inkSoft.opacity(0.12))
                                .frame(width: 40, height: 40)
                            CTCLaurelIcon().stroke(got ? CTCTheme.goldLine : CTCTheme.inkSoft.opacity(0.4),
                                                  style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                                .frame(width: 26, height: 26)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.title).font(CTCTheme.display(15))
                                .foregroundColor(got ? CTCTheme.ink : CTCTheme.inkSoft)
                            Text(a.detail).font(CTCTheme.body(12)).foregroundColor(CTCTheme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                }
                .opacity(got ? 1 : 0.75)
            }
        }
        .ctcColumn(layout.readingWidth)
    }
}

/// Simple swallowtail banner silhouette.
struct CTCBannerShape: InsettableShape {
    var inset: CGFloat = 0
    func inset(by amount: CGFloat) -> CTCBannerShape {
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
