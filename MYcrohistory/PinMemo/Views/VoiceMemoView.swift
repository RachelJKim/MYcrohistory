import SwiftUI
import SwiftData

struct VoiceMemoView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var speechRecognizer = SpeechRecognizer()
    @State private var editableText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ZStack(alignment: .topLeading) {
                    if editableText.isEmpty {
                        Text(speechRecognizer.isModelLoading
                             ? "Loading Whisper model (first run only)..."
                             : "Tap the mic to start recording...")
                            .foregroundStyle(.secondary)
                            .padding(12)
                    }
                    TextEditor(text: $editableText)
                        .opacity(editableText.isEmpty ? 0.01 : 1)
                }
                .frame(maxHeight: .infinity)
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                if let error = speechRecognizer.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                Button {
                    if speechRecognizer.isRecording {
                        speechRecognizer.stopRecording()
                    } else {
                        speechRecognizer.startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(speechRecognizer.isRecording ? Color.red : Color.accentColor)
                            .frame(width: 72, height: 72)
                        Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(speechRecognizer.isModelLoading)
                .padding(.bottom, 32)
            }
            .padding(.top)
            .navigationTitle("Voice Memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        speechRecognizer.stopRecording()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(editableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: speechRecognizer.transcript) { _, newValue in
                if speechRecognizer.isRecording { editableText = newValue }
            }
            .onChange(of: speechRecognizer.finalTranscript) { _, newValue in
                if let final = newValue, !final.isEmpty { editableText = final }
            }
        }
    }

    private func save() {
        speechRecognizer.stopRecording()
        let memo = Memo(memoKind: 1, textContent: editableText)
        context.insert(memo)
        dismiss()
    }
}
