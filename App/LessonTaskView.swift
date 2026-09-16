import SwiftUI
import Domain
import Learning

struct LessonTaskView: View {
    let task: LessonLearningTask
    let copy: LessonLearningTaskText
    let context: LessonTaskContext
    let progress: LessonTaskProgress?
    let canEdit: Bool
    let save: (LessonTaskProgress) -> Void

    private var current: LessonTaskProgress {
        progress?.context == context ? progress! : LessonTaskProgress(context: context)
    }
    private var completed: Bool { task.isComplete(current, context: context) }
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label(LocalizedStringKey("lesson.task.kind." + task.kind.rawValue), systemImage: task.kind == .quiz ? "questionmark.circle" : "checklist")
                    .font(.caption).foregroundStyle(.secondary)
                Text(verbatim: copy.body)
                if task.kind == .quiz { quiz }
                else {
                    ForEach(task.itemIDs, id: \.self) { id in
                        Toggle(isOn: Binding(get: { current.checkedIDs.contains(id) }, set: { checked in
                            var value = current
                            if checked { value.checkedIDs.insert(id) } else { value.checkedIDs.remove(id) }
                            save(value)
                        })) { Text(verbatim: copy.items[id] ?? id) }
                            .toggleStyle(.checkbox).accessibilityIdentifier("lesson.task.\(task.id).\(id)")
                    }
                    if completed { Label("lesson.task.selfCompleted", systemImage: "checkmark.circle") }
                    Text("lesson.task.selfReportHelp").font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .disabled(!canEdit)
        } label: { Text(verbatim: copy.title).font(.headline).accessibilityAddTraits(.isHeader) }
            .accessibilityIdentifier("lesson.task.\(task.id)")
    }

    private var quiz: some View {
        VStack(alignment: .leading, spacing: 10) {
            if task.stimulusExerciseID != nil { Text("lesson.task.listenHelp").font(.callout) }
            ForEach(task.itemIDs, id: \.self) { id in
                Button {
                    save(LessonTaskProgress(context: context, answerID: id))
                } label: {
                    HStack {
                        Text(verbatim: copy.items[id] ?? id).multilineTextAlignment(.leading)
                        if current.answerID == id { Image(systemName: "checkmark.circle.fill") }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.disabled(current.answerID != nil).accessibilityIdentifier("lesson.task.\(task.id).\(id)")
            }
            if current.answerID != nil {
                Label(LocalizedStringKey(completed ? "lesson.task.correct" : "lesson.task.incorrect"),
                      systemImage: completed ? "checkmark.circle" : "arrow.counterclockwise.circle")
                    .font(.headline).accessibilityIdentifier("lesson.task.feedback")
                if let explanation = copy.explanation { Text(verbatim: explanation).textSelection(.enabled) }
                Button("lesson.task.retry") { save(LessonTaskProgress(context: context)) }
                    .accessibilityIdentifier("lesson.task.retry")
            }
        }
    }
}
