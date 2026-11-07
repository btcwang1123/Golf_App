import GolfKit
import SwiftUI

/// Filters for the course list, applied on top of search.
struct CourseFilter: Equatable {
    enum MapData: String, CaseIterable {
        case any, hasMap, full

        var label: String {
            switch self {
            case .any: String(localized: "全部圖資")
            case .hasMap: String(localized: "有球道圖")
            case .full: String(localized: "完整圖資")
            }
        }
    }

    static let distanceOptionsKm = [10, 30, 50, 100]

    var region: TaiwanRegion?
    var mapData: MapData = .any
    var featuredOnly = false
    var mineOnly = false
    var maxDistanceKm: Int?

    var isActive: Bool { self != CourseFilter() }

    func matches(_ item: CourseListItem) -> Bool {
        if let region, TaiwanRegion.of(item.course.center) != region { return false }
        switch mapData {
        case .any: break
        case .hasMap: if item.quality == .scoreOnly { return false }
        case .full: if item.quality != .full { return false }
        }
        if featuredOnly, !item.isFeatured { return false }
        if mineOnly, item.course.source != .user { return false }
        if let maxDistanceKm, let d = item.distanceMeters, d > Double(maxDistanceKm) * 1000 { return false }
        return true
    }
}

/// Horizontal chip row under the search field.
struct CourseFilterBar: View {
    @Binding var filter: CourseFilter
    let hasLocation: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if filter.isActive {
                    Button {
                        withAnimation(Motion.standard) { filter = CourseFilter() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 32, height: 32)
                            .foregroundStyle(Theme.textSecondary)
                            .background(Circle().fill(Theme.surfaceRaised))
                            .overlay(Circle().strokeBorder(Theme.hairline))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除篩選")
                }
                regionMenu
                mapMenu
                if hasLocation { distanceMenu }
                toggleChip(String(localized: "精選"), icon: "star.fill", isOn: $filter.featuredOnly)
                toggleChip(String(localized: "我的球場"), icon: "person.fill", isOn: $filter.mineOnly)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: filter)
    }

    private var regionMenu: some View {
        Menu {
            Picker("地區", selection: $filter.region) {
                Text("全部地區").tag(TaiwanRegion?.none)
                ForEach(TaiwanRegion.allCases, id: \.self) { r in
                    Text(LocalizedStringKey(r.label)).tag(TaiwanRegion?.some(r))
                }
            }
        } label: {
            chip(filter.region.map { String(localized: String.LocalizationValue($0.label)) } ?? String(localized: "地區"),
                 icon: "map", isOn: filter.region != nil, menu: true)
        }
    }

    private var mapMenu: some View {
        Menu {
            Picker("圖資", selection: $filter.mapData) {
                ForEach(CourseFilter.MapData.allCases, id: \.self) { Text($0.label).tag($0) }
            }
        } label: {
            chip(filter.mapData == .any ? String(localized: "圖資") : filter.mapData.label,
                 icon: "flag", isOn: filter.mapData != .any, menu: true)
        }
    }

    private var distanceMenu: some View {
        Menu {
            Picker("距離", selection: $filter.maxDistanceKm) {
                Text("不限距離").tag(Int?.none)
                ForEach(CourseFilter.distanceOptionsKm, id: \.self) { km in
                    Text("\(km) km 內").tag(Int?.some(km))
                }
            }
        } label: {
            chip(filter.maxDistanceKm.map { String(localized: "\($0) km 內") } ?? String(localized: "距離"),
                 icon: "location", isOn: filter.maxDistanceKm != nil, menu: true)
        }
    }

    private func toggleChip(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(Motion.standard) { isOn.wrappedValue.toggle() }
        } label: {
            chip(title, icon: icon, isOn: isOn.wrappedValue, menu: false)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }

    private func chip(_ title: String, icon: String, isOn: Bool, menu: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(verbatim: title).font(.system(size: 13, weight: .medium)).lineLimit(1)
            if menu {
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).opacity(0.7)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .foregroundStyle(isOn ? Theme.onGold : Theme.ivory)
        .background(Capsule().fill(isOn ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(Theme.surfaceRaised)))
        .overlay(Capsule().strokeBorder(isOn ? Color.clear : Theme.hairline))
        .contentShape(Capsule())
    }
}
