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
    @State private var showVideoPlayer = false
    
    var body: some View {
        ZStack {
            CameraPreviewView(session: cameraManager.captureSession)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                if showVideoPlayer {
                    VideoPlayerView(videoURL: cameraManager.videoURL)
                        .frame(height: 300)
                }
                
                RecordButton(isRecording: cameraManager.isRecording) {
                    cameraManager.toggleRecording()
                    if !cameraManager.isRecording {
                        showVideoPlayer = true
                    }
                }
                .padding(.bottom, 20)
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

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        if let session = session {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
