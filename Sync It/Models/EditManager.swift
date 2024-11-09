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
    
    // MARK: - Private Properties
    private var videoAsset: AVAsset?
    private var audioAsset: AVAsset?
    private var timeObserver: Any?
    private var videoDuration: CMTime = .zero
    private var audioDuration: CMTime = .zero
    
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
            
            await createInitialComposition()
            setupTimeObserver()
            
            isLoading = false
            Debug.log("EditManager initialization complete")
        } catch {
            Debug.log("Error initializing EditManager: \(error)")
            isLoading = false
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
            
            // Create audio track
            if let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                if let sourceTrack = try await audioAsset?.loadTracks(withMediaType: .audio).first {
                    try audioTrack.insertTimeRange(
                        CMTimeRange(start: .zero, duration: audioDuration),
                        of: sourceTrack,
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
        
        // Apply audio mix
        let audioMix = AVMutableAudioMix()
        var audioParams: [AVMutableAudioMixInputParameters] = []
        
        // Video audio track parameters
        if let videoAudioTrack = composition.tracks(withMediaType: .audio).first {
            let videoParams = AVMutableAudioMixInputParameters(track: videoAudioTrack)
            videoParams.setVolume(videoVolume, at: .zero)
            audioParams = [videoParams]  // Initialize array with video params
        }
        
        // Separate audio track parameters
        if let audioTrack = composition.tracks(withMediaType: .audio).last {
            let audioMixParams = AVMutableAudioMixInputParameters(track: audioTrack)
            audioMixParams.setVolume(audioVolume, at: .zero)
            audioParams.append(audioMixParams)  // Add audio params to array
        }
        
        audioMix.inputParameters = audioParams
        playerItem.audioMix = audioMix
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
    }
    
    // MARK: - Time Observer
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.01, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = CMTimeGetSeconds(time)
            }
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
