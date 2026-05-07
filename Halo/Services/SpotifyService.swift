import Foundation
import CryptoKit
import AppKit

// MARK: - Models publics

struct SpotifyTrack: Equatable {
    let title: String
    let artist: String
    let albumArtURL: String?
}

// MARK: - SpotifyService

final class SpotifyService: NSObject, ObservableObject {
    static let shared = SpotifyService()

    // MARK: Published
    @Published var isAuthenticated = false
    @Published var currentTrack: SpotifyTrack?
    @Published var isPlaying = false
    @Published var albumArtwork: NSImage?
    @Published var progressMS: Int = 0
    @Published var durationMS: Int = 0

    // MARK: Privé
    private let clientID    = "e81639755bc84993a5bc7aefc77689a2"   // ← remplacer avant build
    private let redirectURI = "halo://spotify-callback"
    private let scopes      = "user-read-playback-state user-modify-playback-state"

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?
    private var codeVerifier: String?
    private var pollingTimer: Timer?
    private var progressTimer: Timer?
    private var lastArtURL: String?   // évite de re-télécharger la même pochette

    private override init() {
        super.init()
        loadTokensFromKeychain()
    }

    // MARK: - Auth PKCE

    func startAuth() {
        let verifier   = makeCodeVerifier()
        codeVerifier   = verifier
        let challenge  = makeCodeChallenge(from: verifier)

        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            .init(name: "client_id",             value: clientID),
            .init(name: "response_type",          value: "code"),
            .init(name: "redirect_uri",           value: redirectURI),
            .init(name: "code_challenge_method",  value: "S256"),
            .init(name: "code_challenge",         value: challenge),
            .init(name: "scope",                  value: scopes),
        ]
        guard let url = comps.url else { return }
        NSWorkspace.shared.open(url)
    }

    func handleCallback(url: URL) {
        guard
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let code  = comps.queryItems?.first(where: { $0.name == "code" })?.value,
            let verifier = codeVerifier
        else { return }
        exchangeCode(code, verifier: verifier)
    }

    private func exchangeCode(_ code: String, verifier: String) {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = [
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI)",
            "client_id=\(clientID)",
            "code_verifier=\(verifier)"
        ].joined(separator: "&").data(using: .utf8)

        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let data, let resp = try? JSONDecoder().decode(TokenResponse.self, from: data) else { return }
            DispatchQueue.main.async { self?.storeTokens(resp) }
        }.resume()
    }

    // MARK: - Token refresh

    private func refreshAccessToken(then completion: @escaping () -> Void) {
        guard let refresh = refreshToken else { return }

        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = [
            "grant_type=refresh_token",
            "refresh_token=\(refresh)",
            "client_id=\(clientID)"
        ].joined(separator: "&").data(using: .utf8)

        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let data, let resp = try? JSONDecoder().decode(TokenResponse.self, from: data) else { return }
            DispatchQueue.main.async {
                self?.storeTokens(resp)
                completion()
            }
        }.resume()
    }

    // MARK: - Polling

    func startPolling() {
        guard pollingTimer == nil else { return }
        fetchNowPlaying()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.fetchNowPlaying()
        }
        // Interpolation locale du progress entre les polls (100 ms)
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying, self.durationMS > 0 else { return }
            DispatchQueue.main.async {
                self.progressMS = min(self.progressMS + 100, self.durationMS)
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - Now Playing

    private func fetchNowPlaying() {
        guard isAuthenticated else { return }
        ensureValidToken {
            self.get("https://api.spotify.com/v1/me/player/currently-playing") { [weak self] data in
                guard let self else { return }
                // 204 No Content → rien en lecture
                guard let data, !data.isEmpty else {
                    DispatchQueue.main.async {
                        self.currentTrack = nil
                        self.albumArtwork = nil
                    }
                    return
                }
                guard let resp = try? JSONDecoder().decode(NowPlayingResponse.self, from: data) else { return }
                let track = SpotifyTrack(
                    title:       resp.item.name,
                    artist:      resp.item.artists.map(\.name).joined(separator: ", "),
                    albumArtURL: resp.item.album.images.first?.url
                )
                DispatchQueue.main.async {
                    self.currentTrack = track
                    self.isPlaying    = resp.is_playing
                    self.progressMS   = resp.progress_ms ?? 0
                    self.durationMS   = resp.item.duration_ms
                }
                // Recharge la pochette seulement si l'URL a changé
                if let artURL = resp.item.album.images.first?.url, artURL != self.lastArtURL {
                    self.lastArtURL = artURL
                    self.fetchArtwork(urlString: artURL)
                }
            }
        }
    }

    private func fetchArtwork(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async { self?.albumArtwork = image }
        }.resume()
    }

    // MARK: - Contrôles lecture

    func togglePlayPause() { isPlaying ? sendPlayerCommand("pause", method: "PUT") : sendPlayerCommand("play", method: "PUT") }
    func next()     { sendPlayerCommand("next",     method: "POST") }
    func previous() { sendPlayerCommand("previous", method: "POST") }

    private func sendPlayerCommand(_ command: String, method: String) {
        ensureValidToken {
            guard let token = self.accessToken,
                  let url = URL(string: "https://api.spotify.com/v1/me/player/\(command)")
            else { return }
            var req = URLRequest(url: url)
            req.httpMethod = method
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: req) { [weak self] _, _, _ in
                // Petit délai pour que Spotify mette à jour son état
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.fetchNowPlaying()
                }
            }.resume()
        }
    }

    // MARK: - Helpers réseau

    private func ensureValidToken(then action: @escaping () -> Void) {
        let bufferSeconds: TimeInterval = 60
        if let expiry = tokenExpiry, Date() < expiry.addingTimeInterval(-bufferSeconds) {
            action()
        } else {
            refreshAccessToken(then: action)
        }
    }

    private func get(_ endpoint: String, completion: @escaping (Data?) -> Void) {
        guard let token = accessToken, let url = URL(string: endpoint) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { data, _, _ in completion(data) }.resume()
    }

    // MARK: - PKCE helpers

    private func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(
            Data(bytes).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
                .prefix(128)
        )
    }

    private func makeCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Keychain

    private func storeTokens(_ resp: TokenResponse) {
        accessToken  = resp.access_token
        tokenExpiry  = Date().addingTimeInterval(TimeInterval(resp.expires_in))
        if let rt = resp.refresh_token { refreshToken = rt }
        isAuthenticated = true

        KeychainHelper.save(key: "halo.access_token",  value: resp.access_token)
        KeychainHelper.save(key: "halo.token_expiry",  value: ISO8601DateFormatter().string(from: tokenExpiry!))
        if let rt = resp.refresh_token {
            KeychainHelper.save(key: "halo.refresh_token", value: rt)
        }
        fetchNowPlaying()
        startPolling()
    }

    private func loadTokensFromKeychain() {
        accessToken  = KeychainHelper.load(key: "halo.access_token")
        refreshToken = KeychainHelper.load(key: "halo.refresh_token")
        if let str = KeychainHelper.load(key: "halo.token_expiry") {
            tokenExpiry = ISO8601DateFormatter().date(from: str)
        }
        isAuthenticated = accessToken != nil && refreshToken != nil
    }
}

// MARK: - Decodable privés

private struct TokenResponse: Decodable {
    let access_token:  String
    let refresh_token: String?
    let expires_in:    Int
}

private struct NowPlayingResponse: Decodable {
    let is_playing: Bool
    let progress_ms: Int?
    let item: Item

    struct Item: Decodable {
        let name: String
        let duration_ms: Int
        let artists: [Artist]
        let album: Album

        struct Artist: Decodable { let name: String }
        struct Album: Decodable {
            let images: [Image]
            struct Image: Decodable { let url: String }
        }
    }
}
