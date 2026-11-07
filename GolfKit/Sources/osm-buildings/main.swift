import Foundation
import GolfKit

// Builds `buildings_tw.json` (course id → building footprints) from OpenStreetMap for courses with hole data.
// Usage: osm-buildings --courses <courses_tw.json> [--featured <dir>] --out <buildings_tw.json> [--input <cache.json>]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let usage = "Usage: osm-buildings --courses <courses_tw.json> [--featured <dir>] --out <path> [--input <cache.json>]"
var coursesPath: String?
var featuredDir: String?
var outPath: String?
var inputPath: String?
var args = CommandLine.arguments.dropFirst().makeIterator()
while let arg = args.next() {
    switch arg {
    case "--courses": coursesPath = args.next()
    case "--featured": featuredDir = args.next()
    case "--out": outPath = args.next()
    case "--input": inputPath = args.next()
    default: fail("Unknown argument: \(arg)\n\(usage)")
    }
}
guard let coursesPath, let outPath else { fail(usage) }

do {
    var courses = try Course.decodeList(from: Data(contentsOf: URL(fileURLWithPath: coursesPath)))
    if let featuredDir {
        let dir = URL(fileURLWithPath: featuredDir)
        for file in try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        where file.pathExtension == "json" {
            courses.append(try JSONDecoder().decode(Course.self, from: Data(contentsOf: file)))
        }
    }
    let boxes = courses.compactMap { c in OSMBuildingBuilder.box(for: c).map { (c.id, $0) } }
    print("Courses with hole data: \(boxes.count)")

    let raw: Data
    if let inputPath {
        raw = try Data(contentsOf: URL(fileURLWithPath: inputPath))
    } else {
        guard let url = URL(string: "https://overpass-api.de/api/interpreter") else { fail("Bad URL") }
        var request = URLRequest(url: url, timeoutInterval: 300)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("GolfApp-osm-buildings/1.0", forHTTPHeaderField: "User-Agent")
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=;")
        let query = OSMBuildingBuilder.overpassQuery(boxes: boxes.map(\.1))
        request.httpBody = Data("data=\(query.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")".utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            fail("Overpass returned HTTP \(http.statusCode)")
        }
        raw = data
        try raw.write(to: URL(fileURLWithPath: outPath + ".overpass-cache.json"))
    }

    let all = OSMBuildingBuilder.buildings(from: try OverpassResponse.decode(from: raw))
    var index = [String: [Building]]()
    for (id, box) in boxes {
        let list = OSMBuildingBuilder.assign(all, to: box)
        if !list.isEmpty { index[id] = list }
        print("  \(id): \(list.count)")
    }
    try BuildingIndex.encode(index).write(to: URL(fileURLWithPath: outPath))
    print("Buildings: \(all.count), courses with buildings: \(index.count)")
    print("Wrote \(outPath)")
} catch {
    fail("Error: \(error)")
}
