//

import Foundation

// MARK: - Network Service Helper
class NetworkService {
    static let shared = NetworkService()
    
    private init() {}
    
    // MARK: - Generic Network Request
    func performRequest<T: Codable>(
        url: URL,
        method: HTTPMethod = .GET,
        headers: [String: String] = [:],
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        // Set headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Handle different status codes
        switch httpResponse.statusCode {
        case 200...299:
            // Success
            break
        case 401:
            throw NetworkError.unauthorized
        case 400:
            throw NetworkError.badRequest
        case 404:
            throw NetworkError.notFound
        case 429:
            throw NetworkError.rateLimited
        default:
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(responseType, from: data)
            return decodedResponse
        } catch {
            print("Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw response: \(jsonString)")
            }
            throw NetworkError.decodingError(error)
        }
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - Network Errors
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case badRequest
    case notFound
    case rateLimited
    case serverError(Int)
    case decodingError(Error)
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .invalidResponse:
            return "잘못된 응답입니다."
        case .unauthorized:
            return "인증이 필요합니다. 토큰을 확인해주세요."
        case .badRequest:
            return "잘못된 요청입니다."
        case .notFound:
            return "요청한 리소스를 찾을 수 없습니다."
        case .rateLimited:
            return "요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요."
        case .serverError(let code):
            return "서버 오류가 발생했습니다. (코드: \(code))"
        case .decodingError(let error):
            return "데이터 처리 중 오류가 발생했습니다: \(error.localizedDescription)"
        case .noData:
            return "데이터가 없습니다."
        }
    }
}

// MARK: - Request Builder
struct SpotifyAPIRequest {
    let baseURL = "https://api.spotify.com/v1"
    
    func artistURL(id: String) -> URL? {
        URL(string: "\(baseURL)/artists/\(id)")
    }
    
    func searchURL(query: String, type: String = "artist", limit: Int = 10) -> URL? {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "\(baseURL)/search?q=\(encodedQuery)&type=\(type)&limit=\(limit)")
    }
    
    func albumsURL(artistId: String, limit: Int = 20) -> URL? {
        URL(string: "\(baseURL)/artists/\(artistId)/albums?limit=\(limit)")
    }
    
    func topTracksURL(artistId: String, market: String = "US") -> URL? {
        URL(string: "\(baseURL)/artists/\(artistId)/top-tracks?market=\(market)")
    }
}

// MARK: - Token Manager
class TokenManager: ObservableObject {
    @Published var accessToken: String?
    @Published var tokenExpirationDate: Date?
    
    private let userDefaults = UserDefaults.standard
    private let tokenKey = "spotify_access_token"
    private let expirationKey = "spotify_token_expiration"
    
    init() {
        loadTokenFromStorage()
    }
    
    var isTokenValid: Bool {
        guard let token = accessToken,
              let expirationDate = tokenExpirationDate else {
            return false
        }
        return !token.isEmpty && expirationDate > Date()
    }
    
    func saveToken(_ token: String, expiresIn: Int) {
        let expirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        
        self.accessToken = token
        self.tokenExpirationDate = expirationDate
        
        userDefaults.set(token, forKey: tokenKey)
        userDefaults.set(expirationDate, forKey: expirationKey)
    }
    
    func clearToken() {
        accessToken = nil
        tokenExpirationDate = nil
        
        userDefaults.removeObject(forKey: tokenKey)
        userDefaults.removeObject(forKey: expirationKey)
    }
    
    private func loadTokenFromStorage() {
        accessToken = userDefaults.string(forKey: tokenKey)
        tokenExpirationDate = userDefaults.object(forKey: expirationKey) as? Date
        
        // Clear token if expired
        if !isTokenValid {
            clearToken()
        }
    }
    
    func authorizationHeader() -> [String: String] {
        guard let token = accessToken else {
            return [:]
        }
        return ["Authorization": "Bearer \(token)"]
    }
}

// MARK: - Logger
class APILogger {
    static let shared = APILogger()
    
    private init() {}
    
    func logRequest(_ request: URLRequest) {
        print("🌐 API Request:")
        print("URL: \(request.url?.absoluteString ?? "Unknown")")
        print("Method: \(request.httpMethod ?? "Unknown")")
        
        if let headers = request.allHTTPHeaderFields {
            print("Headers: \(headers)")
        }
        
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("Body: \(bodyString)")
        }
    }
    
    func logResponse(_ response: URLResponse?, data: Data?) {
        print("📱 API Response:")
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Status Code: \(httpResponse.statusCode)")
        }
        
        if let data = data,
           let responseString = String(data: data, encoding: .utf8) {
            print("Response: \(responseString.prefix(500))...")
        }
    }
    
    func logError(_ error: Error) {
        print("❌ API Error: \(error.localizedDescription)")
    }
}
