import Foundation
import SwiftUI
import AppKit
import Testing
import Domain
import Learning
@testable import PersonalGuitarCoach

/// Opt-in offline geometry artifacts; not native app/VoiceOver execution.
@MainActor struct StaffRenderTests {
    @Test func renderNotationArtifactsWhenRequested() throws {
        guard let folder = ProcessInfo.processInfo.environment["COACH_STAFF_RENDER_DIR"] else { return }
        let root = URL(fileURLWithPath: folder); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var events: [MusicalEvent] = []
        let durations: [Int64] = [960,480,480,240,240,240,240,960]
        var tick: Int64 = 0
        for (index,duration) in durations.enumerated() {
            let rest = [1,4,7].contains(index)
            events.append(try MusicalEvent(id:"r\(index)",startTick:tick,durationTicks:duration,kind:rest ? .rest : .note,
                positions:rest ? [] : [FretPosition(string:6,fret:index)])); tick += duration
        }
        let exercise = try Exercise(id:"staff-render",events:events)
        let half = try Exercise(id:"half",events:[MusicalEvent(id:"half-note",startTick:0,durationTicks:1920,kind:.note,positions:[FretPosition(string:1,fret:0)]),MusicalEvent(id:"half-rest",startTick:1920,durationTicks:1920,kind:.rest)])
        let whole = try Exercise(id:"whole",events:[MusicalEvent(id:"whole-note",startTick:0,durationTicks:3840,kind:.note,positions:[FretPosition(string:1,fret:24)]),MusicalEvent(id:"whole-rest",startTick:3840,durationTicks:3840,kind:.rest)])
        let repository = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let library = LessonCatalogLoader().load(directory:repository.appendingPathComponent("Resources/Lessons"))
        let cMajor = try #require(library.lessons.first { $0.id == "c-major" }?.manifest.exercises.first { $0.id == "c-major-practice" })
        for example in [exercise,half,whole,cMajor] {
        let timeline = try TimelineModel(exercise:example,instrument:.standard)
        for bar in 0..<timeline.barCount {
        for key in StaffKey.allCases {
            let model = StaffModel(timeline:timeline,key:key), symbols = try model.symbols(in:bar)
            for dark in [false,true] {
                let drawing = StaffDrawing(model:model,bar:bar,selectedIDs:["r0"],cursorTick:960)
                let content = Canvas { context,_ in drawing.draw(symbols,context:&context) }
                    .frame(width:drawing.width,height:248).background(dark ? Color.black : Color.white)
                    .environment(\.colorScheme,dark ? .dark : .light)
                let renderer = ImageRenderer(content:content);renderer.scale=2
                let image = try #require(renderer.nsImage)
                let tiff = try #require(image.tiffRepresentation)
                let bitmap = try #require(NSBitmapImageRep(data:tiff))
                let png = try #require(bitmap.representation(using:.png,properties:[:]))
                #expect(bitmap.pixelsWide == Int(drawing.width * 2) && bitmap.pixelsHigh == 496)
                try png.write(to:root.appendingPathComponent("\(example.id)-\(bar)-\(key.rawValue)-\(dark ? "dark" : "light").png"))
            }
        }
        }
        }
    }
}
