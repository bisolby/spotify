//

import SwiftUI

struct ContentView: View {
    @StateObject private var apiManager = SpotifyAPIManager.shared
    @State private var searchText = ""
    @State private var selectedArtist: SpotifyArtist?
    @State private var searchResults: [SpotifyArtist] = []
    @State private var showingArtistDetail = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Main Search Tab
            NavigationView {
                mainSearchView
            }
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("검색")
            }
            .tag(0)
            
            // Featured Artists Tab
            NavigationView {
                featuredArtistsView
            }
            .tabItem {
                Image(systemName: "star.fill")
                Text("추천")
            }
            .tag(1)
            
            // Settings Tab
            NavigationView {
                settingsView
            }
            .tabItem {
                Image(systemName: "gear")
                Text("설정")
            }
            .tag(2)
        }
        .alert("오류", isPresented: .constant(apiManager.errorMessage != nil)) {
            Button("확인") {
                apiManager.clearError()
            }
        } message: {
            Text(apiManager.errorMessage ?? "")
        }
        .sheet(isPresented: $showingArtistDetail) {
            if let artist = selectedArtist {
                ArtistDetailView(artist: artist)
            }
        }
    }
    
    // MARK: - Main Search View
    private var mainSearchView: some View {
        VStack(spacing: 20) {
            headerSection
            
            if !apiManager.tokenManager.isTokenValid {
                authenticationSection
            } else {
                searchSection
                searchResultsSection
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Spotify API")
        .refreshable {
            if !searchText.isEmpty {
                await searchArtists()
            }
        }
    }
    
    // MARK: - Featured Artists View
    private var featuredArtistsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(SpotifyAPIManager.Constants.sampleArtistIds, id: \.self) { artistId in
                    FeaturedArtistCard(artistId: artistId) { artist in
                        selectedArtist = artist
                        showingArtistDetail = true
                    }
                }
            }
            .padding()
        }
        .navigationTitle("추천 아티스트")
    }
    
    // MARK: - Settings View
    private var settingsView: some View {
        List {
            Section("인증 상태") {
                HStack {
                    Image(systemName: apiManager.tokenManager.isTokenValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(apiManager.tokenManager.isTokenValid ? .green : .red)
                    Text(apiManager.tokenManager.isTokenValid ? "인증됨" : "인증 필요")
                }
                if let expirationDate = apiManager.tokenManager.tokenExpirationDate {
                    VStack(alignment: .leading) {
                        Text("토큰 만료 시간")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(expirationDate.formatted())
                    }
                }
            }
            
            Section("액션") {
                Button("토큰 새로고침") {
                    Task {
                        await apiManager.getAccessToken()
                    }
                }
                .disabled(apiManager.isLoading)
                
                Button("로그아웃") {
                    apiManager.logout()
                }
                .foregroundColor(.red)
            }
            
            Section("정보") {
                Link("Spotify 개발자 문서", destination: URL(string: "https://developer.spotify.com/documentation/web-api/")!)
                
                HStack {
                    Text("앱 버전")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("설정")
    }
    
    // MARK: - UI Components
    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Spotify Web API")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Client Credentials Flow 예제")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var authenticationSection: some View {
        VStack(spacing: 15) {
            Text("🔐 인증이 필요합니다")
                .font(.headline)
            
            Text("Spotify Developer Dashboard에서 Client ID와 Client Secret을 설정해주세요.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task {
                    await apiManager.getAccessToken()
                }
            }) {
                HStack {
                    if apiManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "key.fill")
                    }
                    Text("토큰 받기")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(apiManager.isLoading)
        }
    }
    
    private var searchSection: some View {
        VStack(spacing: 15) {
            Text("🔍 아티스트 검색")
                .font(.headline)
            
            HStack {
                TextField("아티스트 이름을 입력하세요", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        Task {
                            await searchArtists()
                        }
                    }
                
                Button("검색") {
                    Task {
                        await searchArtists()
                    }
                }
                .disabled(searchText.isEmpty || apiManager.isLoading)
            }
            
            // Quick search buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    quickSearchButton("Radiohead", artistId: "4Z8W4fKeB5YxbusRsdQVPb")
                    quickSearchButton("BTS", artistId: "3Nrfpe0tUJi4K4DXYWgMUX")
                    quickSearchButton("Queen", artistId: "1dfeR4HaWDbWqFHLkxsg1d")
                    quickSearchButton("Ed Sheeran", artistId: "6eUKZXaKkcviH0Ku9w2n3V")
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if apiManager.isLoading {
                HStack {
                    ProgressView()
                    Text("검색 중...")
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if !searchResults.isEmpty {
                Text("검색 결과 (\(searchResults.count)개)")
                    .font(.headline)
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(searchResults, id: \.id) { artist in
                            EnhancedArtistRowView(artist: artist) {
                                selectedArtist = artist
                                showingArtistDetail = true
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
        }
    }
    
    private func quickSearchButton(_ name: String, artistId: String) -> some View {
        Button(name) {
            Task {
                if let artist = await apiManager.getArtist(artistId: artistId) {
                    selectedArtist = artist
                    showingArtistDetail = true
                }
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(8)
        .disabled(apiManager.isLoading)
    }
    
    private func searchArtists() async {
        guard !searchText.isEmpty else { return }
        
        if let results = await apiManager.searchArtists(query: searchText) {
            await MainActor.run {
                searchResults = results
            }
        }
    }
}

// MARK: - Featured Artist Card
struct FeaturedArtistCard: View {
    let artistId: String
    let onTap: (SpotifyArtist) -> Void
    
    @State private var artist: SpotifyArtist?
    @State private var isLoading = true
    @StateObject private var apiManager = SpotifyAPIManager.shared
    
    var body: some View {
        Button(action: {
            if let artist = artist {
                onTap(artist)
            }
        }) {
            HStack {
                AsyncImage(url: URL(string: artist?.images.first?.url ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    if let artist = artist {
                        Text(artist.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("팔로워: \(artist.followers.total.formatted())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text("\(artist.popularity)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if isLoading {
                        Text("로딩 중...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("로드 실패")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .task {
            await loadArtist()
        }
    }
    
    private func loadArtist() async {
        isLoading = true
        artist = await apiManager.getArtist(artistId: artistId)
        isLoading = false
    }
}

// MARK: - Enhanced Artist Row View
struct EnhancedArtistRowView: View {
    let artist: SpotifyArtist
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                AsyncImage(url: URL(string: artist.images.first?.url ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("\(artist.followers.total.formatted())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text("\(artist.popularity)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !artist.genres.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(artist.genres.prefix(3), id: \.self) { genre in
                                    Text(genre)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
}
