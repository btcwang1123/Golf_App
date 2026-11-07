import SwiftUI

struct CalibrationExportView: View {
    @Environment(PhoneSyncService.self) private var sync
    @State private var files: [URL] = []

    var body: some View {
        List {
            if files.isEmpty {
                Text("尚未收到錄製檔。在手錶上錄製後會自動傳送到這裡。")
                    .foregroundStyle(.secondary)
            }
            ForEach(files, id: \.self) { url in
                HStack {
                    Text(url.lastPathComponent)
                        .font(.footnote)
                        .lineLimit(2)
                    Spacer()
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("揮桿資料校正")
        .toolbar { EditButton() }
        .task(id: sync.calibrationFilesVersion) { files = Self.listFiles() }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets {
            try? FileManager.default.removeItem(at: files[i])
        }
        files.remove(atOffsets: offsets)
    }

    private static func listFiles() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: PhoneSyncService.calibrationDirectory,
            includingPropertiesForKeys: nil)) ?? []
        return urls.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }
}
