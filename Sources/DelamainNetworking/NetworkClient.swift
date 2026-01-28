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

// MARK: - Domain Mapping

public extension NetworkClient {
    /// Performs a network request, decodes to a DTO, and maps to a domain model.
    /// - Parameters:
    ///   - endpoint: The endpoint to request.
    ///   - dtoType: The DTO type to decode (must conform to DomainMappable).
    ///   - decoder: The JSON decoder to use. Defaults to a new instance.
    /// - Returns: The mapped domain model.
    func request<DTO: Decodable & Sendable & DomainMappable>(
        _ endpoint: some Endpoint,
        mapping dtoType: DTO.Type,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> DTO.DomainModel {
        let dto: DTO = try await request(endpoint, decoder: decoder)
        return try dto.toDomain()
    }
}

// MARK: - URLSession Implementation

/// A network client implementation using URLSession.
public actor URLSessionNetworkClient: NetworkClient {
    private let session: URLSession
    private let interceptors: [any RequestInterceptor]
    private let responseHandlers: [any ResponseHandler]
    private let retryConfiguration: RetryConfiguration?

    /// Creates a new URLSession-based network client.
    /// - Parameters:
    ///   - session: The URLSession to use. Defaults to `.shared`.
    ///   - interceptors: Request interceptors to apply before each request.
    ///   - responseHandlers: Response handlers to process responses.
    ///   - retryConfiguration: Optional retry configuration. If nil, retries are disabled.
    public init(
        session: URLSession = .shared,
        interceptors: [any RequestInterceptor] = [],
        responseHandlers: [any ResponseHandler] = [],
        retryConfiguration: RetryConfiguration? = nil
    ) {
        self.session = session
        self.interceptors = interceptors
        self.responseHandlers = responseHandlers
        self.retryConfiguration = retryConfiguration
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

        // Execute with retry if configured
        if let retryConfig = retryConfiguration {
            return try await performRequestWithRetry(request, configuration: retryConfig)
        } else {
            return try await performRequest(request)
        }
    }

    /// Performs a single request attempt without retry.
    private func performRequest(_ request: URLRequest) async throws -> Data {
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

    /// Performs a request with exponential backoff retry.
    private func performRequestWithRetry(
        _ request: URLRequest,
        configuration: RetryConfiguration
    ) async throws -> Data {
        var attempt = 0
        var lastError: Error?

        while attempt <= configuration.maxRetries {
            do {
                return try await performRequest(request)
            } catch let error as NetworkError {
                lastError = error

                // Don't retry on cancelled requests
                if case .cancelled = error {
                    throw error
                }

                // Check if this error is retryable
                let shouldRetry: Bool
                if case .httpError(let statusCode, _) = error {
                    shouldRetry = configuration.retryableStatusCodes.contains(statusCode)
                } else if case .networkError = error {
                    // Retry network errors (connection issues, timeouts, etc.)
                    shouldRetry = true
                } else {
                    // Don't retry decoding errors, invalid URLs, etc.
                    shouldRetry = false
                }

                guard shouldRetry && attempt < configuration.maxRetries else {
                    throw error
                }

                // Calculate exponential backoff delay
                let exponentialDelay = configuration.baseDelay * pow(2.0, Double(attempt))
                let delay = min(exponentialDelay, configuration.maxDelay)

                // Add jitter (random 0-25% of delay) to prevent thundering herd
                let jitter = delay * Double.random(in: 0...0.25)
                let finalDelay = delay + jitter

                try await Task.sleep(nanoseconds: UInt64(finalDelay * 1_000_000_000))

                attempt += 1
            } catch {
                // Non-NetworkError errors are thrown immediately
                throw error
            }
        }

        // This should never be reached due to the guard above, but Swift requires it
        throw lastError ?? NetworkError.networkError(NSError(domain: "DelamainNetworking", code: -1))
    }
}

// MARK: - Convenience Factory

public extension URLSessionNetworkClient {
    /// Creates a client with common configuration.
    /// - Parameters:
    ///   - baseHeaders: Headers to add to every request.
    ///   - enableLogging: Enable request/response logging.
    ///   - retryConfiguration: Optional retry configuration with exponential backoff.
    static func configured(
        baseHeaders: [String: String] = [:],
        enableLogging: Bool = false,
        retryConfiguration: RetryConfiguration? = nil
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
            responseHandlers: handlers,
            retryConfiguration: retryConfiguration
        )
    }
}
