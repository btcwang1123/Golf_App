import GolfKit
import PhotosUI
import SwiftUI
import Vision

/// On-device text recognition for paper scorecards.
enum ScorecardOCR {
    static func tokens(in image: UIImage) async throws -> [OCRToken] {
        guard let cg = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, error in
                if let error { cont.resume(throwing: error); return }
                let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
                let tokens = obs.compactMap { o -> OCRToken? in
                    guard let text = o.topCandidates(1).first?.string else { return nil }
                    let b = o.boundingBox
                    return OCRToken(text: text, minX: b.minX, maxX: b.maxX, midY: 1 - b.midY, height: b.height)
                }
                cont.resume(returning: tokens)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hant", "en-US"]
            request.usesLanguageCorrection = false
            DispatchQueue.global(qos: .userInitiated).async {
                do { try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([request]) } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Photograph a paper scorecard, pick your row, and prefill the manual entry.
struct ScorecardScanView: View {
    /// Picked row's scores and the card's pars, by hole.
    let onPick: (_ scores: [Int: Int], _ pars: [Int: Int]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?
    @State private var showCamera = false
    @State private var image: UIImage?
    @State private var card: ParsedScorecard?
    @State private var working = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
                    } else {
                        Text("拍下紙本記分卡（整張平放、光線充足），App 會在手機上辨識每洞桿數，不會上傳。")
                            .font(.footnote).foregroundStyle(Theme.textSecondary).card()
                    }
                    HStack(spacing: 12) {
                        Button { showCamera = true } label: { Label("拍照", systemImage: "camera") }
                            .buttonStyle(GoldButtonStyle(compact: true))
                        PhotosPicker(selection: $item, matching: .images) { Label("從相簿", systemImage: "photo") }
                            .buttonStyle(GhostButtonStyle(compact: true))
                    }
                    if working { ProgressView("辨識中…").tint(Theme.gold).frame(maxWidth: .infinity) }
                    if failed {
                        Text("找不到記分表格，請重拍：讓「洞號」那一列清楚入鏡。")
                            .font(.footnote).foregroundStyle(Theme.warning)
                    }
                    if let card { rows(card) }
                }
                .padding(Theme.gutter)
            }
            .background(PremiumBackground())
            .navigationTitle("掃描記分卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .onChange(of: item) { _, new in
                guard let new else { return }
                Task {
                    if let data = try? await new.loadTransferable(type: Data.self), let img = UIImage(data: data) { await scan(img) }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { img in Task { await scan(img) } }.ignoresSafeArea()
            }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
    }

    private func rows(_ card: ParsedScorecard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "選擇你的那一列", trailing: card.pars.isEmpty ? nil : "已讀到標準桿")
            if card.rows.isEmpty {
                Text("讀到洞號但沒有成績列，請重拍。").font(.footnote).foregroundStyle(Theme.warning)
            }
            ForEach(card.rows) { row in
                Button {
                    onPick(row.scores, card.pars)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(verbatim: row.label ?? String(localized: "第 \(row.id + 1) 列")).font(.headline).foregroundStyle(Theme.ivory)
                            Spacer()
                            Text("總 \(row.total) · \(row.scores.count) 洞").font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        Text(verbatim: card.holes.map { h in row.scores[h].map(String.init) ?? "·" }.joined(separator: " "))
                            .font(.caption.monospacedDigit()).foregroundStyle(Theme.gold).lineLimit(2)
                    }
                    .card()
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func scan(_ img: UIImage) async {
        image = img
        working = true
        failed = false
        card = nil
        let tokens = (try? await ScorecardOCR.tokens(in: img)) ?? []
        card = ScorecardParser.parse(tokens)
        failed = card == nil
        working = false
    }
}
