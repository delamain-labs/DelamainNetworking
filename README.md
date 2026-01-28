# DelamainNetworking

A modern, async/await networking library for Swift. Clean, type-safe, and testable.

[![CI](https://github.com/delamain-labs/DelamainNetworking/actions/workflows/ci.yml/badge.svg)](https://github.com/delamain-labs/DelamainNetworking/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%20|%20macOS%2014-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- 🚀 **Pure Async/Await** — Built entirely on Swift Concurrency
- 🔒 **Type-Safe** — Generic request methods with Codable support
- 🧪 **Testable** — Protocol-based design with mock client included
- 🔌 **Interceptors** — Easily add authentication, logging, retry logic
- ✅ **Swift 6 Ready** — Full Sendable conformance, no data races

> 📍 See our [Roadmap](ROADMAP.md) for upcoming features

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/delamain-labs/DelamainNetworking.git", from: "1.0.0")
]
```

## Quick Start

### 1. Define Your Endpoints

```swift
import DelamainNetworking

enum GitHubAPI: Endpoint {
    case getUser(username: String)
    case getRepos(username: String)
    
    var baseURL: URL { URL(string: "https://api.github.com")! }
    
    var path: String {
        switch self {
        case .getUser(let username): return "/users/\(username)"
        case .getRepos(let username): return "/users/\(username)/repos"
        }
    }
    
    var method: HTTPMethod { .get }
}
```

### 2. Create a Client

```swift
// Simple client
let client = URLSessionNetworkClient()

// Client with auth and logging
let client = URLSessionNetworkClient(
    interceptors: [
        BearerTokenInterceptor(token: "your-token"),
        LoggingInterceptor()
    ],
    responseHandlers: [
        LoggingResponseHandler()
    ]
)
```

### 3. Make Requests

```swift
// Decode response to a type
let user: GitHubUser = try await client.request(GitHubAPI.getUser(username: "delamain"))

// Get raw data
let data = try await client.requestData(GitHubAPI.getUser(username: "delamain"))

// Fire and forget (no response body expected)
try await client.request(MyAPI.logout)
```

## Endpoints

The `Endpoint` protocol defines everything about a request:

```swift
public protocol Endpoint: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
}
```

Most properties have sensible defaults. For simple cases, use `SimpleEndpoint`:

```swift
let endpoint = SimpleEndpoint(
    baseURL: URL(string: "https://api.example.com")!,
    path: "/users",
    queryItems: [URLQueryItem(name: "page", value: "1")]
)

// With a JSON body
let endpoint = try SimpleEndpoint(
    baseURL: URL(string: "https://api.example.com")!,
    path: "/users",
    method: .post,
    body: newUser  // Any Encodable
)
```

## Interceptors

Interceptors modify requests before they're sent:

```swift
// Add headers to every request
let headerInterceptor = HeaderInterceptor(headers: [
    "X-API-Key": "your-api-key"
])

// Add Bearer token authentication
let authInterceptor = BearerTokenInterceptor(token: "your-token")

// Or with a dynamic token provider (for refresh tokens)
let authInterceptor = BearerTokenInterceptor {
    try await authManager.getValidToken()
}

// Log all requests
let loggingInterceptor = LoggingInterceptor()
```

## Response Handlers

Response handlers process responses before they're returned:

```swift
// Log all responses
let loggingHandler = LoggingResponseHandler()
```

## DTO Mapping

Keep your API responses separate from domain models with `DomainMappable`:

```swift
// DTO matches API response exactly
struct UserDTO: Decodable, DomainMappable {
    let user_id: String
    let display_name: String?
    let created_at: String
    
    // Transform to your clean domain model
    func toDomain() -> User {
        User(
            id: user_id,
            name: display_name ?? "Anonymous",
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? .now
        )
    }
}

// Domain model - what your app actually uses
struct User {
    let id: String
    let name: String
    let createdAt: Date
}
```

Use the mapping variant of `request`:

```swift
// Returns User, not UserDTO
let user = try await client.request(
    API.getUser(id: "123"),
    mapping: UserDTO.self
)
```

**Why use this pattern?**
- API changes don't ripple through your codebase
- Domain models stay clean (no weird optionals, better naming)
- Codable noise isolated to DTOs
- Mapping logic is testable in isolation

## Testing

Use `MockNetworkClient` for tests and SwiftUI previews:

```swift
@Test func testFetchUser() async throws {
    let mockClient = MockNetworkClient()
    let expectedUser = User(id: 1, name: "Test")
    
    try await mockClient.register(path: "/users/1", json: expectedUser)
    
    let user: User = try await mockClient.request(MyAPI.getUser(id: 1))
    
    #expect(user == expectedUser)
}
```

### SwiftUI Previews

```swift
#Preview {
    UserView()
        .environment(\.networkClient, MockNetworkClient.preview(
            returning: User(id: 1, name: "Preview User")
        ))
}
```

## Error Handling

All errors are wrapped in `NetworkError`:

```swift
do {
    let user: User = try await client.request(endpoint)
} catch let error as NetworkError {
    switch error {
    case .httpError(let statusCode, let data):
        // Handle HTTP errors (4xx, 5xx)
    case .decodingError(let underlyingError):
        // Handle JSON decoding failures
    case .networkError(let underlyingError):
        // Handle connection issues
    case .invalidURL:
        // Handle malformed URLs
    case .cancelled:
        // Request was cancelled
    default:
        break
    }
}
```

## Requirements

- iOS 17.0+ / macOS 14.0+ / watchOS 10.0+ / tvOS 17.0+ / visionOS 1.0+
- Swift 6.0+
- Xcode 16.0+

## Development

### Setup

```bash
# Clone the repo
git clone https://github.com/delamain-labs/DelamainNetworking.git
cd DelamainNetworking

# Install git hooks (runs SwiftLint on commit)
./scripts/install-hooks.sh

# Install SwiftLint if needed
brew install swiftlint
```

### Running Tests

```bash
swift test
```

### Linting

```bash
# Check for issues
swiftlint lint

# Auto-fix issues
swiftlint --fix
```

## License

MIT License. See [LICENSE](LICENSE) for details.

---

Built by [Delamain](https://github.com/delamain-labs) 🔹
