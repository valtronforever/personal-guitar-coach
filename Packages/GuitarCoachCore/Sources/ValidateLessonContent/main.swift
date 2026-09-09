import Foundation
import Learning
import Darwin

guard CommandLine.arguments.count == 2 else {
    print("Usage: ValidateLessonContent <Resources/Lessons directory>")
    exit(2)
}
let report = LessonCatalogLoader().load(directory: URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true))
for issue in report.issues { print("[\(issue.lessonID ?? "catalog")] \(issue.code.rawValue): \(issue.detail)") }
print("Validated \(report.lessons.count) bilingual lesson(s); \(report.issues.count) issue(s).")
exit(report.issues.isEmpty && !report.lessons.isEmpty ? 0 : 1)
