import Foundation
import os.log

// MARK: - Request Interceptor Protocol

/// A protocol for intercepting and modifying requests before they are sent.
public protocol RequestInterceptor: Sendable {
    /// Intercepts a request, potentially modifying it.
    /// - Parameter request: The original request.
    /// - Returns: The potentially modified request.
    func intercept(_ request: URLRequest) async throws -> URLRequest
}

// MARK: - Response Handler Protocol

/// A protocol for handling responses before they are returned to the caller.
public protocol ResponseHandler: Sendable {
    /// Handles a response, potentially modifying the data.
    /// - Parameters:
    ///   - data: The response data.
    ///   - response: The URL response.
    /// - Returns: The potentially modified data.
    func handle(_ data: Data, response: URLResponse) async throws -> Data
}

// MARK: - Header Interceptor

/// Adds headers to every request.
public struct HeaderInterceptor: RequestInterceptor {
    private let headers: [String: String]
    
    public init(headers: [String: String]) {
        self.headers = headers
    }
    
    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        for (key, value) in headers {
            modifiedRequest.setValue(value, forHTTPHeaderField: key)
        }
        return modifiedRequest
    }
}

// MARK: - Bearer Token Interceptor

/// Adds a Bearer token to the Authorization header.
public struct BearerTokenInterceptor: RequestInterceptor {
    private let tokenProvider: @Sendable () async throws -> String
    
    /// Creates an interceptor with a static token.
    public init(token: String) {
        self.tokenProvider = { token }
    }
    
    /// Creates an interceptor with a dynamic token provider.
    public init(tokenProvider: @escaping @Sendable () async throws -> String) {
        self.tokenProvider = tokenProvider
    }
    
    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        let token = try await tokenProvider()
        modifiedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return modifiedRequest
    }
}

// MARK: - Logging Interceptor

/// Logs requests for debugging.
public struct LoggingInterceptor: RequestInterceptor {
    private let logger: Logger
    
    public init(subsystem: String = "DelamainNetworking", category: String = "Request") {
        self.logger = Logger(subsystem: subsystem, category: category)
    }
    
    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        logger.debug("➡️ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")")
        
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            logger.debug("   Headers: \(headers.map { "\($0.key): \($0.value)" }.joined(separator: ", "))")
        }
        
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            logger.debug("   Body: \(bodyString.prefix(500))")
        }
        
        return request
    }
}

// MARK: - Logging Response Handler

/// Logs responses for debugging.
public struct LoggingResponseHandler: ResponseHandler {
    private let logger: Logger
    
    public init(subsystem: String = "DelamainNetworking", category: String = "Response") {
        self.logger = Logger(subsystem: subsystem, category: category)
    }
    
    public func handle(_ data: Data, response: URLResponse) async throws -> Data {
        if let httpResponse = response as? HTTPURLResponse {
            let emoji = (200...299).contains(httpResponse.statusCode) ? "✅" : "❌"
            logger.debug("\(emoji) \(httpResponse.statusCode) \(response.url?.absoluteString ?? "?")")
        }
        
        if let bodyString = String(data: data, encoding: .utf8) {
            logger.debug("   Response: \(bodyString.prefix(500))")
        }
        
        return data
    }
}

// MARK: - Retry Interceptor

/// Configuration for retry behavior.
public struct RetryConfiguration: Sendable {
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let retryableStatusCodes: Set<Int>
    
    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        retryableStatusCodes: Set<Int> = [408, 429, 500, 502, 503, 504]
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.retryableStatusCodes = retryableStatusCodes
    }
    
    public static let `default` = RetryConfiguration()
}
