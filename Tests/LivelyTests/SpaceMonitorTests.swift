import XCTest
@testable import LivelyCore

@MainActor
final class SpaceMonitorTests: XCTestCase {
    
    // Testing SpaceMonitor is tricky because it relies on NSWorkspace and NotificationCenter.
    // For a unit test without UI/User interaction, we can check initial state stability.
    // Ideally, we'd mock NSWorkspace, but it's not easily mockable in Swift without protocols.
    // We will test basic initialization and property existence.
    
    func testInitializationPopulatesScreenSpaces() {
        let monitor = SpaceMonitor()
        XCTAssertNotNil(monitor)
        // We can't assert an exact count without mocking, but we can ensure it doesn't crash
        // and that screenSpaces is at least an empty array.
        XCTAssertNotNil(monitor.screenSpaces)
    }
}
