import Foundation
import Domain
import Learning
import Persistence

enum ResultAnnotation: String, CaseIterable {
    case uncertain, missing, pitch, early, late, sustain, bend, pitchTransition, vibrato, legatoChain, matched, restExtra
    var key: String { "result.annotation." + rawValue }
    var symbol: String {
        switch self {
        case .uncertain: "questionmark.diamond"
        case .missing: "minus.circle"
        case .pitch: "waveform.path"
        case .early: "arrow.left.circle"
        case .late: "arrow.right.circle"
        case .sustain: "hourglass"
        case .bend: "arrow.up.right"
        case .legatoChain: "arrow.triangle.branch"
        case .vibrato: "waveform.path"
        case .pitchTransition: "arrow.right"
        case .matched: "link"
        case .restExtra: "plus.circle"
        }
    }
}

enum ResultPresentation {
    static func annotations(_ result: AssessedPractice) -> [String: ResultAnnotation] {
        let graded = result.validity == .valid || result.validity == .uncalibrated
        var annotations: [String: ResultAnnotation] = [:]
        let sustain = Dictionary(uniqueKeysWithValues: (result.sustain?.notes ?? []).map { ($0.id, $0) })
        let transitions = Dictionary(uniqueKeysWithValues: (result.pitchTransitions?.notes ?? []).map { ($0.id, $0) })
        let chains = Dictionary(uniqueKeysWithValues: (result.legatoChains?.notes ?? []).map { ($0.id, $0) })
        let vibrato = Dictionary(uniqueKeysWithValues: (result.vibrato?.notes ?? []).map { ($0.id, $0) })
        let bends = Dictionary(uniqueKeysWithValues: (result.bends?.notes ?? []).map { ($0.id, $0) })
        for note in result.notes {
            if chains[note.id].map({ $0.score == nil }) == true || vibrato[note.id].map({ $0.score == nil }) == true || transitions[note.id].map({ $0.score == nil }) == true || note.uncertain || sustain[note.id]?.state == .uncertain || bends[note.id].map({ $0.score == nil }) == true { annotations[note.id] = .uncertain }
            else if note.attackID == nil { if graded { annotations[note.id] = .missing } }
            else if graded && abs(note.centsError ?? 0) >= 15 { annotations[note.id] = .pitch }
            else if result.validity == .valid, let timing = note.timingErrorSeconds, abs(timing) > result.rhythmToleranceSeconds {
                annotations[note.id] = timing < 0 ? .early : .late
            } else if graded, let held = sustain[note.id]?.heldFraction, held < 0.8 {
                annotations[note.id] = .sustain
            } else if graded, transitions[note.id]?.phases.contains(where: { ($0.matchedFraction ?? 1) < 0.8 }) == true {
                annotations[note.id] = .pitchTransition
            } else if graded, chains[note.id]?.phases.contains(where: { ($0.matchedFraction ?? 1) < 0.8 }) == true {
                annotations[note.id] = .legatoChain
            } else if graded, vibrato[note.id]?.phases.contains(where: { ($0.matchedFraction ?? 1) < 0.8 }) == true {
                annotations[note.id] = .vibrato
            } else if graded, let score = bends[note.id]?.score, score < 80 {
                annotations[note.id] = .bend
            } else { annotations[note.id] = .matched }
        }
        for extra in result.scoredExtras {
            if let rest = extra.restID {
                annotations[rest] = extra.uncertain || annotations[rest] == .uncertain ? .uncertain : .restExtra
            }
        }
        return annotations
    }
    static func lessonTitle(id: String, version: Int, tuning: TuningProfile, lessons: [LoadedLesson], language: LessonLanguage, frets: GuitarFretCount = .twentyFour, historical: Bool = false) -> String? {
        guard let source = lessons.first(where: { $0.id == id }) else { return nil }
        guard source.manifest.version == version else { return nil }
        return source.text(for: language).title
    }
    static func title(record: PracticeRecord, lessons: [LoadedLesson], language: LessonLanguage) -> String? {
        guard let config = record.assessment?.payload.evidence.configuration, let reference = config.lesson else { return nil }
        if let activity = reference.activity { return activity.lessonTitles[language.rawValue] }
        return lessonTitle(id: reference.id, version: reference.version,
            tuning: config.exercise.requiredTuning ?? config.instrument.tuning, lessons: lessons, language: language, frets: config.instrument.frets, historical: true)
    }
}
