//
//  EditManager.swift
//  Sync It
//
//  Created by Wesley Lai on 11/09/24.
//
import Foundation
import AVFoundation
import Combine

@MainActor
class EditManager: ObservableObject {
    // MARK: - Published Properties
    @Published var videoOffset: Double = 0.0  // in seconds
    @Published var audioOffset: Double = 0.0  // in seconds
    @Published var videoVolume: Float = 1.0
    @Published var audioVolume: Float = 1.0
    @Published var composition: AVMutableComposition?
    @Published var player: AVPlayer?
    @Published var isLoading = true
    @Published var totalDuration: Double = 0.0
    @Published var currentTime: Double = 0.0
    @Published var scrollOffset: Double = 0.0  // Shared scroll offset for both waveforms
    @Published var visibleTimeRange: ClosedRange<Double> = 0...10  // Visible time range in the UI
    
    // MARK: - Private Properties
    private var videoAsset: AVAsset?
    private var audioAsset: AVAsset?
    private var timeObserver: Any?
    private var videoDuration: CMTime = .zero
    private var audioDuration: CMTime = .zero
    private let scrollUpdateSubject = PassthroughSubject<Double, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    func initialize(videoURL: URL, audioURL: URL) async {
        Debug.log("Initializing EditManager with video: \(videoURL) and audio: \(audioURL)")
        
        do {
            // Load assets
            videoAsset = AVAsset(url: videoURL)
            audioAsset = AVAsset(url: audioURL)
            
            // Load durations
            videoDuration = try await videoAsset?.load(.duration) ?? .zero
            audioDuration = try await audioAsset?.load(.duration) ?? .zero
            
            // Calculate total duration
            totalDuration = max(
                CMTimeGetSeconds(videoDuration),
                CMTimeGetSeconds(audioDuration)
            )
            
            // Initialize visible time range
            visibleTimeRange = 0...min(10, totalDuration)
            
            setupScrollSynchronization()
            await createInitialComposition()
            setupTimeObserver()
            
            isLoading = false
            Debug.log("EditManager initialization complete")
        } catch {
            Debug.log("Error initializing EditManager: \(error)")
            isLoading = false
        }
    }
    
    // MARK: - Scroll Synchronization
    private func setupScrollSynchronization() {
        scrollUpdateSubject
            .debounce(for: .milliseconds(16), scheduler: DispatchQueue.main)
            .sink { [weak self] newOffset in
                self?.updateVisibleTimeRange(scrollOffset: newOffset)
            }
            .store(in: &cancellables)
    }
    
    func updateScroll(offset: Double) {
        scrollOffset = max(0, min(offset, totalDuration))
        scrollUpdateSubject.send(scrollOffset)
    }
    
    private func updateVisibleTimeRange(scrollOffset: Double) {
        let visibleDuration = 10.0 // Amount of time visible in the window
        let start = max(0, scrollOffset)
        let end = min(totalDuration, start + visibleDuration)
        visibleTimeRange = start...end
    }
    
    // MARK: - Time Observer
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.01, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                let newTime = CMTimeGetSeconds(time)
                self.currentTime = newTime
                
                // Auto-scroll if playhead moves outside visible range
                if !self.visibleTimeRange.contains(newTime) {
                    self.updateScroll(offset: newTime - 5) // Center playhead in visible range
                }
            }
        }
    }
    
    // MARK: - Timeline Management
    func getEffectiveTime(forMediaTime time: Double, isVideo: Bool) -> Double {
        // Adjust time based on media type and offset
        let offset = isVideo ? videoOffset : audioOffset
        return time + offset
    }
    
    func getVisibleWaveformRange(isVideo: Bool) -> ClosedRange<Double> {
        // Adjust visible range based on media offset
        let offset = isVideo ? videoOffset : audioOffset
        return (visibleTimeRange.lowerBound - offset)...(visibleTimeRange.upperBound - offset)
    }
    
    // MARK: - Composition Management
    private func createInitialComposition() async {
            Debug.log("Creating initial composition")
            let composition = AVMutableComposition()
            
            do {
                // Create video track
                if let videoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) {
                    if let sourceTrack = try await videoAsset?.loadTracks(withMediaType: .video).first {
                        try videoTrack.insertTimeRange(
                            CMTimeRange(start: .zero, duration: videoDuration),
                            of: sourceTrack,
                            at: .zero
                        )
                    }
                }
                
                // Create video's audio track
                if let videoAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) {
                    if let sourceVideoAudioTrack = try await videoAsset?.loadTracks(withMediaType: .audio).first {
                        try videoAudioTrack.insertTimeRange(
                            CMTimeRange(start: .zero, duration: videoDuration),
                            of: sourceVideoAudioTrack,
                            at: .zero
                        )
                    }
                }
                
                // Create separate audio track
                if let separateAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) {
                    if let sourceAudioTrack = try await audioAsset?.loadTracks(withMediaType: .audio).first {
                        try separateAudioTrack.insertTimeRange(
                            CMTimeRange(start: .zero, duration: audioDuration),
                            of: sourceAudioTrack,
                            at: .zero
                        )
                    }
                }
                
                self.composition = composition
                updatePlayerItem()
                
            } catch {
                Debug.log("Error creating composition: \(error)")
            }
        }
        
    private func updatePlayerItem() {
        guard let composition = composition else { return }
        
        let playerItem = AVPlayerItem(asset: composition)
        
        // Create audio mix
        let audioMix = AVMutableAudioMix()
        var audioParams: [AVMutableAudioMixInputParameters] = []
        
        // Set up parameters for video's audio track
        if let videoAudioTrack = composition.tracks(withMediaType: .audio).first {
            Debug.log("Setting up video audio track with volume: \(videoVolume)")
            let videoParams = AVMutableAudioMixInputParameters(track: videoAudioTrack)
            videoParams.setVolume(videoVolume, at: .zero)
            audioParams.append(videoParams)
        }
        
        // Set up parameters for separate audio track
        if let separateAudioTrack = composition.tracks(withMediaType: .audio).last {
            Debug.log("Setting up separate audio track with volume: \(audioVolume)")
            let audioMixParams = AVMutableAudioMixInputParameters(track: separateAudioTrack)
            audioMixParams.setVolume(audioVolume, at: .zero)
            audioParams.append(audioMixParams)  // Fixed: Append to the array, not to the parameters
        }
        
        audioMix.inputParameters = audioParams
        playerItem.audioMix = audioMix
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
    }
    
    // MARK: - Offset Management
    func adjustDelay(type: String, increment: Bool, mediaType: String) {
        let increment = increment ? 1.0 : -1.0
        var delay: Double
        
        switch type {
        case "1ms":
            delay = 0.001
        case "10ms":
            delay = 0.01
        case "100ms":
            delay = 0.1
        case "1s":
            delay = 1.0
        default:
            return
        }
        
        if mediaType == "video" {
            let newOffset = videoOffset + (delay * increment)
            if newOffset >= 0 && newOffset <= totalDuration {
                videoOffset = newOffset
                updateTimeOffsets()
            }
        } else {
            let newOffset = audioOffset + (delay * increment)
            if newOffset >= 0 && newOffset <= totalDuration {
                audioOffset = newOffset
                updateTimeOffsets()
            }
        }
    }
    
    private func updateTimeOffsets() {
        Task {
            await createInitialComposition()
            // Apply video offset
            if let videoTrack = composition?.tracks(withMediaType: .video).first {
                let timeRange = videoTrack.timeRange
                try? videoTrack.insertTimeRange(
                    timeRange,
                    of: videoTrack,
                    at: CMTime(seconds: videoOffset, preferredTimescale: 600)
                )
            }
            
            // Apply audio offset
            if let audioTrack = composition?.tracks(withMediaType: .audio).first {
                let timeRange = audioTrack.timeRange
                try? audioTrack.insertTimeRange(
                    timeRange,
                    of: audioTrack,
                    at: CMTime(seconds: audioOffset, preferredTimescale: 600)
                )
            }
            
            updatePlayerItem()
        }
    }
    
    // MARK: - Volume Management
    func updateVolume(value: Float, isVideo: Bool) {
        if isVideo {
            videoVolume = value
        } else {
            audioVolume = value
        }
        updatePlayerItem()
    }
    
    // MARK: - Cleanup
    nonisolated func cleanup() {
        Task { @MainActor in
            if let timeObserver = timeObserver {
                player?.removeTimeObserver(timeObserver)
            }
        }
    }
    
    deinit {
        cleanup()
    }
}
