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

// MARK: - Logging Configuration

/// Configuration for request/response logging with privacy controls.
public struct LoggingConfiguration: Sendable {
    /// Headers to redact (e.g., "Authorization", "Cookie").
    public let redactedHeaders: Set<String>

    /// Maximum body size to log (in bytes). Bodies larger than this are truncated.
    public let maxBodyLogSize: Int

    /// Whether to log request bodies.
    public let logRequestBody: Bool

    /// Whether to log response bodies.
    public let logResponseBody: Bool

    public init(
        redactedHeaders: Set<String> = ["Authorization", "Cookie", "Set-Cookie", "X-API-Key", "X-Auth-Token"],
        maxBodyLogSize: Int = 1024,
        logRequestBody: Bool = true,
        logResponseBody: Bool = true
    ) {
        self.redactedHeaders = redactedHeaders
        self.maxBodyLogSize = maxBodyLogSize
        self.logRequestBody = logRequestBody
        self.logResponseBody = logResponseBody
    }

    public static let `default` = Self()

    /// Safe default for production: minimal logging with strict redaction.
    public static let production = Self(
        redactedHeaders: [
            "Authorization", "Cookie", "Set-Cookie",
            "X-API-Key", "X-Auth-Token", "X-Access-Token"
        ],
        maxBodyLogSize: 0,
        logRequestBody: false,
        logResponseBody: false
    )
}

// MARK: - Logging Interceptor

/// Logs requests for debugging with privacy-aware structured logging.
public struct LoggingInterceptor: RequestInterceptor {
    private let logger: Logger
    private let configuration: LoggingConfiguration

    public init(
        subsystem: String = "DelamainNetworking",
        category: String = "Request",
        configuration: LoggingConfiguration = .default
    ) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.configuration = configuration
    }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        let method = request.httpMethod ?? "UNKNOWN"
        let urlString = request.url?.absoluteString ?? "unknown"

        logger.info("➡️ \(method) \(urlString)")

        // Log headers with redaction
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                let redactedValue = configuration.redactedHeaders.contains(key) ? "<redacted>" : value
                logger.debug("   \(key): \(redactedValue)")
            }
        }

        // Log body if enabled
        if configuration.logRequestBody, let body = request.httpBody {
            let bodySize = body.count
            if bodySize <= configuration.maxBodyLogSize {
                if let bodyString = String(data: body, encoding: .utf8) {
                    logger.debug("   Body: \(bodyString)")
                } else {
                    logger.debug("   Body: <binary \(bodySize) bytes>")
                }
            } else {
                logger.debug("   Body: <\(bodySize) bytes, truncated>")
            }
        }

        return request
    }
}

// MARK: - Logging Response Handler

/// Logs responses for debugging with privacy-aware structured logging.
public struct LoggingResponseHandler: ResponseHandler {
    private let logger: Logger
    private let configuration: LoggingConfiguration

    public init(
        subsystem: String = "DelamainNetworking",
        category: String = "Response",
        configuration: LoggingConfiguration = .default
    ) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.configuration = configuration
    }

    public func handle(_ data: Data, response: URLResponse) async throws -> Data {
        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            let emoji = (200...299).contains(statusCode) ? "✅" : "❌"
            let urlString = response.url?.absoluteString ?? "unknown"

            logger.info("\(emoji) \(statusCode) \(urlString)")

            // Log response headers with redaction
            for (key, value) in httpResponse.allHeaderFields.sorted(by: { "\($0.key)" < "\($1.key)" }) {
                let headerName = "\(key)"
                let headerValue = "\(value)"
                let redactedValue = configuration.redactedHeaders.contains(headerName) ? "<redacted>" : headerValue
                logger.debug("   \(headerName): \(redactedValue)")
            }
        }

        // Log body if enabled
        if configuration.logResponseBody {
            let bodySize = data.count
            if bodySize <= configuration.maxBodyLogSize {
                if let bodyString = String(data: data, encoding: .utf8) {
                    logger.debug("   Response: \(bodyString)")
                } else {
                    logger.debug("   Response: <binary \(bodySize) bytes>")
                }
            } else {
                logger.debug("   Response: <\(bodySize) bytes, truncated>")
            }
        }

        return data
    }
}

// MARK: - Timeout Interceptor

/// Overrides the timeout interval for all requests.
public struct TimeoutInterceptor: RequestInterceptor {
    private let timeoutInterval: TimeInterval

    /// Creates a timeout interceptor.
    /// - Parameter timeoutInterval: The timeout interval in seconds.
    public init(timeoutInterval: TimeInterval) {
        self.timeoutInterval = timeoutInterval
    }

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        modifiedRequest.timeoutInterval = timeoutInterval
        return modifiedRequest
    }
}

// MARK: - Retry Configuration

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

    public static let `default` = Self()
}
