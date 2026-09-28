import Testing
@testable import LivelyCore
import Foundation

@MainActor
struct ConfigPersistenceTests {

    private func makeDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("lively-cfg-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeVideo(in dir: URL, name: String = "clip.mp4") -> URL {
        let url = dir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
        return url
    }

    @Test func oneBadEntryDoesNotDiscardTheRest() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let configURL = dir.appendingPathComponent("config_v2.json")
        let video = makeVideo(in: dir)

        // Produce one genuine entry via the real API.
        let writer = ConfigStore(configFileURL: configURL)
        var wallpaper = DynamicWallpaper()
        wallpaper.staticURL = video
        writer.assign(dynamicWallpaper: wallpaper, toSpaceKey: "1:good")
        writer.flushPendingPersist()

        // Inject a future-schema / malformed sibling entry.
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: configURL)) as? [String: Any])
        json["2:future"] = ["spaceKey": "2:future", "dynamicWallpaper": ["mode": "playlist"], "bookmarks": [:], "addedAt": 0]
        json["3:garbage"] = "not an object"
        try JSONSerialization.data(withJSONObject: json).write(to: configURL)

        let reader = ConfigStore(configFileURL: configURL)
        #expect(reader.configs.keys.sorted() == ["1:good"])
    }

    @Test func corruptFileIsMovedAsideNotOverwritten() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let configURL = dir.appendingPathComponent("config_v2.json")
        try Data("{ this is not json".utf8).write(to: configURL)

        let store = ConfigStore(configFileURL: configURL)
        #expect(store.configs.isEmpty)
        let backup = ConfigStore.corruptBackupURL(for: configURL)
        #expect(FileManager.default.fileExists(atPath: backup.path))
        #expect(try String(contentsOf: backup, encoding: .utf8) == "{ this is not json")
    }

    @Test func persistRecreatesDirectoryAfterReset() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let configDir = dir.appendingPathComponent("Lively")
        let configURL = configDir.appendingPathComponent("config_v2.json")
        let video = makeVideo(in: dir)

        let store = ConfigStore(configFileURL: configURL)
        store.clearAllData()   // deletes configDir, as Reset Data does

        var wallpaper = DynamicWallpaper()
        wallpaper.staticURL = video
        store.assign(dynamicWallpaper: wallpaper, toSpaceKey: "1:after-reset")
        store.flushPendingPersist()

        #expect(ConfigStore(configFileURL: configURL).configs["1:after-reset"] != nil)
    }

    @Test func movedFileIsFollowedAndStoredPathUpdated() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let original = makeVideo(in: dir, name: "before.mp4")
        let store = ConfigStore(configFileURL: dir.appendingPathComponent("config_v2.json"))

        var wallpaper = DynamicWallpaper()
        wallpaper.staticURL = original
        store.assign(dynamicWallpaper: wallpaper, toSpaceKey: "1:moved")

        let renamed = dir.appendingPathComponent("after.mp4")
        try FileManager.default.moveItem(at: original, to: renamed)

        let resolved = try #require(store.resolvedURL(for: "1:moved", appearance: nil))
        #expect(resolved.lastPathComponent == "after.mp4")
        #expect(store.configs["1:moved"]?.dynamicWallpaper.staticURL?.lastPathComponent == "after.mp4")
    }

    @Test func deletedFileResolvesToNil() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let video = makeVideo(in: dir)
        let store = ConfigStore(configFileURL: dir.appendingPathComponent("config_v2.json"))

        var wallpaper = DynamicWallpaper()
        wallpaper.staticURL = video
        store.assign(dynamicWallpaper: wallpaper, toSpaceKey: "1:deleted")
        try FileManager.default.removeItem(at: video)

        #expect(store.resolvedURL(for: "1:deleted", appearance: nil) == nil)
        // The assignment itself is kept so the card can offer "Reselect".
        #expect(store.configs["1:deleted"] != nil)
    }

    @Test func appearanceModePicksMatchingBookmark() throws {
        let dir = try makeDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let light = makeVideo(in: dir, name: "light.mp4")
        let dark = makeVideo(in: dir, name: "dark.mov")
        let store = ConfigStore(configFileURL: dir.appendingPathComponent("config_v2.json"))

        var wallpaper = DynamicWallpaper()
        wallpaper.mode = .appearance
        wallpaper.lightURL = light
        wallpaper.darkURL = dark
        store.assign(dynamicWallpaper: wallpaper, toSpaceKey: "1:appearance")

        let aqua = NSAppearanceProxy.aqua
        let darkAqua = NSAppearanceProxy.darkAqua
        #expect(store.resolvedURL(for: "1:appearance", appearance: aqua)?.lastPathComponent == "light.mp4")
        #expect(store.resolvedURL(for: "1:appearance", appearance: darkAqua)?.lastPathComponent == "dark.mov")
    }
}

import AppKit
private enum NSAppearanceProxy {
    @MainActor static var aqua: NSAppearance? { NSAppearance(named: .aqua) }
    @MainActor static var darkAqua: NSAppearance? { NSAppearance(named: .darkAqua) }
}
