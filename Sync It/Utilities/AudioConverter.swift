//
//  AudioConverter.swift
//  Sync It
//
//  Created by Wesley Lai on 10/29/24.
//


import Foundation
import AVFoundation

class AudioConverter {
    static func convertVideoToAudio(assetManager: AssetManager) async {
        guard let videoURL = await assetManager.audioAssetURL else {
            Debug.log("No video URL available for audio conversion")
            return
        }

        Debug.log("Starting audio conversion from video URL: \(videoURL.absoluteString)")

        let asset = AVAsset(url: videoURL)
        let composition = AVMutableComposition()

        guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            Debug.log("Failed to create audio track in composition")
            return
        }

        do {
            let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first
            guard let assetAudioTrack = assetAudioTrack else {
                Debug.log("No audio track found in the video asset")
                return
            }

            let timeRange = try await asset.load(.duration)
            try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: timeRange), of: assetAudioTrack, at: .zero)

            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("converted_audio_\(UUID().uuidString).m4a")

            guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
                Debug.log("Failed to create export session")
                return
            }

            exportSession.outputURL = outputURL
            exportSession.outputFileType = .m4a
            exportSession.audioTimePitchAlgorithm = .spectral

            await exportSession.export()

            switch exportSession.status {
            case .completed:
                await MainActor.run {
                    assetManager.audioAssetURL = outputURL
                    Debug.log("Audio conversion completed. New audio URL: \(outputURL.absoluteString)")
                }
            case .failed:
                if let error = exportSession.error {
                    Debug.log("Export failed with error: \(error.localizedDescription)")
                } else {
                    Debug.log("Export failed with unknown error")
                }
            case .cancelled:
                Debug.log("Export cancelled")
            default:
                Debug.log("Export ended with status: \(exportSession.status.rawValue)")
            }
        } catch {
            Debug.log("Error during audio conversion: \(error.localizedDescription)")
        }
    }
}
