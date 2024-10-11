//
//  ContentView.swift
//  Sync It
//
//  Created by Wesley Lai on 10/10/24.
//

// ContentView.swift
import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var videoAsset: PhotosPickerItem?
    @State private var audioAsset: PhotosPickerItem?
    @State private var isImportComplete = false
    @State private var path = NavigationPath()
    @State private var isImportingVideo = false
    @State private var isImportingAudio = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 20) {
                Button("Import Video") {
                    print("DEBUG: Video import button tapped")
                    isImportingVideo = true
                }
                .photosPicker(isPresented: $isImportingVideo, selection: $videoAsset, matching: .videos)
                
                Button("Import Audio from Video") {
                    print("DEBUG: Audio import button tapped")
                    isImportingAudio = true
                }
                .photosPicker(isPresented: $isImportingAudio, selection: $audioAsset, matching: .videos)
            }
            .navigationDestination(for: String.self) { _ in
                CompletionView(isActive: $isImportComplete, path: $path, onDismiss: clearAssets)
            }
            .navigationTitle("Import Media")
            .onChange(of: videoAsset) { _ in
                print("DEBUG: Video asset changed")
                checkImportCompletion()
            }
            .onChange(of: audioAsset) { _ in
                print("DEBUG: Audio asset changed")
                checkImportCompletion()
            }
            .onAppear {
                print("DEBUG: ImportMediaView appeared")
            }
        }
    }
    
    func checkImportCompletion() {
        print("DEBUG: Checking import completion")
        print("DEBUG: Video asset: \(videoAsset != nil ? "Set" : "Nil")")
        print("DEBUG: Audio asset: \(audioAsset != nil ? "Set" : "Nil")")
        if videoAsset != nil && audioAsset != nil {
            isImportComplete = true
            path.append("completion")
            print("DEBUG: Both assets imported, navigating to completion view")
            
            processSelectedItems()
        }
    }
    
    func processSelectedItems() {
        print("DEBUG: Processing selected items")
        if let videoItem = videoAsset {
            print("DEBUG: Processing video item")
            loadTransferable(from: videoItem, isVideo: true)
        }
        if let audioItem = audioAsset {
            print("DEBUG: Processing audio item")
            loadTransferable(from: audioItem, isVideo: false)
        }
    }
    
    func loadTransferable(from item: PhotosPickerItem, isVideo: Bool) {
        print("DEBUG: Loading transferable for \(isVideo ? "video" : "audio")")
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data {
                        if isVideo {
                            print("DEBUG: Video data loaded, size: \(data.count) bytes")
                            // Here you would process the video data
                        } else {
                            print("DEBUG: Audio source video data loaded, size: \(data.count) bytes")
                            // Here you would extract the audio from the video data
                        }
                    } else {
                        print("DEBUG: Data is nil for \(isVideo ? "video" : "audio")")
                    }
                case .failure(let error):
                    print("DEBUG: Error loading \(isVideo ? "video" : "audio") data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func clearAssets() {
        print("DEBUG: Clearing assets")
        videoAsset = nil
        audioAsset = nil
        isImportComplete = false
    }
}

struct CompletionView: View {
    @Binding var isActive: Bool
    @Binding var path: NavigationPath
    var onDismiss: () -> Void
    
    var body: some View {
        VStack {
            Text("Both Imported Yay")
                .font(.title)
            
            Button("Go Back") {
                print("DEBUG: Go Back button tapped in CompletionView")
                isActive = false
                path.removeLast()
                onDismiss()
            }
            .padding()
        }
        .onAppear {
            print("DEBUG: CompletionView appeared")
        }
    }
}
