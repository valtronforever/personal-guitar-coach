import Foundation
import Testing
import Domain
import Persistence
@testable import PersonalGuitarCoach

private actor CalibrationRepositoryStub: CalibrationRepository {
    var values: [CalibrationProfile] = []
    var fail = false
    func loadCalibrationProfiles() throws -> [CalibrationProfile] {
        if fail { throw StorageError.corruptDocument }; return values
    }
    func saveCalibration(_ profile: CalibrationProfile, replacing expectedID: UUID?) throws {
        if fail { throw StorageError.corruptDocument }
        values.removeAll { $0.route == profile.route }; values.append(profile)
    }
    func removeCalibration(id: UUID) throws {
        if fail { throw StorageError.corruptDocument }; values.removeAll { $0.id == id }
    }
    func setFailure(_ value: Bool) { fail = value }
}

@MainActor struct CalibrationStoreTests {
    private func route(rate: Double = 48000) throws -> CalibrationRoute {
        let endpoint = try CalibrationEndpoint(uid: "test", channel: 1, sampleRate: rate, bufferFrames: 512)
        return try CalibrationRoute(input: endpoint, output: endpoint, backendVersion: "test")
    }
    @Test func failedWritesKeepPublishedProfileAndChangedRouteCannotSelectIt() async throws {
        let repository = CalibrationRepositoryStub(), store = CalibrationStore(repository: repository)
        await store.load()
        let first = try CalibrationProfile(route: route(), method: .manual, residualOffsetSeconds: 0.05, uncertaintySeconds: 1)
        #expect(await store.save(first))
        #expect(store.profile(for: try route()) == first)
        #expect(store.profile(for: try route(rate: 44100)) == nil)
        await repository.setFailure(true)
        let replacement = try CalibrationProfile(route: route(), method: .estimated, residualOffsetSeconds: 0, uncertaintySeconds: 1)
        #expect(await store.save(replacement) == false)
        await store.forget(first)
        #expect(store.profile(for: try route()) == first)
        #expect(store.errorKey == "calibration.storageSave")
        await repository.setFailure(false)
        let reopened = CalibrationStore(repository: repository); await reopened.load()
        #expect(reopened.profile(for: try route()) == first)
        await reopened.forget(first)
        #expect(reopened.profiles.isEmpty)
    }
    @Test func failedLoadDisablesSavingUntilSuccessfulRetry() async throws {
        let repository = CalibrationRepositoryStub(); await repository.setFailure(true)
        let store = CalibrationStore(repository: repository); await store.load()
        #expect(!store.loaded && store.errorKey == "calibration.storageLoad")
        let profile = try CalibrationProfile(route: route(), method: .manual, residualOffsetSeconds: 0, uncertaintySeconds: 1)
        #expect(await store.save(profile) == false)
        await repository.setFailure(false); await store.load()
        #expect(store.loaded && store.errorKey == nil)
        #expect(await store.save(profile))
    }
}
