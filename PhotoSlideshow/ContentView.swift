//
//  ContentView.swift
//  PhotoSlideshow
//
//  Created by sho kisaragi on 2025/07/22.
//

import SwiftUI
import AppKit
import os.log

private let logger = Logger(subsystem: "com.example.PhotoSlideshow", category: "ContentView")

struct ContentView: View {
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var viewModel: SlideshowViewModel?
    @State private var keyboardHandler: KeyboardHandler?
    @State private var isInitialized = false
    
    var body: some View {
        Group {
            if isInitialized, let viewModel = viewModel, let keyboardHandler = keyboardHandler {
                ZStack {
                    ImageDisplayViewWithObserver(viewModel: viewModel)
                        .ignoresSafeArea()
                    
                    if showControls {
                        ControlsView(viewModel: viewModel)
                    }
                }
                .keyboardHandler(keyboardHandler)
                .onHover { hovering in
                    if hovering {
                        showControlsTemporarily()
                    }
                }
                .onTapGesture {
                    showControlsTemporarily()
                }
                .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                    Button("OK") {
                        viewModel.clearError()
                    }
                } message: {
                    if let error = viewModel.error {
                        Text(error.localizedDescription)
                    }
                }
            } else {
                VStack {
                    ProgressView()
                    Text("Initializing...")
                        .padding()
                }
                .onAppear {
                    NSLog("📱 PhotoSlideshow DEBUG: ContentView loading screen appeared")
                    logger.info("📱 ContentView: Loading screen appeared")
                }
            }
        }
        .onAppear {
            if !isInitialized {
                initializeApp()
            }
        }
    }
    
    private func initializeApp() {
        print("📱 PhotoSlideshow DEBUG: initializeApp() called")
        print("🏗️ ContentView: Starting initialization...")
        
        // Add small delay to ensure UI is ready
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            print("📱 PhotoSlideshow DEBUG: Creating dependencies...")
            do {
                // Create dependencies safely
                let fileAccess = SecureFileAccess()
                let imageLoader = ImageLoader()
                let imageCache = ImageCache()
                let repository = FileSystemPhotoRepository(fileAccess: fileAccess, imageLoader: imageLoader)
                let domainService = SlideshowDomainService(repository: repository, cache: imageCache)
                
                // Create view model and handler
                let createdViewModel = SlideshowViewModel(domainService: domainService, fileAccess: fileAccess)
                let createdKeyboardHandler = KeyboardHandler()
                
                // Setup connection
                createdKeyboardHandler.viewModel = createdViewModel
                
                // Set state
                self.viewModel = createdViewModel
                self.keyboardHandler = createdKeyboardHandler
                self.isInitialized = true
                
                print("🏗️ ContentView: Initialization completed successfully")
                
            } catch {
                print("❌ ContentView: Initialization failed: \(error)")
            }
        }
    }
    
    private func showControlsTemporarily() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls = true
        }
        
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            Task { @MainActor in
                if self.viewModel?.slideshow?.isPlaying == true {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showControls = false
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
