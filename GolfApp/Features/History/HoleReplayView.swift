import SwiftUI
import GolfKit

struct HoleReplayView: View {
    let course: Course
    let holeNumber: Int
    let shots: [ShotInfo]

    @Environment(SettingsService.self) private var settings

    var body: some View {
        VStack(spacing: 0) {
            HoleMapView(course: course, hole: course.hole(holeNumber), shots: shots, player: nil)
                .frame(maxHeight: .infinity)
            List(Array(shots.enumerated()), id: \.element.id) { index, shot in
                HStack {
                    Text("\(index + 1)").font(.headline.monospacedDigit()).frame(width: 24)
                    Text(shot.type == .putt ? "推桿" : (shot.club?.displayName ?? "—"))
                    Spacer()
                    Text(settings.settings.format(meters: shot.distanceToNext))
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: .infinity)
        }
        .navigationTitle("第\(holeNumber)洞")
        .navigationBarTitleDisplayMode(.inline)
    }
}
