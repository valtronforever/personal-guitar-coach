import Foundation
import Testing
@testable import Domain

@Suite("Saved input source compatibility")
struct InputSourceTests {
    @Test func readsExistingSourceIdentifiers() throws {
        let fixture = Data(#"["electricInterface","acousticMicrophone","acousticPickup"]"#.utf8)
        let sources = try JSONDecoder().decode([InputSource].self, from: fixture)
        #expect(sources == [.electricInterface, .acousticMicrophone, .acousticPickup])
    }

    @Test func unknownSourceDoesNotSilentlyBecomeElectric() {
        let fixture = Data(#""unknownSource""#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(InputSource.self, from: fixture)
        }
    }
}
