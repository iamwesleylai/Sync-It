//
//  AssetManager.swift
//  Sync It
//
//  Created by Wesley Lai on 10/11/24.
//
import SwiftUI
import PhotosUI

class AssetManager: ObservableObject {
    @Published var videoAsset: PhotosPickerItem?
    @Published var audioAsset: PhotosPickerItem?
    @Published var videoAssetURL: URL?
    @Published var audioAssetURL: URL?
    @Published var isImportComplete = false
    
    private func checkImportCompletion() {
            isImportComplete = videoAssetURL != nil && audioAssetURL != nil
            if isImportComplete {
                Debug.log("Both assets imported")
            }
        }
    
    func processSelectedItems() async {
        await loadTransferable(from: videoAsset, isVideo: true)
        await loadTransferable(from: audioAsset, isVideo: false)
        checkImportCompletion()
    }
    
    private func loadTransferable(from item: PhotosPickerItem?, isVideo: Bool) async {
        guard let item = item else { return }
        
        do {
            let url = try await item.loadTransferable(type: URL.self)
            if isVideo {
                videoAssetURL = url
                Debug.log("Video URL loaded: \(url)")
            } else {
                audioAssetURL = url
                Debug.log("Audio URL loaded: \(url)")
            }
        } catch {
            Debug.log("Error loading \(isVideo ? "video" : "audio") URL: \(error.localizedDescription)")
        }
    }
    
    
    func clearAssets() {
        videoAsset = nil
        audioAsset = nil
        videoAssetURL = nil
        audioAssetURL = nil
        isImportComplete = false
        Debug.log("Assets cleared")
    }
}
