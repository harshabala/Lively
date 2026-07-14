import Testing
@testable import LivelyCore
import Foundation

@Suite(.serialized)
@MainActor
struct WallpaperLibraryManagerTests {
    
    @Test func managerStatusDictionaryContainsAllCuratedItems() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let manager = WallpaperLibraryManager(libraryDir: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        #expect(manager.downloadStatuses.count == CuratedWallpaper.curatedList.count)
        
        for wallpaper in CuratedWallpaper.curatedList {
            #expect(manager.downloadStatuses[wallpaper.id] == .notDownloaded)
        }
    }
    
    @Test func localURLMatchesCachePathFormat() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let manager = WallpaperLibraryManager(libraryDir: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        for wallpaper in CuratedWallpaper.curatedList {
            let expectedURL = tempDir.appendingPathComponent("\(wallpaper.id).mp4")
            
            // localURL(for:) should return nil when not downloaded
            #expect(manager.localURL(for: wallpaper) == nil)
            
            // Now mock the file existing
            let dummyData = Data("dummy content".utf8)
            let fileURL = tempDir.appendingPathComponent("\(wallpaper.id).mp4")
            try? dummyData.write(to: fileURL)
            
            #expect(manager.localURL(for: wallpaper) == expectedURL)
        }
    }
    
    @Test func checkLocalFilesUpdatesStatuses() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let manager = WallpaperLibraryManager(libraryDir: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Initially all are notDownloaded
        for wallpaper in CuratedWallpaper.curatedList {
            #expect(manager.downloadStatuses[wallpaper.id] == .notDownloaded)
        }
        
        // Write a mock file for one wallpaper
        let targetWallpaper = CuratedWallpaper.curatedList[0]
        let fileURL = tempDir.appendingPathComponent("\(targetWallpaper.id).mp4")
        let dummyData = Data("dummy content".utf8)
        try? dummyData.write(to: fileURL)
        
        // Re-check files
        manager.checkLocalFiles()
        
        #expect(manager.downloadStatuses[targetWallpaper.id] == .downloaded(localURL: fileURL))
        
        // Others should remain notDownloaded
        for wallpaper in CuratedWallpaper.curatedList.dropFirst() {
            #expect(manager.downloadStatuses[wallpaper.id] == .notDownloaded)
        }
    }

    @Test func downloadSuccessWritesToCachesDirectory() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)
        
        let manager = WallpaperLibraryManager(libraryDir: tempDir, session: mockSession)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let targetWallpaper = CuratedWallpaper.curatedList[0]
        let dummyData = Data("mock video content".utf8)
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Length": String(dummyData.count)]
            )!
            return (response, dummyData)
        }
        
        await manager.download(targetWallpaper)
        
        let expectedURL = tempDir.appendingPathComponent("\(targetWallpaper.id).mp4")
        #expect(manager.downloadStatuses[targetWallpaper.id] == .downloaded(localURL: expectedURL))
        #expect(FileManager.default.fileExists(atPath: expectedURL.path))
        let savedData = try? Data(contentsOf: expectedURL)
        #expect(savedData == dummyData)
    }
    
    @Test func downloadFailureSetsFailedStatus() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)
        
        let manager = WallpaperLibraryManager(libraryDir: tempDir, session: mockSession)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let targetWallpaper = CuratedWallpaper.curatedList[0]
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, Data())
        }
        
        await manager.download(targetWallpaper)
        
        if case .failed(let message) = manager.downloadStatuses[targetWallpaper.id] {
            #expect(message.contains("Invalid HTTP status code: 404"))
        } else {
            Issue.record("Expected download status to be failed, but got: \(String(describing: manager.downloadStatuses[targetWallpaper.id]))")
        }
        
        // Also test network connection failure throwing error
        MockURLProtocol.requestHandler = { request in
            throw NSError(domain: "NSURLErrorDomain", code: URLError.notConnectedToInternet.rawValue, userInfo: nil)
        }
        
        // Clear status first
        manager.downloadStatuses[targetWallpaper.id] = .notDownloaded
        await manager.download(targetWallpaper)
        
        if case .failed(let message) = manager.downloadStatuses[targetWallpaper.id] {
            #expect(!message.isEmpty)
        } else {
            Issue.record("Expected download status to be failed after connection error")
        }
    }
}

class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockURLProtocol", code: 0, userInfo: nil))
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
