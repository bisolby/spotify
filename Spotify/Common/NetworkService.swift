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
@MainActor
class TokenManager: ObservableObject {
    @Published var accessToken: String?
    @Published var tokenExpirationDate: Date?
    
    private let userDefaults = UserDefaults.standard
    private let tokenKey = "com.bisolby.spotify_access_token"
    private let expirationKey = "com.bisolby.spotify_token_expiration"
    
    // 토큰 만료 5분 전에 갱신하도록 안전 마진 설정
    private let renewalBufferTime: TimeInterval = 300 // 5분
    
    init() {
        loadTokenFromStorage()
    }
    
    var isTokenValid: Bool {
        guard let token = accessToken,
              let expirationDate = tokenExpirationDate else {
            print("❌ 토큰 검증 실패: 토큰 또는 만료 시간이 없음")
            return false
        }
        
        let now = Date()
        let isValid = !token.isEmpty && expirationDate > now
        
        if isValid {
            let timeRemaining = expirationDate.timeIntervalSince(now)
            print("✅ 토큰 유효: \(Int(timeRemaining/60))분 \(Int(timeRemaining.truncatingRemainder(dividingBy: 60)))초 남음")
        } else {
            print("❌ 토큰 만료됨: \(expirationDate) < \(now)")
        }
        
        return isValid
    }
    
    var needsRenewal: Bool {
        guard let expirationDate = tokenExpirationDate else { return true }
        let timeUntilExpiration = expirationDate.timeIntervalSince(Date())
        return timeUntilExpiration <= renewalBufferTime
    }
    
    func saveToken(_ token: String, expiresIn: Int) {
        // 안전 마진을 고려하여 만료 시간 설정 (실제 만료 시간보다 30초 일찍)
        let safetyMargin: TimeInterval = 30
        let actualExpiresIn = TimeInterval(expiresIn) - safetyMargin
        let expirationDate = Date().addingTimeInterval(actualExpiresIn)
        
        // UI 업데이트를 메인 스레드에서 수행
        self.accessToken = token
        self.tokenExpirationDate = expirationDate
        
        // UserDefaults 저장
        userDefaults.set(token, forKey: tokenKey)
        userDefaults.set(expirationDate, forKey: expirationKey)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        print("✅ 토큰 저장 완료")
        print("   토큰: \(token.prefix(20))...")
        print("   만료 시간: \(formatter.string(from: expirationDate))")
        print("   유효 시간: \(Int(actualExpiresIn/60))분")
    }
    
    func clearToken() {
        print("🗑️ 토큰 삭제 시작")
        
        // UI 업데이트를 메인 스레드에서 수행
        self.accessToken = nil
        self.tokenExpirationDate = nil
        
        // UserDefaults에서 제거
        userDefaults.removeObject(forKey: tokenKey)
        userDefaults.removeObject(forKey: expirationKey)
        
        print("🗑️ 토큰 삭제 완료")
    }
    
    private func loadTokenFromStorage() {
        print("📱 저장된 토큰 로드 시작...")
        
        let storedToken = userDefaults.string(forKey: tokenKey)
        let storedExpirationDate = userDefaults.object(forKey: expirationKey) as? Date
        
        if let token = storedToken, let expiration = storedExpirationDate {
            let now = Date()
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            
            print("📱 저장된 데이터 발견:")
            print("   토큰: \(token.prefix(20))...")
            print("   만료 시간: \(formatter.string(from: expiration))")
            print("   현재 시간: \(formatter.string(from: now))")
            
            if expiration > now {
                // 토큰이 아직 유효함
                self.accessToken = token
                self.tokenExpirationDate = expiration
                
                let timeRemaining = expiration.timeIntervalSince(now)
                print("✅ 저장된 토큰 로드 성공: \(Int(timeRemaining/60))분 \(Int(timeRemaining.truncatingRemainder(dividingBy: 60)))초 남음")
            } else {
                // 토큰이 만료됨 - UserDefaults에서만 제거하고 로그 출력
                print("⏰ 저장된 토큰이 만료됨 - 새 토큰 필요")
                userDefaults.removeObject(forKey: tokenKey)
                userDefaults.removeObject(forKey: expirationKey)
            }
        } else {
            print("❌ 저장된 토큰 없음")
        }
    }
    
    func authorizationHeader() -> [String: String] {
        guard let token = accessToken else {
            print("❌ 인증 헤더 생성 실패: 토큰 없음")
            return [:]
        }
        return ["Authorization": "Bearer \(token)"]
    }
    
    // 토큰 상태 디버깅용 메서드
    func debugTokenStatus() {
        print("🔍 토큰 상태 디버깅:")
        print("   토큰 존재: \(accessToken != nil)")
        print("   만료 시간 존재: \(tokenExpirationDate != nil)")
        print("   토큰 유효: \(isTokenValid)")
        print("   갱신 필요: \(needsRenewal)")
        
        if let expiration = tokenExpirationDate {
            let timeRemaining = expiration.timeIntervalSince(Date())
            print("   남은 시간: \(Int(timeRemaining/60))분 \(Int(timeRemaining.truncatingRemainder(dividingBy: 60)))초")
        }
    }
}

// MARK: - Logger
class APILogger {

    init() {}
    
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
