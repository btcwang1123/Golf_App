import GolfKit
import SwiftUI

/// Survey controls shown in the course editor: stand on the spot, tap, wait 8 seconds.
struct SurveyModeView: View {
    @Bindable var survey: SurveyModel
    let settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow("實地踩點 · 第 \(survey.currentHole) 洞")
                Spacer()
                accuracyBadge
            }
            switch survey.phase {
            case .idle:
                idleControls
            case .sampling(let m, let left):
                HStack(spacing: 12) {
                    ProgressView(value: Double(SurveyModel.sampleSeconds - left), total: Double(SurveyModel.sampleSeconds))
                        .tint(Theme.gold)
                    (Text(LocalizedStringKey(m.title)) + Text(verbatim: " · ") + Text("\(left) 秒"))
                        .font(Theme.numeral(15, weight: .medium))
                        .foregroundStyle(Theme.ivory)
                        .contentTransition(.numericText())
                    Button("取消") { survey.cancel() }.buttonStyle(.bordered)
                }
                Text("請站定不動，取樣 \(survey.averager.count) 筆")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            case .result(let m, _, let err, let retry):
                VStack(alignment: .leading, spacing: 8) {
                    (Text(LocalizedStringKey(m.title)) + Text("：誤差約 \(Int(err.rounded())) m"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(retry ? Theme.warning : Theme.fairway)
                    if retry {
                        Text("精度不足（平均 > 8 m），建議重測。")
                            .font(.caption).foregroundStyle(Theme.warning)
                    }
                    HStack {
                        Button("重測") { survey.retry() }.buttonStyle(.bordered)
                        Button("使用此點") { survey.accept() }.buttonStyle(.borderedProminent)
                    }
                }
            case .walking(let n):
                HStack {
                    Image(systemName: "figure.walk").foregroundStyle(Theme.gold)
                        .symbolEffect(.pulse, options: .repeating)
                    Text("沿果嶺邊緣走一圈 · \(n) 點")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ivory)
                        .contentTransition(.numericText())
                    Spacer()
                    Button("結束繞果嶺") { survey.endWalk() }.buttonStyle(.borderedProminent)
                }
            }
            if let msg = survey.lastMessage {
                Text(msg).font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous).fill(Theme.surface))
        .padding(.horizontal)
        .tint(Theme.gold)
    }

    private var idleControls: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(SurveyModel.Mark.allCases) { m in
                    Button(LocalizedStringKey(m.title)) { survey.mark(m) }
                        .buttonStyle(GhostButtonStyle(compact: true))
                }
            }
            Button("開始繞果嶺", systemImage: "point.topleft.down.to.point.bottomright.curvepath") { survey.startWalk() }
                .buttonStyle(GoldButtonStyle(compact: true))
            Text("先在發球台標記，再走到果嶺；標好發球台與果嶺中心即自動產生球道線。")
                .font(.caption2).foregroundStyle(Theme.textTertiary)
        }
    }

    private var accuracyBadge: some View {
        let acc = survey.accuracy
        let good = (acc ?? .infinity) <= PointAverager.warnAccuracy
        return Label(acc.map { "±\(Int($0.rounded())) m" } ?? "無定位", systemImage: "location.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(good ? Theme.fairway : Theme.warning)
            .accessibilityLabel("定位精度 \(acc.map { "\(Int($0.rounded())) 公尺" } ?? "無")")
    }
}
