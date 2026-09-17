import AppKit
import SwiftUI
import Testing
import Domain
@testable import PersonalGuitarCoach

@MainActor struct TripletRenderTests {
    @Test func renderTripletAndShuffleNotationWhenRequested() throws {
        guard let directory = ProcessInfo.processInfo.environment["COACH_TRIPLET_RENDER_DIR"] else { return }
        let root = URL(fileURLWithPath:directory)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let repo = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf:repo.appendingPathComponent("Resources/Localization/Localizable.xcstrings"))
        let catalog = try #require(JSONSerialization.jsonObject(with:data) as? [String:Any])
        let entries = try #require(catalog["strings"] as? [String:[String:Any]])
        let timeline = try TimelineModel(exercise:TripletNotationTests.exercise(),instrument:.standard)
        let model = StaffModel(timeline:timeline,key:.neutral), symbols = try model.symbols(in:0)
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
                let title = language == "en" ? "Triplets · shuffle · rest · straight eighths" : "Тріолі · shuffle · пауза · рівні восьмі"
                let drawing = StaffDrawing(model:model,bar:0,selectedIDs:[],cursorTick:1600)
                let staff = VStack(alignment:.leading) {
                    Text(verbatim:title).font(.headline).padding(.leading,12)
                    Canvas { context,_ in drawing.draw(symbols,context:&context) }.frame(width:drawing.width,height:StaffModel.canvasHeight)
                }
                let practice = VStack(alignment:.leading) {
                    Text(verbatim:title).font(.headline)
                    TripletScoreFixture(model:timeline,bundle:bundle)
                }.padding(12).frame(width:600)
                for (name,view) in [("staff",AnyView(staff)),("practice",AnyView(practice))] {
                    let content = view.background(dark ? Color.black : Color.white)
                        .environment(\.colorScheme,dark ? .dark : .light).environment(\.locale,Locale(identifier:language))
                    let renderer = ImageRenderer(content:content); renderer.scale = 2
                    let image = try #require(renderer.nsImage), tiff = try #require(image.tiffRepresentation)
                    let bitmap = try #require(NSBitmapImageRep(data:tiff))
                    if name == "staff" {
                        // Reject a partial Canvas export containing only brackets/cursor.
                        var ink = 0
                        for y in stride(from: bitmap.pixelsHigh * 2 / 5, to: bitmap.pixelsHigh * 7 / 10, by: 2) {
                            for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
                                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) {
                                    let brightness = (color.redComponent + color.greenComponent + color.blueComponent) / 3
                                    if dark ? brightness > 0.3 : brightness < 0.7 { ink += 1 }
                                }
                            }
                        }
                        #expect(ink > 200, "Staff lines and noteheads must be present in the exported image")
                    }
                    try #require(bitmap.representation(using:.png,properties:[:])).write(to:root.appendingPathComponent("\(name)-\(language)-\(dark ? "dark" : "light").png"))
                }
            }
        }
    }
}

private struct TripletScoreFixture: View {
    let model: TimelineModel
    let bundle: Bundle
    @FocusState private var focus: TimelineFocus?
    var body: some View {
        let layout = PracticeScoreLayout(timeline:model,firstBar:1,width:576)
        PracticeScoreRow(model:model,layout:layout,row:0,cursor:layout.cursor(1600,endTick:3840),selectedIDs:[],firstBar:1,lastBar:1,
            zoom:1,playing:false,localizationBundle:bundle,focus:$focus,requestedFocus:nil,onSelect:{ _,_ in })
    }
}
