import GolfKit
import SwiftUI

struct WatchSettingsView: View {
    @Environment(WatchSettingsService.self) private var service

    var body: some View {
        let settings = service.settings
        List {
            Picker("距離單位", selection: binding(\.distanceUnit)) {
                Text("碼").tag(AppSettings.DistanceUnit.yard)
                Text("公尺").tag(AppSettings.DistanceUnit.meter)
            }
            Picker("配戴手", selection: binding(\.wrist)) {
                Text("左手").tag(AppSettings.Wrist.left)
                Text("右手").tag(AppSettings.Wrist.right)
            }
            Stepper(
                value: binding(\.swingSensitivity),
                in: AppSettings.sensitivityRange, step: 0.1
            ) {
                VStack(alignment: .leading) {
                    Text("揮桿靈敏度")
                    Text(verbatim: String(format: "%.1f", settings.swingSensitivity))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Stepper(value: binding(\.undoWindowSeconds), in: AppSettings.undoWindowRange) {
                VStack(alignment: .leading) {
                    Text("取消視窗")
                    Text(verbatim: "\(settings.undoWindowSeconds) 秒")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Toggle("自動換洞", isOn: binding(\.autoAdvanceHole))
            Toggle("震動回饋", isOn: binding(\.hapticsOn))
            NavigationLink("校正錄製") { CalibrationView() }
        }
        .navigationTitle("設定")
    }

    private func binding<V: Equatable>(_ keyPath: WritableKeyPath<AppSettings, V>) -> Binding<V> {
        Binding(
            get: { service.settings[keyPath: keyPath] },
            set: { new in service.edit { $0[keyPath: keyPath] = new } })
    }
}
