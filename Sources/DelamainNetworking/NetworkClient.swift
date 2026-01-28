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
    private let metricsCollector: (any MetricsCollector)?

    /// Creates a new URLSession-based network client.
    /// - Parameters:
    ///   - session: The URLSession to use. Defaults to `.shared`.
    ///   - interceptors: Request interceptors to apply before each request.
    ///   - responseHandlers: Response handlers to process responses.
    ///   - metricsCollector: Optional metrics collector for tracking request statistics.
    public init(
        session: URLSession = .shared,
        interceptors: [any RequestInterceptor] = [],
        responseHandlers: [any ResponseHandler] = [],
        metricsCollector: (any MetricsCollector)? = nil
    ) {
        self.session = session
        self.interceptors = interceptors
        self.responseHandlers = responseHandlers
        self.metricsCollector = metricsCollector
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

        // Start metrics tracking
        let startTime = Date()
        let endpointPath = request.url?.path ?? "unknown"
        let bytesSent = Int64(request.httpBody?.count ?? 0)

        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            await recordFailureMetrics(
                endpoint: endpointPath,
                startTime: startTime,
                bytesSent: bytesSent
            )
            throw NetworkError.cancelled
        } catch {
            await recordFailureMetrics(
                endpoint: endpointPath,
                startTime: startTime,
                bytesSent: bytesSent
            )
            throw NetworkError.networkError(error)
        }

        // Add metrics handler if collector is configured
        var handlers = responseHandlers
        if let collector = metricsCollector {
            let metricsHandler = MetricsResponseHandler(
                collector: collector,
                startTime: startTime,
                endpoint: endpointPath,
                bytesSent: bytesSent
            )
            handlers.append(metricsHandler)
        }

        // Process response through handlers (including metrics)
        var processedData = data
        for handler in handlers {
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

    /// Records metrics for failed requests.
    private func recordFailureMetrics(
        endpoint: String,
        startTime: Date,
        bytesSent: Int64
    ) async {
        guard let collector = metricsCollector else { return }

        let duration = Date().timeIntervalSince(startTime)
        let metrics = RequestMetrics(
            endpoint: endpoint,
            statusCode: nil,
            duration: duration,
            bytesSent: bytesSent,
            bytesReceived: 0,
            isSuccess: false,
            timestamp: startTime
        )
        await collector.record(metrics)
    }
}

// MARK: - Convenience Factory

public extension URLSessionNetworkClient {
    /// Creates a client with common configuration.
    /// - Parameters:
    ///   - baseHeaders: Headers to add to every request.
    ///   - enableLogging: Enable request/response logging.
    ///   - metricsCollector: Optional metrics collector for tracking request statistics.
    static func configured(
        baseHeaders: [String: String] = [:],
        enableLogging: Bool = false,
        metricsCollector: (any MetricsCollector)? = nil
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
            metricsCollector: metricsCollector
        )
    }
}
