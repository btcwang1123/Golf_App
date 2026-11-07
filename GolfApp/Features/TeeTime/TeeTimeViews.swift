import GolfKit
import SwiftUI

/// Schedule a tee time with reminders.
struct TeeTimeEditorView: View {
    let course: Course
    var existing: TeeTime?

    @Environment(TeeTimeStore.self) private var store
    @Environment(WeatherService.self) private var weather
    @Environment(\.dismiss) private var dismiss
    @State private var date = Self.defaultDate()
    @State private var reminderMinutes = 90
    @State private var eveningBefore = true
    @State private var saving = false

    static let reminderChoices = [30, 60, 90, 120]

    static func defaultDate() -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("開球時間", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute]).themedRow()
                } header: {
                    Eyebrow(course.name, color: Theme.textSecondary)
                }
                Section {
                    Toggle("前一晚 8 點提醒天氣", isOn: $eveningBefore).tint(Theme.gold).themedRow()
                    Picker("出發提醒", selection: $reminderMinutes) {
                        ForEach(Self.reminderChoices, id: \.self) { Text("提前 \($0) 分鐘").tag($0) }
                    }
                    .themedRow()
                } footer: {
                    Text("10 天內的開球會附上 Apple 天氣預報。提醒只存在這支手機。")
                }
                if existing != nil {
                    Section {
                        Button("刪除這個開球時間", role: .destructive) {
                            if let existing { store.delete(existing) }
                            dismiss()
                        }
                        .themedRow()
                    }
                }
            }
            .premiumBackground()
            .navigationTitle(existing == nil ? "預約開球提醒" : "編輯開球時間")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        saving = true
                        let t = TeeTime(id: existing?.id ?? UUID(), courseId: course.id, courseName: course.name,
                                        center: course.center, date: date, reminderMinutes: reminderMinutes,
                                        eveningBefore: eveningBefore)
                        Task {
                            await store.save(t, weather: weather)
                            dismiss()
                        }
                    }
                    .disabled(saving)
                }
            }
            .onAppear {
                if let existing {
                    date = existing.date
                    reminderMinutes = existing.reminderMinutes
                    eveningBefore = existing.eveningBefore
                }
            }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
    }
}

/// Next tee time on the home screen, with the forecast for that hour.
struct UpcomingTeeTimeCard: View {
    let teeTime: TeeTime
    let onEdit: () -> Void

    @Environment(WeatherService.self) private var weather
    @State private var forecast: ForecastSnapshot?

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(teeTime.date.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.gold)
                    Text(teeTime.date.formatted(.dateTime.day()))
                        .font(Theme.numeral(24, weight: .regular)).foregroundStyle(Theme.ivory)
                }
                .frame(width: 52, height: 56)
                .background(RoundedRectangle(cornerRadius: Theme.cornerSmall).fill(Theme.surfaceRaised))
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow("下次開球", color: Theme.fairway)
                    Text(verbatim: teeTime.courseName).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ivory).lineLimit(1)
                    Text(teeTime.date.formatted(.dateTime.weekday(.wide).hour().minute()))
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if let forecast {
                    VStack(spacing: 2) {
                        Image(systemName: forecast.symbolName).symbolRenderingMode(.multicolor).font(.title3)
                        Text(verbatim: "\(Int(forecast.temperatureC.rounded()))°").font(.caption.weight(.semibold)).foregroundStyle(Theme.ivory)
                        Text(verbatim: "☂︎ \(Int((forecast.precipitationChance * 100).rounded()))%").font(.caption2).foregroundStyle(Theme.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(forecast.summary)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
        .task(id: teeTime.id) {
            if let c = teeTime.center { forecast = await weather.forecast(at: c, date: teeTime.date) }
        }
    }
}
