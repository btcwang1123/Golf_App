import GolfKit
import SwiftUI
import UIKit

@MainActor
enum ShareCardRenderer {
    static func render(_ template: ShareCardTemplate, round: RoundState, course: Course?, courseName: String,
                       settings: AppSettings) -> UIImage {
        let data = ShareCardData(round: round, course: course, courseName: courseName, settings: settings)
        let renderer = ImageRenderer(content: ShareCardView(template: template, data: data))
        renderer.scale = ShareCardTemplate.renderScale
        renderer.proposedSize = ProposedViewSize(template.pointSize)
        return renderer.uiImage ?? UIImage()
    }
}

/// The card itself; a fixed-size, self-contained dark card that reads well on any background.
struct ShareCardView: View {
    let template: ShareCardTemplate
    let data: ShareCardData

    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(colors: [Theme.backgroundTop, .clear], center: .init(x: 0.2, y: 0), startRadius: 10, endRadius: 420)
            RadialGradient(colors: [Theme.gold.opacity(0.12), .clear], center: .init(x: 1, y: 0), startRadius: 0, endRadius: 300)
            content.padding(22)
            RoundedRectangle(cornerRadius: 0).strokeBorder(Theme.goldGradient, lineWidth: 1.5).padding(8)
        }
        .frame(width: template.pointSize.width, height: template.pointSize.height)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var content: some View {
        switch template {
        case .story:
            VStack(alignment: .leading, spacing: 16) {
                header
                if let hole = data.featuredHole {
                    HoleThumbnail(hole: hole, course: data.course)
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            Tag(text: "第 \(hole.number) 洞").padding(8)
                        }
                }
                score
                highlights
                if !data.standings.isEmpty { leaderboard }
                Spacer(minLength: 0)
                footer
            }
        case .square:
            VStack(alignment: .leading, spacing: 14) {
                header
                HStack(alignment: .center, spacing: 16) {
                    score
                    if let hole = data.featuredHole {
                        HoleThumbnail(hole: hole, course: data.course)
                            .frame(width: 110, height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
                    }
                }
                highlights
                Spacer(minLength: 0)
                footer
            }
        case .scorecard:
            VStack(alignment: .leading, spacing: 14) {
                header
                score
                if data.players.count > 1 {
                    GroupScorecardCard(round: data.round, holeCount: data.holeCount)
                } else {
                    ScorecardCard(holes: data.holes)
                }
                Spacer(minLength: 0)
                footer
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(data.date.formatted(.dateTime.year().month().day().weekday(.abbreviated)))
            Text(verbatim: data.courseName)
                .font(Theme.display(24, weight: .medium))
                .foregroundStyle(Theme.ivory)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
    }

    private var score: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(verbatim: "\(data.total)")
                .font(Theme.numeral(76, weight: .thin))
                .foregroundStyle(Theme.ivory)
            Text(ScoreFormat.toPar(data.toPar))
                .font(Theme.numeral(30, weight: .medium))
                .foregroundStyle(Theme.gold)
            Spacer(minLength: 0)
            if data.holeCount > 9 {
                VStack(alignment: .trailing, spacing: 2) {
                    nineTotal("OUT", data.highlights.front)
                    nineTotal("IN", data.highlights.back)
                }
            }
        }
    }

    private func nineTotal(_ label: String, _ v: Int) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: label).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(Theme.textTertiary)
            Text(verbatim: "\(v)").font(Theme.numeral(18, weight: .regular)).foregroundStyle(Theme.ivory)
        }
    }

    private var highlights: some View {
        let h = data.highlights
        return HStack(spacing: 8) {
            chip("博蒂+", "\(h.birdiesOrBetter)")
            if let l = h.longestShot { chip("最遠一桿", data.settings.format(meters: l.meters)) }
            if let f = h.fewestPuttsHole { chip("最少推桿", String(localized: "\(f.hole) 洞 · \(f.putts)")) }
        }
    }

    private func chip(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title)).font(.system(size: 9, weight: .semibold)).tracking(0.6).foregroundStyle(Theme.textSecondary)
            Text(verbatim: value).font(Theme.numeral(15, weight: .medium)).foregroundStyle(Theme.ivory).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.cornerTiny, style: .continuous).fill(Theme.surfaceRaised))
    }

    private var leaderboard: some View {
        VStack(spacing: 6) {
            ForEach(Array(data.standings.prefix(4).enumerated()), id: \.offset) { i, s in
                HStack {
                    Text(verbatim: "\(i + 1)").font(Theme.numeral(13, weight: .semibold)).foregroundStyle(i == 0 ? Theme.gold : Theme.textSecondary).frame(width: 18)
                    Text(verbatim: s.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.ivory).lineLimit(1)
                    Spacer()
                    Text(LocalizedStringKey(s.detail)).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                    Text(verbatim: "\(s.total)").font(Theme.numeral(15, weight: .regular)).foregroundStyle(Theme.ivory)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.cornerTiny, style: .continuous).fill(Theme.surface))
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: AppBrand.displayName)
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                Text("Apple Watch 揮桿自動記桿")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textSecondary)
                Text(GolfKit.mapAttribution)
                    .font(.system(size: 7))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            if let qr = QRCodeGenerator.image(for: data.shareURL) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 52, height: 52)
                    .padding(4)
                    .background(Theme.ivory)
            }
        }
    }
}

enum AppBrand {
    static var displayName: String {
        (Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String) ?? "GolfApp"
    }
}
