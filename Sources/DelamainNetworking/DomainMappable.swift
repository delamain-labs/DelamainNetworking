/// Protocol for DTOs that can be transformed to domain models.
///
/// Implement this on your API response types to enable automatic mapping
/// when using `NetworkClient.request(_:)` with domain model return types.
///
/// Example:
/// ```swift
/// struct UserDTO: Decodable, DomainMappable {
///     let user_id: String
///     let display_name: String?
///
///     func toDomain() -> User {
///         User(id: user_id, name: display_name ?? "Anonymous")
///     }
/// }
/// ```
public protocol DomainMappable {
    /// The domain model type this DTO maps to.
    associatedtype DomainModel

    /// Transforms this DTO into its corresponding domain model.
    /// - Returns: The mapped domain model.
    /// - Throws: Any errors that occur during mapping.
    func toDomain() throws -> DomainModel
}
