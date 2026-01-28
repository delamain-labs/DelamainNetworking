import Foundation

/// A mock network client for testing and SwiftUI previews.
public actor MockNetworkClient: NetworkClient {
    /// A mock response configuration.
    public struct MockResponse: Sendable {
        public let data: Data
        public let statusCode: Int
        public let delay: TimeInterval

        public init(data: Data, statusCode: Int = 200, delay: TimeInterval = 0) {
            self.data = data
            self.statusCode = statusCode
            self.delay = delay
        }

        /// Creates a mock response from an Encodable value.
        public static func json<T: Encodable>(
            _ value: T,
            statusCode: Int = 200,
            delay: TimeInterval = 0,
            encoder: JSONEncoder = JSONEncoder()
        ) throws -> MockResponse {
            let data = try encoder.encode(value)
            return MockResponse(data: data, statusCode: statusCode, delay: delay)
        }

        /// Creates an error response.
        public static func error(statusCode: Int, message: String = "", delay: TimeInterval = 0) -> MockResponse {
            let data = message.data(using: .utf8) ?? Data()
            return MockResponse(data: data, statusCode: statusCode, delay: delay)
        }
    }

    private var responses: [String: MockResponse] = [:]
    private var defaultResponse: MockResponse?
    private var requestHistory: [URLRequest] = []

    public init() {}

    /// Registers a mock response for a specific path.
    public func register(path: String, response: MockResponse) {
        responses[path] = response
    }

    /// Registers a mock response for a specific path with a JSON value.
    public func register<T: Encodable>(path: String, json: T, statusCode: Int = 200) throws {
        responses[path] = try .json(json, statusCode: statusCode)
    }

    /// Sets the default response for unregistered paths.
    public func setDefault(response: MockResponse) {
        defaultResponse = response
    }

    /// Returns all requests made to this mock client.
    public func getRequestHistory() -> [URLRequest] {
        requestHistory
    }

    /// Clears the request history.
    public func clearHistory() {
        requestHistory.removeAll()
    }

    public func request<T: Decodable & Sendable>(
        _ endpoint: some Endpoint,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let data = try await requestData(endpoint)
        return try decoder.decode(T.self, from: data)
    }

    public func request(_ endpoint: some Endpoint) async throws {
        _ = try await requestData(endpoint)
    }

    public func requestData(_ endpoint: some Endpoint) async throws -> Data {
        let request = try endpoint.makeRequest()
        requestHistory.append(request)

        let path = endpoint.path
        let response = responses[path] ?? defaultResponse

        guard let mockResponse = response else {
            throw NetworkError.custom("No mock response registered for path: \(path)")
        }

        if mockResponse.delay > 0 {
            try await Task.sleep(for: .seconds(mockResponse.delay))
        }

        guard (200...299).contains(mockResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: mockResponse.statusCode, data: mockResponse.data)
        }

        return mockResponse.data
    }
}

// MARK: - Preview Helpers

#if DEBUG
public extension MockNetworkClient {
    /// Creates a mock client pre-configured with sample data for previews.
    /// Note: This is an async factory method to properly handle the setup.
    static func preview<T: Encodable & Sendable>(returning value: T) async -> MockNetworkClient {
        let client = MockNetworkClient()
        do {
            let response = try MockResponse.json(value)
            await client.setDefault(response: response)
        } catch {
            await client.setDefault(response: .error(statusCode: 500, message: "Mock encoding failed"))
        }
        return client
    }

    /// Creates a mock client with pre-encoded data (sync version for previews).
    static func preview(data: Data, statusCode: Int = 200) -> MockNetworkClient {
        let client = MockNetworkClient()
        let response = MockResponse(data: data, statusCode: statusCode)
        // Use nonisolated(unsafe) for preview-only sync initialization
        Task { await client.setDefault(response: response) }
        return client
    }
}
#endif
