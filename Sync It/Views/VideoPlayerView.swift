//
//  VideoPlayerView.swift
//  Sync It
//
//  Created by Wesley Lai on 10/10/24.
//
import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoURL: URL?
    @State private var player: AVPlayer?
    
    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                Text("No video recorded")
            }
        }
        .onChange(of: videoURL) { newURL in
            if let url = newURL {
                player = AVPlayer(url: url)
            }
        }
    }
}
