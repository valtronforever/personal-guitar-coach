import AVFoundation
import Audio
import Foundation

struct CoachRecordedTake: Sendable {
    let recording: PracticeRecording
    let renderEpoch: Double
    let transport: TransportRequest

    /// Channel 2 is the rendered click reference, not microphone capture or measured output latency.
    func write(to url: URL) throws {
        let rate = recording.sampleRate
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096),
              let channels = buffer.floatChannelData else { throw CoachFileError.invalid }
        let plan = try TransportPlan(request: transport, sampleRate: rate)
        var fileSettings = format.settings
        fileSettings[AVLinearPCMIsNonInterleaved] = false
        let file = try AVAudioFile(forWriting: url, settings: fileSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let offset = Int64(((recording.firstHostSeconds - renderEpoch) * rate).rounded())
        for start in stride(from: 0, to: recording.samples.count, by: 4096) {
            try Task.checkCancellation()
            let count = min(4096, recording.samples.count - start)
            buffer.frameLength = AVAudioFrameCount(count)
            for index in 0..<count { channels[0][index] = recording.samples[start + index]; channels[1][index] = 0 }
            let frame = Int64(start) + offset
            let padding = Int(min(Int64(count), max(0, -frame)))
            if padding < count {
                let clicks = try plan.render(startFrame: max(0, frame), count: count - padding)
                for index in clicks.indices { channels[1][index + padding] = clicks[index] }
            }
            try file.write(from: buffer)
        }
    }
}
