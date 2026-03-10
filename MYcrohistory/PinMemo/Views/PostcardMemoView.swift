import SwiftUI
import SwiftData

// MARK: - Draft Pin (in-memory while editing)
struct DraftPin: Identifiable {
    let id: UUID = UUID()
    var normalizedX: Double
    var normalizedY: Double
    var text: String = ""
}

// MARK: - Callout Tail Shape
private struct CalloutTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - 8, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + 8, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Pin Callout View
struct PinCalloutView: View {
    @Binding var pin: DraftPin
    @State private var isActive: Bool = true
    @State private var speechRecognizer = SpeechRecognizer()

    var body: some View {
        ZStack(alignment: .bottom) {
            if isActive {
                // Expanded callout — auto-sizing
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 8) {
                        TextField("Note...", text: $pin.text, axis: .vertical)
                            .font(.callout)
                            .lineLimit(1...8)

                        Button {
                            if speechRecognizer.isRecording {
                                speechRecognizer.stopRecording()
                            } else {
                                speechRecognizer.startRecording()
                            }
                        } label: {
                            Image(systemName: speechRecognizer.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(speechRecognizer.isRecording ? .red : .accentColor)
                        }
                    }
                    .padding(10)
                    .frame(minWidth: 180, maxWidth: 260)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)

                    CalloutTail()
                        .fill(.ultraThinMaterial)
                        .frame(width: 20, height: 12)
                }
                .onChange(of: speechRecognizer.transcript) { _, newValue in
                    if !newValue.isEmpty { pin.text = newValue }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))

            } else {
                // Collapsed dot
                VStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.85))
                            .shadow(radius: 2)

                        Text(pin.text.isEmpty ? "📌" : pin.text)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                    }
                    .frame(width: 60, height: 28)

                    CalloutTail()
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(width: 14, height: 8)
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .onTapGesture {
            withAnimation(.spring(duration: 0.25)) {
                isActive.toggle()
                if !isActive { speechRecognizer.stopRecording() }
            }
        }
    }
}

// MARK: - Postcard Memo View
struct PostcardMemoView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let selectedImage: UIImage

    @State private var draftPins: [DraftPin] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Full-screen photo background
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .onTapGesture { location in
                        let nx = location.x / geo.size.width
                        let ny = location.y / geo.size.height
                        withAnimation {
                            // Remove any empty pins first
                            draftPins.removeAll { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                            draftPins.append(DraftPin(normalizedX: nx, normalizedY: ny))
                        }
                    }

                // Pins
                ForEach($draftPins) { $pin in
                    PinCalloutView(pin: $pin)
                        .position(
                            x: pin.normalizedX * geo.size.width,
                            y: pin.normalizedY * geo.size.height
                        )
                }

                // Top toolbar overlay
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }

                        Spacer()

                        Button {
                            save(frameSize: geo.size)
                        } label: {
                            Text("Save")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                                .shadow(radius: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 56) // below status bar

                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
    }

    private func save(frameSize: CGSize) {
        let memoID = UUID()
        let filename = MemoStore.saveImage(selectedImage, forMemoID: memoID)

        let memo = Memo(
            id: memoID,
            memoKind: 0,
            title: "",
            imagePath: filename
        )
        context.insert(memo)

        for draft in draftPins {
            let pin = PinAnnotation(
                normalizedX: draft.normalizedX,
                normalizedY: draft.normalizedY,
                text: draft.text
            )
            pin.memo = memo
            memo.pins.append(pin)
            context.insert(pin)
        }

        dismiss()
    }
}
