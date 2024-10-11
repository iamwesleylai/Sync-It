//
//  CompletionView.swift
//  Sync It
//
//  Created by Wesley Lai on 10/11/24.
//
import SwiftUI

struct CompletionView: View {
    @ObservedObject var assetManager: AssetManager
    @Binding var path: NavigationPath
    
    var body: some View {
        VStack {
            Text("Both Imported Yay")
                .font(.title)
            
            Button("Go Back") {
                Debug.log("Go Back button tapped in CompletionView")
                assetManager.clearAssets()
                path.removeLast()
            }
            .padding()
        }
        .onAppear {
            Debug.log("CompletionView appeared")
        }
    }
}
