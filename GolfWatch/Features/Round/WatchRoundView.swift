import SwiftUI

/// Round pages in a vertical TabView: main / hazards / mini map / scorecard.
struct WatchRoundView: View {
    @Environment(WatchRoundStore.self) private var store
    @Environment(WatchLocationService.self) private var location
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var crownValue = 0.0
    @State private var showMenu = false
    @State private var page = 0

    private let config = WatchRoundConfig.default

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                main.tag(0)
                WatchHazardPageView().tag(1)
                WatchHoleMapView().tag(2)
                WatchScorecardPageView().tag(3)
            }
            .tabViewStyle(.verticalPage)
            .navigationTitle(store.activeCourse?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showMenu = true } label: { Image(systemName: "ellipsis") }
                        .accessibilityLabel("選單")
                }
            }
            .sheet(isPresented: $showMenu) { WatchRoundMenuView() }
        }
        .onChange(of: isLuminanceReduced, initial: true) { _, reduced in location.setLowPower(reduced) }
    }

    private var main: some View {
        WatchHoleView()
            .focusable(page == 0)
            .digitalCrownRotation(
                $crownValue, from: 0, through: config.crownMax, by: 1,
                sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: crownValue) { _, new in applyCrown(new) }
            .onChange(of: store.currentHoleState.strokes) { _, new in crownValue = Double(new) }
            .onChange(of: store.currentHoleNumber) { _, _ in crownValue = Double(store.currentHoleState.strokes) }
            .onAppear { crownValue = Double(store.currentHoleState.strokes) }
            .overlay(alignment: .bottom) { overlays }
            .animation(.easeInOut(duration: 0.2), value: store.toast)
            .animation(.easeInOut(duration: 0.2), value: store.advanceBanner)
    }

    @ViewBuilder
    private var overlays: some View {
        if let toast = store.toast {
            SwingToastView(toast: toast, onUndo: store.undoToast, onPenalty: store.penaltyToast)
        } else if let banner = store.advanceBanner {
            AdvanceBannerView(banner: banner, onUndo: store.undoAdvance)
        }
    }

    /// Crown up = manual stroke, crown down = void the last stroke of this hole.
    private func applyCrown(_ value: Double) {
        let target = Int(value.rounded())
        let current = store.currentHoleState.strokes
        if target > current {
            store.addStroke(.manual)
        } else if target < current {
            store.removeLastStroke()
        }
    }
}
