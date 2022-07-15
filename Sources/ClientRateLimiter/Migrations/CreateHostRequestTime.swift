import Fluent

public struct CreateHostRequestTime: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        try await database.schema("host_request_time")
            .id()
            .field("host", .string, .required)
            .field("lastRequestedAt", .datetime, .required)
            .create()
    }
    
    public func revert(on database: Database) async throws {
        try await database.schema("host_request_time").delete()
    }
}
