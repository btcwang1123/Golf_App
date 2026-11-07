import GolfKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(SettingsService.self) private var service
    @Environment(AppRouter.self) private var router
    @Environment(LocationService.self) private var location
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var service = service
        NavigationStack {
            Form {
                Section {
                    Picker("單位", selection: $service.settings.distanceUnit) {
                        Text("碼").tag(AppSettings.DistanceUnit.yard)
                        Text("公尺").tag(AppSettings.DistanceUnit.meter)
                    }
                    .pickerStyle(.segmented)
                    .themedRow()
                } header: {
                    header("距離")
                }

                Section {
                    Picker("佩戴手腕", selection: $service.settings.wrist) {
                        Text("左手").tag(AppSettings.Wrist.left)
                        Text("右手").tag(AppSettings.Wrist.right)
                    }
                    .pickerStyle(.segmented)
                    .themedRow()
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("揮桿靈敏度")
                            Spacer()
                            Text(service.settings.swingSensitivity, format: .number.precision(.fractionLength(2)))
                                .font(Theme.numeral(15, weight: .regular))
                                .foregroundStyle(Theme.gold)
                        }
                        Slider(value: $service.settings.swingSensitivity, in: AppSettings.sensitivityRange)
                    }
                    .padding(.vertical, 4)
                    .themedRow()
                    Stepper(value: $service.settings.undoWindowSeconds, in: AppSettings.undoWindowRange) {
                        HStack {
                            Text("取消時間")
                            Spacer()
                            Text("\(service.settings.undoWindowSeconds) 秒")
                                .font(Theme.numeral(15, weight: .regular))
                                .foregroundStyle(Theme.gold)
                                .padding(.trailing, 8)
                        }
                    }
                    .themedRow()
                    Toggle("自動前進下一洞", isOn: $service.settings.autoAdvanceHole).themedRow()
                    Toggle("觸覺回饋", isOn: $service.settings.hapticsOn).themedRow()
                } header: {
                    header("Apple Watch")
                }

                Section {
                    Toggle("自動播放球洞飛越", isOn: $service.settings.autoFlyover).themedRow()
                    Toggle("顯示 100/150/200 距離弧", isOn: $service.settings.distanceArcs).themedRow()
                    Toggle("博蒂慶祝動畫", isOn: $service.settings.celebrations).themedRow()
                    Toggle("選桿建議考慮風向", isOn: $service.settings.windAdjustsClubs).themedRow()
                } header: {
                    header("回合畫面")
                }

                Section {
                    HStack {
                        Text("定位")
                        Spacer()
                        Text(location.isAuthorized ? "已允許" : (location.isDenied ? "已拒絕" : "未設定"))
                            .foregroundStyle(location.isAuthorized ? Theme.fairway : Theme.textSecondary)
                    }
                    .themedRow()
                    Button("開啟系統設定") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .themedRow()
                } header: {
                    header("權限")
                } footer: {
                    Text("拒絕權限時仍可手動記桿。")
                }

                Section {
                    Button("重看新手引導") { router.showOnboarding = true }.themedRow()
                    Button("看展示") { router.showShowcase = true }.themedRow()
                } header: {
                    header("介紹")
                }

                Section {
                    NavigationLink("揮桿資料校正") { CalibrationExportView() }
                        .themedRow()
                    NavigationLink("診斷與效能") { DiagnosticsView() }
                        .themedRow()
                    TextField("分享卡 QR 網址", text: $service.settings.shareURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .themedRow()
                } header: {
                    header("進階")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(GolfKit.mapAttribution)
                        Text("球場資料來自 OpenStreetMap，依 ODbL 授權使用。你自行繪製或編輯的球場資料只儲存在本機，不會上傳。")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        Link(" Weather 資料來源與法律資訊", destination: Self.weatherLegal)
                            .font(.footnote)
                    }
                    .padding(.vertical, 4)
                    .themedRow()
                } header: {
                    header("關於資料")
                }
            }
            .foregroundStyle(Theme.ivory)
            .premiumBackground()
            .navigationTitle("設定")
        }
    }

    static let weatherLegal = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    private func header(_ text: String) -> some View {
        Eyebrow(text, color: Theme.textSecondary)
    }
}
