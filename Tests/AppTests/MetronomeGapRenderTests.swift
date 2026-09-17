import AppKit
import SwiftUI
import Testing
import Domain
import Learning
@testable import PersonalGuitarCoach

@MainActor struct MetronomeGapRenderTests {
    @Test func renderMetronomeGapsWhenRequested() throws {
        guard let directory = ProcessInfo.processInfo.environment["COACH_METRONOME_RENDER_DIR"] else { return }
        let root = URL(fileURLWithPath:directory)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let repo = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf:repo.appendingPathComponent("Resources/Localization/Localizable.xcstrings"))
        let catalog = try #require(JSONSerialization.jsonObject(with:data) as? [String:Any])
        let entries = try #require(catalog["strings"] as? [String:[String:Any]])
        let lesson = try #require(LessonCatalogLoader().load(directory:repo.appendingPathComponent("Resources/Lessons")).lessons.first { $0.id == "missing-clicks" })
        let timeline = try TimelineModel(exercise:lesson.manifest.exercises[1],instrument:.standard)
        for language in ["en","uk"] {
            let resources = root.appendingPathComponent("\(language).lproj")
            try FileManager.default.createDirectory(at:resources,withIntermediateDirectories:true)
            var strings: [String:String] = [:]
            for (key,entry) in entries {
                if let locales = entry["localizations"] as? [String:[String:Any]], let unit = locales[language]?["stringUnit"] as? [String:String] { strings[key] = unit["value"] }
            }
            try PropertyListSerialization.data(fromPropertyList:strings,format:.xml,options:0).write(to:resources.appendingPathComponent("Localizable.strings"))
            let bundle = try #require(Bundle(url:resources))
            for dark in [false,true] {
                let practice = VStack(alignment:.leading) {
                    Text("practice.metronomeGaps", bundle:bundle).font(.callout)
                    MetronomeScoreFixture(model:timeline,bundle:bundle)
                }.padding(12).frame(width:600)
                for (name,view) in [("practice",AnyView(practice))] {
                    let content = view.background(dark ? Color.black : Color.white)
                        .environment(\.colorScheme,dark ? .dark : .light).environment(\.locale,Locale(identifier:language))
                    let renderer = ImageRenderer(content:content); renderer.scale = 2
                    let image = try #require(renderer.nsImage), tiff = try #require(image.tiffRepresentation)
                    let bitmap = try #require(NSBitmapImageRep(data:tiff))
                    try #require(bitmap.representation(using:.png,properties:[:])).write(to:root.appendingPathComponent("\(name)-\(language)-\(dark ? "dark" : "light").png"))
                }
            }
        }
    }
}

private struct MetronomeScoreFixture: View {
    let model: TimelineModel
    let bundle: Bundle
    @FocusState private var focus: TimelineFocus?
    var body: some View {
        let layout = PracticeScoreLayout(timeline:model,firstBar:1,width:576)
        VStack(spacing:16) {
            ForEach(0..<2, id: \.self) { row in
                PracticeScoreRow(model:model,layout:layout,row:Int64(row),cursor:layout.cursor(5400,endTick:model.exercise.durationTicks),selectedIDs:[],firstBar:1,lastBar:6,
                    zoom:1,playing:false,localizationBundle:bundle,focus:$focus,requestedFocus:nil,onSelect:{ _,_ in })
            }
        }
    }
}
