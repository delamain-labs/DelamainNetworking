import Testing
import Foundation
@testable import DelamainNetworking

// MARK: - Test Models

struct TestUser: Codable, Sendable, Equatable {
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
