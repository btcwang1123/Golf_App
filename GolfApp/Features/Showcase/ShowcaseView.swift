import GolfKit
import SwiftData
import SwiftUI

/// 30–60 s auto-playing demo using the real round screen with an in-memory store and simulated GPS.
struct ShowcaseView: View {
    @Environment(CourseRepository.self) private var mainCourses
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var session: ShowcaseSession?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let session {
                ShowcasePlayer(session: session, onClose: { dismiss() }, onStartReal: startReal, onReplay: replay)
                    .id(session.id)
            } else {
                ProgressView().tint(Theme.gold)
            }
        }
        .preferredColorScheme(.dark)
        .task { if session == nil { session = ShowcaseSession(courses: mainCourses) } }

    }

    private func replay() {
        session?.stop()
        session = ShowcaseSession(courses: mainCourses)
    }

    private func startReal() {
        dismiss()
        router.tab = .courses
    }
}

/// One playthrough: its own model container, round store, course list and GPS.
@MainActor @Observable
final class ShowcaseSession: Identifiable {
    let id = UUID()
    let container: ModelContainer
    let courses: CourseRepository
    let store: RoundStore
    let location: SimulatedLocationProvider
    let script: ShowcaseScript?
    let course: Course
    let steps: [ShowcaseScript.Step]

    private(set) var stepIndex = 0
    private(set) var caption = ""
    private(set) var toast: String?
    private(set) var finishedRoundId: UUID?
    var isPaused = false
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var skipRequested = false

    var progress: Double { steps.isEmpty ? 0 : Double(stepIndex) / Double(steps.count) }

    init(courses main: CourseRepository) {
        let script = ShowcaseScript.load()
        let featured = script.flatMap { main.course(id: $0.courseId) } ?? main.featuredCourses.first
        let course = featured ?? ShowcaseScript.demoCourse
        self.course = course
        self.script = script
        let schema = Schema([RoundRecord.self, UserCourseRecord.self])
        // In-memory only: the showcase never touches history or the active round.
        let container = (try? ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
            ?? ModelContainer.app()
        self.container = container
        self.courses = CourseRepository(courses: [course])
        self.store = RoundStore(context: container.mainContext, courses: courses)
        self.location = SimulatedLocationProvider(track: [course.holes.first?.effectiveTee ?? course.center], speed: script?.walkSpeed ?? 30)
        self.steps = script?.steps(course: course) ?? []
    }

    var demoWeather: WeatherSnapshot? {
        script.map { WeatherSnapshot(windFromDeg: $0.wind.fromDeg, windSpeed: $0.wind.speed, temperatureC: $0.wind.temperatureC,
                                     fetchedAt: Date(), attributionMarkURL: nil, legalURL: nil) }
    }

    func start() {
        let friends = (script?.friends ?? []).map { Player(name: $0.name, handicap: $0.handicap) }
        store.start(course: course, friends: friends, game: .stroke)
        if let tee = course.hole(script?.holes.first?.number ?? 1)?.effectiveTee { location.teleport(tee) }
        task = Task { [weak self] in await self?.run() }
    }

    func stop() { task?.cancel() }

    func skip() { skipRequested = true }

    private func run() async {
        while stepIndex < steps.count, !Task.isCancelled {
            skipRequested = false
            await perform(steps[stepIndex])
            stepIndex += 1
        }
    }

    private func wait(_ seconds: Double) async {
        var left = seconds
        while left > 0, !Task.isCancelled, !skipRequested {
            try? await Task.sleep(for: .seconds(0.1))
            if !isPaused { left -= 0.1 }
        }
    }

    private func perform(_ step: ShowcaseScript.Step) async {
        switch step {
        case .intro(let n):
            caption = String(localized: "第 \(n) 洞 · 球洞飛越")
            if let tee = course.hole(n)?.effectiveTee { location.teleport(tee) }
            await wait(HoleFlyover.legDurations.reduce(0, +) + 0.6)
        case .walk(let to, let caption):
            self.caption = String(localized: String.LocalizationValue(caption))
            await location.walk([to]) { [weak self] in self?.isPaused ?? false }
            await wait(0.6)
        case .swing(let hole, let at):
            location.teleport(at)
            caption = String(localized: "手錶偵測到揮桿")
            await wait(0.8)
            store.append(.stroke(hole: hole, type: .swing, location: at, swing: nil))
            Haptics.play(.stroke)
            flash(String(localized: "揮桿 +1"))
            await wait(1.4)
        case .putt(let hole, let at):
            location.teleport(at)
            caption = String(localized: "果嶺上，推桿手動 +1")
            await wait(0.6)
            store.append(.stroke(hole: hole, type: .putt, location: at, swing: nil))
            flash(String(localized: "推桿 +1"))
            await wait(1.0)
        case .friendScores(let hole):
            caption = String(localized: "同組朋友的成績一次輸入")
            let friends = store.active?.players.filter { !$0.isOwner } ?? []
            let scores = script?.holes.first { $0.number == hole }?.friendScores ?? []
            store.append(zip(friends, scores).map { .playerScore(playerId: $0.0.id, hole: hole, strokes: $0.1, putts: nil) })
            await wait(1.2)
        case .nextHole(let n):
            store.append(.goToHole(n))
            await wait(0.4)
        case .pause(let s, let caption):
            self.caption = caption
            await wait(s)
        case .finish:
            caption = String(localized: "結算與成績卡")
            finishedRoundId = store.active?.roundId
            store.end()
        }
    }

    private func flash(_ text: String) {
        toast = text
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.3))
            if self?.toast == text { self?.toast = nil }
        }
    }
}

private struct ShowcasePlayer: View {
    @Bindable var session: ShowcaseSession
    let onClose: () -> Void
    let onStartReal: () -> Void
    let onReplay: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if let id = session.finishedRoundId {
                    NavigationStack {
                        RoundSummaryView(roundId: id, onDone: onClose, primaryTitle: "開始我的第一場", onPrimary: onStartReal)
                            .background(PremiumBackground())
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("重播", systemImage: "arrow.counterclockwise", action: onReplay)
                                }
                            }
                    }
                    .tint(Theme.gold)
                } else {
                    RoundView()
                }
            }
            .environment(session.store)
            .environment(session.courses)
            .environment(\.locationOverride, session.location)
            .environment(\.isShowcase, true)
            .environment(\.clubProfileOverride, session.script?.demoProfile)
            .environment(\.weatherOverride, session.demoWeather)

            if session.finishedRoundId == nil { controlBar }
            if let toast = session.toast {
                Text(verbatim: toast)
                    .font(Theme.display(28, weight: .semibold))
                    .foregroundStyle(Theme.onGold)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.goldGradient).shadow(color: Theme.gold.opacity(0.5), radius: 24))
                    .frame(maxHeight: .infinity)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(Motion.hero, value: session.toast)
        .animation(Motion.standard, value: session.finishedRoundId)
        .onAppear { session.start() }
        .onDisappear { session.stop() }
    }

    private var controlBar: some View {
        VStack(spacing: 6) {
            ProgressView(value: session.progress).tint(Theme.gold)
            HStack(spacing: 10) {
                Text(verbatim: session.caption)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ivory)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                    .animation(Motion.fade, value: session.caption)
                Spacer()
                Button { session.isPaused.toggle() } label: {
                    Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                }
                .accessibilityLabel(session.isPaused ? "繼續" : "暫停")
                Button { session.skip() } label: { Image(systemName: "forward.fill") }
                    .accessibilityLabel("跳過")
                Button { onClose() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("離開展示")
            }
            .buttonStyle(CircleIconButtonStyle(size: 34))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 54)
        .environment(\.colorScheme, .dark)
    }

}
