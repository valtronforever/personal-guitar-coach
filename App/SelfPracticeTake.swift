import Foundation
import Domain
import Learning
import Audio

struct SelfPracticeRecordingContext: Identifiable, Sendable {
    let id = UUID()
    let snapshot: ResolvedLessonActivity
    let exercise: Exercise
    init(snapshot: ResolvedLessonActivity, exercise: Exercise) throws {
        guard snapshot.activity.recording == .selfPractice, snapshot.exercises.contains(exercise),
              exercise.assessmentMode == .displayOnly,
              exercise.events.flatMap(\.techniquePositions).allSatisfy(snapshot.instrument.contains) else { throw MusicError.invalidExercise }
        self.snapshot = snapshot; self.exercise = exercise
    }
    func transport(bpm: Double) throws -> TransportRequest {
        guard (exercise.minimumBPM...exercise.maximumBPM).contains(bpm),
              try MusicalTime.seconds(forTicks: exercise.durationTicks, bpm: bpm, pulseTicks: exercise.timeSignature.pulseTicks) <= 120,
              try MusicalTime.seconds(forTicks: exercise.durationTicks + exercise.timeSignature.ticksPerBar, bpm: bpm, pulseTicks: exercise.timeSignature.pulseTicks) <= 130 else { throw CoachFileError.tooLarge }
        return try TransportRequest(exercise: exercise, tuning: snapshot.instrument.tuning, bpm: bpm,
            countInBars: 1, loops: false, mode: .practice, clickEnabled: true, toneVolume: 0)
    }
}

/// An exported recording is evidence of audio only, never a computed music score.
struct SelfPracticeTakeMetadata: Codable, Sendable {
    let schemaVersion: Int
    let kind: String
    let id: UUID
    let capturedAt: Date
    let completed: Bool
    let lessonID: String
    let lessonVersion: Int
    let activity: LessonActivity
    let materialID: String
    let position: PositionChoice
    let resolverVersion: String
    let sourceMappings: [ExerciseSourceMapping]
    let exercise: Exercise
    let instrument: InstrumentProfile
    let bpm: Double
    let countInBars: Int
    let route: AudioRouteSelection
    let routeTiming: CalibrationRoute?
    let outputAlignment: OutputAlignmentProfile?
    let sampleRate: Double
    let sampleCount: Int
    let firstInputHostSeconds: Double
    let renderEpoch: Double
    let assessmentCalibrationApplied: Bool
    let channels: [String]
}

struct SelfPracticeTake: Sendable {
    let audio: CoachRecordedTake
    let metadata: SelfPracticeTakeMetadata
    init(context: SelfPracticeRecordingContext, recording: PracticeRecording, transport: TransportRequest,
         epoch: Double, route: AudioCoordinatorSnapshot, outputAlignment: OutputAlignmentProfile?, completed: Bool, capturedAt: Date) throws {
        guard !recording.samples.isEmpty, recording.sampleRate.isFinite, (8000...192000).contains(recording.sampleRate),
              recording.samples.count <= Int(recording.sampleRate * 150), recording.firstHostSeconds.isFinite,
              epoch.isFinite, epoch >= 0, recording.firstHostSeconds >= 0, abs(recording.firstHostSeconds - epoch) <= 150,
              transport.exercise == context.exercise, transport.range == 0..<context.exercise.durationTicks,
              transport.tuning == context.snapshot.instrument.tuning, transport.countInBars == 1, !transport.loops,
              transport.startTick == 0, transport.mode == .practice, transport.toneVolume == 0, transport.clickEnabled else { throw CoachFileError.invalid }
        if completed {
            let duration = try MusicalTime.seconds(forTicks: context.exercise.durationTicks + context.exercise.timeSignature.ticksPerBar,
                bpm: transport.bpm, pulseTicks: context.exercise.timeSignature.pulseTicks)
            guard recording.firstHostSeconds <= epoch,
                  recording.firstHostSeconds + Double(recording.samples.count) / recording.sampleRate >= epoch + duration else { throw CoachFileError.invalid }
        }
        audio = CoachRecordedTake(recording: recording, renderEpoch: epoch, transport: transport)
        let snapshot = context.snapshot
        metadata = SelfPracticeTakeMetadata(schemaVersion: 1, kind: "self-practice-ungraded", id: UUID(), capturedAt: capturedAt,
            completed: completed, lessonID: snapshot.lessonID, lessonVersion: snapshot.lessonVersion, activity: snapshot.activity,
            materialID: snapshot.material.id, position: snapshot.choice, resolverVersion: ResolvedLessonActivity.resolverVersion,
            sourceMappings: snapshot.sourceMappings, exercise: context.exercise, instrument: snapshot.instrument, bpm: transport.bpm,
            countInBars: transport.countInBars, route: route.selection, routeTiming: route.calibrationRoute, outputAlignment: outputAlignment,
            sampleRate: recording.sampleRate, sampleCount: recording.samples.count, firstInputHostSeconds: recording.firstHostSeconds,
            renderEpoch: epoch, assessmentCalibrationApplied: false, channels: ["selected-mono-guitar-input", "generated-metronome-reference-not-measured-output"])
    }
    /// Build in our temporary directory, then replace only the explicitly selected destination atomically.
    func export(to destination: URL) throws {
        guard audio.recording.samples.allSatisfy(\.isFinite) else { throw CoachFileError.invalid }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SelfPractice-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let temporary = directory.appendingPathComponent("take.wav")
        try Task.checkCancellation()
        try audio.write(to: temporary)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
        let metadata = try encoder.encode(metadata)
        guard metadata.count <= 2 * 1024 * 1024 else { throw CoachFileError.tooLarge }
        try Self.appendMetadata(metadata, to: temporary)
        try Task.checkCancellation()
        try Data(contentsOf: temporary, options: .mappedIfSafe).write(to: destination, options: .atomic)
    }
    /// Unknown RIFF chunks are ignored by ordinary WAV players. pgcx retains our frozen context.
    static func appendMetadata(_ data: Data, to url: URL) throws {
        let file = try FileHandle(forUpdating: url); defer { try? file.close() }
        let header = try file.read(upToCount: 12) ?? Data()
        guard header.count == 12, header.prefix(4) == Data("RIFF".utf8), header.suffix(4) == Data("WAVE".utf8) else { throw CoachFileError.invalid }
        let end = try file.seekToEnd()
        guard end % 2 == 0, end >= 12, end + UInt64(data.count + data.count % 2) <= UInt64(UInt32.max) else { throw CoachFileError.tooLarge }
        func little(_ value: UInt32) -> Data { var value = value.littleEndian; return withUnsafeBytes(of: &value) { Data($0) } }
        try file.write(contentsOf: Data("pgcx".utf8)); try file.write(contentsOf: little(UInt32(data.count)))
        try file.write(contentsOf: data)
        if data.count % 2 != 0 { try file.write(contentsOf: Data([0])) }
        let size = try file.offset() - 8
        try file.seek(toOffset: 4); try file.write(contentsOf: little(UInt32(size)))
    }
}
