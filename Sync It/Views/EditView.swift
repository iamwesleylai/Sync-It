//
//  EditView.swift
//  Sync It
//
//  Created by Wesley Lai on 10/11/24.
//

import SwiftUI
import AVKit
import AVFoundation

struct EditView: View {
    @ObservedObject var assetManager: AssetManager
    @Binding var path: NavigationPath
    @State private var composition: AVMutableComposition?
    @State private var playerItem: AVPlayerItem?
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var videoOffset: CMTime = .zero
    @State private var audioOffset: CMTime = .zero

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading media...")
            } else if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }

                Text("Video Offset: \(CMTimeGetSeconds(videoOffset), specifier: "%.3f")s")
                Text("Audio Offset: \(CMTimeGetSeconds(audioOffset), specifier: "%.3f")s")

                HStack {
                    Button("Add Video Frame") { addVideoFrame() }
                    Button("Remove Video Frame") { removeVideoFrame() }
                }
                HStack {
                    Button("Add Audio Sample") { addAudioSample() }
                    Button("Remove Audio Sample") { removeAudioSample() }
                }

                Button("Apply Changes") { applyChanges() }
                
                Button("Go Back") {
                    Debug.log("Go Back button tapped in EditView")
                    assetManager.clearAssets()
                    path.removeLast()
                }
            } else {
                Text("Failed to load media")
            }
        }
        .onAppear {
            Debug.log("EditView appeared")
            loadComposition()
        }
    }

    private func loadComposition() {
        Debug.log("Starting to load composition")
        guard let videoURL = assetManager.videoAssetURL,
              let audioURL = assetManager.audioAssetURL else {
            Debug.log("Video or audio asset URL is nil")
            isLoading = false
            return
        }

        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            Debug.log("Failed to create composition tracks")
            isLoading = false
            return
        }

        do {
            let videoAsset = AVAsset(url: videoURL)
            let audioAsset = AVAsset(url: audioURL)
            
            // Use async/await to load duration and tracks
            Task {
                let videoDuration = try await videoAsset.load(.duration)
                let audioDuration = try await audioAsset.load(.duration)
                
                let videoAssetTrack = try await videoAsset.loadTracks(withMediaType: .video).first
                let audioAssetTrack = try await audioAsset.loadTracks(withMediaType: .audio).first
                
                guard let videoAssetTrack = videoAssetTrack, let audioAssetTrack = audioAssetTrack else {
                    Debug.log("Failed to load asset tracks")
                    isLoading = false
                    return
                }
                
                try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration),
                                               of: videoAssetTrack,
                                               at: .zero)
                
                try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: audioDuration),
                                               of: audioAssetTrack,
                                               at: .zero)
                
                await MainActor.run {
                    self.composition = composition
                    self.playerItem = AVPlayerItem(asset: composition)
                    self.player = AVPlayer(playerItem: playerItem)
                    
                    Debug.log("Composition loaded successfully")
                    isLoading = false
                }
            }
        } catch {
            Debug.log("Error creating composition: \(error.localizedDescription)")
            isLoading = false
        }
    }

    private func addVideoFrame() {
        guard let composition = composition,
              let videoTrack = composition.tracks(withMediaType: .video).first else { return }
        
        let frameDuration = CMTime(value: 1, timescale: 30) // Assuming 30 fps
        videoTrack.insertEmptyTimeRange(CMTimeRange(start: .zero, duration: frameDuration))
        videoOffset = CMTimeAdd(videoOffset, frameDuration)
        updatePlayerItem()
    }

    private func removeVideoFrame() {
        guard let composition = composition,
              let videoTrack = composition.tracks(withMediaType: .video).first else { return }
        
        let frameDuration = CMTime(value: 1, timescale: 30) // Assuming 30 fps
        videoTrack.removeTimeRange(CMTimeRange(start: .zero, duration: frameDuration))
        videoOffset = CMTimeSubtract(videoOffset, frameDuration)
        updatePlayerItem()
    }

    private func addAudioSample() {
        guard let composition = composition,
              let audioTrack = composition.tracks(withMediaType: .audio).first else { return }
        
        let sampleDuration = CMTime(value: 1, timescale: 44100) // Assuming 44.1 kHz sample rate
        audioTrack.insertEmptyTimeRange(CMTimeRange(start: .zero, duration: sampleDuration))
        audioOffset = CMTimeAdd(audioOffset, sampleDuration)
        updatePlayerItem()
    }

    private func removeAudioSample() {
        guard let composition = composition,
              let audioTrack = composition.tracks(withMediaType: .audio).first else { return }
        
        let sampleDuration = CMTime(value: 1, timescale: 44100) // Assuming 44.1 kHz sample rate
        audioTrack.removeTimeRange(CMTimeRange(start: .zero, duration: sampleDuration))
        audioOffset = CMTimeSubtract(audioOffset, sampleDuration)
        updatePlayerItem()
    }

    private func updatePlayerItem() {
        playerItem = AVPlayerItem(asset: composition!)
        player?.replaceCurrentItem(with: playerItem)
    }

    private func applyChanges() {
        // Here you would typically save the composition or export it
        Debug.log("Changes applied. Video offset: \(CMTimeGetSeconds(videoOffset))s, Audio offset: \(CMTimeGetSeconds(audioOffset))s")
    }
}
