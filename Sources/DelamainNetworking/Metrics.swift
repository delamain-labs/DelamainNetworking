import Foundation

// MARK: - Network Metrics

/// Metrics collected for a single network request.
public struct RequestMetrics: Sendable {
    /// The endpoint that was requested.
    public let endpoint: String

    /// HTTP status code (nil if request failed before receiving response).
    public let statusCode: Int?

    /// Request duration in seconds.
    public let duration: TimeInterval

    /// Bytes sent (request body size).
    public let bytesSent: Int64

    /// Bytes received (response body size).
    public let bytesReceived: Int64

    /// Whether the request succeeded (2xx status code).
    public let isSuccess: Bool

    /// Timestamp when the request started.
    public let timestamp: Date

    public init(
        endpoint: String,
        statusCode: Int?,
        duration: TimeInterval,
        bytesSent: Int64,
        bytesReceived: Int64,
        isSuccess: Bool,
        timestamp: Date = Date()
    ) {
        self.endpoint = endpoint
        self.statusCode = statusCode
        self.duration = duration
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
        self.isSuccess = isSuccess
        self.timestamp = timestamp
    }
}

// MARK: - Metrics Collector Protocol

/// A protocol for collecting network request metrics.
public protocol MetricsCollector: Sendable {
    /// Records metrics for a completed request.
    func record(_ metrics: RequestMetrics) async
}

// MARK: - In-Memory Metrics Collector

/// Collects metrics in memory for analysis.
public actor InMemoryMetricsCollector: MetricsCollector {
    private var metrics: [RequestMetrics] = []

    public init() {}

    public func record(_ metrics: RequestMetrics) async {
        self.metrics.append(metrics)
    }

    /// Returns all collected metrics.
    public func getAllMetrics() -> [RequestMetrics] {
        metrics
    }

    /// Returns aggregated statistics.
    public func getStatistics() -> MetricsStatistics {
        let totalRequests = metrics.count
        let successfulRequests = metrics.filter { $0.isSuccess }.count
        let failedRequests = totalRequests - successfulRequests

        let totalDuration = metrics.reduce(0.0) { $0 + $1.duration }
        let averageDuration = totalRequests > 0 ? totalDuration / Double(totalRequests) : 0

        let totalBytesSent = metrics.reduce(0) { $0 + $1.bytesSent }
        let totalBytesReceived = metrics.reduce(0) { $0 + $1.bytesReceived }

        let successRate = totalRequests > 0 ? Double(successfulRequests) / Double(totalRequests) : 0

        return MetricsStatistics(
            totalRequests: totalRequests,
            successfulRequests: successfulRequests,
            failedRequests: failedRequests,
            successRate: successRate,
            averageDuration: averageDuration,
            totalBytesSent: totalBytesSent,
            totalBytesReceived: totalBytesReceived
        )
    }

    /// Clears all collected metrics.
    public func reset() {
        metrics.removeAll()
    }
}

// MARK: - Metrics Statistics

/// Aggregated statistics from collected metrics.
public struct MetricsStatistics: Sendable {
    /// Total number of requests recorded.
    public let totalRequests: Int

    /// Number of successful requests (2xx status).
    public let successfulRequests: Int

    /// Number of failed requests.
    public let failedRequests: Int

    /// Success rate (0.0 to 1.0).
    public let successRate: Double

    /// Average request duration in seconds.
    public let averageDuration: TimeInterval

    /// Total bytes sent across all requests.
    public let totalBytesSent: Int64

    /// Total bytes received across all requests.
    public let totalBytesReceived: Int64

    public init(
        totalRequests: Int,
        successfulRequests: Int,
        failedRequests: Int,
        successRate: Double,
        averageDuration: TimeInterval,
        totalBytesSent: Int64,
        totalBytesReceived: Int64
    ) {
        self.totalRequests = totalRequests
        self.successfulRequests = successfulRequests
        self.failedRequests = failedRequests
        self.successRate = successRate
        self.averageDuration = averageDuration
        self.totalBytesSent = totalBytesSent
        self.totalBytesReceived = totalBytesReceived
    }
}

// MARK: - Metrics Response Handler

/// Response handler that collects metrics for each request.
public struct MetricsResponseHandler: ResponseHandler {
    private let collector: any MetricsCollector
    private let startTime: Date
    private let endpoint: String
    private let bytesSent: Int64

    public init(
        collector: any MetricsCollector,
        startTime: Date,
        endpoint: String,
        bytesSent: Int64
    ) {
        self.collector = collector
        self.startTime = startTime
        self.endpoint = endpoint
        self.bytesSent = bytesSent
    }

    public func handle(_ data: Data, response: URLResponse) async throws -> Data {
        let duration = Date().timeIntervalSince(startTime)
        let bytesReceived = Int64(data.count)

        let statusCode: Int?
        let isSuccess: Bool

        if let httpResponse = response as? HTTPURLResponse {
            statusCode = httpResponse.statusCode
            isSuccess = (200...299).contains(httpResponse.statusCode)
        } else {
            statusCode = nil
            isSuccess = true  // Assume success if not HTTP
        }

        let metrics = RequestMetrics(
            endpoint: endpoint,
            statusCode: statusCode,
            duration: duration,
            bytesSent: bytesSent,
            bytesReceived: bytesReceived,
            isSuccess: isSuccess,
            timestamp: startTime
        )

        await collector.record(metrics)

        return data
    }
}
