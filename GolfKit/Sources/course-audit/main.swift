import Foundation
import GolfKit

// Usage: course-audit <courses.json> [--featured <dir>] [--only-mapped]
//        course-audit <courses.json> --promote <osm-id> --out <featured/x.json> [--id <featured-id>]
// Prints courses sorted by completeness, then a summary line.

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data((msg + "\n").utf8))
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
guard let listPath = args.first, !listPath.hasPrefix("--") else {
    fail("usage: course-audit <courses.json> [--featured <dir>] [--only-mapped]")
}
args.removeFirst()
var featuredDir: String?
var onlyMapped = false
var promoteId: String?
var outPath: String?
var newId: String?
while let a = args.first {
    args.removeFirst()
    switch a {
    case "--featured":
        guard let d = args.first else { fail("--featured needs a directory") }
        featuredDir = d
        args.removeFirst()
    case "--only-mapped": onlyMapped = true
    case "--promote", "--out", "--id":
        guard let v = args.first else { fail("\(a) needs a value") }
        args.removeFirst()
        if a == "--promote" { promoteId = v } else if a == "--out" { outPath = v } else { newId = v }
    default: fail("unknown option \(a)")
    }
}

guard let data = FileManager.default.contents(atPath: listPath),
      var courses = try? Course.decodeList(from: data) else { fail("cannot read \(listPath)") }

if let promoteId {
    // Copy an OSM course into a featured file (provenance .osm, replaces the OSM id).
    guard let outPath else { fail("--promote needs --out") }
    guard var c = courses.first(where: { $0.id == promoteId }) else { fail("no course \(promoteId)") }
    c.replaces = c.id
    c.id = newId ?? "featured-\(c.id)"
    c.source = .featured
    c.provenance = .osm
    let q = c.quality
    let enc = JSONEncoder()
    enc.outputFormatting = [.sortedKeys, .prettyPrinted]
    guard let out = try? enc.encode(c) else { fail("encode failed") }
    FileManager.default.createFile(atPath: outPath, contents: out)
    print("wrote \(outPath): \(c.name) · \(c.holes.count) holes · \(q.level.rawValue) (\(String(format: "%.2f", q.score)))")
    exit(0)
}

if let featuredDir {
    let urls = (try? FileManager.default.contentsOfDirectory(atPath: featuredDir)) ?? []
    var featured: [Course] = []
    for name in urls.sorted() where name.hasSuffix(".json") {
        let path = (featuredDir as NSString).appendingPathComponent(name)
        guard let d = FileManager.default.contents(atPath: path),
              var c = try? JSONDecoder().decode(Course.self, from: d) else {
            print("! cannot decode \(name)")
            continue
        }
        c.source = .featured
        featured.append(c)
    }
    let replaced = Set(featured.compactMap(\.replaces) + featured.map(\.id))
    courses = courses.filter { !replaced.contains($0.id) } + featured
}

struct Row { var course: Course; var q: CourseQuality }
var rows = courses.map { Row(course: $0, q: $0.quality) }
if onlyMapped { rows = rows.filter { !$0.course.holes.isEmpty } }
rows.sort { a, b in
    if a.q.level != b.q.level { return a.q.level < b.q.level }
    if a.q.score != b.q.score { return a.q.score > b.q.score }
    return a.course.name < b.course.name
}

func pad(_ s: String, _ w: Int) -> String {
    // East Asian characters take two columns.
    let width = s.unicodeScalars.reduce(0) { $0 + ($1.value > 0x2E80 ? 2 : 1) }
    return s + String(repeating: " ", count: max(0, w - width))
}

print(pad("名稱", 40) + pad("洞數", 6) + pad("level", 11) + pad("score", 7) + pad("缺必要", 8) + "缺漏")
print(String(repeating: "-", count: 82))
for r in rows {
    let flag = r.course.source == .featured ? "★ " : ""
    print(pad(flag + r.course.name, 40) + pad("\(r.course.holes.count)", 6) + pad(r.q.level.rawValue, 11)
          + pad(String(format: "%.2f", r.q.score), 7) + pad("\(r.q.missingRequiredCount)", 8) + "\(r.q.missingCount)")
}
let byLevel = Dictionary(grouping: rows, by: \.q.level).mapValues(\.count)
print("共 \(rows.count) 座 · full \(byLevel[.full] ?? 0) · partial \(byLevel[.partial] ?? 0) · scoreOnly \(byLevel[.scoreOnly] ?? 0)")
