import GolfKit
import SwiftUI

/// Picks the game format; match play only with exactly two players.
struct GameSetupView: View {
    @Binding var game: GameFormat
    let playerCount: Int
    let course: Course?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("玩法", selection: $game.kind) {
                ForEach(GameFormat.Kind.allCases, id: \.self) { k in
                    Text(LocalizedStringKey(k.title)).tag(k)
                        .disabled(!k.allows(playerCount: playerCount))
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: playerCount) {
                if !game.kind.allows(playerCount: playerCount) { game.kind = .stroke }
            }
            Toggle("套用差點讓桿", isOn: $game.useHandicap)
                .tint(Theme.gold)
            Text(LocalizedStringKey(Self.explain(game.kind)))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            if game.kind == .match, playerCount != 2 {
                Text("比洞限兩人").font(.caption).foregroundStyle(Theme.warning)
            }
            if game.useHandicap, HandicapAllocator.usesEvenSpread(course: course) {
                Text("此球場缺少洞難度，讓桿將依洞號平均分配。")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
        }
    }

    static func explain(_ k: GameFormat.Kind) -> String {
        switch k {
        case .stroke: "總桿數少者勝。"
        case .stableford: "依每洞淨桿對標準桿計分：雙柏忌以上 0、柏忌 1、平標準 2、博蒂 3、老鷹 4。"
        case .match: "逐洞比勝負，顯示 UP / DN 與 3&2。"
        case .skins: "該洞唯一最低者得 1 skin，平手累積到下一洞。"
        }
    }
}
