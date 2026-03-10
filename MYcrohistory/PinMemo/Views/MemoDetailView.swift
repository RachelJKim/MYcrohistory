import SwiftUI
import SwiftData
import UIKit

struct MemoDetailView: View {
    let memo: Memo
    @Environment(\.dismiss) private var dismiss
    @State private var categoryText: String = ""
    @State private var isEditingCategory = false

    var body: some View {
        switch memo.memoKind {
        case 0:
            postcardDetail
        case 1:
            voiceDetail
        default:
            textDetail
        }
    }

    // MARK: - Postcard Detail (full screen with pins)
    private var postcardDetail: some View {
        GeometryReader { geo in
            ZStack {
                if let url = memo.resolvedImageURL,
                   let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Color.black
                }

                // Saved pins (read-only)
                ForEach(memo.pins) { pin in
                    SavedPinView(pin: pin)
                        .position(
                            x: pin.normalizedX * geo.size.width,
                            y: pin.normalizedY * geo.size.height
                        )
                }

                // Close button
                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        Spacer()

                        Text(memo.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.4), in: Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 56)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Category Tag

    private var categoryTag: some View {
        HStack(spacing: 6) {
            if isEditingCategory {
                TextField("Category", text: $categoryText)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
                    .frame(maxWidth: 200)
                    .onSubmit { saveCategory() }
                Button("Done") { saveCategory() }
                    .font(.subheadline.weight(.medium))
            } else if let cat = memo.category, !cat.isEmpty {
                Label(cat, systemImage: "tag.fill")
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                    .onTapGesture {
                        categoryText = cat
                        isEditingCategory = true
                    }
            } else {
                Button {
                    categoryText = ""
                    isEditingCategory = true
                } label: {
                    Label("Add Category", systemImage: "tag")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func saveCategory() {
        let trimmed = categoryText.trimmingCharacters(in: .whitespacesAndNewlines)
        memo.category = trimmed.isEmpty ? nil : trimmed
        isEditingCategory = false
    }

    // MARK: - Voice Detail
    private var voiceDetail: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(memo.createdAt.formatted(date: .long, time: .shortened), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    categoryTag

                    Text(memo.textContent ?? "")
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Voice Memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Text Detail
    private var textDetail: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(memo.createdAt.formatted(date: .long, time: .shortened), systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    categoryTag

                    Text(memo.textContent ?? "")
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Text Memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Read-only pin callout
private struct SavedPinView: View {
    let pin: PinAnnotation
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            if expanded && !pin.text.isEmpty {
                Text(pin.text)
                    .font(.callout)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 4)
                    .frame(maxWidth: 220)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            Circle()
                .fill(Color.accentColor)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(radius: 2)
        }
        .onTapGesture {
            withAnimation(.spring(duration: 0.25)) { expanded.toggle() }
        }
    }
}
