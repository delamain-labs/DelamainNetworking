// DelamainNetworking
// A modern, async/await networking library for Swift.
//
// Created by Delamain
// https://github.com/delamain-labs/DelamainNetworking

// Re-export all public types
@_exported import Foundation

// MARK: - Module Overview

// DelamainNetworking provides a clean, type-safe, and testable networking layer
// built on Swift Concurrency.
//
// Quick Start:
//
//     // Define your API endpoints
//     enum MyAPI: Endpoint {
//         case getUser(id: String)
//         // ...
//     }
//
//     // Create a client
//     let client = URLSessionNetworkClient()
//
//     // Make requests
//     let user: User = try await client.request(MyAPI.getUser(id: "123"))
//
// Features:
// - Async/Await: Built entirely on Swift Concurrency
// - Type-Safe: Generic request methods with Codable support
// - Testable: Protocol-based design with mock client included
// - Interceptors: Easily add authentication, logging, and more
// - Swift 6 Ready: Full Sendable conformance
