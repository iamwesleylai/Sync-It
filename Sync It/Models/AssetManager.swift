//
//  AssetManager.swift
//  Sync It
//
//  Created by Wesley Lai on 10/11/24.
//
import SwiftUI
import PhotosUI

@MainActor
class AssetManager: ObservableObject {
    @Published var videoAsset: PhotosPickerItem? {
        didSet { Debug.log("Video asset set: \(videoAsset != nil)") }
    }
    @Published var audioAsset: PhotosPickerItem? {
        didSet { Debug.log("Audio asset set: \(audioAsset != nil)") }
    }
    @Published var videoAssetURL: URL? {
        didSet { Debug.log("Video URL set: \(videoAssetURL?.absoluteString ?? "nil")") }
    }
    @Published var audioAssetURL: URL? {
        didSet { Debug.log("Audio URL set: \(audioAssetURL?.absoluteString ?? "nil")") }
    }
    @Published var isImportComplete = false {
        didSet { Debug.log("Import complete status changed: \(isImportComplete)") }
    }
    
    private func checkImportCompletion() {
        Debug.log("Checking import completion...")
        let videoReady = videoAssetURL != nil
        let audioReady = audioAssetURL != nil
        Debug.log("Video ready: \(videoReady), Audio ready: \(audioReady)")
        
        isImportComplete = videoReady && audioReady
        if isImportComplete {
            Debug.log("Both assets imported successfully")
        } else {
            Debug.log("Import not complete. Missing: \(!videoReady ? "Video" : "") \(!audioReady ? "Audio" : "")")
        }
    }
    
    func processSelectedItems() async {
        await MainActor.run {
            Debug.log("Starting to process selected items...")
            Debug.log("Video asset exists: \(videoAsset != nil)")
            Debug.log("Audio asset exists: \(audioAsset != nil)")
        }
        await loadTransferable(from: videoAsset, isVideo: true)
        await loadTransferable(from: audioAsset, isVideo: false)
        await MainActor.run {
            Debug.log("Finished loading transferables, checking completion...")
            checkImportCompletion()
        }
    }
    
    private func loadTransferable(from item: PhotosPickerItem?, isVideo: Bool) async {
        Debug.log("Loading transferable for \(isVideo ? "video" : "audio")...")
        guard let item = item else {
            Debug.log("No item to load for \(isVideo ? "video" : "audio")")
            return
        }
        
        do {
            Debug.log("Attempting to load Data for \(isVideo ? "video" : "audio")...")
            if let data = try await item.loadTransferable(type: Data.self) {
                Debug.log("\(isVideo ? "Video" : "Audio") Data loaded successfully, size: \(data.count) bytes")
                
                // Create a temporary file URL with the appropriate extension
                let tempDirectoryURL = FileManager.default.temporaryDirectory
                let fileName = "\(isVideo ? "video" : "audio")_\(UUID().uuidString).\(isVideo ? "mov" : "m4a")"
                let fileURL = tempDirectoryURL.appendingPathComponent(fileName)
                
                // Write the data to the file
                try data.write(to: fileURL)
                
                await MainActor.run {
                    if isVideo {
                        self.videoAssetURL = fileURL
                        Debug.log("Video URL set to: \(self.videoAssetURL?.absoluteString ?? "nil")")
                    } else {
                        self.audioAssetURL = fileURL
                        Debug.log("Audio URL set to: \(self.audioAssetURL?.absoluteString ?? "nil")")
                    }
                }
            } else {
                Debug.log("Failed to load \(isVideo ? "video" : "audio") Data: Data is nil")
            }
        } catch {
            Debug.log("Error loading \(isVideo ? "video" : "audio") Data: \(error.localizedDescription)")
        }
    }
    
    func clearAssets() {
        Debug.log("Clearing all assets...")
        videoAsset = nil
        audioAsset = nil
        videoAssetURL = nil
        audioAssetURL = nil
        isImportComplete = false
        Debug.log("All assets cleared")
    }
}
