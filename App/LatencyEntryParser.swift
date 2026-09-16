import Foundation

/// Milliseconds with an optional sign and decimal dot/comma; reject partial parses and grouping ambiguities.
enum LatencyEntryParser {
    static func seconds(_ text: String) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "−", with: "-")
        guard value.range(of: #"^[+-]?(?:[0-9]+(?:[.,][0-9]+)?|[.,][0-9]+)$"#, options: .regularExpression) != nil,
              let milliseconds = Double(value.replacingOccurrences(of: ",", with: ".")), milliseconds.isFinite,
              (-1000...1000).contains(milliseconds) else { return nil }
        return milliseconds / 1000
    }
    static func text(_ seconds: Double) -> String { String(format: "%.1f", seconds * 1000) }
}
