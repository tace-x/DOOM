import Foundation

public enum SelectionValidator {
    public static func validate(
        _ raw: String,
        source: SourceApplication,
        method: AcquisitionMethod,
        restoreSkipped: Bool = false
    ) throws(TextAcquisitionError) -> SelectedText {
        // Rule 1: Remove U+0000 (NUL) characters
        let sanitized = raw.replacingOccurrences(of: "\0", with: "")

        // Rule 2: Trim leading and trailing whitespace and newlines
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        // Rule 3: Empty after trim -> .emptySelection (E-SEL-01)
        if trimmed.isEmpty {
            throw .emptySelection
        }

        // Rule 4: Count grapheme clusters (Swift Characters) > 20,000 -> .tooLong (never truncate)
        let count = trimmed.count
        if count > SelectionLimits.maxCharacters {
            throw .tooLong(count: count, limit: SelectionLimits.maxCharacters)
        }

        return SelectedText(
            value: trimmed,
            characterCount: count,
            source: source,
            method: method,
            restoreSkipped: restoreSkipped
        )
    }
}
