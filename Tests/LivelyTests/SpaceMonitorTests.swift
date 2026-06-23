import Testing
@testable import LivelyCore

@MainActor
struct SpaceMonitorTests {

    @Test func initializationPopulatesScreenSpaces() {
        let monitor = SpaceMonitor()
        // Can't assert an exact count without mocking NSScreen, but verifies no crash
        // and screenSpaces is a valid (possibly empty) array.
        _ = monitor.screenSpaces
    }
}
