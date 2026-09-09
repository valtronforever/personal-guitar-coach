import Foundation

/// Persistent device identities; channel numbers are one-based. No system defaults are changed.
public struct AudioRouteSelection: Codable, Equatable, Sendable {
    public let inputUID: String?
    public let inputChannel: Int
    public let outputUID: String?
    public let outputChannel: Int
    public init(inputUID: String? = nil, inputChannel: Int = 1, outputUID: String? = nil, outputChannel: Int = 1) throws {
        guard (1...256).contains(inputChannel), (1...256).contains(outputChannel),
              [inputUID, outputUID].allSatisfy({ $0.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? true }) else {
            throw MusicError.invalidAudioRoute
        }
        self.inputUID = inputUID; self.inputChannel = inputChannel
        self.outputUID = outputUID; self.outputChannel = outputChannel
    }
    public static let unselected = try! AudioRouteSelection()
    private enum CodingKeys: CodingKey { case inputUID, inputChannel, outputUID, outputChannel }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(inputUID: values.decodeIfPresent(String.self, forKey: .inputUID),
                      inputChannel: values.decode(Int.self, forKey: .inputChannel),
                      outputUID: values.decodeIfPresent(String.self, forKey: .outputUID),
                      outputChannel: values.decode(Int.self, forKey: .outputChannel))
    }
}
