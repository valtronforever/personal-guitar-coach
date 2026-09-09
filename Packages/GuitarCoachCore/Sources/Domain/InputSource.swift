/// Physical source of the guitar signal, independent of the selected audio device.
/// Raw values are persisted identifiers; keep them stable across translations.
public enum InputSource: String, CaseIterable, Codable, Identifiable, Sendable {
    case electricInterface
    case acousticMicrophone
    case acousticPickup

    public var id: String { rawValue }
}
