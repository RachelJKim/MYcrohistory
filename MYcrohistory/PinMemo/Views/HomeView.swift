import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Memo.createdAt, order: .reverse) private var memos: [Memo]

    @State private var showCameraFlow = false
    @State private var showVoice = false
    @State private var showText = false
    @State private var capturedImage: UIImage? = nil
    @State private var selectedMemo: Memo? = nil
    @State private var selectedCategory: String? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var categories: [String] {
        Array(Set(memos.compactMap(\.category))).sorted()
    }

    private var filteredMemos: [Memo] {
        guard let cat = selectedCategory else { return memos }
        return memos.filter { $0.category == cat }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                if memos.isEmpty {
                    ContentUnavailableView(
                        "No Memos",
                        systemImage: "pin.slash",
                        description: Text("Tap a button below to create your first memo.")
                    )
                } else {
                    VStack(spacing: 0) {
                        if !categories.isEmpty {
                            categoryBar
                        }

                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(filteredMemos) { memo in
                                    MemoBubble(memo: memo)
                                        .onTapGesture { selectedMemo = memo }
                                        .contextMenu {
                                            categoryMenu(for: memo)
                                            Button(role: .destructive) {
                                                MemoStore.deleteMemo(memo, context: context)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding(16)
                        }
                    }
                }

                // FAB stack
                VStack(spacing: 12) {
                    FABButton(icon: "pencil", color: .indigo) { showText = true }
                    FABButton(icon: "mic.fill", color: .orange) { showVoice = true }
                    FABButton(icon: "camera.fill", color: .teal) { showCameraFlow = true }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("MYcrohistory")
        }
        // Camera → Postcard flow
        .fullScreenCover(isPresented: $showCameraFlow, onDismiss: { capturedImage = nil }) {
            if let image = capturedImage {
                PostcardMemoView(selectedImage: image)
            } else {
                CameraPickerView(selectedImage: $capturedImage, onCancel: { showCameraFlow = false })
                    .ignoresSafeArea()
            }
        }
        // View saved memo
        .fullScreenCover(item: $selectedMemo) { memo in
            MemoDetailView(memo: memo)
        }
        .sheet(isPresented: $showVoice) {
            VoiceMemoView()
        }
        .sheet(isPresented: $showText) {
            TextMemoView()
        }
    }

    // MARK: - Category Bar

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(categories, id: \.self) { cat in
                    CategoryChip(title: cat, isSelected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Category Context Menu

    @ViewBuilder
    private func categoryMenu(for memo: Memo) -> some View {
        Menu("Category") {
            Button("None") { memo.category = nil }
            ForEach(categories, id: \.self) { cat in
                Button(cat) { memo.category = cat }
            }
        }
    }
}

// MARK: - Category Chip
private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15),
                            in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}

// MARK: - Memo Bubble
private struct MemoBubble: View {
    let memo: Memo

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch memo.memoKind {
                case 0:
                    if let url = memo.resolvedImageURL,
                       let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholderIcon("photo", color: .teal)
                    }
                case 1:
                    snippetBubble(icon: "mic.fill", color: .orange)
                default:
                    snippetBubble(icon: "text.alignleft", color: .indigo)
                }
            }
            .frame(width: bubbleSize, height: bubbleSize)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(memo.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var bubbleSize: CGFloat {
        (UIScreen.main.bounds.width - 16 * 2 - 12 * 2) / 3
    }

    private func snippetBubble(icon: String, color: Color) -> some View {
        ZStack(alignment: .bottomTrailing) {
            color.opacity(0.10)

            if let text = memo.textContent, !text.isEmpty {
                Text(text.prefix(120))
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color.opacity(0.6))
                .padding(6)
        }
    }

    private func placeholderIcon(_ name: String, color: Color) -> some View {
        ZStack {
            color.opacity(0.15)
            Image(systemName: name)
                .font(.system(size: 24))
                .foregroundStyle(color)
        }
    }
}

// MARK: - FAB Button
private struct FABButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(color, in: Circle())
                .shadow(radius: 4)
        }
    }
}
