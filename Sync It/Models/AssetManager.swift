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
    @Published var isImportComplete = false

    func checkImportCompletion() {
        Debug.log("Checking import completion")
        Debug.log("Video asset: \(videoAsset != nil ? "Set" : "Nil")")
        Debug.log("Audio asset: \(audioAsset != nil ? "Set" : "Nil")")
        if videoAsset != nil && audioAsset != nil {
            isImportComplete = true
            Debug.log("Both assets imported")
            processSelectedItems()
        }
    }
    
    func processSelectedItems() {
        Debug.log("Processing selected items")
        if let videoItem = videoAsset {
            Debug.log("Processing video item")
            loadTransferable(from: videoItem, isVideo: true)
        }
        if let audioItem = audioAsset {
            Debug.log("Processing audio item")
            loadTransferable(from: audioItem, isVideo: false)
        }
    }
    
    func loadTransferable(from item: PhotosPickerItem, isVideo: Bool) {
        Debug.log("Loading transferable for \(isVideo ? "video" : "audio")")
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data {
                        if isVideo {
                            Debug.log("Video data loaded, size: \(data.count) bytes")
                            // Here you would process the video data
                        } else {
                            Debug.log("Audio source video data loaded, size: \(data.count) bytes")
                            // Here you would extract the audio from the video data
                        }
                    } else {
                        Debug.log("Data is nil for \(isVideo ? "video" : "audio")")
                    }
                case .failure(let error):
                    Debug.log("Error loading \(isVideo ? "video" : "audio") data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func clearAssets() {
        Debug.log("Clearing assets")
        videoAsset = nil
        audioAsset = nil
        isImportComplete = false
    }
}
