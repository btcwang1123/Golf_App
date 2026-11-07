import CoreTransferable
import GolfKit
import SwiftUI

struct RoundFile: Transferable {
    let export: RoundExport

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .golfRound) { file in
            let name = "\(CoursePackage.sanitize(file.export.courseName))-\(file.export.roundId.uuidString.prefix(6)).\(RoundExport.fileExtension)"
            let url = URL.temporaryDirectory.appending(path: name)
            try file.export.encode().write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// Shares the round as `.golfround` so friends can save it in their own history.
struct RoundExportButton: View {
    let events: [RoundEvent]
    let course: Course?
    let courseId: String
    let courseName: String

    var body: some View {
        let export = RoundExport.make(events: events, course: course, courseId: courseId, courseName: courseName)
        ShareLink(item: RoundFile(export: export),
                  message: Text("用 \(AppBrand.displayName) 打開這個檔案，就能把這場存進你的紀錄。"),
                  preview: SharePreview(Text(verbatim: courseName), image: Image(systemName: "flag.fill"))) {
            Label("傳回合檔給同組", systemImage: "person.2.fill")
        }
    }
}
