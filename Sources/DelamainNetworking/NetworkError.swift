import Foundation

/// Errors that can occur during network operations.
public enum NetworkError: Error, Sendable {
    /// The URL could not be constructed from the endpoint.
    case invalidURL
    
    /// The request failed with an HTTP error status code.
    case httpError(statusCode: Int, data: Data?)
    
    /// The response could not be decoded into the expected type.
    case decodingError(Error)
    
    /// The request could not be encoded.
    case encodingError(Error)
    
    /// The network request failed.
    case networkError(Error)
    
    /// No data was returned when data was expected.
    case noData
    
    /// The request was cancelled.
    case cancelled
    
    /// A custom error with a message.
    case custom(String)
}

extension NetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .httpError(let statusCode, _):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .cancelled:
            return "Request cancelled"
        case .custom(let message):
            return message
        }
    }
}
