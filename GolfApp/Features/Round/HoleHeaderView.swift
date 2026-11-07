import SwiftUI

struct HoleHeaderView: View {
    let holeNumber: Int
    let par: Int?
    let holeStrokes: Int
    let totalStrokes: Int
    let toParText: String
    let onSetPar: (Int) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(holeNumber)")
                    .font(Theme.display(46))
                    .foregroundStyle(Theme.ivory)
                    .contentTransition(.numericText(value: Double(holeNumber)))
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow("Hole")
                    parView
                }
            }
            Spacer()
            stat(title: "本洞", value: "\(holeStrokes)")
            Rectangle().fill(Theme.hairline).frame(width: 1, height: 34).padding(.horizontal, 16)
            stat(title: "總桿", value: "\(totalStrokes)", detail: toParText)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 10)
        .background(Theme.background)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    @ViewBuilder private var parView: some View {
        if let par {
            Text("PAR \(par)")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Theme.textSecondary)
        } else {
            Menu {
                ForEach(RoundViewModel.parChoices, id: \.self) { value in
                    Button("Par \(value)") { onSetPar(value) }
                }
            } label: {
                Text("設定 PAR").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.gold)
            }
        }
    }

    private func stat(title: String, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Eyebrow(title, color: Theme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(Theme.numeral(26, weight: .regular))
                    .foregroundStyle(Theme.ivory)
                    .contentTransition(.numericText())
                if let detail {
                    Text(detail).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.gold)
                }
            }
        }
    }
}
