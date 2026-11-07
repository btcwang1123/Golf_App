import SwiftUI

/// Shown after auto-advancing to the next hole, with a one-tap undo.
struct AdvanceBannerView: View {
    let banner: WatchRoundStore.AdvanceBanner
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: "已前往第 \(banner.to) 洞")
                .font(.footnote.weight(.semibold))
            Button("退回", action: onUndo)
                .font(.footnote)
                .buttonStyle(.bordered)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
