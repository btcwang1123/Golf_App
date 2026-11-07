import SwiftUI

/// Explains why a permission is needed right before the system prompt.
struct PermissionPrimerView: View {
    enum Kind { case location, motion }

    let kind: Kind
    @Environment(LocationService.self) private var location
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: kind == .location ? "location.circle.fill" : "applewatch.radiowaves.left.and.right")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.gold)
                .padding(.top, 30)
            Text(kind == .location ? "顯示附近球場與距離" : "讓手錶自動記桿")
                .font(Theme.display(26, weight: .medium))
                .foregroundStyle(Theme.ivory)
            Text(kind == .location
                 ? "定位只用在本機：找出附近球場、計算到果嶺的距離、記錄每一桿的位置。不會上傳。"
                 : "回合開始時，Apple Watch 會請求「動作與健身」及「健康」權限，以體能訓練模式持續偵測揮桿。拒絕也能手動記桿。")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            Button(kind == .location ? "允許定位" : "了解") {
                if kind == .location { location.requestPermission() }
                dismiss()
            }
            .buttonStyle(GoldButtonStyle())
            .padding(.horizontal, Theme.gutter)
            Button("稍後再說") { dismiss() }
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(PremiumBackground())
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}
