import SwiftUI

struct WatchRootView: View {
    @Environment(WatchRoundStore.self) private var store
    @Environment(WatchPracticeStore.self) private var practice

    var body: some View {
        if practice.isActive {
            NavigationStack { WatchPracticeView() }
        } else if store.active != nil {
            WatchRoundView()
        } else {
            NavigationStack {
                List {
                    Section {
                        Text("等待 iPhone 開始回合")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if !store.recentCourses.isEmpty {
                        Section("最近球場") {
                            ForEach(store.recentCourses) { course in
                                Button {
                                    store.start(courseId: course.id)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(verbatim: course.name)
                                        if let county = course.county {
                                            Text(verbatim: county).font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    NavigationLink { WatchPracticeView() } label: {
                        Label("練習場模式", systemImage: "figure.golf")
                    }
                    NavigationLink("設定") { WatchSettingsView() }
                }
                .navigationTitle("高爾夫")
                .task { store.refreshRecentCourses() }
            }
        }
    }
}
