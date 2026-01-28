import Foundation

/// A protocol defining the interface for making network requests.
public protocol NetworkClient: Sendable {
    /// Performs a network request and decodes the response.
    /// - Parameters:
    ///   - endpoint: The endpoint to request.
    ///   - decoder: The JSON decoder to use. Defaults to a new instance.
    /// - Returns: The decoded response.
    func request<T: Decodable & Sendable>(
        _ endpoint: some Endpoint,
        decoder: JSONDecoder
    ) async throws -> T
    
    /// Performs a network request without expecting a response body.
    /// - Parameter endpoint: The endpoint to request.
    func request(_ endpoint: some Endpoint) async throws
    
    /// Performs a network request and returns raw data.
    /// - Parameter endpoint: The endpoint to request.
    /// - Returns: The response data.
    func requestData(_ endpoint: some Endpoint) async throws -> Data
}

// MARK: - Default Parameter Values

public extension NetworkClient {
    func request<T: Decodable & Sendable>(
        _ endpoint: some Endpoint,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        try await request(endpoint, decoder: decoder)
    }
}

// MARK: - URLSession Implementation

/// A network client implementation using URLSession.
public actor URLSessionNetworkClient: NetworkClient {
    private let session: URLSession
    private let interceptors: [any RequestInterceptor]
    private let responseHandlers: [any ResponseHandler]
    
    /// Creates a new URLSession-based network client.
    /// - Parameters:
    ///   - session: The URLSession to use. Defaults to `.shared`.
    ///   - interceptors: Request interceptors to apply before each request.
    ///   - responseHandlers: Response handlers to process responses.
    public init(
        session: URLSession = .shared,
        interceptors: [any RequestInterceptor] = [],
        responseHandlers: [any ResponseHandler] = []
    ) {
        self.session = session
        self.interceptors = interceptors
        self.responseHandlers = responseHandlers
    }
    
    public func request<T: Decodable & Sendable>(
        _ endpoint: some Endpoint,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let data = try await requestData(endpoint)
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    
    public func request(_ endpoint: some Endpoint) async throws {
        _ = try await requestData(endpoint)
    }
    
    public func requestData(_ endpoint: some Endpoint) async throws -> Data {
        var request = try endpoint.makeRequest()
        
        // Apply interceptors
        for interceptor in interceptors {
            request = try await interceptor.intercept(request)
        }
        
        let (data, response): (Data, URLResponse)
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw NetworkError.cancelled
        } catch {
            throw NetworkError.networkError(error)
        }
        
        // Process response through handlers
        var processedData = data
        for handler in responseHandlers {
            processedData = try await handler.handle(processedData, response: response)
        }
        
        // Validate HTTP status code
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: processedData)
            }
        }
        
        return processedData
    }
}

// MARK: - Convenience Factory

public extension URLSessionNetworkClient {
    /// Creates a client with common configuration.
    /// - Parameters:
    ///   - baseHeaders: Headers to add to every request.
    ///   - logger: Optional logger for request/response logging.
    static func configured(
        baseHeaders: [String: String] = [:],
        enableLogging: Bool = false
    ) -> URLSessionNetworkClient {
        var interceptors: [any RequestInterceptor] = []
        var handlers: [any ResponseHandler] = []
        
        if !baseHeaders.isEmpty {
            interceptors.append(HeaderInterceptor(headers: baseHeaders))
        }
        
        if enableLogging {
            interceptors.append(LoggingInterceptor())
            handlers.append(LoggingResponseHandler())
        }
        
        return URLSessionNetworkClient(
            interceptors: interceptors,
            responseHandlers: handlers
        )
    }
}
