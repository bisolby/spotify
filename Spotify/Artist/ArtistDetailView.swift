//

import SwiftUI

struct ArtistDetailView: View {
    let artist: SpotifyArtist
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiManager = SpotifyAPIManager.shared
    
    @State private var albums: [SpotifyAlbum] = []
    @State private var topTracks: [SpotifyTrack] = []
    @State private var isLoadingAlbums = false
    @State private var isLoadingTracks = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    artistHeaderSection
                    
                    tabSelectionView
                    
                    switch selectedTab {
                    case 0:
                        artistInfoSection
                    case 1:
                        albumsSection
                    case 2:
                        topTracksSection
                    default:
                        artistInfoSection
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadAdditionalData()
        }
    }
    
    // MARK: - Artist Header Section
    private var artistHeaderSection: some View {
        VStack(spacing: 16) {
            AsyncImage(url: URL(string: artist.images.first?.url ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 10)
            
            VStack(spacing: 8) {
                Text(artist.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 20) {
                    StatBubble(
                        value: artist.followers.total.formatted(),
                        label: "팔로워",
                        icon: "person.2.fill",
                        color: .blue
                    )
                    
                    StatBubble(
                        value: "\(artist.popularity)",
                        label: "인기도",
                        icon: "star.fill",
                        color: .yellow
                    )
                    
                    StatBubble(
                        value: "\(artist.genres.count)",
                        label: "장르",
                        icon: "music.quarternote.3",
                        color: .purple
                    )
                }
                
                if let spotifyUrl = URL(string: artist.externalUrls.spotify) {
                    Link(destination: spotifyUrl) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                            Text("Spotify에서 열기")
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.clear, Color(.systemGray6).opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Tab Selection
    private var tabSelectionView: some View {
        HStack(spacing: 0) {
            TabButton(title: "정보", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            TabButton(title: "앨범", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            
            TabButton(title: "인기곡", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Artist Info Section
    private var artistInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            genresSection
            detailsSection
            imagesSection
        }
        .padding()
    }
    
    private var genresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "장르", icon: "music.quarternote.3")
            
            if artist.genres.isEmpty {
                Text("장르 정보가 없습니다")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 120))
                ], spacing: 8) {
                    ForEach(artist.genres, id: \.self) { genre in
                        Text(genre)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(15)
                    }
                }
            }
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "상세 정보", icon: "info.circle")
            
            VStack(spacing: 8) {
                DetailRow(label: "Spotify ID", value: artist.id)
                DetailRow(label: "타입", value: "Artist")
                DetailRow(label: "URI", value: "spotify:artist:\(artist.id)")
            }
        }
    }
    
    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "이미지", icon: "photo")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(artist.images, id: \.url) { image in
                        VStack(spacing: 4) {
                            AsyncImage(url: URL(string: image.url)) { img in
                                img
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Text("\(image.width)×\(image.height)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Albums Section
    private var albumsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoadingAlbums {
                HStack {
                    ProgressView()
                    Text("앨범 로딩 중...")
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if albums.isEmpty {
                Text("앨범 정보를 불러올 수 없습니다")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(albums) { album in
                        AlbumRowView(album: album)
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Top Tracks Section
    private var topTracksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoadingTracks {
                HStack {
                    ProgressView()
                    Text("인기곡 로딩 중...")
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if topTracks.isEmpty {
                Text("인기곡 정보를 불러올 수 없습니다")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(topTracks.enumerated()), id: \.element.id) { index, track in
                        TrackRowView(track: track, rank: index + 1)
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadAdditionalData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await loadAlbums()
            }
            group.addTask {
                await loadTopTracks()
            }
        }
    }
    
    private func loadAlbums() async {
        await MainActor.run {
            isLoadingAlbums = true
        }
        
        if let loadedAlbums = await apiManager.getArtistAlbums(artistId: artist.id) {
            await MainActor.run {
                albums = loadedAlbums
                isLoadingAlbums = false
            }
        } else {
            await MainActor.run {
                isLoadingAlbums = false
            }
        }
    }
    
    private func loadTopTracks() async {
        await MainActor.run {
            isLoadingTracks = true
        }
        
        if let loadedTracks = await apiManager.getArtistTopTracks(artistId: artist.id) {
            await MainActor.run {
                topTracks = loadedTracks
                isLoadingTracks = false
            }
        } else {
            await MainActor.run {
                isLoadingTracks = false
            }
        }
    }
}

// MARK: - Supporting Views
struct StatBubble: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue : Color.clear)
                )
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .fontWeight(.medium)
                .textSelection(.enabled)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct AlbumRowView: View {
    let album: SpotifyAlbum
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: album.images.first?.url ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "opticaldisc")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(album.name)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    Text(album.albumType.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text(album.releaseDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(album.totalTracks)곡")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TrackRowView: View {
    let track: SpotifyTrack
    let rank: Int
    
    var body: some View {
        HStack {
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    if track.explicit {
                        Image(systemName: "e.square.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text("\(track.popularity)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(track.durationFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if track.previewUrl != nil {
                Image(systemName: "play.circle")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    ArtistDetailView(artist: SpotifyArtist(
        id: "4Z8W4fKeB5YxbusRsdQVPb",
        name: "Radiohead",
        popularity: 79,
        followers: SpotifyFollowers(total: 7625607),
        genres: ["alternative rock", "art rock", "melancholia"],
        images: [
            SpotifyImage(url: "https://i.scdn.co/image/ab6761610000e5eba03696716c9ee605006047fd", height: 640, width: 640)
        ],
        externalUrls: SpotifyExternalUrls(spotify: "https://open.spotify.com/artist/4Z8W4fKeB5YxbusRsdQVPb")
    ))
}

struct SectionHeaderView: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}
