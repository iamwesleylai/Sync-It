//
//  EditView.swift
//  Sync It
//
//  Created by Wesley Lai on 10/11/24.
//

import SwiftUI
import AVKit

struct EditView: View {
    @ObservedObject var assetManager: AssetManager
    @Binding var path: NavigationPath
    @State private var player: AVPlayer?
    
    var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
                .aspectRatio(16/9, contentMode: .fit)
                .onAppear {
                    player.play()
                }
                .onDisappear {
                    player.pause()
                }
            } else {
                Text("Loading video...")
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
            self.player = AVPlayer(url: videoURL)
            Debug.log("Player initialized with URL: \(videoURL)")
        }
    }
}
