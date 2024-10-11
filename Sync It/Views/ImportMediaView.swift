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

    var body: some View {
        VStack(spacing: 20) {
            Button("Import Video") {
                Debug.log("Video import button tapped")
                isImportingVideo = true
            }
            .photosPicker(isPresented: $isImportingVideo, selection: $assetManager.videoAsset, matching: .videos)
            
            Button("Import Audio from Video") {
                Debug.log("Audio import button tapped")
                isImportingAudio = true
            }
            .photosPicker(isPresented: $isImportingAudio, selection: $assetManager.audioAsset, matching: .videos)
        }
        .navigationTitle("Import Media")
        .onChange(of: assetManager.videoAsset) { _ in
            Debug.log("Video asset changed")
            assetManager.checkImportCompletion()
        }
        .onChange(of: assetManager.audioAsset) { _ in
            Debug.log("Audio asset changed")
            assetManager.checkImportCompletion()
        }
        .onChange(of: assetManager.isImportComplete) { newValue in
            if newValue {
                path.append("completion")
            }
        }
        .onAppear {
            Debug.log("ImportMediaView appeared")
        }
    }
}
