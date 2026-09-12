import Foundation
import Domain
import Learning
import Persistence

enum ResultAnnotation: String, CaseIterable {
    case uncertain, missing, pitch, early, late, matched, restExtra
    var key: String { "result.annotation." + rawValue }
    var symbol: String {
        switch self {
        case .uncertain: "questionmark.diamond"
        case .missing: "minus.circle"
        case .pitch: "waveform.path"
        case .early: "arrow.left.circle"
        case .late: "arrow.right.circle"
        case .matched: "link"
        case .restExtra: "plus.circle"
        }
    }
}

enum ResultPresentation {
    static func annotations(_ result: AssessedPractice) -> [String: ResultAnnotation] {
        let graded = result.validity == .valid || result.validity == .uncalibrated
        var annotations: [String: ResultAnnotation] = [:]
        for note in result.notes {
            if note.uncertain { annotations[note.id] = .uncertain }
            else if note.attackID == nil { if graded { annotations[note.id] = .missing } }
            else if graded && abs(note.centsError ?? 0) >= 15 { annotations[note.id] = .pitch }
            else if result.validity == .valid, let timing = note.timingErrorSeconds, abs(timing) > result.rhythmToleranceSeconds {
                annotations[note.id] = timing < 0 ? .early : .late
            } else { annotations[note.id] = .matched }
        }
        for extra in result.extras {
            if let rest = extra.restID {
                annotations[rest] = extra.uncertain || annotations[rest] == .uncertain ? .uncertain : .restExtra
            }
        }
        return annotations
    }
    static func lessonTitle(id: String, version: Int, tuning: TuningProfile, lessons: [LoadedLesson], language: LessonLanguage) -> String? {
        guard let source = lessons.first(where: { $0.id == id }) else { return nil }
        if source.manifest.version == version { return source.text(for: language).title }
        guard source.manifest.adaptation?.lessonVersion == version else { return nil }
        return (try? source.adapted(to: tuning))?.text(for: language).title
    }
    static func title(record: PracticeRecord, lessons: [LoadedLesson], language: LessonLanguage) -> String? {
        guard let config = record.assessment?.payload.evidence.configuration, let reference = config.lesson else { return nil }
        return lessonTitle(id: reference.id, version: reference.version,
            tuning: config.exercise.requiredTuning ?? config.instrument.tuning, lessons: lessons, language: language)
    }
}
