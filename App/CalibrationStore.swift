import SwiftUI
import Domain
import Audio
import Persistence

@MainActor @Observable
final class CalibrationStore {
    @ObservationIgnored private let repository: (any CalibrationRepository)?
    let wizard = CalibrationModel()
    var calibrationString = 3
    private(set) var outputProfiles: [OutputAlignmentProfile] = []
    private(set) var profiles: [CalibrationProfile] = []
    private(set) var loaded = false
    private(set) var busy = false
    private(set) var errorKey: String?
    init(repository: (any CalibrationRepository)?) { self.repository = repository }
    func outputProfile(for endpoint: CalibrationEndpoint?) -> OutputAlignmentProfile? {
        guard let value = storedOutputProfile(for: endpoint), value.isNonnegativeSetting else { return nil }
        return value
    }
    func storedOutputProfile(for endpoint: CalibrationEndpoint?) -> OutputAlignmentProfile? {
        outputProfiles.first { $0.output == endpoint }
    }
    func saveOutput(_ value: OutputAlignmentProfile) async -> Bool {
        guard value.isNonnegativeSetting else { errorKey = "sync.manual.invalid"; return false }
        guard loaded, !busy, let repository = repository as? any OutputAlignmentRepository else { errorKey = "calibration.storageSave"; return false }
        busy = true; defer { busy = false }
        do {
            try await repository.saveOutputAlignment(value)
            outputProfiles.removeAll { $0.output == value.output || $0.id == value.id }; outputProfiles.append(value)
            receipts.removeAll(); errorKey = nil; return true
        } catch { errorKey = "calibration.storageSave"; return false }
    }
    func resetOutput(_ endpoint: CalibrationEndpoint?) async {
        guard loaded, !busy, let value = storedOutputProfile(for: endpoint), let repository = repository as? any OutputAlignmentRepository else { return }
        busy = true; defer { busy = false }
        do {
            try await repository.removeOutputAlignment(id: value.id)
            outputProfiles.removeAll { $0.id == value.id }; receipts.removeAll(); errorKey = nil
        } catch { errorKey = "calibration.storageSave" }
    }
    func profile(for route: CalibrationRoute?) -> CalibrationProfile? {
        guard let route else { return nil }
        return profiles.first { $0.route == route }
    }
    private struct Receipt {
        let session: UUID
        let revision: UInt64
    }
    private var receipts: [UUID: Receipt] = [:]
    func usableProfile(audio: AudioSessionStore, instrument: InstrumentProfile) -> CalibrationProfile? {
        guard let profile = profile(for: audio.state?.calibrationRoute), profile.isNonnegativeSetting else { return nil }
        guard profile.method.isPersonal else { return profile }
        guard let receipt = receipts[profile.id], receipt.session == audio.synchronizationSession,
              receipt.revision == audio.state?.routeRevision,
              profile.personalInstrument == instrument,
              profile.outputSetting?.id == outputProfile(for: audio.state?.outputEndpoint)?.id else { return nil }
        return profile
    }
    func confirm(_ profile: CalibrationProfile, session: UUID, revision: UInt64) {
        guard profiles.contains(profile), profile.method.isPersonal, profile.isNonnegativeSetting else { return }
        receipts[profile.id] = Receipt(session: session, revision: revision)
    }
    func load() async {
        guard !busy, !loaded else { return }
        busy = true; defer { busy = false }
        do {
            guard let repository else { throw StorageError.corruptDocument }
            let values = try await repository.loadCalibrationProfiles()
            let outputs = try await (repository as? any OutputAlignmentRepository)?.loadOutputAlignments() ?? []
            profiles = values; outputProfiles = outputs; loaded = true; errorKey = nil
        } catch { errorKey = "calibration.storageLoad" }
    }
    @discardableResult func save(_ value: CalibrationProfile) async -> Bool {
        guard value.isNonnegativeSetting else { errorKey = "sync.manual.invalid"; return false }
        guard loaded, !busy, let repository else { return false }
        busy = true; defer { busy = false }
        do {
            try await repository.saveCalibration(value, replacing: profile(for: value.route)?.id)
            profiles.removeAll { $0.route == value.route }; profiles.append(value); errorKey = nil
            receipts = receipts.filter { receipt in profiles.contains { $0.id == receipt.key } }
            return true
        } catch { errorKey = "calibration.storageSave"; return false }
    }
    func forget(_ value: CalibrationProfile) async {
        guard loaded, !busy, let repository else { return }
        busy = true; defer { busy = false }
        do { try await repository.removeCalibration(id: value.id); profiles.removeAll { $0.id == value.id }; receipts[value.id] = nil; errorKey = nil }
        catch { errorKey = "calibration.storageSave" }
    }
}
