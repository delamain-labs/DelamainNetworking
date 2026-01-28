import Foundation

/// HTTP methods supported by the network client.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}

/// Defines an API endpoint with all information needed to make a request.
public protocol Endpoint: Sendable {
    /// The base URL for the API (e.g., "https://api.example.com").
    var baseURL: URL { get }
    
    /// The path component of the URL (e.g., "/users/123").
    var path: String { get }
    
    /// The HTTP method for this endpoint.
    var method: HTTPMethod { get }
    
    /// HTTP headers to include in the request.
    var headers: [String: String] { get }
    
    /// Query parameters to append to the URL.
    var queryItems: [URLQueryItem]? { get }
    
    /// The body data for the request (for POST, PUT, PATCH).
    var body: Data? { get }
    
    /// The cache policy for this request.
    var cachePolicy: URLRequest.CachePolicy { get }
    
    /// The timeout interval for this request.
    var timeoutInterval: TimeInterval { get }
}

// MARK: - Default Implementations

public extension Endpoint {
    var headers: [String: String] {
        ["Content-Type": "application/json", "Accept": "application/json"]
    }
    
    var queryItems: [URLQueryItem]? { nil }
    
    var body: Data? { nil }
    
    var cachePolicy: URLRequest.CachePolicy { .useProtocolCachePolicy }
    
    var timeoutInterval: TimeInterval { 30 }
    
    /// Constructs the full URL for this endpoint.
    var url: URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems?.isEmpty == false ? queryItems : nil
        return components?.url
    }
    
    /// Constructs a URLRequest for this endpoint.
    func makeRequest() throws -> URLRequest {
        guard let url = url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.cachePolicy = cachePolicy
        request.timeoutInterval = timeoutInterval
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        request.httpBody = body
        
        return request
    }
}

// MARK: - Convenience Initializers

/// A concrete endpoint implementation for simple use cases.
public struct SimpleEndpoint: Endpoint {
    public let baseURL: URL
    public let path: String
    public let method: HTTPMethod
    public let headers: [String: String]
    public let queryItems: [URLQueryItem]?
    public let body: Data?
    public let cachePolicy: URLRequest.CachePolicy
    public let timeoutInterval: TimeInterval
    
    public init(
        baseURL: URL,
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String] = ["Content-Type": "application/json", "Accept": "application/json"],
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        timeoutInterval: TimeInterval = 30
    ) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
        self.cachePolicy = cachePolicy
        self.timeoutInterval = timeoutInterval
    }
    
    /// Creates an endpoint with a JSON-encodable body.
    public init<T: Encodable>(
        baseURL: URL,
        path: String,
        method: HTTPMethod = .post,
        headers: [String: String] = ["Content-Type": "application/json", "Accept": "application/json"],
        queryItems: [URLQueryItem]? = nil,
        body: T,
        encoder: JSONEncoder = JSONEncoder(),
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        timeoutInterval: TimeInterval = 30
    ) throws {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = try encoder.encode(body)
        self.cachePolicy = cachePolicy
        self.timeoutInterval = timeoutInterval
    }
}
