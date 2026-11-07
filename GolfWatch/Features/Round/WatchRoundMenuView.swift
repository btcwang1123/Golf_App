import SwiftUI

/// Round menu: settings and end round.
struct WatchRoundMenuView: View {
    @Environment(WatchRoundStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmEnd = false

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("設定") { WatchSettingsView() }
                Button("結束回合", role: .destructive) { confirmEnd = true }
            }
            .navigationTitle("選單")
            .confirmationDialog("結束這場回合？", isPresented: $confirmEnd) {
                Button("結束回合", role: .destructive) {
                    store.end()
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
}
