import GolfKit
import SwiftUI

/// Derived values for the round screen; keeps logic out of `body`.
struct RoundViewModel {
    static let parChoices = [3, 4, 5]
    static let defaultHoleCount = 18
    static let swipeThreshold: CGFloat = 60

    let round: RoundState
    let course: Course?

    var holeNumber: Int { round.currentHole }
    var hole: Hole? { course?.hole(holeNumber) }
    var holeState: HoleState { round.hole(holeNumber) ?? HoleState(number: holeNumber) }
    var par: Int? { holeState.par ?? hole?.par }
    var shots: [ShotInfo] { holeState.shots }
    var canUndo: Bool { !shots.isEmpty }
    var pin: GeoPoint? { round.pin(for: holeNumber) }
    var friends: [Player] { round.players.filter { !$0.isOwner } }

    var holeCount: Int {
        let n = course?.holes.map(\.number).max() ?? 0
        return n > 0 ? n : Self.defaultHoleCount
    }

    var toParText: String {
        guard let diff = round.toPar else { return "E" }
        return Self.format(toPar: diff)
    }

    func nextHole(_ delta: Int) -> Int? {
        let n = holeNumber + delta
        return (1...holeCount).contains(n) ? n : nil
    }

    func distances(from location: GeoPoint?) -> (front: Double, center: Double, back: Double)? {
        guard let location, let hole else { return nil }
        return hole.distancesMeters(from: location, pin: pin)
    }

    /// Where distances are measured to: pin, else green center.
    var flag: GeoPoint? { pin ?? hole?.effectiveGreenCenter }

    func hazards(from location: GeoPoint?) -> [HazardDistance] {
        guard let hole, let from = location ?? hole.effectiveTee else { return [] }
        return HazardDistances.compute(from: from, hole: hole, target: flag, extraFeatures: course?.features ?? [])
    }

    func defaultTarget(from location: GeoPoint?, profile: ClubProfile) -> GeoPoint? {
        hole?.defaultTarget(from: location, carry: profile.driveDistance)
    }

    func holeBearing(from location: GeoPoint?) -> Double? {
        guard let flag, let from = location ?? hole?.effectiveTee else { return nil }
        return Geo.bearing(from, flag)
    }

    /// Owner's score on a hole was birdie or better.
    func isBirdieOrBetter(hole n: Int) -> Bool {
        guard let h = round.hole(n), h.total > 0, let par = h.par ?? course?.hole(n)?.par else { return false }
        return h.total < par
    }

    func friendScores(hole n: Int) -> [UUID: Int] {
        var out: [UUID: Int] = [:]
        for p in friends { if let s = round.scores(for: p.id)[n] { out[p.id] = s.strokes } }
        return out
    }

    static func format(toPar diff: Int) -> String {
        diff == 0 ? "E" : diff > 0 ? "+\(diff)" : "−\(-diff)"
    }

    static func typeName(_ type: RoundEvent.StrokeType) -> String {
        switch type {
        case .swing: "揮桿"
        case .putt: "推桿"
        case .manual: "補桿"
        }
    }
}

extension EnvironmentValues {
    /// Club distances to use instead of the user's history (showcase).
    @Entry var clubProfileOverride: ClubProfile? = nil
    /// Weather to use instead of WeatherKit (showcase).
    @Entry var weatherOverride: WeatherSnapshot? = nil
}

struct RoundView: View {
    @Environment(RoundStore.self) private var roundStore
    @Environment(CourseRepository.self) private var courses
    @Environment(LocationService.self) private var realLocation
    @Environment(\.locationOverride) private var locationOverride
    @Environment(\.isShowcase) private var isShowcase
    @Environment(\.clubProfileOverride) private var profileOverride
    @Environment(\.weatherOverride) private var weatherOverride
    @Environment(SettingsService.self) private var settingsService
    @Environment(WeatherService.self) private var weatherService
    @Environment(LiveActivityService.self) private var liveActivity
    @Environment(HolePlanStore.self) private var plans
    @Environment(\.dismiss) private var dismiss

    @State private var showScorecard = false
    @State private var showLeaderboard = false
    @State private var showEndConfirm = false
    @State private var manualPoint: GeoPoint?
    @State private var selectedShot: ShotInfo?
    @State private var target: GeoPoint?
    @State private var flyover = 0
    @State private var entryHole: Int?
    @State private var editingPin = false
    @State private var celebrate = 0
    @State private var holeFade = 0.0
    @State private var isFadingHole = false
    @State private var endedRoundId: UUID?
    @State private var profile = ClubProfile()
    @State private var weather: WeatherSnapshot?
    @State private var showNote = false

    private var location: any LocationProviding { locationOverride ?? realLocation }
    private var settings: AppSettings { settingsService.settings }

    var body: some View {
        NavigationStack {
            Group {
                if let endedRoundId {
                    RoundSummaryView(roundId: endedRoundId, onDone: { dismiss() })
                } else if let round = roundStore.active {
                    content(RoundViewModel(round: round, course: roundStore.activeCourse))
                } else {
                    EmptyStateView(icon: "flag.slash", title: "沒有進行中的回合", message: "從球場頁開始一場新的回合。",
                                   actionTitle: "關閉", action: { dismiss() })
                }
            }
            .background(PremiumBackground())
            .navigationTitle(Text(verbatim: endedRoundId == nil ? (roundStore.activeCourse?.name ?? "") : ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { if endedRoundId == nil { toolbar } }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .overlay { if settings.celebrations { CelebrationGlow(trigger: celebrate) } }
        .onAppear {
            if !location.isAuthorized { location.requestPermission() }
            location.start()
            if settings.autoFlyover, let round = roundStore.active, (round.hole(round.currentHole)?.strokes ?? 0) == 0 {
                Task { try? await Task.sleep(for: .seconds(0.6)); flyover += 1 }
            }
        }
        .onDisappear { if locationOverride == nil { location.stop() } }
        .task { await loadProfile() }
        .onChange(of: roundStore.active?.currentHole) { old, new in
            guard let old, let new, old != new else { return }
            holeChanged(from: old, to: new)
        }
        .onChange(of: location.current) { _, p in
            guard !isShowcase, let p, let round = roundStore.active else { return }
            liveActivity.locationChanged(p, state: LiveActivityService.content(
                round: round, course: roundStore.activeCourse, location: p, unit: settings.distanceUnit))
        }
        .task(id: roundStore.active?.currentHole) { await refreshWeather() }
        .sheet(isPresented: $showScorecard) {
            if let round = roundStore.active {
                ScorecardSheet(round: round, holeCount: RoundViewModel(round: round, course: roundStore.activeCourse).holeCount)
            }
        }
        .sheet(isPresented: $showLeaderboard) {
            if let round = roundStore.active {
                LeaderboardView(state: round, course: roundStore.activeCourse,
                                onChangeGame: { roundStore.append(.setGame($0)) },
                                onChangeBets: { roundStore.append(.setBets($0)) })
            }
        }
        .sheet(item: Binding(get: { entryHole.map(HoleRef.init) }, set: { entryHole = $0?.number })) { ref in
            if let round = roundStore.active {
                let vm = RoundViewModel(round: round, course: roundStore.activeCourse)
                PlayerScoreEntrySheet(
                    hole: ref.number, par: round.hole(ref.number)?.par ?? vm.course?.hole(ref.number)?.par,
                    players: vm.friends, existing: vm.friendScores(hole: ref.number)) { values in
                    roundStore.append(values.map { .playerScore(playerId: $0.key, hole: ref.number, strokes: $0.value, putts: nil) })
                }
            }
        }
        .sheet(isPresented: $showNote) {
            if let round = roundStore.active, let course = roundStore.activeCourse {
                HoleNoteSheet(course: course, hole: round.currentHole, roundId: round.roundId)
            }
        }
        .sheet(item: $selectedShot) { shot in
            ShotEditSheet(
                shot: shot,
                onClub: { roundStore.append(.setClub(strokeId: shot.id, club: $0)) },
                onDelete: { roundStore.append(.void(strokeId: shot.id)) })
        }
        .confirmationDialog("在此補一桿", isPresented: manualDialogBinding, titleVisibility: .visible) {
            Button("補一桿") {
                if let point = manualPoint, let n = roundStore.active?.currentHole {
                    roundStore.append(.stroke(hole: n, type: .manual, location: point, swing: nil))
                    Haptics.play(.stroke)
                }
                manualPoint = nil
            }
            Button("取消", role: .cancel) { manualPoint = nil }
        }
        .confirmationDialog("結束回合？", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("結束回合", role: .destructive) { endRound() }
            Button("取消", role: .cancel) {}
        }
    }

    private struct HoleRef: Identifiable { let number: Int; var id: Int { number } }

    private var manualDialogBinding: Binding<Bool> {
        Binding(get: { manualPoint != nil }, set: { if !$0 { manualPoint = nil } })
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("關閉", systemImage: "xmark") { dismiss() }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if (roundStore.active?.players.count ?? 0) > 1 {
                Button("排行榜", systemImage: "trophy") { showLeaderboard = true }
            }
            Button("計分卡", systemImage: "list.number") { showScorecard = true }
                .disabled(roundStore.active == nil)
            Button("結束回合", systemImage: "flag.checkered") { showEndConfirm = true }
                .disabled(roundStore.active == nil)
        }
    }

    @ViewBuilder
    private func content(_ vm: RoundViewModel) -> some View {
        VStack(spacing: 0) {
            HoleHeaderView(
                holeNumber: vm.holeNumber, par: vm.par, holeStrokes: vm.holeState.total,
                totalStrokes: vm.round.totalStrokes, toParText: vm.toParText,
                onSetPar: { roundStore.append(.setPar(hole: vm.holeNumber, par: $0)) })
            map(vm)
                .padding(.bottom, -26)
            controls(vm)
        }
        .background(Theme.background)
        .overlay {
            Theme.background
                .opacity(holeFade)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(holeFade > 0)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func map(_ vm: RoundViewModel) -> some View {
        if let course = roundStore.activeCourse {
            let here = location.current
            HoleMapView(
                course: course, hole: vm.hole, shots: vm.shots, player: here,
                target: $target, pin: vm.pin, hazards: vm.hazards(from: here),
                flyoverTrigger: flyover, defaultTarget: planTarget(vm) ?? vm.defaultTarget(from: here, profile: profile),
                onLongPress: { manualPoint = $0 }, editingPin: editingPin,
                onPinMove: { roundStore.append(.setPin(hole: vm.holeNumber, location: $0)) },
                animatesHoleChange: false)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    ClubSuggestionView(
                        distance: suggestionDistance(vm, from: here), profile: profile,
                        headwind: headwind(vm, from: here), settings: settings)
                    DistanceBadgeView(distances: vm.distances(from: here), settings: settings, toPin: vm.pin != nil)
                }
                .padding(.leading, 14)
                .padding(.bottom, 40)
            }
            .overlay(alignment: .top) {
                if vm.holeState.strokes == 0, let plan = plans.plan(courseId: course.id, hole: vm.holeNumber) {
                    HoleNoteBanner(plan: plan)
                        .padding(.horizontal, 60)
                        .padding(.top, 10)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    if let weather, let bearing = vm.holeBearing(from: here) {
                        WindBadgeView(snapshot: weather, holeBearing: bearing)
                    }
                    if !isShowcase { PaceBadgeView(round: vm.round) }
                    mapButtons(vm)
                }
                .padding(10)
            }
        } else {
            Theme.background.overlay(ProgressView().tint(Theme.gold))
        }
    }

    private func mapButtons(_ vm: RoundViewModel) -> some View {
        HStack(spacing: 8) {
            if HoleFlyover.canPlay(vm.hole) {
                Button { flyover += 1 } label: { Image(systemName: "play.circle") }
                    .buttonStyle(CircleIconButtonStyle(size: 36))
                    .accessibilityLabel("重播球洞飛越")
            }
            if let presets = vm.hole?.pinPresets() {
                Menu {
                    Button("前段旗位") { roundStore.append(.setPin(hole: vm.holeNumber, location: presets.front)) }
                    Button("中段旗位") { roundStore.append(.setPin(hole: vm.holeNumber, location: presets.center)) }
                    Button("後段旗位") { roundStore.append(.setPin(hole: vm.holeNumber, location: presets.back)) }
                    if vm.hole?.green != nil {
                        Button(editingPin ? "完成拖曳" : "拖曳調整旗桿") { editingPin.toggle() }
                    }
                } label: {
                    Image(systemName: editingPin ? "flag.checkered.circle.fill" : "flag.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(editingPin ? Theme.gold : Theme.ivory)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.surface.opacity(0.8)))
                        .overlay(Circle().strokeBorder(Theme.hairline))
                }
                .accessibilityLabel("旗桿位置")
            }
            if !isShowcase {
                Button { showNote = true } label: { Image(systemName: "note.text.badge.plus") }
                    .buttonStyle(CircleIconButtonStyle(size: 36))
                    .accessibilityLabel("筆記與照片")
            }
            if target != nil {
                Button { withAnimation(Motion.snappy) { target = nil } } label: { Image(systemName: "scope") }
                    .buttonStyle(CircleIconButtonStyle(size: 36))
                    .accessibilityLabel("重設目標點")
            }
        }
    }

    private func controls(_ vm: RoundViewModel) -> some View {
        VStack(spacing: 12) {
            Capsule().fill(Theme.ivory.opacity(0.15)).frame(width: 36, height: 4)
            WolfPickBar(state: vm.round, hole: vm.holeNumber) { roundStore.append(.wolfPick(hole: vm.holeNumber, partnerId: $0)) }
            HazardListView(hazards: vm.hazards(from: location.current), settings: settings)
            ShotListView(shots: vm.shots, settings: settings) { selectedShot = $0 }
            StrokeControlsView(
                canUndo: vm.canUndo,
                onSwing: { addStroke(.swing, vm) },
                onPutt: { addStroke(.putt, vm) },
                onPenalty: { roundStore.append(.penalty(hole: vm.holeNumber, count: 1, reason: $0)) },
                onUndo: { if let last = vm.shots.last { roundStore.append(.void(strokeId: last.id)) } })
            HStack {
                navButton("chevron.left", target: vm.nextHole(-1), label: "上一洞")
                Spacer()
                HStack(spacing: 5) {
                    ForEach(1...vm.holeCount, id: \.self) { n in
                        Capsule()
                            .fill(n == vm.holeNumber ? Theme.gold : Theme.ivory.opacity(vm.round.hole(n).map { $0.total > 0 } == true ? 0.4 : 0.12))
                            .frame(width: n == vm.holeNumber ? 14 : 5, height: 5)
                    }
                }
                .animation(Motion.snappy, value: vm.holeNumber)
                .accessibilityElement()
                .accessibilityLabel("第 \(vm.holeNumber) 洞，共 \(vm.holeCount) 洞")
                Spacer()
                navButton("chevron.right", target: vm.nextHole(1), label: "下一洞")
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
                .fill(Theme.background)
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
                        .strokeBorder(Theme.hairline))
                .shadow(color: Theme.scrim, radius: 20, y: -6)
                .ignoresSafeArea(edges: .bottom))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > RoundViewModel.swipeThreshold, abs(dx) > abs(value.translation.height) else { return }
                if let n = vm.nextHole(dx < 0 ? 1 : -1) { goToHole(n) }
            })
    }

    private func navButton(_ icon: String, target: Int?, label: String) -> some View {
        Button {
            if let target { goToHole(target) }
        } label: {
            Image(systemName: icon)
        }
        .buttonStyle(CircleIconButtonStyle(size: Theme.iconButton))
        .disabled(target == nil)
        .opacity(target == nil ? 0.35 : 1)
        .accessibilityLabel(LocalizedStringKey(label))
    }

    // MARK: Actions

    private func addStroke(_ type: RoundEvent.StrokeType, _ vm: RoundViewModel) {
        roundStore.append(.stroke(hole: vm.holeNumber, type: type, location: location.current, swing: nil))
        Haptics.play(.stroke)
    }

    /// Fade to dark, switch hole while hidden, then fade back in.
    private func goToHole(_ n: Int) {
        guard !isFadingHole else { return }
        isFadingHole = true
        withAnimation(.easeIn(duration: Motion.holeFadeOut)) { holeFade = 1 }
        Task {
            try? await Task.sleep(for: .seconds(Motion.holeFadeOut))
            roundStore.append(.goToHole(n))
            try? await Task.sleep(for: .seconds(Motion.holeFadeHold))
            withAnimation(.easeOut(duration: Motion.holeFadeIn)) { holeFade = 0 }
            isFadingHole = false
        }
    }

    private func holeChanged(from old: Int, to new: Int) {
        if !isFadingHole {
            // Changed elsewhere (watch, auto-advance, showcase): already switched, so just fade in.
            holeFade = 1
            withAnimation(.easeOut(duration: Motion.holeFadeIn)) { holeFade = 0 }
        }
        target = nil
        editingPin = false
        Haptics.play(.holeChange)
        guard let round = roundStore.active else { return }
        let vm = RoundViewModel(round: round, course: roundStore.activeCourse)
        if new > old, vm.isBirdieOrBetter(hole: old) {
            celebrate += 1
            Haptics.play(.birdie)
        }
        if new > old, !vm.friends.isEmpty, vm.friendScores(hole: old).count < vm.friends.count {
            entryHole = old
        }
        // No auto flyover on hole change: after the fade the new hole should just appear.
    }

    private func endRound() {
        guard let round = roundStore.active else { return }
        let id = round.roundId
        roundStore.end()
        withAnimation(Motion.hero) { endedRoundId = id }
        if !isShowcase { liveActivity.end() }
    }

    /// The player's planned aim point for the next shot on this hole.
    private func planTarget(_ vm: RoundViewModel) -> GeoPoint? {
        guard let course = vm.course, let plan = plans.plan(courseId: course.id, hole: vm.holeNumber) else { return nil }
        let index = vm.shots.filter { $0.type != .putt }.count
        return plan.targets.indices.contains(index) ? plan.targets[index] : nil
    }

    private func suggestionDistance(_ vm: RoundViewModel, from p: GeoPoint?) -> Double? {
        guard let p else { return nil }
        if let target { return Geo.distance(p, target) }
        return vm.flag.map { Geo.distance(p, $0) }
    }

    private func headwind(_ vm: RoundViewModel, from p: GeoPoint?) -> Double? {
        guard let weather, let bearing = vm.holeBearing(from: p) else { return nil }
        return WindComponent.relative(windFromDeg: weather.windFromDeg, speed: weather.windSpeed, holeBearing: bearing).head
    }

    private func loadProfile() async {
        if let profileOverride { profile = profileOverride; return }
        let records = roundStore.history().prefix(60)
        var states: [RoundState] = []
        var dict: [String: Course] = [:]
        for r in records {
            let c = courses.course(id: r.courseId)
            if let c { dict[c.id] = c }
            states.append(RoundStore.state(of: r, course: c))
        }
        profile = ClubProfile.build(rounds: states, courses: dict)
    }

    private func refreshWeather() async {
        if let weatherOverride { weather = weatherOverride; return }
        guard !isShowcase else { return }
        let p = location.current ?? roundStore.activeCourse?.center
        guard let p else { return }
        weather = await weatherService.current(at: p)
    }
}
