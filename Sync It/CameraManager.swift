//
//  CameraManager.swift
//  Sync It
//
//  Created by Wesley Lai on 10/10/24.
//

import AVFoundation
import UIKit

class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var videoURL: URL?
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let audioDevice = AVCaptureDevice.default(for: .audio),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
              let captureSession = captureSession else {
            print("Failed to set up capture session")
            return
        }
        
        if captureSession.canAddInput(videoInput) && captureSession.canAddInput(audioInput) {
            captureSession.addInput(videoInput)
            captureSession.addInput(audioInput)
        }
        
        videoOutput = AVCaptureMovieFileOutput()
        if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func toggleRecording() {
        guard let videoOutput = videoOutput else { return }
        
        if !isRecording {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let videoName = "video_\(Date().timeIntervalSince1970).mov"
            let videoPath = documentsPath.appendingPathComponent(videoName)
            videoOutput.startRecording(to: videoPath, recordingDelegate: self)
        } else {
            videoOutput.stopRecording()
        }
        
        isRecording.toggle()
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
            return
        }
        
        DispatchQueue.main.async {
            self.videoURL = outputFileURL
            print("Video recorded successfully: \(outputFileURL.path)")
        }
    }
}
