import SwiftUI

struct CalibrationView: View {
    @Environment(MotionRecorder.self) private var recorder

    var body: some View {
        @Bindable var recorder = recorder
        ScrollView {
            VStack(spacing: 8) {
                if recorder.swingDetected {
                    Label("偵測到揮桿", systemImage: "figure.golf")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else {
                    Text(recorder.isRecording ? "錄製中…" : "尚未錄製")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Text(verbatim: "樣本 \(recorder.sampleCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(MotionRecorder.Label.allCases, id: \.self) { item in
                    Button {
                        recorder.label = item
                    } label: {
                        HStack {
                            Text(Self.title(item))
                            Spacer()
                            if recorder.label == item { Image(systemName: "checkmark") }
                        }
                    }
                    .tint(recorder.label == item ? .green : .gray)
                }

                Button(role: recorder.isRecording ? .destructive : nil) {
                    if recorder.isRecording { recorder.stop() } else { recorder.start() }
                } label: {
                    Text(recorder.isRecording ? "停止並傳送" : "開始錄製")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(recorder.isRecording ? .red : .blue)

                if let message = recorder.errorMessage {
                    Text(message).font(.caption2).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("校正錄製")
    }

    private static func title(_ label: MotionRecorder.Label) -> LocalizedStringKey {
        switch label {
        case .real: "真揮桿"
        case .practice: "練習揮桿"
        case .walk: "走路"
        }
    }
}
