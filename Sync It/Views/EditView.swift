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
    @State private var videoPlayer: AVPlayer?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isLoading = true
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading media...")
            } else if let videoPlayer = videoPlayer {
                VideoPlayer(player: videoPlayer)
                    .aspectRatio(16/9, contentMode: .fit)
                    .onAppear {
                        videoPlayer.play()
                        audioPlayer?.play()
                    }
                    .onDisappear {
                        videoPlayer.pause()
                        audioPlayer?.pause()
                    }
            } else {
                Text("Failed to load media")
            }
            
            Button("Go Back") {
                Debug.log("Go Back button tapped in EditView")
                assetManager.clearAssets()
                path.removeLast()
            }
            .padding()
        }
        .onAppear {
            Debug.log("EditView appeared")
            loadVideo()
            loadAudio()
        }
    }
    
    private func loadVideo() {
        Debug.log("Starting to load video")
        Debug.log("VideoAssetURL: \(assetManager.videoAssetURL?.absoluteString ?? "nil")")
        
        guard let videoURL = assetManager.videoAssetURL else {
            Debug.log("Video asset URL is nil")
            return
        }
        
        DispatchQueue.main.async {
            self.videoPlayer = AVPlayer(url: videoURL)
            Debug.log("Video player initialized with URL: \(videoURL)")
            self.isLoading = false
        }
    }
    
    private func loadAudio() {
        Debug.log("Starting to load audio")
        Debug.log("AudioAssetURL: \(assetManager.audioAssetURL?.absoluteString ?? "nil")")
        
        guard let audioURL = assetManager.audioAssetURL else {
            Debug.log("Audio asset URL is nil")
            return
        }
        
        do {
            self.audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            Debug.log("Audio player initialized with URL: \(audioURL)")
        } catch {
            Debug.log("Error initializing audio player: \(error.localizedDescription)")
        }
    }
}
