import Foundation
import GolfKit
import Observation
import OSLog
import SwiftData
import UIKit

/// Hole plans / notes per course and photos per round.
@MainActor @Observable
final class HolePlanStore {
    /// Bumped on every change so views re-read.
    private(set) var revision = 0
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let log = Logger(subsystem: "GolfApp", category: "HolePlanStore")

    /// Longest edge of stored photos.
    static let photoMaxPixels: CGFloat = 1600

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Plans

    func plan(courseId: String, hole: Int) -> HolePlan? {
        _ = revision
        let key = HolePlan.key(courseId: courseId, hole: hole)
        let d = FetchDescriptor<HolePlanRecord>(predicate: #Predicate { $0.key == key })
        return (try? context.fetch(d))?.first?.plan
    }

    func plans(courseId: String) -> [Int: HolePlan] {
        _ = revision
        let d = FetchDescriptor<HolePlanRecord>(predicate: #Predicate { $0.courseId == courseId })
        let records = (try? context.fetch(d)) ?? []
        return Dictionary(records.map { ($0.hole, $0.plan) }, uniquingKeysWith: { a, _ in a })
    }

    func save(_ plan: HolePlan) {
        let key = plan.id
        let d = FetchDescriptor<HolePlanRecord>(predicate: #Predicate { $0.key == key })
        let existing = (try? context.fetch(d))?.first
        if plan.isEmpty {
            if let existing { context.delete(existing) }
        } else if let existing {
            var p = plan
            p.updatedAt = Date()
            existing.plan = p
        } else {
            context.insert(HolePlanRecord(plan: plan))
        }
        commit()
    }

    // MARK: Photos

    func photos(roundId: UUID) -> [RoundPhotoRecord] {
        _ = revision
        let d = FetchDescriptor<RoundPhotoRecord>(
            predicate: #Predicate { $0.roundId == roundId }, sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(d)) ?? []
    }

    func addPhoto(_ image: UIImage, roundId: UUID, hole: Int) {
        guard let data = Self.downscaled(image).jpegData(compressionQuality: 0.8) else { return }
        context.insert(RoundPhotoRecord(roundId: roundId, hole: hole, imageData: data))
        commit()
    }

    func delete(_ photo: RoundPhotoRecord) {
        context.delete(photo)
        commit()
    }

    static func downscaled(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > photoMaxPixels else { return image }
        let scale = photoMaxPixels / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    private func commit() {
        do { try context.save() } catch { log.error("save failed: \(error.localizedDescription)") }
        revision += 1
    }
}
