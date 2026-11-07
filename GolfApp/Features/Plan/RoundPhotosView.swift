import GolfKit
import SwiftUI

/// Horizontal strip of a round's photos, grouped by hole.
struct RoundPhotoStrip: View {
    let roundId: UUID
    @Environment(HolePlanStore.self) private var store
    @State private var viewing: RoundPhotoRecord?

    var body: some View {
        let photos = store.photos(roundId: roundId)
        if !photos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "照片", trailing: "\(photos.count)")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { p in
                            if let img = UIImage(data: p.imageData) {
                                Button { viewing = p } label: {
                                    Image(uiImage: img).resizable().scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall, style: .continuous))
                                        .overlay(alignment: .bottomLeading) {
                                            Tag(text: String(localized: "第 \(p.hole) 洞"), color: Theme.ivory).padding(6)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("第 \(p.hole) 洞照片")
                            }
                        }
                    }
                }
            }
            .sheet(item: $viewing) { p in
                PhotoViewer(photo: p) { store.delete(p); viewing = nil }
            }
        }
    }
}

private struct PhotoViewer: View {
    let photo: RoundPhotoRecord
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let img = UIImage(data: photo.imageData) {
                    let image = Image(uiImage: img)
                    image.resizable().scaledToFit()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                ShareLink(item: image, preview: SharePreview(Text("第 \(photo.hole) 洞"), image: image))
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationTitle("第 \(photo.hole) 洞")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .bottomBar) {
                    Button("刪除照片", systemImage: "trash", role: .destructive, action: onDelete)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Quick note + photo for the hole being played.
struct HoleNoteSheet: View {
    let course: Course
    let hole: Int
    let roundId: UUID

    @Environment(HolePlanStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("下次打這洞要記得…", text: $note, axis: .vertical).lineLimit(3...6).themedRow()
                } header: {
                    Eyebrow("第 \(hole) 洞筆記", color: Theme.textSecondary)
                } footer: {
                    Text("筆記存在這座球場，下次打到這洞會自動跳出。")
                }
                Section {
                    Button { showCamera = true } label: { Label("拍一張這洞的照片", systemImage: "camera") }.themedRow()
                }
                if let h = course.hole(hole) {
                    Section {
                        NavigationLink { HolePlanEditorView(course: course, hole: h, plan: store.plan(courseId: course.id, hole: hole)) } label: {
                            Label("編輯攻略目標點", systemImage: "scope")
                        }
                        .themedRow()
                    }
                }
            }
            .premiumBackground()
            .navigationTitle("筆記與照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        var p = store.plan(courseId: course.id, hole: hole) ?? HolePlan(courseId: course.id, hole: hole)
                        p.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.save(p)
                        dismiss()
                    }
                }
            }
            .onAppear { note = store.plan(courseId: course.id, hole: hole)?.note ?? "" }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { store.addPhoto($0, roundId: roundId, hole: hole) }.ignoresSafeArea()
            }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

/// Note reminder shown at the top of the round screen.
struct HoleNoteBanner: View {
    let plan: HolePlan
    var body: some View {
        if !plan.note.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "note.text").foregroundStyle(Theme.gold)
                Text(verbatim: plan.note).font(.footnote).foregroundStyle(Theme.ivory).lineLimit(2)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.surface.opacity(0.92)))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerSmall).strokeBorder(Theme.gold.opacity(0.3)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("本洞筆記：\(plan.note)")
        }
    }
}
