import Foundation
import Domain

public protocol PracticeRepository: Sendable {
    func history() async throws -> HistoryLoad
    @discardableResult func save(_ record: PracticeRecord) async throws -> [StorageIssue]
    func clearHistory() async throws
}

public protocol InstrumentRepository: Sendable {
    func loadPreferences() async -> PreferencesLoad
    func savePreferences(_ preferences: InstrumentPreferences) async throws
    func restoreDefaultPreferencesPreservingCopy() async throws
}

public protocol AudioSettingsRepository: Sendable {
    func loadAudioSelection() async throws -> AudioRouteSelection
    func saveAudioSelection(_ value: AudioRouteSelection) async throws
}

public protocol CalibrationRepository: Sendable {
    func loadCalibrationProfiles() async throws -> [CalibrationProfile]
    func saveCalibration(_ profile: CalibrationProfile, replacing expectedID: UUID?) async throws
    func removeCalibration(id: UUID) async throws
}

public struct AtomicDocumentWriter: Sendable {
    let write: @Sendable (Data, URL) throws -> Void
    public init(write: @escaping @Sendable (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) {
        self.write = write
    }
}

/// One actor serializes each app's disk mutations. Individual attempt files are authoritative.
public actor LocalRepository: PracticeRepository, InstrumentRepository, ReadingRepository, AudioSettingsRepository, CalibrationRepository {
    public let root: URL
    private let writer: AtomicDocumentWriter
    private let manager = FileManager.default
    private var sessions: URL { root.appendingPathComponent("Sessions", isDirectory: true) }
    private var preferencesURL: URL { root.appendingPathComponent("instrument.json") }
    private var indexURL: URL { root.appendingPathComponent("history-index.json") }
    private var readingURL: URL { root.appendingPathComponent("reading-progress.json") }
    private var calibrationURL: URL { root.appendingPathComponent("calibration-profiles.json") }
    private var audioURL: URL { root.appendingPathComponent("audio-selection.json") }

    public init(root: URL, writer: AtomicDocumentWriter = AtomicDocumentWriter()) {
        self.root = root; self.writer = writer
    }

    public static func applicationSupport() throws -> LocalRepository {
        let library = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: false)
        return LocalRepository(root: library.appendingPathComponent("PersonalGuitarCoach", isDirectory: true))
    }

    public func loadCalibrationProfiles() throws -> [CalibrationProfile] {
        do {
            let data = try Data(contentsOf: calibrationURL)
            let version = try JSONDecoder().decode(VersionHeader.self, from: data).schemaVersion
            guard version == 1 else { throw StorageError.unsupportedVersion(version) }
            let profiles = try JSONDecoder().decode(DocumentEnvelope<[CalibrationProfile]>.self, from: data).payload
            try validateCalibrationProfiles(profiles)
            return profiles
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { return [] }
    }
    public func saveCalibration(_ profile: CalibrationProfile, replacing expectedID: UUID?) throws {
        var profiles = try loadCalibrationProfiles()
        if let index = profiles.firstIndex(where: { $0.route == profile.route }) {
            let old = profiles[index]
            guard old.id == expectedID else { throw StorageError.identifierConflict }
            if old.id == profile.id {
                guard old == profile || (old.revision < Int.max && profile.revision == old.revision + 1) else { throw StorageError.identifierConflict }
            } else if profile.revision != 1 { throw StorageError.identifierConflict }
            profiles[index] = profile
        } else {
            guard expectedID == nil, profile.revision == 1 else { throw StorageError.identifierConflict }
            profiles.append(profile)
        }
        try validateCalibrationProfiles(profiles)
        try prepare()
        try writer.write(encode(DocumentEnvelope(schemaVersion: 1, payload: profiles)), calibrationURL)
    }
    public func removeCalibration(id: UUID) throws {
        let profiles = try loadCalibrationProfiles(), remaining = profiles.filter { $0.id != id }
        guard profiles.count != remaining.count else { return }
        try prepare()
        try writer.write(encode(DocumentEnvelope(schemaVersion: 1, payload: remaining)), calibrationURL)
    }
    private func validateCalibrationProfiles(_ profiles: [CalibrationProfile]) throws {
        guard profiles.count <= 128, Set(profiles.map(\.id)).count == profiles.count,
              Set(profiles.map(\.route)).count == profiles.count else { throw StorageError.invalidRecord }
    }

    public func loadAudioSelection() throws -> AudioRouteSelection {
        do {
            let data = try Data(contentsOf: audioURL)
            let version = try JSONDecoder().decode(VersionHeader.self, from: data).schemaVersion
            guard version == 1 else { throw StorageError.unsupportedVersion(version) }
            return try JSONDecoder().decode(DocumentEnvelope<AudioRouteSelection>.self, from: data).payload
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return .unselected
        }
    }

    public func saveAudioSelection(_ value: AudioRouteSelection) throws {
        _ = try loadAudioSelection()
        try prepare()
        try writer.write(encode(DocumentEnvelope(schemaVersion: 1, payload: value)), audioURL)
    }

    public func loadReadingProgress() throws -> ReadingProgress {
        do {
            let data = try Data(contentsOf: readingURL)
            let version = try JSONDecoder().decode(VersionHeader.self, from: data).schemaVersion
            guard version == 1 else { throw StorageError.unsupportedVersion(version) }
            let value = try JSONDecoder().decode(DocumentEnvelope<ReadingProgress>.self, from: data).payload
            try value.validate()
            return value
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return ReadingProgress()
        }
    }

    public func saveReadingProgress(_ value: ReadingProgress) throws {
        try value.validate()
        _ = try loadReadingProgress() // Preserve corrupt/future documents instead of replacing them.
        try prepare()
        try writer.write(encode(DocumentEnvelope(schemaVersion: 1, payload: value)), readingURL)
    }

    public func loadPreferences() -> PreferencesLoad {
        do {
            let data = try Data(contentsOf: preferencesURL)
            let version = try JSONDecoder().decode(VersionHeader.self, from: data).schemaVersion
            let value: InstrumentPreferences
            switch version {
            case 1:
                let old = try JSONDecoder().decode(DocumentEnvelope<LegacyPreferences>.self, from: data).payload
                value = try InstrumentPreferences(instrument: InstrumentProfile(tuning: old.tuning, orientation: old.orientation),
                                                  customTunings: old.customTunings, practiceBPM: old.practiceBPM)
            case 2:
                value = try JSONDecoder().decode(DocumentEnvelope<InstrumentPreferences>.self, from: data).payload
            default: throw StorageError.unsupportedVersion(version)
            }
            try value.validate()
            return .available(value, migrated: version == 1)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return .available(.defaults, migrated: false)
        } catch { return .needsRecovery(issue(for: preferencesURL, error: error)) }
    }

    public func savePreferences(_ preferences: InstrumentPreferences) throws {
        try preferences.validate()
        if case .needsRecovery = loadPreferences() { throw StorageError.preferencesNeedRecovery }
        try prepare()
        try writer.write(encode(DocumentEnvelope(schemaVersion: 2, payload: preferences)), preferencesURL)
    }

    /// Recovery is explicit. The unreadable/future file is retained before replacing preferences.
    public func restoreDefaultPreferencesPreservingCopy() throws {
        try prepare()
        if manager.fileExists(atPath: preferencesURL.path) {
            let recovery = root.appendingPathComponent("Recovery", isDirectory: true)
            try manager.createDirectory(at: recovery, withIntermediateDirectories: true)
            try manager.copyItem(at: preferencesURL, to: recovery.appendingPathComponent("instrument-\(UUID().uuidString).json"))
        }
        try writer.write(encode(DocumentEnvelope(schemaVersion: 2, payload: InstrumentPreferences.defaults)), preferencesURL)
    }

    public func history() throws -> HistoryLoad {
        try prepare()
        var records: [PracticeRecord] = []
        var issues: [StorageIssue] = []
        var identifiers = Set<UUID>()
        for url in try sessionFiles() {
            do {
                let resource = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard resource.isRegularFile == true, resource.isSymbolicLink != true,
                      let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { throw StorageError.corruptDocument }
                let record = try decodeRecord(Data(contentsOf: url))
                guard record.id == id, identifiers.insert(id).inserted else { throw StorageError.corruptDocument }
                records.append(record)
            } catch { issues.append(issue(for: url, error: error)) }
        }
        records.sort { $0.startedAt == $1.startedAt ? $0.id.uuidString < $1.id.uuidString : $0.startedAt > $1.startedAt }
        do { try writeIndex(records) }
        catch { issues.append(StorageIssue(fileName: indexURL.lastPathComponent, reason: .indexUnavailable)) }
        return HistoryLoad(records: records, issues: issues)
    }

    /// A saved attempt is immutable. Retrying an identical save is safe; rewriting its facts is rejected.
    @discardableResult public func save(_ record: PracticeRecord) throws -> [StorageIssue] {
        try record.validate()
        try prepare()
        let url = sessions.appendingPathComponent(record.id.uuidString + ".json")
        if manager.fileExists(atPath: url.path) {
            guard try decodeRecord(Data(contentsOf: url)) == record else { throw StorageError.identifierConflict }
        } else {
            try writer.write(encode(DocumentEnvelope(schemaVersion: record.assessment == nil ? 1 : 2, payload: record)), url)
        }
        // The attempt is committed; an index failure is a recoverable warning, not a failed save.
        do { return try history().issues }
        catch { return [StorageIssue(fileName: indexURL.lastPathComponent, reason: .indexUnavailable)] }
    }

    public func clearHistory() throws {
        try prepare()
        // Only this app's attempt directory is affected; instrument/preferences and recovery copies stay intact.
        for file in try sessionFiles() {
            let resource = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard resource.isRegularFile == true || resource.isSymbolicLink == true else { throw StorageError.corruptDocument }
            try manager.removeItem(at: file)
        }
        try writeIndex([])
    }

    private func prepare() throws { try manager.createDirectory(at: sessions, withIntermediateDirectories: true) }
    private func sessionFiles() throws -> [URL] {
        try manager.contentsOfDirectory(at: sessions, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                                        options: [.skipsHiddenFiles]).filter { $0.pathExtension == "json" }
    }
    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(value)
    }
    private func decodeRecord(_ data: Data) throws -> PracticeRecord {
        let version = try JSONDecoder().decode(VersionHeader.self, from: data).schemaVersion
        guard version == 1 || version == 2 else { throw StorageError.unsupportedVersion(version) }
        let record = try JSONDecoder().decode(DocumentEnvelope<PracticeRecord>.self, from: data).payload
        guard (version == 2) == (record.assessment != nil) else { throw StorageError.invalidRecord }
        try record.validate()
        return record
    }
    private func writeIndex(_ records: [PracticeRecord]) throws {
        let entries = records.map { IndexEntry(id: $0.id, startedAt: $0.startedAt, exerciseID: $0.exercise.id) }
        try writer.write(encode(DocumentEnvelope(schemaVersion: 1, payload: entries)), indexURL)
    }
    private func issue(for url: URL, error: Error) -> StorageIssue {
        let reason: StorageIssue.Reason
        if case StorageError.unsupportedVersion = error { reason = .unsupported }
        else if case AssessmentError.unsupportedVersion = error { reason = .unsupported }
        else if error is CocoaError { reason = .unreadable }
        else { reason = .corrupt }
        return StorageIssue(fileName: url.lastPathComponent, reason: reason)
    }
}

private struct VersionHeader: Decodable { let schemaVersion: Int }
private struct IndexEntry: Codable, Sendable { let id: UUID; let startedAt: Date; let exerciseID: String }
/// Documented v1 migration fixture: source was implicit electric-interface, tuning was at the root.
private struct LegacyPreferences: Codable, Sendable {
    let tuning: TuningProfile
    let orientation: FretboardOrientation
    let customTunings: [TuningProfile]
    let practiceBPM: Double
}
