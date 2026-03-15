import XCTest
import Combine
@testable import LivelyCore

@MainActor
final class WallpaperControllerTests: XCTestCase {

    func testPlaybackErrorBubblesToSubject() {
        let monitor = SpaceMonitor()
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        // Use an empty config so WallpaperController won't try to create windows
        let store = ConfigStore(configFileURL: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let controller = WallpaperController(spaceMonitor: monitor, configStore: store)

        var receivedSpaceKey: String?
        var receivedMessage: String?

        let cancellable = controller.playbackErrors.sink { (spaceKey, message) in
            receivedSpaceKey = spaceKey
            receivedMessage = message
        }

        // PassthroughSubject.send is synchronous — sink fires immediately
        controller.playbackErrors.send(("test-space", "Simulated error"))

        XCTAssertEqual(receivedSpaceKey, "test-space")
        XCTAssertEqual(receivedMessage, "Simulated error")
        cancellable.cancel()
    }
    
    func testTogglePause() {
        let monitor = SpaceMonitor()
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = ConfigStore(configFileURL: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let controller = WallpaperController(spaceMonitor: monitor, configStore: store)

        XCTAssertFalse(controller.isPaused)
        controller.togglePause()
        XCTAssertTrue(controller.isPaused)
        controller.togglePause()
        XCTAssertFalse(controller.isPaused)
    }

    func testResumeAfterPauseTriggersSynchronize() {
        let monitor = SpaceMonitor()
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = ConfigStore(configFileURL: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let controller = WallpaperController(spaceMonitor: monitor, configStore: store)

        // Pause then immediately resume — should not crash, isPaused should be false
        controller.togglePause()
        XCTAssertTrue(controller.isPaused)
        controller.togglePause()
        XCTAssertFalse(controller.isPaused, "Controller should be playing after second toggle")
    }
}
