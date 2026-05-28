import AVFoundation
import CoreMedia
import Flutter
import UIKit

/// Flutter method channel plugin that decodes a compressed audio file (MP3, AAC,
/// M4A…) to raw PCM-16 LE mono at 16 kHz using AVAssetReader — the iOS
/// equivalent of AudioDecoderPlugin.kt on Android.
///
/// Channel: com.inouiw.audesiq/audio_decoder
/// Method:  decodeToPcm(inputPath: String, outputPath: String) → void
///
/// AVAssetReaderTrackOutput with the output-settings dictionary handles all of:
///   • Compressed-format decoding  (MP3 / AAC / ALAC / …)
///   • Channel downmix             (stereo → mono)
///   • Sample-rate conversion      (native rate → 16 kHz)
///   • PCM format change           (float → Int16 LE)
class AudioDecoderPlugin: NSObject, FlutterPlugin {

    // MARK: - FlutterPlugin

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.inouiw.audesiq/audio_decoder",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(AudioDecoderPlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "decodeToPcm" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard
            let args = call.arguments as? [String: Any],
            let inputPath  = args["inputPath"]  as? String,
            let outputPath = args["outputPath"] as? String
        else {
            result(FlutterError(
                code: "ARG_ERROR",
                message: "inputPath and outputPath are required",
                details: nil
            ))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try AudioDecoderPlugin.decodeToPcm16(
                    inputPath: inputPath,
                    outputPath: outputPath
                )
                DispatchQueue.main.async { result(nil) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "DECODE_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }

    // MARK: - Decoder

    private static func decodeToPcm16(inputPath: String, outputPath: String) throws {
        guard FileManager.default.fileExists(atPath: inputPath) else {
            throw NSError(
                domain: "AudioDecoder", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "File not found: \(inputPath)"]
            )
        }

        let asset = AVURLAsset(url: URL(fileURLWithPath: inputPath))
        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw NSError(
                domain: "AudioDecoder", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No audio track in: \(inputPath)"]
            )
        }

        // Request 16 kHz / mono / PCM-16 LE output.
        // AVAssetReader performs decompression + resampling + downmix automatically.
        let outputSettings: [String: Any] = [
            AVFormatIDKey:               kAudioFormatLinearPCM,
            AVSampleRateKey:             16_000.0,
            AVNumberOfChannelsKey:       1,
            AVLinearPCMBitDepthKey:      16,
            AVLinearPCMIsFloatKey:       false,
            AVLinearPCMIsBigEndianKey:   false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let reader = try AVAssetReader(asset: asset)
        let trackOutput = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: outputSettings
        )
        trackOutput.alwaysCopiesSampleData = false
        reader.add(trackOutput)

        guard reader.startReading() else {
            throw reader.error ?? NSError(
                domain: "AudioDecoder", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not start AVAssetReader"]
            )
        }

        // Prepare the output file (truncate if it already exists).
        let fm = FileManager.default
        if fm.fileExists(atPath: outputPath) {
            try fm.removeItem(atPath: outputPath)
        }
        fm.createFile(atPath: outputPath, contents: nil)
        let outHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: outputPath))
        defer { outHandle.closeFile() }

        // Drain all PCM-16 LE sample buffers and write bytes directly.
        while let sampleBuf = trackOutput.copyNextSampleBuffer() {
            guard let blockBuf = CMSampleBufferGetDataBuffer(sampleBuf) else { continue }
            let length = CMBlockBufferGetDataLength(blockBuf)
            var rawData = Data(count: length)
            rawData.withUnsafeMutableBytes { ptr in
                _ = CMBlockBufferCopyDataBytes(
                    blockBuf,
                    atOffset: 0,
                    dataLength: length,
                    destination: ptr.baseAddress!
                )
            }
            outHandle.write(rawData)
        }

        guard reader.status != .failed else {
            throw reader.error ?? NSError(
                domain: "AudioDecoder", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "AVAssetReader failed"]
            )
        }
    }
}
