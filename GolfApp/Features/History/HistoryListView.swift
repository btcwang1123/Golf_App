import GolfKit
import SwiftData
import SwiftUI

enum ScoreFormat {
    /// "E", "+3", "−2"; "—" when unknown.
    static func toPar(_ value: Int?) -> String {
        guard let value else { return "—" }
        if value == 0 { return "E" }
        return value > 0 ? "+\(value)" : "−\(abs(value))"
    }
}

struct HistoryListView: View {
    @Environment(RoundStore.self) private var roundStore
    @Query(sort: \RoundRecord.startedAt, order: .reverse) private var records: [RoundRecord]
    @State private var pendingDelete: RoundRecord?
    @State private var showManual = false

    private var finished: [RoundRecord] { records.filter { ($0.totalStrokes ?? 0) > 0 } }
    private var average: String {
        let totals = finished.compactMap(\.totalStrokes)
        guard !totals.isEmpty else { return "—" }
        return String(format: "%.1f", Double(totals.reduce(0, +)) / Double(totals.count))
    }
    private var best: String { finished.compactMap(\.totalStrokes).min().map(String.init) ?? "—" }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(PremiumBackground())
            .navigationTitle("歷史")
            .navigationDestination(for: RoundRecord.self) { RoundDetailView(record: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("手動記錄", systemImage: "plus") { showManual = true }
                }
            }
            .sheet(isPresented: $showManual) { ManualRoundEntryView() }
            .confirmationDialog(
                "刪除這個回合？", isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("刪除", role: .destructive) {
                    if let r = pendingDelete { roundStore.delete(r) }
                    pendingDelete = nil
                }
                Button("取消", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("刪除後無法復原。")
            }
        }
    }

    private var list: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    StatTile(title: "場數", value: "\(records.count)")
                    StatTile(title: "平均", value: average)
                    StatTile(title: "最佳", value: best, accent: Theme.gold)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: Theme.gutter, bottom: 12, trailing: Theme.gutter))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            ForEach(groupedByMonth, id: \.title) { group in
                Section {
                    ForEach(group.records) { record in
                        RoundRowCard(record: record)
                            .background(NavigationLink(value: record) { EmptyView() }.opacity(0))
                            .listRowInsets(EdgeInsets(top: 5, leading: Theme.gutter, bottom: 5, trailing: Theme.gutter))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button("刪除", systemImage: "trash", role: .destructive) { pendingDelete = record }
                            }
                    }
                } header: {
                    Eyebrow(group.title, color: Theme.textSecondary)
                        .padding(.leading, 4)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var groupedByMonth: [(title: String, records: [RoundRecord])] {
        var order: [String] = []
        var dict: [String: [RoundRecord]] = [:]
        for r in records {
            let key = r.startedAt.formatted(.dateTime.year().month(.wide))
            if dict[key] == nil { order.append(key) }
            dict[key, default: []].append(r)
        }
        return order.map { ($0, dict[$0] ?? []) }
    }

    private var emptyState: some View {
        EmptyStateView(icon: "flag.and.flag.filled.crossed", title: "還沒有任何紀錄",
                       message: "在球場開始一個回合，或手動輸入過去的成績。",
                       actionTitle: "手動記錄成績", action: { showManual = true })
    }
}

/// Card summarising one round, used on Home and History.
struct RoundRowCard: View {
    let record: RoundRecord

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 0) {
                Text(record.startedAt.formatted(.dateTime.day()))
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.ivory)
                Text(record.startedAt.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 44)

            Rectangle().fill(Theme.hairline).frame(width: 1, height: 40)

            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: record.courseName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.ivory)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(record.startedAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    if record.endedAt == nil {
                        Tag(text: "進行中", color: Theme.fairway)
                    }
                }
            }
            Spacer(minLength: 8)
            ScoreRing(total: record.totalStrokes, toPar: record.toPar, size: 58)
        }
        .card(padding: 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.courseName)，\(record.startedAt.formatted(date: .abbreviated, time: .omitted))，總桿 \(record.totalStrokes ?? 0)")
    }
}
