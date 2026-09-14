import AVFoundation
import Audio
import CryptoKit
import Foundation

enum CoachFileError: Error { case unsupported, tooLarge, invalid, channel, resources, response }

struct CoachAudioEvent: Codable, Sendable {
    let id: String
    let seconds: Double
    let frequency: Double?
    let clarity: Double?
    let quality: SignalQuality
}

struct CoachAudioReport: Codable, Sendable {
    let algorithmVersion: String
    let sha256: String
    let durationSeconds: Double
    let sampleRate: Double
    let channel: Int
    let channelCount: Int
    let peak: Double
    let rms: Double
    let clippingFraction: Double
    let observationsByQuality: [String: Int]
    let events: [CoachAudioEvent]
    /// Reliable sustained pitch samples at 100 ms intervals, including notes without a detected attack.
    let pitchSamples: [CoachAudioEvent]
}

/// Offline processing of a user-selected file; never touches the live capture pipeline.
enum CoachAudioFile {
    static let maximumBytes = 100 * 1024 * 1024
    static let maximumSeconds = 150.0

    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    static func copy(_ source: URL, to destination: URL) throws {
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let size = values.fileSize, size > 0 else { throw CoachFileError.invalid }
        guard size <= maximumBytes else { throw CoachFileError.tooLarge }
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else { throw CoachFileError.invalid }
        let output = try FileHandle(forWritingTo: destination)
        var complete = false, bytes = 0
        defer { try? output.close(); if !complete { try? FileManager.default.removeItem(at: destination) } }
        while let data = try input.read(upToCount: 65536), !data.isEmpty {
            try Task.checkCancellation(); bytes += data.count
            guard bytes <= maximumBytes else { throw CoachFileError.tooLarge }
            try output.write(contentsOf: data)
        }
        complete = true
    }

    static func analyze(_ url: URL, channel: Int) throws -> CoachAudioReport {
        guard ["wav", "mp3"].contains(url.pathExtension.lowercased()) else { throw CoachFileError.unsupported }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let size = values.fileSize, size > 0 else { throw CoachFileError.invalid }
        guard size <= maximumBytes else { throw CoachFileError.tooLarge }
        // Hash in bounded chunks, including cancellation during large file reads.
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var digest = SHA256()
        var bytes = 0
        while let block = try handle.read(upToCount: 65536), !block.isEmpty {
            try Task.checkCancellation()
            bytes += block.count
            guard bytes <= maximumBytes else { throw CoachFileError.tooLarge }
            digest.update(data: block)
        }
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        guard [44100.0, 48000.0].contains(format.sampleRate) else { throw CoachFileError.unsupported }
        guard (1...Int(format.channelCount)).contains(channel) else { throw CoachFileError.channel }
        guard file.length > 0 else { throw CoachFileError.invalid }
        guard Double(file.length) / format.sampleRate <= maximumSeconds else { throw CoachFileError.tooLarge }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else { throw CoachFileError.invalid }
        let analyzer = try MonophonicAnalyzer(sampleRate: format.sampleRate)
        var frames: Int64 = 0, clipped: Int64 = 0
        var peak = 0.0, squares = 0.0
        var qualities: [String: Int] = [:]
        var events: [CoachAudioEvent] = []
        var pitchSamples: [CoachAudioEvent] = []
        var nextPitchSample = 0.0
        var lastID: UInt64?
        func collect() {
            for event in analyzer.snapshot().events where lastID == nil || event.id > lastID! {
                events.append(CoachAudioEvent(id: "audio:\(event.id)", seconds: event.onset.streamSeconds,
                    frequency: event.pitch?.frequency, clarity: event.pitch?.clarity, quality: event.quality))
                lastID = event.id
            }
        }
        while file.framePosition < file.length {
            try Task.checkCancellation()
            try file.read(into: buffer, frameCount: buffer.frameCapacity)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { throw CoachFileError.invalid }
            frames += Int64(buffer.frameLength)
            guard Double(frames) / format.sampleRate <= maximumSeconds else { throw CoachFileError.tooLarge }
            let samples = UnsafeBufferPointer(start: channels[channel - 1], count: Int(buffer.frameLength))
            for sample in samples {
                guard sample.isFinite else { throw CoachFileError.invalid }
                let value = Double(sample)
                peak = max(peak, abs(value)); squares += value * value
                if abs(value) >= 0.999 { clipped += 1 }
            }
            analyzer.process(samples) { observation in
                qualities[observation.quality.rawValue, default: 0] += 1
                if observation.time.streamSeconds >= nextPitchSample {
                    nextPitchSample = observation.time.streamSeconds + 0.1
                    if observation.quality == .reliable, let pitch = observation.pitch {
                        pitchSamples.append(CoachAudioEvent(id: "audio:pitch:\(pitchSamples.count)", seconds: observation.time.streamSeconds,
                            frequency: pitch.frequency, clarity: pitch.clarity, quality: observation.quality))
                    }
                }
            }
            collect()
        }
        analyzer.finish(); collect()
        guard frames > 0 else { throw CoachFileError.invalid }
        return CoachAudioReport(algorithmVersion: MonophonicAnalyzer.algorithmVersion,
            sha256: digest.finalize().map { String(format: "%02x", $0) }.joined(),
            durationSeconds: Double(frames) / format.sampleRate, sampleRate: format.sampleRate,
            channel: channel, channelCount: Int(format.channelCount), peak: peak,
            rms: sqrt(squares / Double(frames)), clippingFraction: Double(clipped) / Double(frames),
            observationsByQuality: qualities, events: events, pitchSamples: pitchSamples)
    }
}
