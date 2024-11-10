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
        HStack(spacing: 0) {
            // Main content (video and timeline)
            VStack {
                if editManager.isLoading {
                    ProgressView("Loading media...")
                } else {
                    // Video Player
                    VideoPlayer(player: editManager.player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .onAppear { editManager.player?.play() }
                        .onDisappear { editManager.player?.pause() }
                    
                    // Enhanced Timeline
                    EnhancedTimelineView(
                        currentTime: editManager.currentTime,
                        totalDuration: editManager.totalDuration,
                        videoOffset: editManager.videoOffset,
                        audioOffset: editManager.audioOffset
                    )
                    .frame(height: 120)
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
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            
            // Side panel for specific mode
            if showSpecificMode {
                VStack {
                    Text("Fine-Tune Sync")
                        .font(.headline)
                        .padding(.top)
                    
                    EnhancedDelayControlsView(editManager: editManager)
                        .padding()
                    
                    Spacer()
                }
                .frame(width: 300)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(width: 1)
                        .foregroundColor(Color.gray.opacity(0.3)),
                    alignment: .leading
                )
            }
        }
        .overlay(
            HStack {
                Button(action: { showSpecificMode.toggle() }) {
                    Label(showSpecificMode ? "Hide Controls" : "Show Controls",
                          systemImage: showSpecificMode ? "chevron.right.circle.fill" : "chevron.left.circle.fill")
                }
                .padding(8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                
                Spacer()
                
                Button("Go Back") {
                    Debug.log("Go Back button tapped in EditView")
                    assetManager.clearAssets()
                    path.removeLast()
                }
            }
            .padding(),
            alignment: .topTrailing
        )
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

struct EnhancedTimelineView: View {
    let currentTime: Double
    let totalDuration: Double
    let videoOffset: Double
    let audioOffset: Double
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                // Video Timeline
                TimelineTrack(
                    label: "Video",
                    color: .purple,
                    currentTime: currentTime,
                    totalDuration: totalDuration,
                    offset: videoOffset,
                    width: geometry.size.width
                )
                
                // Audio Timeline
                TimelineTrack(
                    label: "Audio",
                    color: .green,
                    currentTime: currentTime,
                    totalDuration: totalDuration,
                    offset: audioOffset,
                    width: geometry.size.width
                )
                
                // Time markers
                TimeMarkers(width: geometry.size.width, duration: totalDuration)
            }
        }
    }
}

struct TimelineTrack: View {
    let label: String
    let color: Color
    let currentTime: Double
    let totalDuration: Double
    let offset: Double
    let width: CGFloat
    
    // Add scroll position state
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 8) {
            // Label remains fixed
            Text(label)
                .frame(width: 50, alignment: .trailing)
                .font(.caption)
            
            // Timeline container
            ZStack(alignment: .leading) {
                // Background remains fixed
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 24)
                
                // Scrollable content
                ScrollView(.horizontal, showsIndicators: true) {
                    ZStack(alignment: .leading) {
                        // Waveform container with extra width for scrolling
                        Color.clear
                            .frame(width: max(width * 2, width - 58))
                            .frame(height: 24)
                        
                        // Waveform representation
                        WaveformView(color: color)
                            .frame(height: 24)
                            .frame(width: max(width * 2, width - 58))
                            .offset(x: width * CGFloat(offset / max(totalDuration, 1)))
                    }
                }
                .coordinateSpace(name: "scroll")
                .overlay(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: proxy.frame(in: .named("scroll")).origin.x
                        )
                    }
                )
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
                
                // Current time indicator (fixed position)
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: 24)
                    .offset(x: width * CGFloat(currentTime / max(totalDuration, 1)))
            }
        }
    }
}

// Preference key to track scroll position
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Update WaveformView to support longer durations
struct WaveformView: View {
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2
                
                // Create a more detailed waveform pattern
                stride(from: 0, to: width, by: 3).forEach { x in
                    let amplitude = Double.random(in: 0.2...0.8)
                    let y = midHeight - (CGFloat(amplitude) * midHeight)
                    path.move(to: CGPoint(x: x, y: midHeight + y))
                    path.addLine(to: CGPoint(x: x, y: midHeight - y))
                }
            }
            .stroke(color.opacity(0.5), lineWidth: 2)
        }
    }
}

// Update TimeMarkers to support scrolling
struct TimeMarkers: View {
    let width: CGFloat
    let duration: Double
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(0...8, id: \.self) { i in
                    Text(timeString(for: duration * Double(i) / 8))
                        .font(.caption2)
                        .frame(width: width / 8)
                }
            }
            .frame(width: max(width * 2, width))
        }
    }
    
    private func timeString(for seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VolumeControlsView: View {
    @Binding var videoVolume: Double
    @Binding var audioVolume: Double
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Video Volume")
                    .font(.subheadline)
                
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(videoVolume == 0 ? .gray : .purple)
                    
                    Slider(value: $videoVolume, in: 0...1)
                        .tint(.purple)
                    
                    Text("\(Int(videoVolume * 100))%")
                        .monospacedDigit()
                        .frame(width: 50)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Volume")
                    .font(.subheadline)
                
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(audioVolume == 0 ? .gray : .green)
                    
                    Slider(value: $audioVolume, in: 0...1)
                        .tint(.green)
                    
                    Text("\(Int(audioVolume * 100))%")
                        .monospacedDigit()
                        .frame(width: 50)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct EnhancedDelayControlsView: View {
    @ObservedObject var editManager: EditManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Video Sync")
                    .font(.headline)
                
                DelayControl(
                    label: "Fine",
                    value: editManager.videoOffset,
                    onIncrement: { editManager.adjustDelay(type: "1ms", increment: true, mediaType: "video") },
                    onDecrement: { editManager.adjustDelay(type: "1ms", increment: false, mediaType: "video") }
                )
                
                DelayControl(
                    label: "Medium",
                    value: editManager.videoOffset,
                    onIncrement: { editManager.adjustDelay(type: "10ms", increment: true, mediaType: "video") },
                    onDecrement: { editManager.adjustDelay(type: "10ms", increment: false, mediaType: "video") }
                )
                
                DelayControl(
                    label: "Coarse",
                    value: editManager.videoOffset,
                    onIncrement: { editManager.adjustDelay(type: "100ms", increment: true, mediaType: "video") },
                    onDecrement: { editManager.adjustDelay(type: "100ms", increment: false, mediaType: "video") }
                )
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Audio Sync")
                    .font(.headline)
                
                DelayControl(
                    label: "Fine",
                    value: editManager.audioOffset,
                    onIncrement: { editManager.adjustDelay(type: "1ms", increment: true, mediaType: "audio") },
                    onDecrement: { editManager.adjustDelay(type: "1ms", increment: false, mediaType: "audio") }
                )
                
                DelayControl(
                    label: "Medium",
                    value: editManager.audioOffset,
                    onIncrement: { editManager.adjustDelay(type: "10ms", increment: true, mediaType: "audio") },
                    onDecrement: { editManager.adjustDelay(type: "10ms", increment: false, mediaType: "audio") }
                )
                
                DelayControl(
                    label: "Coarse",
                    value: editManager.audioOffset,
                    onIncrement: { editManager.adjustDelay(type: "100ms", increment: true, mediaType: "audio") },
                    onDecrement: { editManager.adjustDelay(type: "100ms", increment: false, mediaType: "audio") }
                )
            }
        }
    }
}

struct DelayControl: View {
    let label: String
    let value: Double
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 60, alignment: .leading)
            
            Button(action: onDecrement) {
                Image(systemName: "minus.circle.fill")
                    .imageScale(.large)
            }
            
            Text(String(format: "%.3f", value))
                .monospacedDigit()
                .frame(width: 80)
            
            Button(action: onIncrement) {
                Image(systemName: "plus.circle.fill")
                    .imageScale(.large)
            }
        }
    }
}

//
//struct WaveformView: View {
//    let color: Color
//    
//    var body: some View {
//        GeometryReader { geometry in
//            Path { path in
//                let width = geometry.size.width
//                let height = geometry.size.height
//                let midHeight = height / 2
//                
//                // Create a simple waveform pattern
//                stride(from: 0, to: width, by: 3).forEach { x in
//                    let amplitude = Double.random(in: 0.2...0.8)
//                    let y = midHeight - (CGFloat(amplitude) * midHeight)
//                    path.move(to: CGPoint(x: x, y: midHeight + y))
//                    path.addLine(to: CGPoint(x: x, y: midHeight - y))
//                }
//            }
//            .stroke(color.opacity(0.5), lineWidth: 2)
//        }
//    }
//}
//
//struct TimeMarkers: View {
//    let width: CGFloat
//    let duration: Double
//    
//    var body: some View {
//        HStack(spacing: 0) {
//            ForEach(0...4, id: \.self) { i in
//                Text(timeString(for: duration * Double(i) / 4))
//                    .font(.caption2)
//                    .frame(width: width / 4)
//            }
//        }
//    }
//    
//    private func timeString(for seconds: Double) -> String {
//        let minutes = Int(seconds) / 60
//        let seconds = Int(seconds) % 60
//        return String(format: "%d:%02d", minutes, seconds)
//    }
//}
