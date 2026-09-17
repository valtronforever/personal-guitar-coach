import AppKit
import SwiftUI
import Domain
import Learning
import Testing
@testable import PersonalGuitarCoach

@MainActor struct MeterRenderTests {
    @Test func exportMeterNotationWhenRequested() throws {
        guard let directory = ProcessInfo.processInfo.environment["COACH_METER_RENDER_DIR"] else { return }
        let root = URL(fileURLWithPath:directory)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let repo = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf:repo.appendingPathComponent("Resources/Localization/Localizable.xcstrings"))
        let catalog = try #require(JSONSerialization.jsonObject(with:data) as? [String:Any])
        let entries = try #require(catalog["strings"] as? [String:[String:Any]])
        let lessons = LessonCatalogLoader().load(directory:repo.appendingPathComponent("Resources/Lessons")).lessons
        for (language,dark) in [("en",true),("uk",false)] {
            let resources = root.appendingPathComponent("\(language).lproj")
            try FileManager.default.createDirectory(at:resources,withIntermediateDirectories:true)
            var strings: [String:String] = [:]
            for (key,entry) in entries {
                if let locales = entry["localizations"] as? [String:[String:Any]], let unit = locales[language]?["stringUnit"] as? [String:String] { strings[key] = unit["value"] }
            }
            try PropertyListSerialization.data(fromPropertyList:strings,format:.xml,options:0).write(to:resources.appendingPathComponent("Localizable.strings"))
            let bundle = try #require(Bundle(url:resources))
            for (slug,activity) in [("compound-meters","six-eight-phrase"),("compound-meters","twelve-eight-flow"),("odd-meters","five-two-three"),("odd-meters","seven-three-two-two")] {
                let lesson = try #require(lessons.first { $0.id == slug })
                let ex = try lesson.resolveActivity(id:activity,instrument:InstrumentProfile()).exercises[0]
                let timeline = try TimelineModel(exercise:ex,instrument:.standard)
                let model = StaffModel(timeline:timeline,key:.neutral), symbols = try model.symbols(in:0)
                let drawing = StaffDrawing(model:model,bar:0,selectedIDs:[])
                let title = ex.timeSignature.rawValue + " · " + (strings[ex.timeSignature.tempoUnitKey] ?? "Missing pulse label")
                let staff = VStack(alignment:.leading) {
                    Text(verbatim:title).font(.headline).padding(.leading,12)
                    Canvas { context,_ in drawing.draw(symbols,context:&context) }.frame(width:drawing.width,height:StaffModel.canvasHeight)
                }
                let practice = VStack(alignment:.leading) {
                    Text(verbatim:title).font(.headline)
                    MeterScoreFixture(model:timeline,bundle:bundle)
                }.padding(12).frame(width:600)
                for (name,view) in [("staff",AnyView(staff)),("practice",AnyView(practice))] {
                    let content = view.background(dark ? Color.black : Color.white)
                        .environment(\.colorScheme,dark ? .dark : .light).environment(\.locale,Locale(identifier:language))
                    let renderer = ImageRenderer(content:content); renderer.scale = 2
                    let tiff = try #require(renderer.nsImage?.tiffRepresentation)
                    let bitmap = try #require(NSBitmapImageRep(data:tiff))
                    if name == "staff" {
                        var ink = 0
                        for y in stride(from:bitmap.pixelsHigh*2/5,to:bitmap.pixelsHigh*7/10,by:2) {
                            for x in stride(from:0,to:bitmap.pixelsWide,by:4) {
                                if let color = bitmap.colorAt(x:x,y:y)?.usingColorSpace(.deviceRGB) {
                                    let brightness = (color.redComponent+color.greenComponent+color.blueComponent)/3
                                    if dark ? brightness>0.3 : brightness<0.7 { ink += 1 }
                                }
                            }
                        }
                        #expect(ink>200)
                    }
                    let meter = ex.timeSignature.rawValue.replacingOccurrences(of:"/",with:"-")
                    try #require(bitmap.representation(using:.png,properties:[:])).write(to:root.appendingPathComponent("\(meter)-\(name)-\(language).png"))
                }
            }
        }
    }
}

private struct MeterScoreFixture: View {
    let model: TimelineModel
    let bundle: Bundle
    @FocusState private var focus: TimelineFocus?
    var body: some View {
        let layout = PracticeScoreLayout(timeline:model,firstBar:1,width:576)
        VStack(spacing:16) {
            ForEach(0..<2,id:\.self) { row in
                PracticeScoreRow(model:model,layout:layout,row:Int64(row),cursor:layout.cursor(Double(model.pulseTicks),endTick:model.exercise.durationTicks),selectedIDs:[],firstBar:1,lastBar:Int(model.barCount),zoom:1,playing:false,localizationBundle:bundle,focus:$focus,requestedFocus:nil,onSelect:{ _,_ in })
            }
        }
    }
}
