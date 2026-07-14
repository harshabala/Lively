import Testing
@testable import LivelyCore
import Foundation

@Suite(.serialized)
@MainActor
struct WallpaperLibraryManagerTests {

    private func makeTempVideo(named name: String = "clip.mp4") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + name)
        try Data("fake-video".utf8).write(to: url)
        return url
    }

    @Test func startsEmpty() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let manager = WallpaperLibraryManager(libraryDir: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        #expect(manager.items.isEmpty)
    }

    @Test func addCopiesFileIntoLibrary() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let manager = WallpaperLibraryManager(libraryDir: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let source = try makeTempVideo()
        defer { try? FileManager.default.removeItem(at: source) }

        let item = try manager.add(from: source)
        #expect(manager.items.count == 1)
        #expect(item.name == source.deletingPathExtension().lastPathComponent)
        #expect(manager.resolvedURL(for: item) != nil)
        #expect(FileManager.default.fileExists(atPath: manager.fileURL(for: item).path))
        // Original still present; library has its own copy
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test func addRejectsUnsupportedFormat() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let manager = WallpaperLibraryManager(libraryDir: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        try Data("nope".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        #expect(throws: WallpaperLibraryManager.LibraryError.unsupportedFormat) {
            try manager.add(from: source)
        }
        #expect(manager.items.isEmpty)
    }

    @Test func removeDeletesFileAndIndexEntry() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let manager = WallpaperLibraryManager(libraryDir: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let source = try makeTempVideo()
        defer { try? FileManager.default.removeItem(at: source) }

        let item = try manager.add(from: source)
        let stored = manager.fileURL(for: item)
        #expect(FileManager.default.fileExists(atPath: stored.path))

        manager.remove(item)
        #expect(manager.items.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: stored.path))
    }

    @Test func indexPersistsAcrossInstances() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let source = try makeTempVideo(named: "aurora.mp4")
        defer { try? FileManager.default.removeItem(at: source) }

        let first = WallpaperLibraryManager(libraryDir: tempDir)
        let item = try first.add(from: source)
        #expect(first.items.count == 1)

        let second = WallpaperLibraryManager(libraryDir: tempDir)
        #expect(second.items.count == 1)
        #expect(second.items[0].id == item.id)
        #expect(second.items[0].name == item.name)
        #expect(second.resolvedURL(for: second.items[0]) != nil)
    }

    @Test func renameUpdatesDisplayName() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let manager = WallpaperLibraryManager(libraryDir: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let source = try makeTempVideo(named: "raw.mp4")
        defer { try? FileManager.default.removeItem(at: source) }

        let item = try manager.add(from: source)
        manager.rename(item, to: "Mountain Loop")
        #expect(manager.items.first?.name == "Mountain Loop")
    }
}
