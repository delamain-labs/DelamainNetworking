// DelamainNetworking
// A modern, async/await networking library for Swift.
//
// Created by Delamain
// https://github.com/delamain-labs/DelamainNetworking

/// DelamainNetworking provides a clean, type-safe, and testable networking layer
/// built on Swift Concurrency.
///
/// ## Quick Start
///
/// ```swift
/// // Define your API endpoints
/// enum MyAPI: Endpoint {
///     case getUser(id: String)
///     case createUser(User)
///
///     var baseURL: URL { URL(string: "https://api.example.com")! }
///
///     var path: String {
///         switch self {
///         case .getUser(let id): return "/users/\(id)"
///         case .createUser: return "/users"
///         }
///     }
///
///     var method: HTTPMethod {
///         switch self {
///         case .getUser: return .get
///         case .createUser: return .post
///         }
///     }
///
///     var body: Data? {
///         switch self {
///         case .getUser: return nil
///         case .createUser(let user): return try? JSONEncoder().encode(user)
///         }
///     }
/// }
///
/// // Create a client
/// let client = URLSessionNetworkClient()
///
/// // Make requests
/// let user: User = try await client.request(MyAPI.getUser(id: "123"))
/// ```
///
/// ## Features
///
/// - **Async/Await**: Built entirely on Swift Concurrency
/// - **Type-Safe**: Generic request methods with Codable support
/// - **Testable**: Protocol-based design with mock client included
/// - **Interceptors**: Easily add authentication, logging, and more
/// - **Swift 6 Ready**: Full Sendable conformance
///

// Re-export all public types
@_exported import Foundation
