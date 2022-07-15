import Fluent

public struct CreateRateLimitedRequest: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema("rate_limited_request")
            .id()
            .field("host", .string, .required)
            .field("requestedAt", .datetime, .required)
            .create()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema("rate_limited_request").delete()
    }
}
