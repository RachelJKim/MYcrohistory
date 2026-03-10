import Foundation
import SwiftData

@Model final class Memo: Identifiable {
    var id: UUID
    var memoKind: Int          // 0=postcard, 1=voice, 2=text
    var createdAt: Date
    var title: String
    var imagePath: String?
    var textContent: String?
    var category: String? = nil
    @Relationship(deleteRule: .cascade) var pins: [PinAnnotation] = []

    var resolvedImageURL: URL? {
        guard let path = imagePath else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(path)
    }

    init(
        id: UUID = UUID(),
        memoKind: Int,
        title: String = "",
        imagePath: String? = nil,
        textContent: String? = nil,
        category: String? = nil
    ) {
        self.id = id
        self.memoKind = memoKind
        self.createdAt = Date()
        self.title = title
        self.imagePath = imagePath
        self.textContent = textContent
        self.category = category
    }
}
