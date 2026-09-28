import Testing
@testable import LivelyCore
import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

/// Exercises the real AVFoundation validation path with tiny generated clips.
struct VideoValidatorTests {

    // MARK: - Pure codec decision

    @Test func acceptsH264AndHEVC() {
        #expect(VideoValidator.evaluate(codecs: [kCMVideoCodecType_H264]) == .valid)
        #expect(VideoValidator.evaluate(codecs: [kCMVideoCodecType_HEVC]) == .valid)
        #expect(VideoValidator.evaluate(codecs: [kCMVideoCodecType_H264, kCMVideoCodecType_HEVC]) == .valid)
    }

    @Test func rejectsOtherCodecsAndEmptyTrackList() {
        let unsupported: [FourCharCode] = [
            kCMVideoCodecType_AppleProRes422,
            kCMVideoCodecType_JPEG,
            kCMVideoCodecType_VP9,
            kCMVideoCodecType_AV1,
        ]
        for codec in unsupported {
            #expect(VideoValidator.evaluate(codecs: [codec]) == .invalid(VideoValidator.unsupportedCodecMessage))
        }
        // Mixed: one bad track poisons the file.
        #expect(VideoValidator.evaluate(codecs: [kCMVideoCodecType_H264, kCMVideoCodecType_JPEG]) != .valid)
        #expect(VideoValidator.evaluate(codecs: []) != .valid)
    }

    // MARK: - Real files

    @Test func acceptsGeneratedH264Clip() async throws {
        let url = try await Self.writeClip(codec: .h264, ext: "mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(await VideoValidator.validate(url) == .valid)
    }

    @Test func rejectsGeneratedMotionJPEGClipWithClearError() async throws {
        let url = try await Self.writeClip(codec: .jpeg, ext: "mov")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(await VideoValidator.validate(url) == .invalid(VideoValidator.unsupportedCodecMessage))
    }

    @Test func rejectsTruncatedFile() async throws {
        let url = try await Self.writeClip(codec: .h264, ext: "mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        try data.prefix(data.count / 3).write(to: url)
        #expect(await VideoValidator.validate(url) != .valid)
    }

    @Test func rejectsGarbageAndEmptyFiles() async throws {
        let garbage = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try Data((0..<4096).map { _ in UInt8.random(in: 0...255) }).write(to: garbage)
        defer { try? FileManager.default.removeItem(at: garbage) }
        #expect(await VideoValidator.validate(garbage) != .valid)

        let empty = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        try Data().write(to: empty)
        defer { try? FileManager.default.removeItem(at: empty) }
        #expect(await VideoValidator.validate(empty) != .valid)
    }

    @Test func rejectsMissingFileAndWrongExtension() async {
        let missing = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).mp4")
        #expect(await VideoValidator.validate(missing) == .invalid(VideoValidator.missingFileMessage))
        #expect(await VideoValidator.validate(URL(fileURLWithPath: "/tmp/x.webm"))
                == .invalid(VideoValidator.unsupportedFormatMessage))
    }

    // MARK: - Helpers

    /// Writes a 4-frame 64×64 clip with the given codec.
    static func writeClip(codec: AVVideoCodecType, ext: String) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lively-\(UUID().uuidString).\(ext)")
        let fileType: AVFileType = ext == "mov" ? .mov : .mp4
        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: 64,
            AVVideoHeightKey: 64,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 64,
            kCVPixelBufferHeightKey as String: 64,
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<4 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &buffer)
            guard let buffer else { throw CocoaError(.fileWriteUnknown) }
            CVPixelBufferLockBaseAddress(buffer, [])
            memset(CVPixelBufferGetBaseAddress(buffer), Int32(frame * 60), CVPixelBufferGetDataSize(buffer))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 10))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        return url
    }
}
