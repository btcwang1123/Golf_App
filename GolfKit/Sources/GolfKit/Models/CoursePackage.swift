import Foundation

/// `.golfcourse` file: one course for sharing via AirDrop / LINE / Files.
public struct CoursePackage: Sendable, Codable, Equatable {
    public static let currentVersion = 1
    public static let fileExtension = "golfcourse"

    public enum PackageError: Error, Equatable, LocalizedError {
        case corrupted
        case unsupportedVersion(Int)

        public var errorDescription: String? {
            switch self {
            case .corrupted: "檔案已損毀或不是球場資料。"
            case .unsupportedVersion(let v): "此檔案版本（v\(v)）需要較新的 App。"
            }
        }
    }

    public var version: Int
    public var course: Course
    public var exportedAt: Date

    public init(course: Course, exportedAt: Date = Date(), version: Int = CoursePackage.currentVersion) {
        self.version = version
        self.course = course
        self.exportedAt = exportedAt
    }

    public func encode() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return try e.encode(self)
    }

    public static func decode(_ data: Data) throws -> CoursePackage {
        struct Header: Decodable { var version: Int }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        guard let header = try? d.decode(Header.self, from: data) else { throw PackageError.corrupted }
        guard header.version <= currentVersion, header.version >= 1 else {
            throw PackageError.unsupportedVersion(header.version)
        }
        do {
            return try d.decode(CoursePackage.self, from: data)
        } catch {
            throw PackageError.corrupted
        }
    }

    /// File name safe for sharing: "<名稱>.golfcourse".
    public static func fileName(for course: Course) -> String {
        "\(sanitize(course.name)).\(fileExtension)"
    }

    public static func sanitize(_ name: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = name.components(separatedBy: bad).joined(separator: "_").trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "course" : cleaned
    }
}
