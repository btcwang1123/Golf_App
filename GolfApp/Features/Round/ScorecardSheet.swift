import GolfKit
import SwiftUI

struct ScorecardSheet: View {
    let round: RoundState
    let holeCount: Int
    @Environment(\.dismiss) private var dismiss

    private var holes: [HoleState] {
        (1...max(holeCount, 1)).map { round.hole($0) ?? HoleState(number: $0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        StatTile(title: "總桿", value: "\(round.totalStrokes)")
                        StatTile(title: "對標準桿", value: ScoreFormat.toPar(round.toPar), accent: Theme.gold)
                        StatTile(title: "推桿", value: "\(holes.reduce(0) { $0 + $1.putts })")
                    }
                    if round.players.count > 1 {
                        GroupScorecardCard(round: round, holeCount: holeCount)
                    } else {
                        ScorecardCard(holes: holes)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .background(PremiumBackground())
            .navigationTitle("計分卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

struct ScorecardRow: Identifiable {
    let id: String
    let title: String
    let par: Int?
    let strokes: Int?
    let putts: Int?
    let penalties: Int?
    let isSubtotal: Bool

    static func build(round: RoundState, holeCount: Int) -> [ScorecardRow] {
        let half = (holeCount + 1) / 2
        var result: [ScorecardRow] = []
        var out: [HoleState] = []
        var inn: [HoleState] = []
        for n in 1...max(holeCount, 1) {
            let state = round.hole(n) ?? HoleState(number: n)
            result.append(ScorecardRow(
                id: "h\(n)", title: "\(n)", par: state.par,
                strokes: state.total > 0 ? state.total : nil,
                putts: state.total > 0 ? state.putts : nil,
                penalties: state.total > 0 ? state.penalties : nil, isSubtotal: false))
            if n <= half { out.append(state) } else { inn.append(state) }
            if n == half, holeCount > 9 {
                result.append(subtotal(id: "out", title: "OUT", holes: out))
            }
        }
        if holeCount > 9 { result.append(subtotal(id: "in", title: "IN", holes: inn)) }
        result.append(subtotal(id: "total", title: "總計", holes: out + inn))
        return result
    }

    private static func subtotal(id: String, title: String, holes: [HoleState]) -> ScorecardRow {
        let pars = holes.compactMap(\.par)
        return ScorecardRow(
            id: id, title: title, par: pars.isEmpty ? nil : pars.reduce(0, +),
            strokes: holes.reduce(0) { $0 + $1.total },
            putts: holes.reduce(0) { $0 + $1.putts },
            penalties: holes.reduce(0) { $0 + $1.penalties }, isSubtotal: true)
    }
}

/// Every player's hole scores, coloured birdie / bogey like the classic card.
struct GroupScorecardCard: View {
    let round: RoundState
    let holeCount: Int

    private var halves: [[Int]] {
        let all = Array(1...max(holeCount, 1))
        guard all.count > 9 else { return [all] }
        let mid = (all.count + 1) / 2
        return [Array(all.prefix(mid)), Array(all.dropFirst(mid))]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "計分卡")
            VStack(spacing: 16) {
                ForEach(Array(halves.enumerated()), id: \.offset) { i, numbers in
                    nine(numbers, label: halves.count == 1 ? "TOT" : (i == 0 ? "OUT" : "IN"))
                }
            }
            .card(padding: 12)
        }
    }

    private func nine(_ numbers: [Int], label: String) -> some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 8) {
            GridRow {
                cell("洞", tertiary: true).frame(width: 46, alignment: .leading)
                ForEach(numbers, id: \.self) { cell("\($0)", tertiary: true) }
                cell(label, gold: true)
            }
            GridRow {
                cell("PAR", tertiary: true).frame(width: 46, alignment: .leading)
                ForEach(numbers, id: \.self) { cell(round.hole($0)?.par.map(String.init) ?? "–") }
                cell(sum(numbers.compactMap { round.hole($0)?.par }))
            }
            ForEach(round.players) { p in
                let scores = round.scores(for: p.id)
                GridRow {
                    Text(verbatim: p.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.ivory)
                        .lineLimit(1)
                        .frame(width: 46, alignment: .leading)
                    ForEach(numbers, id: \.self) { n in
                        ScoreMark(strokes: scores[n]?.strokes, par: round.hole(n)?.par, size: 22)
                            .frame(maxWidth: .infinity)
                    }
                    cell(sum(numbers.compactMap { scores[$0]?.strokes }), gold: true)
                }
            }
        }
    }

    private func cell(_ text: String, tertiary: Bool = false, gold: Bool = false) -> some View {
        Text(verbatim: text)
            .font(Theme.numeral(11, weight: .regular))
            .foregroundStyle(gold ? Theme.gold : (tertiary ? Theme.textTertiary : Theme.textSecondary))
            .frame(maxWidth: .infinity)
    }

    private func sum(_ v: [Int]) -> String {
        let s = v.reduce(0, +)
        return s > 0 ? "\(s)" : "–"
    }
}
