import Foundation
import SwiftData

@Model final class PinAnnotation {
    var id: UUID
    var normalizedX: Double
    var normalizedY: Double
    var text: String
    var memo: Memo?

    init(id: UUID = UUID(), normalizedX: Double, normalizedY: Double, text: String = "") {
        self.id = id
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.text = text
    }
}
