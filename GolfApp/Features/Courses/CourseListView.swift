import GolfKit
import SwiftUI

/// Courses tab: searchable, filterable list, nearest first, featured courses first within the same distance.
struct CourseListView: View {
    @Environment(CourseRepository.self) private var courses
    @Environment(LocationService.self) private var location

    @State private var query = ""
    @State private var showNewCourse = false
    @State private var showPrimer = false
    @State private var filter = CourseFilter()

    private static let listLimit = 60

    private var items: [CourseListItem] {
        let all = courses.list(query: query, near: location.current)
        return filter.isActive ? all.filter(filter.matches) : all
    }

    /// Show everything when the user has narrowed the list (search or filters).
    private var isNarrowed: Bool { !query.isEmpty || filter.isActive }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    CourseFilterBar(filter: $filter, hasLocation: location.current != nil)
                        .padding(.horizontal, -Theme.gutter)
                    if location.isDenied && !isNarrowed { locationHint }
                    courseSection
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background(PremiumBackground())
            .navigationTitle("球場")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜尋球場或縣市")
            .navigationDestination(for: Course.self) { CourseDetailView(course: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新增球場", systemImage: "plus") { showNewCourse = true }
                }
            }
            .task {
                if location.isUndetermined { showPrimer = true } else { location.start() }
            }
            .sheet(isPresented: $showPrimer, onDismiss: { location.start() }) {
                PermissionPrimerView(kind: .location)
            }
            .sheet(isPresented: $showNewCourse) { CourseEditorView(course: nil) }
        }
    }

    private var sectionTitle: String {
        if !query.isEmpty { return String(localized: "搜尋結果") }
        if filter.isActive { return String(localized: "篩選結果") }
        return location.current == nil ? String(localized: "全部球場") : String(localized: "附近球場")
    }

    private var locationHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash").foregroundStyle(Theme.gold)
            Text("未開啟定位，依名稱排序。可在設定中開啟以顯示附近球場。")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .card(padding: 14)
    }

    @ViewBuilder private var courseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: sectionTitle,
                trailing: courses.isLoaded ? String(localized: "\(items.count) 座") : nil)
            if !courses.isLoaded {
                SkeletonRows()
                    .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.surface))
            } else if items.isEmpty {
                if filter.isActive {
                    EmptyStateView(icon: "line.3.horizontal.decrease.circle", title: "沒有符合條件的球場",
                                   message: "放寬篩選條件，或清除篩選看全部球場。",
                                   actionTitle: "清除篩選", action: { withAnimation(Motion.standard) { filter = CourseFilter() } })
                        .frame(minHeight: 320)
                } else {
                    EmptyStateView(icon: "magnifyingglass", title: "找不到球場",
                                   message: "試試其他關鍵字，或自己新增一座球場。",
                                   actionTitle: "新增球場", action: { showNewCourse = true })
                        .frame(minHeight: 320)
                }
            } else {
                list
            }
            if !isNarrowed, items.count > Self.listLimit {
                Text("搜尋或篩選以查看全部 \(items.count) 座球場")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
            Text(GolfKit.mapAttribution)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            let shown = Array(items.prefix(isNarrowed ? items.count : Self.listLimit))
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                NavigationLink(value: item.course) {
                    CourseRowView(item: item)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                if index < shown.count - 1 {
                    Divider().overlay(Theme.hairline).padding(.leading, 70)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).strokeBorder(Theme.hairline))
        .transition(.opacity)
        .animation(Motion.standard, value: items.count)
    }
}
