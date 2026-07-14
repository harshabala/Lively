import Foundation
import Combine

public enum DownloadStatus: Equatable, Sendable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded(localURL: URL)
    case failed(String)
}

@MainActor
public final class WallpaperLibraryManager: NSObject, ObservableObject {
    public static let shared = WallpaperLibraryManager()
    
    public var downloadStatuses: [String: DownloadStatus] = [:] {
        didSet {
            _downloadStatusesPublisher.send(downloadStatuses)
        }
    }
    private let _downloadStatusesPublisher = CurrentValueSubject<[String: DownloadStatus], Never>([:])
    public var downloadStatusesPublisher: AnyPublisher<[String: DownloadStatus], Never> {
        _downloadStatusesPublisher.eraseToAnyPublisher()
    }
    
    @Published public var spaceKeyTarget: String?
    
    public let libraryDir: URL
    private let session: URLSession
    
    public init(libraryDir: URL? = nil, session: URLSession = .shared) {
        self.session = session
        if let libraryDir = libraryDir {
            self.libraryDir = libraryDir
        } else if let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            self.libraryDir = cachesDir.appendingPathComponent("Lively/Library")
        } else {
            self.libraryDir = FileManager.default.temporaryDirectory.appendingPathComponent("Lively/Library")
        }
        
        super.init()
        
        do {
            try FileManager.default.createDirectory(at: self.libraryDir, withIntermediateDirectories: true)
        } catch {
            LivelyLogger.wallpaper.error("Failed to create library directory: \(error.localizedDescription)")
        }
        
        checkLocalFiles()
    }
    
    public func checkLocalFiles() {
        for wallpaper in CuratedWallpaper.curatedList {
            let fileURL = libraryDir.appendingPathComponent("\(wallpaper.id).mp4")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                downloadStatuses[wallpaper.id] = .downloaded(localURL: fileURL)
            } else {
                if case .downloading = downloadStatuses[wallpaper.id] {
                    // Keep the current downloading status
                } else {
                    downloadStatuses[wallpaper.id] = .notDownloaded
                }
            }
        }
    }
    
    public func localURL(for wallpaper: CuratedWallpaper) -> URL? {
        let fileURL = libraryDir.appendingPathComponent("\(wallpaper.id).mp4")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }
    
    public func download(_ wallpaper: CuratedWallpaper) async {
        if case .downloaded = downloadStatuses[wallpaper.id] {
            return
        }
        if case .downloading = downloadStatuses[wallpaper.id] {
            return
        }
        
        downloadStatuses[wallpaper.id] = .downloading(progress: 0.0)
        
        let delegate = DownloadProgressDelegate { [weak self] progress in
            Task { @MainActor in
                // Only update if we are still in downloading state
                if case .downloading = self?.downloadStatuses[wallpaper.id] {
                    self?.downloadStatuses[wallpaper.id] = .downloading(progress: progress)
                }
            }
        }
        
        do {
            let (tempURL, response) = try await session.download(from: wallpaper.remoteURL, delegate: delegate)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw NSError(domain: "WallpaperLibraryManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP status code: \(statusCode)"])
            }
            
            let destinationURL = libraryDir.appendingPathComponent("\(wallpaper.id).mp4")
            
            // Remove existing file if any
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            
            downloadStatuses[wallpaper.id] = .downloaded(localURL: destinationURL)
            LivelyLogger.wallpaper.info("Successfully downloaded and saved wallpaper: \(wallpaper.id)")
        } catch {
            downloadStatuses[wallpaper.id] = .failed(error.localizedDescription)
            LivelyLogger.wallpaper.error("Failed to download wallpaper \(wallpaper.id): \(error.localizedDescription)")
        }
    }
}

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Double) -> Void
    
    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
        super.init()
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(progress)
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Required but no-op, handled by the return value of download(from:delegate:)
    }
}
