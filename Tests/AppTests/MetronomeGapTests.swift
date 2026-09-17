import AVFoundation
import Audio
import Domain
import Learning
import Testing
@testable import PersonalGuitarCoach

struct MetronomeGapAppTests {
    @MainActor @Test func gappedAttemptsSelectNewPromptWhileHistoricalOnesKeepTheirVersion() throws {
        let baseline = try AssessmentFixtureView.result("valid")
        #expect(CoachExchange.promptVersion(for:baseline) == "file-coach-1")
        var json = try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode(baseline.evidence)) as? [String:Any])
        var config = try #require(json["configuration"] as? [String:Any])
        var exercise = try #require(config["exercise"] as? [String:Any])
        exercise["metronome"] = ["silentBeatTicks":[0]]; config["exercise"] = exercise; json["configuration"] = config
        let evidence = try JSONDecoder().decode(PracticeEvidence.self,from:JSONSerialization.data(withJSONObject:json))
        let gapped = try AssessmentEngine.evaluate(evidence)
        #expect(CoachExchange.promptVersion(for:gapped) == "file-coach-3")
        #expect(gapped.notes == baseline.notes)
        exercise.removeValue(forKey:"metronome"); exercise["timeSignature"] = "6/8"
        config["exercise"] = exercise; json["configuration"] = config
        let compoundEvidence = try JSONDecoder().decode(PracticeEvidence.self,from:JSONSerialization.data(withJSONObject:json))
        #expect(CoachExchange.promptVersion(for:try AssessmentEngine.evaluate(compoundEvidence)) == "file-coach-4")
    }

    @Test func scoreMarkersAndRecordedReferenceKeepTheSameOmissions() throws {
        let events = try (0..<12).map { i in
            try MusicalEvent(id:"e\(i)",startTick:Int64(i*960),durationTicks:960,kind:.note,positions:[FretPosition(string:3,fret:5)])
        }
        let exercise = try Exercise(id:"gaps",events:events,metronome:MetronomePattern(silentBeatTicks:[0,1920,3840,4800,5760,6720]))
        let timeline = try TimelineModel(exercise:exercise,instrument:.standard)
        #expect(timeline.silentBeatNumbers(in:0) == [1,3])
        #expect(timeline.silentBeatNumbers(in:1) == [1,2,3,4])
        #expect(timeline.silentBeatNumbers(in:2).isEmpty)
        let rate = 8000.0
        let request = try TransportRequest(exercise:exercise,tuning:.standard,bpm:60,mode:.practice)
        let guitar = (0..<128000).map { Float(($0%13)-6)*0.01 }
        let take = CoachRecordedTake(recording:PracticeRecording(samples:guitar,sampleRate:rate,firstHostSeconds:100),renderEpoch:100,transport:request)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".wav")
        defer { try? FileManager.default.removeItem(at:url) }
        try take.write(to:url)
        let file = try AVAudioFile(forReading:url)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:128000))
        try file.read(into:buffer)
        let channels = try #require(buffer.floatChannelData)
        #expect(buffer.frameLength == 128000)
        #expect((0..<128000).allSatisfy { channels[0][$0] == guitar[$0] })
        for beat in 0..<16 {
            let silent = beat >= 4 && [0,2,4,5,6,7].contains(beat-4)
            let range = (beat*8000)..<(beat*8000+128)
            #expect(silent ? range.allSatisfy { channels[1][$0] == 0 } : range.contains { abs(channels[1][$0])>0.01 })
        }
    }
}
