//
//  ImportMediaView.swift
//  Sync It
//
//  Created by Wesley Lai on 10/11/24.
//
import SwiftUI
import PhotosUI

struct ImportMediaView: View {
    @ObservedObject var assetManager: AssetManager
    @Binding var path: NavigationPath
    @State private var isImportingVideo = false
    @State private var isImportingAudio = false
    @State private var showReminder = false
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 20) {
            Button(assetManager.videoAsset == nil ? "Import Video" : "Change Video") {
                Debug.log("Video import button tapped")
                isImportingVideo = true
            }
            .photosPicker(isPresented: $isImportingVideo, selection: $assetManager.videoAsset, matching: .videos)
            .padding()
            .background(assetManager.videoAsset == nil ? Color.blue : Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button(assetManager.audioAsset == nil ? "Import Audio from Video" : "Change Audio") {
                Debug.log("Audio import button tapped")
                isImportingAudio = true
            }
            .photosPicker(isPresented: $isImportingAudio, selection: $assetManager.audioAsset, matching: .videos)
            .padding()
            .background(assetManager.audioAsset == nil ? Color.blue : Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button("Click To Process") {
                Debug.log("Process button tapped")
                if assetManager.videoAsset != nil && assetManager.audioAsset != nil {
                    isProcessing = true
                    Task {
                        await assetManager.processSelectedItems()
                        await MainActor.run {
                            isProcessing = false
                            if assetManager.isImportComplete {
                                path.append("EditView")
                            } else {
                                showReminder = true
                            }
                        }
                    }
                } else {
                    showReminder = true
                }
            }
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(isProcessing)

            if isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5)
            }
        }
        .navigationTitle("Import Media")
        .onChange(of: assetManager.videoAsset) { _ in
            Debug.log("Video asset changed")
        }
        .onChange(of: assetManager.audioAsset) { _ in
            Debug.log("Audio asset changed")
        }
        .onAppear {
            Debug.log("ImportMediaView appeared")
        }
        .alert(isPresented: $showReminder) {
            Alert(
                title: Text("Reminder"),
                message: Text("Make sure to have chosen both video and audio!"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
