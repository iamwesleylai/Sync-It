//
//  ContentView.swift
//  Sync It
//
//  Created by Wesley Lai on 10/10/24.
//

// ContentView.swift
import SwiftUI
import AVFoundation
import AVKit

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var player: AVPlayer?
    
    var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 300)
            } else {
                Text("No video recorded")
            }
            
            Button(cameraManager.isRecording ? "Stop Recording" : "Start Recording") {
                cameraManager.toggleRecording()
            }
            .padding()
            .background(cameraManager.isRecording ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .onAppear {
            requestCameraPermission()
        }
        .onChange(of: cameraManager.videoURL) { newURL in
            if let url = newURL {
                player = AVPlayer(url: url)
            }
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                print("Camera permission granted")
            } else {
                print("Camera permission denied")
            }
        }
    }
}
