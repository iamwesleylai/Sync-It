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
    @StateObject private var editManager = EditManager()
    @Binding var path: NavigationPath
    @State private var showSpecificMode = false
    @State private var isPlaying = false
    
    var body: some View {
        VStack {
            if editManager.isLoading {
                ProgressView("Loading media...")
            } else {
                // Video Player
                VideoPlayer(player: editManager.player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .onAppear { editManager.player?.play() }
                    .onDisappear { editManager.player?.pause() }
                
                // Timeline Visualization
                TimelineVisualization(
                    currentTime: editManager.currentTime,
                    totalDuration: editManager.totalDuration,
                    videoOffset: editManager.videoOffset,
                    audioOffset: editManager.audioOffset
                )
                .frame(height: 100)
                .padding()
                
                // Volume Controls
                VolumeControlsView(
                    videoVolume: Binding(
                        get: { Double(editManager.videoVolume) },
                        set: { editManager.updateVolume(value: Float($0), isVideo: true) }
                    ),
                    audioVolume: Binding(
                        get: { Double(editManager.audioVolume) },
                        set: { editManager.updateVolume(value: Float($0), isVideo: false) }
                    )
                )
                .padding()
                
                // Specific Mode Toggle
                DisclosureGroup("Specific Mode", isExpanded: $showSpecificMode) {
                    DelayControlsView(editManager: editManager)
                        .padding()
                }
                .padding()
                
                Button("Go Back") {
                    Debug.log("Go Back button tapped in EditView")
                    assetManager.clearAssets()
                    path.removeLast()
                }
                .padding()
            }
        }
        .onAppear {
            Debug.log("EditView appeared")
            Task {
                guard let videoURL = assetManager.videoAssetURL,
                      let audioURL = assetManager.audioAssetURL else {
                    return
                }
                await editManager.initialize(videoURL: videoURL, audioURL: audioURL)
            }
        }
    }
}

struct TimelineVisualization: View {
    let currentTime: Double
    let totalDuration: Double
    let videoOffset: Double
    let audioOffset: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Video Timeline
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.purple.opacity(0.5))
                    .frame(
                        width: geometry.size.width * CGFloat(totalDuration / max(totalDuration, 1)),
                        height: 30
                    )
                    .offset(x: geometry.size.width * CGFloat(videoOffset / max(totalDuration, 1)))
                
                // Audio Timeline
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green.opacity(0.5))
                    .frame(
                        width: geometry.size.width * CGFloat(totalDuration / max(totalDuration, 1)),
                        height: 30
                    )
                    .offset(x: geometry.size.width * CGFloat(audioOffset / max(totalDuration, 1)))
                
                // Playhead
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: 30)
                    .offset(x: geometry.size.width * CGFloat(currentTime / max(totalDuration, 1)))
            }
        }
    }
}

struct VolumeControlsView: View {
    @Binding var videoVolume: Double
    @Binding var audioVolume: Double
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Video Volume")
                Slider(value: $videoVolume, in: 0...1)
                Text("\(Int(videoVolume * 100))%")
            }
            
            HStack {
                Text("Audio Volume")
                Slider(value: $audioVolume, in: 0...1)
                Text("\(Int(audioVolume * 100))%")
            }
        }
    }
}

struct DelayControlsView: View {
    @ObservedObject var editManager: EditManager
    
    var body: some View {
        VStack(spacing: 20) {
            DelayButtonGroup(title: "Video Delay", mediaType: "video", editManager: editManager)
            DelayButtonGroup(title: "Audio Delay", mediaType: "audio", editManager: editManager)
        }
    }
}

struct DelayButtonGroup: View {
    let title: String
    let mediaType: String
    @ObservedObject var editManager: EditManager
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            
            HStack {
                ForEach(["1ms", "10ms", "100ms", "1s"], id: \.self) { delay in
                    HStack {
                        Button("-\(delay)") {
                            editManager.adjustDelay(type: delay, increment: false, mediaType: mediaType)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("+\(delay)") {
                            editManager.adjustDelay(type: delay, increment: true, mediaType: mediaType)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}
