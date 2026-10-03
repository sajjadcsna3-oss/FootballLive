import Foundation

enum NetworkError: LocalizedError, Equatable {
    case missingConfiguration(String), offline, invalidResponse, unauthorized, rateLimited, serviceUnavailable, server(Int), decoding(String)
    var errorDescription: String? {
        switch self {
        case .missingConfiguration(let key): return "The app's \(key) service is not configured. Please contact support."
        case .offline: return "You're offline. Check your internet connection."
        case .invalidResponse: return "The server returned an invalid response."
        case .unauthorized: return "The API key was rejected."
        case .rateLimited: return "The service request limit was reached. Please wait and try again."
        case .serviceUnavailable: return "The service is temporarily unavailable. Please try again later."
        case .server(let code): return "The server returned error \(code)."
        case .decoding(let message): return "Unable to read API data: \(message)"
        }
    }
}

actor NetworkService {
    struct CacheEntry { let data: Data; let expires: Date }
    private var cache: [URL: CacheEntry] = [:]
    private var inFlight: [URL: Task<Data, Error>] = [:]
    private let session: URLSession
    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
    }

    func data(for request: URLRequest, cacheFor seconds: TimeInterval = 0) async throws -> Data {
        guard let url = request.url else { throw NetworkError.invalidResponse }
        if let hit = cache[url], hit.expires > Date() { return hit.data }
        if let task = inFlight[url] { return try await task.value }
        let task = Task<Data, Error> {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
                switch http.statusCode {
                case 200..<300: return data
                case 401, 403: throw NetworkError.unauthorized
                case 429: throw NetworkError.rateLimited
                case 502, 503, 504: throw NetworkError.serviceUnavailable
                default: throw NetworkError.server(http.statusCode)
                }
            } catch let error as URLError {
                switch error.code {
                case .notConnectedToInternet, .networkConnectionLost,
                     .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                    throw NetworkError.offline
                case .timedOut:
                    throw NetworkError.server(408)
                case .cancelled:
                    throw CancellationError()
                default:
                    throw error
                }
            }
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        let data = try await task.value
        if seconds > 0 { cache[url] = CacheEntry(data: data, expires: Date().addingTimeInterval(seconds)) }
        return data
    }
}
