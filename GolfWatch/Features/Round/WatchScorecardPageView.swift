import GolfKit
import SwiftUI

/// Last page: the owner's hole-by-hole scores.
struct WatchScorecardPageView: View {
    @Environment(WatchRoundStore.self) private var store

    var body: some View {
        List {
            if let round = store.active {
                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    let pace = PaceOfPlay(state: round, now: ctx.date)
                    HStack {
                        Image(systemName: "timer").foregroundStyle(.secondary)
                        Text(verbatim: PaceOfPlay.format(pace.elapsed)).font(.footnote.monospacedDigit())
                        Spacer()
                        if let avg = pace.averageMinutesPerHole {
                            Text("\(Int(avg.rounded())) 分/洞").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            HStack {
                Text("總桿").font(.footnote)
                Spacer()
                Text(verbatim: "\(store.totalStrokes)").font(.title3.weight(.semibold))
            }
            ForEach(store.active?.holes.filter { $0.total > 0 || $0.number == store.currentHoleNumber } ?? [], id: \.number) { h in
                HStack {
                    Text(verbatim: "\(h.number)").font(.footnote.weight(.semibold)).frame(width: 24, alignment: .leading)
                    Text(verbatim: h.par.map { "Par \($0)" } ?? "").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(verbatim: "\(h.total)").font(.body.weight(.semibold))
                    Text(verbatim: "(\(h.putts))").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}
