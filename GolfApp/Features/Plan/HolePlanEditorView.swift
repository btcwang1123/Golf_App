import GolfKit
import SwiftUI

/// Tap the hole map to place up to three aim points; pick a club per shot and write a note.
struct HolePlanEditorView: View {
    let course: Course
    let hole: Hole

    @Environment(HolePlanStore.self) private var store
    @Environment(SettingsService.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var plan: HolePlan
    @State private var editingIndex = 0
    @State private var tapTarget: GeoPoint?

    static let maxTargets = 3

    init(course: Course, hole: Hole, plan: HolePlan?) {
        self.course = course
        self.hole = hole
        _plan = State(initialValue: plan ?? HolePlan(courseId: course.id, hole: hole.number))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HoleMapView(course: course, hole: hole, shots: planShots, player: nil, target: $tapTarget,
                            pin: nil, animatesHoleChange: false)
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .top) {
                        Text("點地圖放置第 \(editingIndex + 1) 桿的目標")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(Theme.surface.opacity(0.9)))
                            .padding(.top, 10)
                    }
                form
            }
            .background(Theme.background)
            .navigationTitle("第 \(hole.number) 洞攻略")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        store.save(plan)
                        dismiss()
                    }
                }
            }
            .onChange(of: tapTarget) { _, p in
                guard let p else { return }
                if editingIndex < plan.targets.count { plan.targets[editingIndex] = p } else { plan.targets.append(p) }
                tapTarget = nil
                if editingIndex < Self.maxTargets - 1, editingIndex == plan.targets.count - 1 { editingIndex += 1 }
                Haptics.play(.selection)
            }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
    }

    /// Aim points drawn as a shot line from the tee.
    private var planShots: [ShotInfo] {
        let points = [hole.effectiveTee].compactMap { $0 } + plan.targets
        return points.enumerated().map { i, p in
            ShotInfo(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(i))), type: .swing,
                     location: p, club: i > 0 ? plan.club(for: i - 1) : nil, timestamp: Date(timeIntervalSince1970: Double(i)))
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(0..<Self.maxTargets, id: \.self) { i in
                    let has = i < plan.targets.count
                    Button {
                        editingIndex = min(i, plan.targets.count)
                    } label: {
                        VStack(spacing: 2) {
                            Text("第 \(i + 1) 桿").font(.caption.weight(.semibold))
                            Text(distanceLabel(i)).font(.caption2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(editingIndex == i ? Theme.onGold : (has ? Theme.ivory : Theme.textTertiary))
                        .background(RoundedRectangle(cornerRadius: Theme.cornerTiny)
                            .fill(editingIndex == i ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.surfaceRaised)))
                    }
                    .buttonStyle(.plain)
                    .disabled(i > plan.targets.count)
                }
            }
            if editingIndex < plan.targets.count {
                HStack {
                    Picker("球桿", selection: clubBinding(editingIndex)) {
                        Text("未指定").tag(Club?.none)
                        ForEach(Club.allCases.filter { $0 != .putter }, id: \.self) { Text(verbatim: $0.displayName).tag(Club?.some($0)) }
                    }
                    Spacer()
                    Button("移除此點", role: .destructive) {
                        plan.targets.remove(at: editingIndex)
                        if editingIndex < plan.clubs.count { plan.clubs.remove(at: editingIndex) }
                        editingIndex = max(0, min(editingIndex, plan.targets.count))
                    }
                    .font(.footnote)
                }
            }
            TextField("筆記：例如果嶺很快、右邊 OB", text: $plan.note, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Color.white.opacity(0.05)))
        }
        .padding(Theme.gutter)
        .background(Theme.background)
    }

    private func distanceLabel(_ i: Int) -> String {
        guard i < plan.targets.count else { return "—" }
        let from = i == 0 ? hole.effectiveTee : plan.targets[i - 1]
        guard let from else { return "—" }
        return settings.settings.format(meters: Geo.distance(from, plan.targets[i]))
    }

    private func clubBinding(_ i: Int) -> Binding<Club?> {
        Binding(
            get: { plan.club(for: i) },
            set: { new in
                while plan.clubs.count <= i { plan.clubs.append(.driver) }
                if let new { plan.clubs[i] = new } else if i == plan.clubs.count - 1 { plan.clubs.removeLast() }
            })
    }
}

/// All holes of a course with their plan status.
struct CoursePlanView: View {
    let course: Course

    @Environment(HolePlanStore.self) private var store
    @State private var editing: EditingHole?

    var body: some View {
        let plans = store.plans(courseId: course.id)
        List {
            Section {
                ForEach(course.holes.filter { HoleQuality.evaluate($0).isPlayable }, id: \.number) { hole in
                    Button { editing = EditingHole(hole: hole) } label: {
                        HStack(spacing: 14) {
                            Text(verbatim: "\(hole.number)").font(Theme.numeral(17, weight: .medium)).foregroundStyle(Theme.gold).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hole.par.map { "Par \($0)" } ?? "—").foregroundStyle(Theme.ivory)
                                if let p = plans[hole.number] {
                                    Text(verbatim: summary(p)).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: plans[hole.number] == nil ? "plus.circle" : "checkmark.circle.fill")
                                .foregroundStyle(plans[hole.number] == nil ? Theme.textTertiary : Theme.fairway)
                        }
                    }
                    .themedRow()
                }
            } footer: {
                Text("打這座球場時，地圖會顯示你的目標點，並在開球前提醒筆記。")
            }
        }
        .premiumBackground()
        .navigationTitle("攻略規劃")
        .sheet(item: $editing) { e in
            HolePlanEditorView(course: course, hole: e.hole, plan: plans[e.hole.number])
        }
    }

    private func summary(_ p: HolePlan) -> String {
        let clubs = p.clubs.prefix(p.targets.count).map(\.displayName).joined(separator: " → ")
        return [clubs.isEmpty ? nil : clubs, p.note.isEmpty ? nil : p.note].compactMap { $0 }.joined(separator: " · ")
    }
}

private struct EditingHole: Identifiable {
    let hole: Hole
    var id: Int { hole.number }
}
