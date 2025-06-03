//

import Foundation

// MARK: - Spotify API Manager
class SpotifyAPIManager: ObservableObject {
    static let shared = SpotifyAPIManager()
    
    // TODO: Replace with your actual credentials
    private let clientId = "e73f6a4a362e49c48257d5eb45f61d72"
    private let clientSecret = "25fa9da35640423b80dbbb295348c07d"
    
    private let tokenEndpoint = "https://accounts.spotify.com/api/token"
    private let networkService = NetworkService.shared
    private let requestBuilder = SpotifyAPIRequest()
    private let logger = APILogger.shared
    
    @Published var tokenManager = TokenManager()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    // MARK: - Authentication
    func authenticateIfNeeded() async {
        if !tokenManager.isTokenValid {
            await getAccessToken()
        }
    }
    
    func getAccessToken() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        guard let url = URL(string: tokenEndpoint) else {
            await handleError(NetworkError.invalidURL)
            return
        }
        
        let bodyParams = "grant_type=client_credentials&client_id=\(clientId)&client_secret=\(clientSecret)"
        let headers = ["Content-Type": "application/x-www-form-urlencoded"]
        
        do {
            let tokenResponse: SpotifyAccessToken = try await networkService.performRequest(
                url: url,
                method: .POST,
                headers: headers,
                body: bodyParams.data(using: .utf8),
                responseType: SpotifyAccessToken.self
            )
            
            await MainActor.run {
                tokenManager.saveToken(tokenResponse.accessToken, expiresIn: tokenResponse.expiresIn)
                isLoading = false
            }
            
        } catch {
            await handleError(error)
        }
    }
    
    // MARK: - Artist Operations
    func getArtist(artistId: String) async -> SpotifyArtist? {
        await authenticateIfNeeded()
        
        guard let url = requestBuilder.artistURL(id: artistId) else {
            await handleError(NetworkError.invalidURL)
            return nil
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let artist: SpotifyArtist = try await networkService.performRequest(
                url: url,
                headers: tokenManager.authorizationHeader(),
                responseType: SpotifyArtist.self
            )
            
            await MainActor.run {
                isLoading = false
            }
            
            return artist
            
        } catch {
            await handleError(error)
            return nil
        }
    }
    
    func searchArtists(query: String, limit: Int = 10) async -> [SpotifyArtist]? {
        await authenticateIfNeeded()
        
        guard let url = requestBuilder.searchURL(query: query, limit: limit) else {
            await handleError(NetworkError.invalidURL)
            return nil
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let searchResponse: SpotifySearchResponse = try await networkService.performRequest(
                url: url,
                headers: tokenManager.authorizationHeader(),
                responseType: SpotifySearchResponse.self
            )
            
            await MainActor.run {
                isLoading = false
            }
            
            return searchResponse.artists.items
            
        } catch {
            await handleError(error)
            return nil
        }
    }
    
    // MARK: - Additional Features
    func getArtistAlbums(artistId: String, limit: Int = 20) async -> [SpotifyAlbum]? {
        await authenticateIfNeeded()
        
        guard let url = requestBuilder.albumsURL(artistId: artistId, limit: limit) else {
            await handleError(NetworkError.invalidURL)
            return nil
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let albumsResponse: SpotifyAlbumsResponse = try await networkService.performRequest(
                url: url,
                headers: tokenManager.authorizationHeader(),
                responseType: SpotifyAlbumsResponse.self
            )
            
            await MainActor.run {
                isLoading = false
            }
            
            return albumsResponse.items
            
        } catch {
            await handleError(error)
            return nil
        }
    }
    
    func getArtistTopTracks(artistId: String, market: String = "US") async -> [SpotifyTrack]? {
        await authenticateIfNeeded()
        
        guard let url = requestBuilder.topTracksURL(artistId: artistId, market: market) else {
            await handleError(NetworkError.invalidURL)
            return nil
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let tracksResponse: SpotifyTopTracksResponse = try await networkService.performRequest(
                url: url,
                headers: tokenManager.authorizationHeader(),
                responseType: SpotifyTopTracksResponse.self
            )
            
            await MainActor.run {
                isLoading = false
            }
            
            return tracksResponse.tracks
            
        } catch {
            await handleError(error)
            return nil
        }
    }
    
    // MARK: - Error Handling
    private func handleError(_ error: Error) async {
        logger.logError(error)
        
        await MainActor.run {
            if let networkError = error as? NetworkError {
                errorMessage = networkError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    // MARK: - Utility Methods
    func clearError() {
        errorMessage = nil
    }
    
    func logout() {
        tokenManager.clearToken()
    }
}

// MARK: - Spotify API Models
struct SpotifyAccessToken: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct SpotifyArtist: Codable {
    let id: String
    let name: String
    let popularity: Int
    let followers: SpotifyFollowers
    let genres: [String]
    let images: [SpotifyImage]
    let externalUrls: SpotifyExternalUrls
    
    enum CodingKeys: String, CodingKey {
        case id, name, popularity, followers, genres, images
        case externalUrls = "external_urls"
    }
}

struct SpotifyFollowers: Codable {
    let total: Int
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int
    let width: Int
}

struct SpotifyExternalUrls: Codable {
    let spotify: String
}

struct SpotifyAlbum: Codable, Identifiable {
    let id: String
    let name: String
    let albumType: String
    let releaseDate: String
    let totalTracks: Int
    let images: [SpotifyImage]
    let externalUrls: SpotifyExternalUrls
    
    enum CodingKeys: String, CodingKey {
        case id, name, images
        case albumType = "album_type"
        case releaseDate = "release_date"
        case totalTracks = "total_tracks"
        case externalUrls = "external_urls"
    }
}

struct SpotifyTrack: Codable, Identifiable {
    let id: String
    let name: String
    let popularity: Int
    let trackNumber: Int
    let durationMs: Int
    let explicit: Bool
    let previewUrl: String?
    let externalUrls: SpotifyExternalUrls
    
    enum CodingKeys: String, CodingKey {
        case id, name, popularity, explicit
        case trackNumber = "track_number"
        case durationMs = "duration_ms"
        case previewUrl = "preview_url"
        case externalUrls = "external_urls"
    }
    
    var durationFormatted: String {
        let minutes = durationMs / 60000
        let seconds = (durationMs % 60000) / 1000
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Response Models
struct SpotifySearchResponse: Codable {
    let artists: SpotifyArtistsResponse
}

struct SpotifyArtistsResponse: Codable {
    let items: [SpotifyArtist]
}

struct SpotifyAlbumsResponse: Codable {
    let items: [SpotifyAlbum]
    let total: Int
    let limit: Int
    let offset: Int
}

struct SpotifyTopTracksResponse: Codable {
    let tracks: [SpotifyTrack]
}

// MARK: - Constants
extension SpotifyAPIManager {
    enum Constants {
        static let defaultLimit = 20
        static let maxSearchResults = 50
        static let defaultMarket = "US"
        
        // Popular artist IDs for quick testing
        static let sampleArtistIds = [
            "4Z8W4fKeB5YxbusRsdQVPb", // Radiohead
            "3Nrfpe0tUJi4K4DXYWgMUX", // BTS
            "1dfeR4HaWDbWqFHLkxsg1d", // Queen
            "6eUKZXaKkcviH0Ku9w2n3V", // Ed Sheeran
            "1vCWHaC5f2uS3yhpwWbIA6"  // Avicii
        ]
    }
}
