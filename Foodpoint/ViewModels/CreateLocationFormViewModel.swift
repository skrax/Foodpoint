import Foundation
import Observation

@Observable
class CreateLocationFormViewModel {
    static let nameMinLength = 3
    static let nameMaxLength = 50

    static let availableIcons = [
        "tray.full", "refrigerator", "cabinet", "basket",
        "shippingbox", "takeoutbag.and.cup.and.straw.fill", "carrot", "leaf.fill",
    ]

    var name: String = ""
    var icon: String = availableIcons[0]
    var errorMessage: String?

    func validate() -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < Self.nameMinLength {
            return "Name must be at least \(Self.nameMinLength) characters."
        }
        if trimmed.count > Self.nameMaxLength {
            return "Name must be at most \(Self.nameMaxLength) characters."
        }
        return nil
    }

    func save(onSave: (String, String) -> Void) -> Bool {
        guard let error = validate() else {
            errorMessage = nil
            onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), icon)
            return true
        }
        errorMessage = error
        return false
    }
}
