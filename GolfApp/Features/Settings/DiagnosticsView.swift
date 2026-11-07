import SwiftUI

/// MetricKit crash / hang / energy reports stored on device, exportable for support.
struct DiagnosticsView: View {
    @Environment(DiagnosticsService.self) private var diagnostics

    var body: some View {
        List {
            Section {
                row("啟動到可互動", diagnostics.launchToInteractive)
                ForEach(DiagnosticsService.timings().sorted { $0.key < $1.key }, id: \.key) { k, v in
                    row(LocalizedStringKey(k), v)
                }
            } header: {
                Text("本次與最近的計時")
            }
            Section {
                if diagnostics.files.isEmpty {
                    Text("尚無報告。系統每天最多傳送一次 MetricKit 報告。")
                        .foregroundStyle(.secondary)
                }
                ForEach(diagnostics.files, id: \.self) { url in
                    HStack {
                        Text(verbatim: url.lastPathComponent).font(.footnote).lineLimit(2)
                        Spacer()
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                            .buttonStyle(.borderless)
                    }
                }
                .onDelete { idx in idx.map { diagnostics.files[$0] }.forEach(diagnostics.delete) }
            } header: {
                Text("當機 / 卡頓 / 耗電報告")
            } footer: {
                Text("報告只存在本機，分享前不會傳送給任何人。")
            }
        }
        .navigationTitle("診斷與效能")
        .refreshable { diagnostics.refresh() }
    }

    private func row(_ title: LocalizedStringKey, _ seconds: Double?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(verbatim: seconds.map { String(format: "%.2f s", $0) } ?? "—").foregroundStyle(.secondary)
        }
    }
}
