import GolfKit
import SwiftUI

/// Hand-entered scorecard: pick a course (or type a name), date, then score each hole.
struct ManualRoundEntryView: View {
    @Environment(RoundStore.self) private var roundStore
    @Environment(CourseRepository.self) private var courses
    @Environment(\.dismiss) private var dismiss

    /// Existing manual round to edit; nil creates a new one.
    let editing: RoundRecord?

    @State private var course: Course?
    @State private var customName = ""
    @State private var date = Date()
    @State private var holeCount = 18
    @State private var holes: [ManualHoleScore] = []
    @State private var selected = 1
    @State private var showCoursePicker = false
    @State private var showDiscard = false
    @State private var loaded = false
    @State private var showScan = false

    private static let holeCounts = [9, 18]

    init(course: Course? = nil, editing: RoundRecord? = nil) {
        self.editing = editing
        _course = State(initialValue: course)
    }

    // MARK: Derived

    private var courseHoleCount: Int? {
        guard let course, !course.holes.isEmpty else { return nil }
        return course.holes.map(\.number).max()
    }

    private var played: [ManualHoleScore] { holes.filter(\.isPlayed) }
    private var total: Int { played.reduce(0) { $0 + $1.strokes } }
    private var toPar: Int? { played.isEmpty ? nil : played.reduce(0) { $0 + $1.strokes - $1.par } }
    private var totalPutts: Int { played.reduce(0) { $0 + $1.putts } }
    private var courseName: String {
        course?.name ?? customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var canSave: Bool { !played.isEmpty && !courseName.isEmpty }
    private var isDirty: Bool { !played.isEmpty || course != nil || !customName.isEmpty }

    private var current: Binding<ManualHoleScore> {
        Binding(
            get: { holes.first { $0.number == selected } ?? ManualHoleScore(number: selected, par: 4) },
            set: { newValue in
                guard let i = holes.firstIndex(where: { $0.number == newValue.number }) else { return }
                var v = newValue
                v.clamp()
                holes[i] = v
            })
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    roundInfoCard
                    holeStrip
                    holeCard
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, 140)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PremiumBackground())
            .safeAreaInset(edge: .bottom) { summaryBar }
            .navigationTitle(editing == nil ? "手動記錄" : "編輯成績")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        if isDirty && editing == nil { showDiscard = true } else { dismiss() }
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
            }
            .confirmationDialog("放棄這份記錄？", isPresented: $showDiscard, titleVisibility: .visible) {
                Button("放棄", role: .destructive) { dismiss() }
                Button("繼續編輯", role: .cancel) {}
            }
            .sheet(isPresented: $showScan) {
                ScorecardScanView { scores, pars in applyScan(scores: scores, pars: pars) }
            }
            .sheet(isPresented: $showCoursePicker) {
                CoursePickerSheet { picked in
                    course = picked
                    rebuildHoles(keepScores: true)
                }
            }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isDirty)
        .onAppear(perform: loadIfNeeded)
    }

    // MARK: Sections

    private var roundInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow("回合資訊")
            Button { showCoursePicker = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.gold)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.gold.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course?.name ?? "選擇球場")
                            .font(Theme.display(18, weight: .medium))
                            .foregroundStyle(Theme.ivory)
                            .lineLimit(1)
                        Text(course?.county ?? "或在下方輸入未列出的球場")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if course == nil {
                TextField("球場名稱", text: $customName, prompt: Text("輸入球場名稱").foregroundStyle(Theme.textTertiary))
                    .font(.body)
                    .foregroundStyle(Theme.ivory)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline))
            } else {
                Button("改為手動輸入球場名稱") {
                    course = nil
                    rebuildHoles(keepScores: true)
                }
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            }

            if editing == nil {
                Button { showScan = true } label: {
                    Label("掃描紙本記分卡", systemImage: "doc.viewfinder")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.gold)
            }

            Divider().overlay(Theme.hairline)

            DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .foregroundStyle(Theme.ivory)

            if courseHoleCount == nil {
                HStack {
                    Text("洞數").foregroundStyle(Theme.ivory)
                    Spacer()
                    Picker("洞數", selection: $holeCount) {
                        ForEach(Self.holeCounts, id: \.self) { Text("\($0) 洞").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                .onChange(of: holeCount) { rebuildHoles(keepScores: true) }
            }
        }
        .card()
    }

    private var holeStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "逐洞成績", trailing: "\(played.count)/\(holes.count) 洞")
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(holes) { hole in
                            holeChip(hole).id(hole.number)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onChange(of: selected) { _, n in
                    withAnimation(.snappy) { proxy.scrollTo(n, anchor: .center) }
                }
            }
        }
    }

    private func holeChip(_ hole: ManualHoleScore) -> some View {
        let isSelected = hole.number == selected
        return Button {
            withAnimation(.snappy) { selected = hole.number }
        } label: {
            VStack(spacing: 6) {
                Text("\(hole.number)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.gold : Theme.textSecondary)
                ScoreMark(strokes: hole.isPlayed ? hole.strokes : nil, par: hole.par, size: 30)
            }
            .frame(width: 50, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Theme.surfaceRaised : Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Theme.gold.opacity(0.7) : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var holeCard: some View {
        let hole = current.wrappedValue
        let tone = ScoreTone(strokes: hole.isPlayed ? hole.strokes : nil, par: hole.par)
        return VStack(spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow("Hole")
                    Text("第 \(hole.number) 洞")
                        .font(Theme.display(30))
                        .foregroundStyle(Theme.ivory)
                }
                Spacer()
                if hole.isPlayed, tone != .none {
                    Tag(text: tone.label, color: tone.color)
                }
            }

            parSelector(hole)

            ValueStepper(
                title: "總桿數", value: current.strokes, range: ManualHoleScore.strokeRange, emphasized: true)

            quickPicks(hole)

            Divider().overlay(Theme.hairline)

            HStack(spacing: 8) {
                ValueStepper(title: "推桿", value: current.putts, range: 0...max(0, hole.strokes - hole.penalties))
                Rectangle().fill(Theme.hairline).frame(width: 1, height: 70)
                ValueStepper(title: "罰桿", value: current.penalties, range: 0...max(0, hole.strokes - hole.putts))
            }

            HStack(spacing: 12) {
                Button {
                    withAnimation(.snappy) { selected = max(1, selected - 1) }
                } label: {
                    Label("上一洞", systemImage: "chevron.left")
                }
                .buttonStyle(GhostButtonStyle(compact: true))
                .disabled(selected <= 1)
                .opacity(selected <= 1 ? 0.4 : 1)

                Button {
                    withAnimation(.snappy) { selected = min(holes.count, selected + 1) }
                } label: {
                    Label("下一洞", systemImage: "chevron.right").labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(GoldButtonStyle(compact: true))
                .disabled(selected >= holes.count)
                .opacity(selected >= holes.count ? 0.4 : 1)
            }
        }
        .card(padding: 22, raised: true)
    }

    private func parSelector(_ hole: ManualHoleScore) -> some View {
        HStack(spacing: 10) {
            Text("PAR")
                .font(Theme.eyebrow)
                .tracking(1.6)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            ForEach(ManualHoleScore.parRange.prefix(3), id: \.self) { p in
                let on = hole.par == p
                Button {
                    withAnimation(.snappy) { current.par.wrappedValue = p }
                } label: {
                    Text("\(p)")
                        .font(Theme.numeral(17, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? Theme.onGold : Theme.ivory)
                        .frame(width: 46, height: 36)
                        .background(Capsule().fill(on ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Color.white.opacity(0.05))))
                        .overlay(Capsule().strokeBorder(on ? .clear : Theme.hairline))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func quickPicks(_ hole: ManualHoleScore) -> some View {
        let picks: [(String, Int)] = [("博蒂", -1), ("平標準", 0), ("柏忌", 1), ("雙柏忌", 2)]
        return HStack(spacing: 8) {
            ForEach(picks, id: \.1) { name, delta in
                let value = hole.par + delta
                let on = hole.strokes == value
                Button {
                    withAnimation(.snappy) {
                        var h = current.wrappedValue
                        h.strokes = value
                        if h.putts == 0 && !hole.isPlayed { h.putts = min(2, value) }
                        current.wrappedValue = h
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text("\(value)").font(Theme.numeral(16, weight: .medium))
                        Text(name).font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(on ? Theme.gold : Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(on ? 0.08 : 0.03)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(on ? Theme.gold.opacity(0.6) : Theme.hairline))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 18) {
            HStack(spacing: 18) {
                summaryItem("總桿", total > 0 ? "\(total)" : "—")
                summaryItem("對標準桿", ScoreFormat.toPar(toPar))
                summaryItem("推桿", totalPutts > 0 ? "\(totalPutts)" : "—")
            }
            Spacer(minLength: 0)
            Button(action: save) {
                Text(editing == nil ? "儲存" : "更新")
            }
            .buttonStyle(GoldButtonStyle(compact: true))
            .frame(width: 110)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Theme.background.opacity(0.55))
                .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
                .ignoresSafeArea())
    }

    private func summaryItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.textSecondary)
            Text(value).font(Theme.numeral(22, weight: .regular)).foregroundStyle(Theme.ivory)
        }
    }

    // MARK: Actions

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        if let editing {
            course = courses.course(id: editing.courseId)
            if course == nil { customName = editing.courseName }
            date = editing.startedAt
            let state = RoundStore.state(of: editing, course: course)
            let maxPlayed = state.holes.filter { $0.strokes > 0 || $0.penalties > 0 }.map(\.number).max() ?? 18
            holeCount = courseHoleCount ?? (maxPlayed <= 9 ? 9 : 18)
            holes = ManualHoleScore.from(state: state, holeCount: holeCount, defaultPar: defaultPar)
        } else {
            rebuildHoles(keepScores: false)
        }
    }

    private func defaultPar(_ n: Int) -> Int { course?.hole(n)?.par ?? 4 }

    private func rebuildHoles(keepScores: Bool) {
        let count = courseHoleCount ?? holeCount
        let old = Dictionary(uniqueKeysWithValues: holes.map { ($0.number, $0) })
        holes = (1...max(count, 1)).map { n in
            var h = ManualHoleScore(number: n, par: defaultPar(n))
            if keepScores, let prev = old[n] {
                h.strokes = prev.strokes
                h.putts = prev.putts
                h.penalties = prev.penalties
                if course?.hole(n)?.par == nil { h.par = prev.par }
            }
            return h
        }
        selected = min(selected, holes.count)
    }

    /// Fills holes from a scanned scorecard; pars only where the course has none.
    private func applyScan(scores: [Int: Int], pars: [Int: Int]) {
        if courseHoleCount == nil { holeCount = (scores.keys.max() ?? 18) > 9 ? 18 : 9 }
        rebuildHoles(keepScores: true)
        for i in holes.indices {
            let n = holes[i].number
            if course?.hole(n)?.par == nil, let p = pars[n], ManualHoleScore.parRange.contains(p) { holes[i].par = p }
            if let s = scores[n] {
                holes[i].strokes = s
                holes[i].clamp()
            }
        }
        if let first = holes.first(where: { !$0.isPlayed })?.number { selected = first }
        Haptics.play(.selection)
    }

    private func save() {
        guard canSave else { return }
        let id = course?.id ?? "manual-\(courseName)"
        if let editing {
            roundStore.updateManual(editing, courseId: id, courseName: courseName, date: date, holes: holes)
        } else {
            roundStore.recordManual(courseId: id, courseName: courseName, date: date, holes: holes)
        }
        dismiss()
    }
}

/// Puts the icon after the title.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
        }
    }
}

/// Searchable list for choosing a course.
struct CoursePickerSheet: View {
    let onPick: (Course) -> Void

    @Environment(CourseRepository.self) private var courses
    @Environment(LocationService.self) private var location
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(courses.list(query: query, near: location.current)) { item in
                    Button {
                        onPick(item.course)
                        dismiss()
                    } label: {
                        CourseRowView(item: item, compact: true)
                    }
                    .buttonStyle(.plain)
                    .themedRow()
                }
            }
            .listStyle(.insetGrouped)
            .premiumBackground()
            .searchable(text: $query, prompt: "搜尋球場或縣市")
            .navigationTitle("選擇球場")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }.foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
    }
}
