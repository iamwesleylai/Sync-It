//
//  ContentView.swift
//  Sync It
//
//  Created by Wesley Lai on 10/10/24.
//

// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var assetManager = AssetManager()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ImportMediaView(assetManager: assetManager, path: $path)
                .navigationDestination(for: String.self) { _ in
                    EditView(assetManager: assetManager, path: $path)
                }
        }
    }
}
