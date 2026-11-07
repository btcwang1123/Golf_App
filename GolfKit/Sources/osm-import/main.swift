import Foundation
import GolfKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

var outPath: String?
var inputPath: String?
var args = CommandLine.arguments.dropFirst().makeIterator()
while let arg = args.next() {
    switch arg {
    case "--out": outPath = args.next()
    case "--input": inputPath = args.next()
    default: fail("Unknown argument: \(arg)\nUsage: osm-import --out <path> [--input <cached.json>]")
    }
}
guard let outPath else { fail("Usage: osm-import --out <path> [--input <cached.json>]") }

do {
    let raw: Data
    if let inputPath {
        raw = try Data(contentsOf: URL(fileURLWithPath: inputPath))
    } else {
        guard let url = URL(string: "https://overpass-api.de/api/interpreter") else { fail("Bad URL") }
        var request = URLRequest(url: url, timeoutInterval: 240)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=;")
        let encoded = OSMCourseBuilder.overpassQuery.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        request.httpBody = Data("data=\(encoded)".utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            fail("Overpass returned HTTP \(http.statusCode)")
        }
        raw = data
        try raw.write(to: URL(fileURLWithPath: outPath + ".overpass-cache.json"))
    }
    let courses = OSMCourseBuilder.build(from: try OverpassResponse.decode(from: raw))
    try Course.encodeList(courses).write(to: URL(fileURLWithPath: outPath))
    let withHoles = courses.filter { !$0.holes.isEmpty }.count
    let totalHoles = courses.reduce(0) { $0 + $1.holes.count }
    print("Courses: \(courses.count)")
    print("Courses with hole data: \(withHoles)")
    print("Total holes: \(totalHoles)")
    print("Wrote \(outPath)")
} catch {
    fail("Error: \(error)")
}
