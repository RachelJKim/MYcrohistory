import Foundation
import SwiftData
import UIKit

struct MemoStore {
    // MARK: - Image I/O

    static func saveImage(_ image: UIImage, forMemoID id: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let filename = "memo-\(id.uuidString).jpg"
        let url = documentsURL().appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return filename
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }

    static func deleteImage(filename: String) {
        let url = documentsURL().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    static func loadImage(from url: URL) -> UIImage? {
        UIImage(contentsOfFile: url.path)
    }

    // MARK: - Memo Deletion

    static func deleteMemo(_ memo: Memo, context: ModelContext) {
        if let path = memo.imagePath {
            deleteImage(filename: path)
        }
        context.delete(memo)
    }

    // MARK: - Private

    private static func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
