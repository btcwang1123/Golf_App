import GolfKit
import SwiftUI

/// Range mode: big swing counter, tempo of the last swing and the session average.
struct WatchPracticeView: View {
    @Environment(WatchPracticeStore.self) private var practice

    var body: some View {
        Group {
            if practice.isActive {
                active
            } else if let done = practice.finished {
                summary(done)
            } else {
                start
            }
        }
        .navigationTitle("練習場")
    }

    private var clubBinding: Binding<Club?> {
        Binding(get: { practice.club }, set: { practice.club = $0 })
    }

    private var start: some View {
        List {
            Picker("球桿", selection: clubBinding) {
                Text("不指定").tag(Club?.none)
                ForEach(Club.allCases.filter { $0 != .putter }, id: \.self) { Text(verbatim: $0.displayName).tag(Club?.some($0)) }
            }
            Button {
                practice.start()
            } label: {
                Label("開始練習", systemImage: "figure.golf")
            }
            .tint(.green)
            Text("每次揮桿自動計數並分析節奏（上桿：下桿，理想約 3:1）。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var active: some View {
        let stats = practice.stats
        return ScrollView {
            VStack(spacing: 6) {
                Text(verbatim: "\(practice.session?.swings.count ?? 0)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .accessibilityLabel("揮桿 \(practice.session?.swings.count ?? 0) 次")
                Text("揮桿").font(.caption2).foregroundStyle(.secondary)
                if let t = practice.lastTempo {
                    tempoLine(title: "上一桿", tempo: t)
                }
                if let avg = stats.average {
                    tempoLine(title: "平均", tempo: avg)
                }
                Picker("球桿", selection: clubBinding) {
                    Text("不指定").tag(Club?.none)
                    ForEach(Club.allCases.filter { $0 != .putter }, id: \.self) { Text(verbatim: $0.displayName).tag(Club?.some($0)) }
                }
                .frame(height: 50)
                HStack {
                    Button { practice.undoLast() } label: { Image(systemName: "arrow.uturn.backward") }
                        .accessibilityLabel("刪除上一桿")
                    Button("結束", role: .destructive) { practice.end() }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func tempoLine(title: LocalizedStringKey, tempo: Double) -> some View {
        let rating = TempoStats.rating(tempo)
        return HStack {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text(verbatim: String(format: "%.1f:1", tempo)).font(.body.monospacedDigit().weight(.semibold))
            Text(LocalizedStringKey(rating.title)).font(.caption2)
                .foregroundStyle(rating == .ideal ? .green : .orange)
        }
    }

    private func summary(_ s: PracticeSession) -> some View {
        let stats = s.tempo
        return List {
            LabeledContent("揮桿") { Text(verbatim: "\(s.swings.count)") }
            LabeledContent("時間") { Text(verbatim: "\(Int(s.duration / 60)) min") }
            if let avg = stats.average { LabeledContent("平均節奏") { Text(verbatim: String(format: "%.1f:1", avg)) } }
            if let share = stats.idealShare { LabeledContent("理想節奏") { Text(verbatim: "\(Int((share * 100).rounded()))%") } }
            Text("已傳到 iPhone，可在「統計 › 練習場」查看。").font(.footnote).foregroundStyle(.secondary)
            Button("完成") { practice.clearSummary() }
        }
    }
}
