import Testing
import Foundation
@testable import DelamainNetworking

// MARK: - Test Models

struct TestUser: Codable, Sendable, Equatable {
    let id: Int
    let name: String
    let email: String
}

// MARK: - DTO Mapping Test Models

// swiftlint:disable identifier_name
struct UserDTO: Codable, Sendable, DomainMappable {
    let user_id: Int
    let display_name: String
    let email_address: String

    func toDomain() -> DomainUser {
        DomainUser(
            id: user_id,
            name: display_name,
            email: email_address
        )
    }
}
// swiftlint:enable identifier_name

struct DomainUser: Equatable {
    let id: Int
    let name: String
    let email: String
}

// MARK: - Test Endpoint

enum TestAPI: Endpoint {
    case getUser(id: Int)
    case getUsers
    case createUser(TestUser)

    var baseURL: URL { URL(string: "https://api.example.com")! }

    var path: String {
        switch self {
        case .getUser(let id): return "/users/\(id)"
        case .getUsers: return "/users"
        case .createUser: return "/users"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getUser, .getUsers: return .get
        case .createUser: return .post
        }
    }

    var body: Data? {
        switch self {
        case .getUser, .getUsers: return nil
        case .createUser(let user): return try? JSONEncoder().encode(user)
        }
    }
}

// MARK: - Tests

@Suite("NetworkClient Tests")
struct NetworkClientTests {

    @Test("MockNetworkClient returns registered response")
    func mockClientReturnsRegisteredResponse() async throws {
        let mockClient = MockNetworkClient()
        let expectedUser = TestUser(id: 1, name: "Test User", email: "test@example.com")

        try await mockClient.register(path: "/users/1", json: expectedUser)

        let user: TestUser = try await mockClient.request(TestAPI.getUser(id: 1))

        #expect(user == expectedUser)
    }

    @Test("MockNetworkClient records request history")
    func mockClientRecordsHistory() async throws {
        let mockClient = MockNetworkClient()
        let user = TestUser(id: 1, name: "Test", email: "test@example.com")

        try await mockClient.register(path: "/users/1", json: user)

        let _: TestUser = try await mockClient.request(TestAPI.getUser(id: 1))

        let history = await mockClient.getRequestHistory()
        #expect(history.count == 1)
        #expect(history.first?.url?.path == "/users/1")
    }

    @Test("MockNetworkClient throws for HTTP errors")
    func mockClientThrowsForHTTPError() async throws {
        let mockClient = MockNetworkClient()
        await mockClient.setDefault(response: .error(statusCode: 404, message: "Not found"))

        await #expect(throws: NetworkError.self) {
            let _: TestUser = try await mockClient.request(TestAPI.getUser(id: 999))
        }
    }

    @Test("Request maps DTO to domain model")
    func requestMapsDTOToDomainModel() async throws {
        let mockClient = MockNetworkClient()
        let dto = UserDTO(user_id: 42, display_name: "Test User", email_address: "test@example.com")

        try await mockClient.register(path: "/users/42", json: dto)

        let domainUser = try await mockClient.request(
            TestAPI.getUser(id: 42),
            mapping: UserDTO.self
        )

        #expect(domainUser == DomainUser(id: 42, name: "Test User", email: "test@example.com"))
    }

    @Test("SimpleEndpoint constructs correct URL")
    func simpleEndpointConstructsURL() throws {
        let endpoint = SimpleEndpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "/users",
            method: .get,
            queryItems: [
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "limit", value: "10")
            ]
        )

        let url = endpoint.url
        #expect(url?.absoluteString == "https://api.example.com/users?page=1&limit=10")
    }

    @Test("SimpleEndpoint creates request with body")
    func simpleEndpointCreatesRequestWithBody() throws {
        let user = TestUser(id: 1, name: "Test", email: "test@example.com")

        let endpoint = try SimpleEndpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "/users",
            method: .post,
            body: user
        )

        let request = try endpoint.makeRequest()

        #expect(request.httpMethod == "POST")
        #expect(request.httpBody != nil)

        let decodedUser = try JSONDecoder().decode(TestUser.self, from: request.httpBody!)
        #expect(decodedUser == user)
    }
}

@Suite("Interceptor Tests")
struct InterceptorTests {

    @Test("HeaderInterceptor adds headers")
    func headerInterceptorAddsHeaders() async throws {
        let interceptor = HeaderInterceptor(headers: [
            "X-Custom-Header": "custom-value"
        ])

        var request = URLRequest(url: URL(string: "https://example.com")!)
        request = try await interceptor.intercept(request)

        #expect(request.value(forHTTPHeaderField: "X-Custom-Header") == "custom-value")
    }

    @Test("BearerTokenInterceptor adds authorization header")
    func bearerTokenInterceptorAddsAuth() async throws {
        let interceptor = BearerTokenInterceptor(token: "test-token-123")

        var request = URLRequest(url: URL(string: "https://example.com")!)
        request = try await interceptor.intercept(request)

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token-123")
    }

    @Test("BearerTokenInterceptor uses dynamic token provider")
    func bearerTokenInterceptorUsesDynamicProvider() async throws {
        let counter = Counter()
        let interceptor = BearerTokenInterceptor {
            let count = await counter.increment()
            return "dynamic-token-\(count)"
        }

        var request = URLRequest(url: URL(string: "https://example.com")!)
        request = try await interceptor.intercept(request)

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer dynamic-token-1")
    }
}

// Helper actor for thread-safe counting in tests
private actor Counter {
    private var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}

@Suite("NetworkError Tests")
struct NetworkErrorTests {

    @Test("NetworkError provides localized descriptions")
    func networkErrorHasDescriptions() {
        let errors: [NetworkError] = [
            .invalidURL,
            .httpError(statusCode: 404, data: nil),
            .noData,
            .cancelled,
            .custom("Test error")
        ]

        for error in errors {
            #expect(error.localizedDescription.isEmpty == false)
        }
    }
}

@Suite("Retry Tests")
struct RetryTests {

    @Test("Retry configuration defaults are reasonable")
    func retryConfigurationDefaults() {
        let config = RetryConfiguration.default

        #expect(config.maxRetries == 3)
        #expect(config.baseDelay == 1.0)
        #expect(config.maxDelay == 30.0)
        #expect(config.retryableStatusCodes.contains(503))
        #expect(config.retryableStatusCodes.contains(429))
        #expect(!config.retryableStatusCodes.contains(404))
    }

    @Test("Retry configuration can be customized")
    func retryConfigurationCustomization() {
        let config = RetryConfiguration(
            maxRetries: 5,
            baseDelay: 2.0,
            maxDelay: 60.0,
            retryableStatusCodes: [500, 502]
        )

        #expect(config.maxRetries == 5)
        #expect(config.baseDelay == 2.0)
        #expect(config.maxDelay == 60.0)
        #expect(config.retryableStatusCodes.count == 2)
    }

    @Test("Client can be created with retry configuration")
    func clientWithRetryConfiguration() {
        let retryConfig = RetryConfiguration(
            maxRetries: 2,
            baseDelay: 0.5
        )

        let client = URLSessionNetworkClient.configured(
            enableLogging: true,
            retryConfiguration: retryConfig
        )

        // Client should be created successfully with retry config
        #expect(client != nil)
    }

    // NOTE: Behavioral retry tests (verifying actual retry on 503, etc.) require
    // either a mock URLSession or extracting retry logic into a testable component.
    // The retry logic is tightly coupled to URLSessionNetworkClient's performRequest.
    // TODO: Consider extracting RetryExecutor for better testability.
}

@Suite("Timeout Tests")
struct TimeoutTests {

    @Test("Endpoint has default timeout of 30 seconds")
    func endpointDefaultTimeout() throws {
        let endpoint = SimpleEndpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "/test"
        )

        #expect(endpoint.timeoutInterval == 30)
    }

    @Test("Endpoint timeout can be customized")
    func endpointCustomTimeout() throws {
        let endpoint = SimpleEndpoint(
            baseURL: URL(string: "https://api.example.com")!,
            path: "/test",
            timeoutInterval: 60
        )

        #expect(endpoint.timeoutInterval == 60)
    }

    @Test("TimeoutInterceptor overrides request timeout")
    func timeoutInterceptorOverridesTimeout() async throws {
        let interceptor = TimeoutInterceptor(timeoutInterval: 15)

        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.timeoutInterval = 30

        request = try await interceptor.intercept(request)

        #expect(request.timeoutInterval == 15)
    }

    @Test("Client can be configured with default timeout")
    func clientWithDefaultTimeout() {
        let client = URLSessionNetworkClient.configured(
            timeoutInterval: 45
        )

        // Client should be created successfully with timeout
        #expect(client != nil)
    }
}

@Suite("Logging Tests")
struct LoggingTests {

    @Test("LoggingConfiguration has sensible defaults")
    func loggingConfigurationDefaults() {
        let config = LoggingConfiguration.default

        #expect(config.shouldRedact(header: "Authorization"))
        #expect(config.shouldRedact(header: "Cookie"))
        #expect(config.maxBodyLogSize == 1024)
        #expect(config.logRequestBody == true)
        #expect(config.logResponseBody == true)
    }

    @Test("Production logging configuration is strict")
    func productionLoggingConfiguration() {
        let config = LoggingConfiguration.production

        #expect(config.shouldRedact(header: "Authorization"))
        #expect(config.maxBodyLogSize == 0)
        #expect(config.logRequestBody == false)
        #expect(config.logResponseBody == false)
    }

    @Test("Header redaction is case-insensitive")
    func headerRedactionCaseInsensitive() {
        let config = LoggingConfiguration(
            redactedHeaders: ["Authorization", "X-API-Key"]
        )

        // Same case
        #expect(config.shouldRedact(header: "Authorization"))
        #expect(config.shouldRedact(header: "X-API-Key"))

        // Different cases (HTTP headers are case-insensitive)
        #expect(config.shouldRedact(header: "authorization"))
        #expect(config.shouldRedact(header: "AUTHORIZATION"))
        #expect(config.shouldRedact(header: "x-api-key"))
        #expect(config.shouldRedact(header: "X-Api-Key"))

        // Non-redacted headers
        #expect(!config.shouldRedact(header: "Content-Type"))
        #expect(!config.shouldRedact(header: "Accept"))
    }

    @Test("LoggingInterceptor can be created with custom configuration")
    func loggingInterceptorCustomConfiguration() {
        let config = LoggingConfiguration(
            redactedHeaders: ["X-Custom-Token"],
            maxBodyLogSize: 512
        )

        let interceptor = LoggingInterceptor(configuration: config)
        #expect(interceptor != nil)
    }

    @Test("Client can be configured with logging")
    func clientWithLogging() {
        let client = URLSessionNetworkClient.configured(
            enableLogging: true,
            loggingConfiguration: .production
        )

        #expect(client != nil)
    }
}

@Suite("Mock Sequence Tests")
struct MockSequenceTests {

    @Test("MockClient returns sequential responses")
    func mockClientReturnsSequentialResponses() async throws {
        let mockClient = MockNetworkClient()
        let user = TestUser(id: 1, name: "Test", email: "test@example.com")

        // Register: first call fails with 503, second succeeds
        await mockClient.registerSequence(path: "/users/1", responses: [
            .error(statusCode: 503, message: "Service Unavailable"),
            try .json(user)
        ])

        // First call should fail
        await #expect(throws: NetworkError.self) {
            let _: TestUser = try await mockClient.request(TestAPI.getUser(id: 1))
        }

        // Second call should succeed
        let result: TestUser = try await mockClient.request(TestAPI.getUser(id: 1))
        #expect(result == user)

        // History should show both attempts
        let history = await mockClient.getRequestHistory()
        #expect(history.count == 2)
    }

    @Test("MockClient repeats last response in sequence")
    func mockClientRepeatsLastResponse() async throws {
        let mockClient = MockNetworkClient()
        let user = TestUser(id: 1, name: "Test", email: "test@example.com")

        // Register single success response
        await mockClient.registerSequence(path: "/users/1", responses: [
            try .json(user)
        ])

        // Multiple calls should all succeed (last response repeats)
        for _ in 1...3 {
            let result: TestUser = try await mockClient.request(TestAPI.getUser(id: 1))
            #expect(result == user)
        }
    }
}

@Suite("Metrics Tests")
struct MetricsTests {

    @Test("InMemoryMetricsCollector records metrics")
    func metricsCollectorRecordsMetrics() async {
        let collector = InMemoryMetricsCollector()
        await collector.record(RequestMetrics(
            endpoint: "/test", statusCode: 200, duration: 1.5,
            bytesSent: 100, bytesReceived: 200, isSuccess: true
        ))

        let allMetrics = await collector.getAllMetrics()
        #expect(allMetrics.count == 1)
        #expect(allMetrics.first?.endpoint == "/test")
    }

    @Test("Metrics statistics are calculated correctly")
    func metricsStatisticsCalculation() async {
        let collector = InMemoryMetricsCollector()

        await collector.record(RequestMetrics(
            endpoint: "/s1", statusCode: 200, duration: 1.0,
            bytesSent: 100, bytesReceived: 200, isSuccess: true
        ))
        await collector.record(RequestMetrics(
            endpoint: "/s2", statusCode: 201, duration: 2.0,
            bytesSent: 150, bytesReceived: 300, isSuccess: true
        ))
        await collector.record(RequestMetrics(
            endpoint: "/fail", statusCode: 500, duration: 0.5,
            bytesSent: 50, bytesReceived: 100, isSuccess: false
        ))

        let stats = await collector.getStatistics()
        #expect(stats.totalRequests == 3)
        #expect(stats.successfulRequests == 2)
        #expect(stats.failedRequests == 1)
        #expect(stats.totalBytesSent == 300)
    }

    @Test("Client can be configured with metrics collector")
    func clientWithMetricsCollector() async {
        let collector = InMemoryMetricsCollector()
        _ = URLSessionNetworkClient.configured(metricsCollector: collector)
        let stats = await collector.getStatistics()
        #expect(stats.totalRequests == 0)
    }
}
