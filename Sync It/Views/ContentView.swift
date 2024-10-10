//
//  ContentView.swift
//  Sync It
//
//  Created by Wesley Lai on 10/10/24.
//

// ContentView.swift
import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        VStack {
            VideoPlayerView(videoURL: cameraManager.videoURL)
                .frame(height: 300)
            
            RecordButton(isRecording: cameraManager.isRecording) {
                cameraManager.toggleRecording()
            }
        }
        .onAppear {
            PermissionHelper.requestCameraPermission()
        }
    }
}

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        Button(isRecording ? "Stop Recording" : "Start Recording", action: action)
            .padding()
            .background(isRecording ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
    }
}
