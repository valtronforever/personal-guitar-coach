import Foundation
import Testing
import Domain
@testable import Learning

struct LegatoChainResolverTests {
    @Test func everyIntermediateTargetRestrictsCandidatesIncludingDropAndNeckLength() throws {
        for (index, tuning) in TuningProfile.presets.enumerated() {
            let shift = [0, 0, -2, -2, -4, -4, -5, -5][index]
            for frets in GuitarFretCount.allCases {
                let source = try FretPosition(string: 6, fret: 5)
                let positions = try LessonFingeringResolver.resolve([source], sourceTuning: .standard, tuning: tuning,
                    shift: shift, maximumFret: frets.rawValue, region: nil, linkedFretOffsets: [0, 3, 7, 3, 0])
                let base = try #require(positions.first)
                #expect(base.string == 6 && base.fret == (index.isMultiple(of: 2) ? 5 : 7))
                for offset in [0, 3, 7, 3, 0] {
                    #expect(try tuning.pitch(at: FretPosition(string: base.string, fret: base.fret + offset)).midi == 45 + shift + offset)
                }
            }
        }
        // Identical first/last pitch does not excuse an unreachable intermediate tap.
        let position = try FretPosition(string: 3, fret: 5)
        #expect(throws: LessonAdaptationError.unplayable) {
            try LessonFingeringResolver.resolve([position], sourceTuning: .standard, tuning: .standard, shift: 0,
                maximumFret: 19, region: FretRegion(firstFret: 5, windowFrets: 7), linkedFretOffsets: [0, 3, 7, 3, 0])
        }
        #expect(try LessonFingeringResolver.resolve([position], sourceTuning: .standard, tuning: .standard, shift: 0,
            maximumFret: 19, region: FretRegion(firstFret: 5, windowFrets: 8), linkedFretOffsets: [0, 3, 7, 3, 0]) == [position])
    }
}
