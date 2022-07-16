import Fluent
import FluentPostgresDriver
import Vapor
import ClientRateLimiter

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    app.logger.logLevel = .debug

    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database"
    ), as: .psql)

    app.migrations.add(CreateHostRequestTime())
    app.migrations.add(CreateRateLimitedRequest())
    
    let clientRateLimiterConfig = RateLimiterConfig(maxRequestsPerSecond: 5, timeout: 30)
    app.clientRateLimiters.use {
        ClientRateLimiter(byteBufferAllocator: $0.allocator, logger: $0.logger, client: $0.client, db: $0.db, config: clientRateLimiterConfig)
    }

    // register routes
    try routes(app)
    
    try app.autoMigrate().wait()
}
