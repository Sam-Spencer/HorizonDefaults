import XCTest
@testable import HorizonDefaults

final class HorizonDefaultsTests: XCTestCase {
    
    @available(iOS 10.0, *)
    func testLoggingVariable() {
        HorizonDefaults.standard.verboseLogging = true
        XCTAssertEqual(HorizonDefaults.standard.verboseLogging, true)
    }

    @available(iOS 10.0, *)
    static var allTests = [
        ("testLogging", testLoggingVariable),
    ]
}
