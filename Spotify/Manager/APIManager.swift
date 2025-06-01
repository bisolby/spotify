import Foundation
import Combine

// MARK: - Spotify API Manager
class SpotifyManager: ObservableObject {
    
    // MARK: - Properties
    static let shared = SpotifyManager()
    
    private let clientId = "e73f6a4a362e49c48257d5eb45f61d72" // Spotify Developer Dashboard에서 가져온 Client ID
    private let clientSecret = "25fa9da35640423b80dbbb295348c07d" // Client Secret
    private let redirectURI = "bisolby.com://callback" // 앱에서 설정한 Redirect URI
    
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var currentTrack: SpotifyTrack?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // 저장된 토큰이 있는지 확인
        checkSavedToken()
    }
    
    // MARK: - Authentication
    
    /// 클라이언트 자격 증명 플로우로 토큰 요청 (사용자 로그인 불필요)
    func authenticateWithClientCredentials() {
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Basic Auth 헤더
        let credentials = "\(clientId):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Body
        let bodyString = "grant_type=client_credentials"
        request.httpBody = bodyString.data(using: .utf8)
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: SpotifyTokenResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("Authentication failed: \(error)")
                    }
                },
                receiveValue: { [weak self] tokenResponse in
                    self?.accessToken = tokenResponse.accessToken
                    self?.isAuthenticated = true
                    self?.saveToken(tokenResponse.accessToken)
                    print("✅ Spotify authentication successful!")
                }
            )
            .store(in: &cancellables)
    }
    
    /// 사용자 인증 플로우 (PKCE)를 위한 Authorization URL 생성
    func createAuthorizationURL() -> URL? {
        let scopes = [
            "user-read-private",
            "user-read-email",
            "user-library-read",
            "user-top-read",
            "playlist-read-private",
            "playlist-modify-public",
            "playlist-modify-private"
        ].joined(separator: "%20")
        
        let state = UUID().uuidString
        let urlString = "https://accounts.spotify.com/authorize?" +
            "client_id=\(clientId)" +
            "&response_type=code" +
            "&redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" +
            "&scope=\(scopes)" +
            "&state=\(state)"
        
        return URL(string: urlString)
    }
    
    // MARK: - Token Management
    
    private func saveToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "spotify_access_token")
    }
    
    private func checkSavedToken() {
        if let savedToken = UserDefaults.standard.string(forKey: "spotify_access_token") {
            accessToken = savedToken
            isAuthenticated = true
        }
    }
    
    // MARK: - API Calls
    
    /// 아티스트 정보 가져오기
    func getArtist(id: String) -> AnyPublisher<SpotifyArtist, Error> {
        guard let token = accessToken else {
            return Fail(error: SpotifyError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        let url = URL(string: "https://api.spotify.com/v1/artists/\(id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: SpotifyArtist.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    /// 트랙 검색
    func searchTracks(query: String, limit: Int = 20) -> AnyPublisher<SpotifySearchResponse, Error> {
        guard let token = accessToken else {
            return Fail(error: SpotifyError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=track&limit=\(limit)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: SpotifySearchResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    /// 사용자의 탑 트랙 가져오기
    func getUserTopTracks(limit: Int = 20) -> AnyPublisher<SpotifyTracksResponse, Error> {
        guard let token = accessToken else {
            return Fail(error: SpotifyError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        let url = URL(string: "https://api.spotify.com/v1/me/top/tracks?limit=\(limit)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: SpotifyTracksResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    /// 사용자 프로필 가져오기
    func getUserProfile() -> AnyPublisher<SpotifyUser, Error> {
        guard let token = accessToken else {
            return Fail(error: SpotifyError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        let url = URL(string: "https://api.spotify.com/v1/me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: SpotifyUser.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

// MARK: - Models
struct SpotifyTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct SpotifyArtist: Codable, Identifiable {
    let id: String
    let name: String
    let genres: [String]
    let popularity: Int
    let followers: SpotifyFollowers
    let images: [SpotifyImage]
    let externalUrls: SpotifyExternalUrls
    
    enum CodingKeys: String, CodingKey {
        case id, name, genres, popularity, followers, images
        case externalUrls = "external_urls"
    }
}

struct SpotifyTrack: Codable, Identifiable {
    let id: String
    let name: String
    let artists: [SpotifySimpleArtist]
    let album: SpotifySimpleAlbum
    let popularity: Int
    let previewUrl: String?
    let durationMs: Int
    let explicit: Bool
    let externalUrls: SpotifyExternalUrls
    
    enum CodingKeys: String, CodingKey {
        case id, name, artists, album, popularity, explicit
        case previewUrl = "preview_url"
        case durationMs = "duration_ms"
        case externalUrls = "external_urls"
    }
}

struct SpotifySimpleArtist: Codable, Identifiable {
    let id: String
    let name: String
    let externalUrls: SpotifyExternalUrls
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case externalUrls = "external_urls"
    }
}

struct SpotifySimpleAlbum: Codable, Identifiable {
    let id: String
    let name: String
    let images: [SpotifyImage]
    let releaseDate: String
    let releaseDatePrecision: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, images
        case releaseDate = "release_date"
        case releaseDatePrecision = "release_date_precision"
    }
}

struct SpotifyUser: Codable, Identifiable {
    let id: String
    let displayName: String?
    let email: String?
    let followers: SpotifyFollowers
    let images: [SpotifyImage]
    let country: String?
    
    enum CodingKeys: String, CodingKey {
        case id, email, followers, images, country
        case displayName = "display_name"
    }
}

struct SpotifyFollowers: Codable {
    let total: Int
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int?
    let width: Int?
}

struct SpotifyExternalUrls: Codable {
    let spotify: String
}

struct SpotifySearchResponse: Codable {
    let tracks: SpotifyTracksResponse
}

struct SpotifyTracksResponse: Codable {
    let items: [SpotifyTrack]
    let total: Int
    let limit: Int
    let offset: Int
}

// MARK: - Errors
enum SpotifyError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Spotify authentication required"
        case .invalidResponse:
            return "Invalid response from Spotify API"
        case .networkError:
            return "Network error occurred"
        }
    }
}
