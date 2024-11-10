//
//  EditManager.swift
//  Sync It
//
//  Created by Wesley Lai on 11/09/24.
//
//
// EditManager.swift
import Foundation
import AVFoundation
import Combine

@MainActor
class EditManager: ObservableObject {
    // MARK: - Published Properties
    @Published var audioOffset: Double = 0.0  // in seconds
    @Published var videoVolume: Float = 1.0
    @Published var audioVolume: Float = 1.0
    @Published var composition: AVMutableComposition?
    @Published var player: AVPlayer?
    @Published var isLoading = true
    @Published var totalDuration: Double = 0.0
    @Published var currentTime: Double = 0.0
    @Published var scrollOffset: Double = 0.0
    @Published var visibleTimeRange: ClosedRange<Double> = 0...10
    
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
    
    // MARK: - Audio Offset Management
    func adjustAudioOffset(by delta: Double) {
        let newOffset = audioOffset + delta
        // Ensure offset stays within valid bounds
        if newOffset >= 0 && newOffset <= totalDuration {
            audioOffset = newOffset
            updateAudioPlayback()
        }
    }
    
    private func updateAudioPlayback() {
        Task {
            await createInitialComposition()
        }
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
            
            // Create separate audio track with offset
            if let separateAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                if let sourceAudioTrack = try await audioAsset?.loadTracks(withMediaType: .audio).first {
                    let offsetTime = CMTime(seconds: audioOffset, preferredTimescale: 600)
                    try separateAudioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: audioDuration),
                        of: sourceAudioTrack,
                        at: offsetTime
                    )
                }
            }
            
            self.composition = composition
            updatePlayerItem()
            
        } catch {
            Debug.log("Error creating composition: \(error)")
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
        let visibleDuration = 10.0
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
                
                if !self.visibleTimeRange.contains(newTime) {
                    self.updateScroll(offset: newTime - 5)
                }
            }
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
    
    private func updatePlayerItem() {
        guard let composition = composition else { return }
        
        let playerItem = AVPlayerItem(asset: composition)
        
        // Create audio mix
        let audioMix = AVMutableAudioMix()
        var audioParams: [AVMutableAudioMixInputParameters] = []
        
        // Set up parameters for video's audio track
        if let videoAudioTrack = composition.tracks(withMediaType: .audio).first {
            let videoParams = AVMutableAudioMixInputParameters(track: videoAudioTrack)
            videoParams.setVolume(videoVolume, at: .zero)
            audioParams.append(videoParams)
        }
        
        // Set up parameters for separate audio track
        if let separateAudioTrack = composition.tracks(withMediaType: .audio).last {
            let audioMixParams = AVMutableAudioMixInputParameters(track: separateAudioTrack)
            audioMixParams.setVolume(audioVolume, at: .zero)
            audioParams.append(audioMixParams)
        }
        
        audioMix.inputParameters = audioParams
        playerItem.audioMix = audioMix
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
    }
    
    // MARK: - Timeline Management
    func getEffectiveTime(forMediaTime time: Double, isVideo: Bool) -> Double {
        return isVideo ? time : time + audioOffset
    }
    
    func getVisibleWaveformRange(isVideo: Bool) -> ClosedRange<Double> {
        return isVideo ? visibleTimeRange : (visibleTimeRange.lowerBound - audioOffset)...(visibleTimeRange.upperBound - audioOffset)
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
