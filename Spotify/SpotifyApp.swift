//
//  SpotifyApp.swift
//  Spotify
//
//  Created by Rajat Nagvenker on 16/04/21.
//

import SwiftUI

@main
struct SpotifyApp: App {
    var body: some Scene {
        WindowGroup {
            SpotifyContentView()
        }
    }
}

// MARK: - App Delegate for URL Handling
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    // Handle incoming URLs for Spotify authentication callback
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle Spotify authentication callback
        if url.scheme == "bisolby.com" {
            // Extract authorization code from URL
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                
                for item in queryItems {
                    if item.name == "code", let code = item.value {
                        // Handle authorization code
                        print("Received authorization code: \(code)")
                        // TODO: Exchange code for access token
                        return true
                    }
                    if item.name == "error", let error = item.value {
                        print("Authorization error: \(error)")
                        return false
                    }
                }
            }
        }
        return false
    }
}
