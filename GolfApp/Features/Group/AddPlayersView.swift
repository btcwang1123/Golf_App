import GolfKit
import SwiftUI

/// Before a round: add 0–3 friends (one tap from recent players) and pick a game.
struct AddPlayersView: View {
    let course: Course
    let onStart: ([Player], GameFormat, BetConfig?) -> Void

    @Environment(RecentPlayersStore.self) private var recent
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [Player] = []
    @State private var name = ""
    @State private var handicap: Int?
    @State private var game = GameFormat.stroke
    @State private var bets = BetConfig()
    @State private var showPrimer = false
    @AppStorage("primer.motion.shown") private var motionPrimerShown = false
    @FocusState private var nameFocused: Bool

    private var canAdd: Bool { friends.count < Player.maxPerRound - 1 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(friends) { p in
                        HStack {
                            Text(verbatim: p.name)
                            Spacer()
                            if let h = p.handicap { Text("差點 \(h)").foregroundStyle(Theme.textSecondary) }
                        }
                        .themedRow()
                    }
                    .onDelete { friends.remove(atOffsets: $0) }
                    if canAdd {
                        HStack {
                            TextField("朋友名字", text: $name)
                                .focused($nameFocused)
                                .submitLabel(.done)
                                .onSubmit(addTyped)
                            // Borderless so only the button itself is tappable — otherwise Form
                            // routes taps anywhere in the row to a single control.
                            Button("加入", action: addTyped)
                                .buttonStyle(.borderless)
                                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .themedRow()
                        // Own row: a Picker sharing a row with the text field hijacked every tap.
                        Picker("差點", selection: $handicap) {
                            Text("無差點").tag(Int?.none)
                            ForEach(0...36, id: \.self) { Text("\($0)").tag(Int?.some($0)) }
                        }
                        .pickerStyle(.menu)
                        .themedRow()
                    }
                } header: {
                    Eyebrow("同組朋友（最多 3 位）", color: Theme.textSecondary)
                } footer: {
                    Text("朋友不需要安裝 App。每洞結束時快速輸入大家的桿數。")
                }

                let suggestions = recent.entries.filter { e in !friends.contains { $0.name == e.name } }
                if canAdd, !suggestions.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions) { e in
                                    Button {
                                        add(Player(name: e.name, handicap: e.handicap))
                                    } label: {
                                        Label(e.name, systemImage: "plus")
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Capsule().fill(Theme.surfaceRaised))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("加入 \(e.name)")
                                }
                            }
                        }
                        .themedRow()
                    } header: {
                        Eyebrow("最近一起打球", color: Theme.textSecondary)
                    }
                }

                if !friends.isEmpty {
                    Section {
                        GameSetupView(game: $game, playerCount: friends.count + 1, course: course).themedRow()
                    } header: {
                        Eyebrow("玩法", color: Theme.textSecondary)
                    }
                    Section {
                        BetSetupView(config: $bets, players: [.owner()] + friends).themedRow()
                    } header: {
                        Eyebrow("賭局（選填）", color: Theme.textSecondary)
                    }
                }
            }
            .premiumBackground()
            .navigationTitle(Text(verbatim: course.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if motionPrimerShown { start() } else { showPrimer = true }
                } label: {
                    Label(friends.isEmpty ? "開始回合" : "開始回合（\(friends.count + 1) 人）", systemImage: "figure.golf")
                }
                .buttonStyle(GoldButtonStyle())
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 8)
            }
            .sheet(isPresented: $showPrimer, onDismiss: {
                motionPrimerShown = true
                start()
            }) {
                PermissionPrimerView(kind: .motion)
            }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
    }

    private func addTyped() {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        add(Player(name: n, handicap: handicap))
        name = ""
        handicap = nil
    }

    private func add(_ p: Player) {
        guard canAdd else { return }
        withAnimation(Motion.snappy) { friends.append(p) }
        Haptics.play(.selection)
    }

    private func start() {
        recent.remember(friends)
        let g = game.kind.allows(playerCount: friends.count + 1) ? game : GameFormat(kind: .stroke, useHandicap: game.useHandicap)
        dismiss()
        onStart(friends, g, bets.isEmpty ? nil : bets)
    }
}
