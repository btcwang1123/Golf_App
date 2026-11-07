import CoreTransferable
import GolfKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let golfCourse = UTType(exportedAs: "com.bobby.golfapp.course")
    static let golfRound = UTType(exportedAs: "com.bobby.golfapp.round")
}

/// `.golfcourse` file built on demand for the share sheet.
struct CourseFile: Transferable {
    let course: Course

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .golfCourse) { file in
            let url = URL.temporaryDirectory.appending(path: CoursePackage.fileName(for: file.course))
            try CoursePackage(course: file.course).encode().write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// "分享球場資料" — exports the course as `<名稱>.golfcourse`.
struct CourseExportButton: View {
    let course: Course

    var body: some View {
        ShareLink(item: CourseFile(course: course),
                  preview: SharePreview(Text(verbatim: course.name), image: Image(systemName: "flag.fill"))) {
            Label("分享球場資料", systemImage: "square.and.arrow.up")
        }
    }
}
