import SwiftUI
import Combine

struct SpotifyContentView: View {
    @StateObject private var spotifyManager = SpotifyManager.shared
    @State private var searchText = ""
    @State private var searchResults: [SpotifyTrack] = []
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Authentication Section
                if !spotifyManager.isAuthenticated {
                    authenticationSection
                } else {
                    authenticatedSection
                }
            }
            .padding()
            .navigationTitle("Spotify App")
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Authentication Section
    private var authenticationSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Welcome to Spotify")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Connect to discover music")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: authenticate) {
                HStack {
                    Image(systemName: "music.note.house")
                    Text("Connect to Spotify")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.green)
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Authenticated Section
    private var authenticatedSection: some View {
        VStack(spacing: 20) {
            // Status
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected to Spotify")
                    .fontWeight(.medium)
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
            
            // Search Section
            searchSection
            
            // Results
            if isLoading {
                ProgressView("Searching...")
                    .padding()
            } else {
                resultsSection
            }
            
            Spacer()
        }
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search Music")
                .font(.headline)
            
            HStack {
                TextField("Search tracks, artists...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        searchTracks()
                    }
                
                Button(action: searchTracks) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.green)
                        .cornerRadius(6)
                }
            }
        }
    }
    
    // MARK: - Results Section
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !searchResults.isEmpty {
                Text("Search Results")
                    .font(.headline)
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(searchResults) { track in
                            TrackRowView(track: track)
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else if !searchText.isEmpty {
                Text("No results found")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    // MARK: - Actions
    private func authenticate() {
        isLoading = true
        // 클라이언트 자격 증명 플로우 사용 (사용자 로그인 불필요)
        spotifyManager.authenticateWithClientCredentials()
        
        // 결과 관찰
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
            if !spotifyManager.isAuthenticated {
                alertMessage = "Authentication failed. Please check your credentials."
                showingAlert = true
            }
        }
    }
    
    private func searchTracks() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isLoading = true
        
        spotifyManager.searchTracks(query: searchText, limit: 20)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case let .failure(error) = completion {
                        alertMessage = "Search failed: \(error.localizedDescription)"
                        showingAlert = true
                    }
                },
                receiveValue: { response in
                    searchResults = response.tracks.items
                    isLoading = false
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Track Row View
struct TrackRowView: View {
    let track: SpotifyTrack
    
    var body: some View {
        HStack(spacing: 12) {
            // Album artwork placeholder
            AsyncImage(url: URL(string: track.album.images.first?.url ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .cornerRadius(6)
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(track.artists.map(\.name).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(track.album.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            Text(formatDuration(track.durationMs))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ milliseconds: Int) -> String {
        let seconds = milliseconds / 1000
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview
struct SpotifyContentView_Previews: PreviewProvider {
    static var previews: some View {
        SpotifyContentView()
    }
}
