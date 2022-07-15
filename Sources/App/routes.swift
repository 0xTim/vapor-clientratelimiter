import Fluent
import Vapor
import ClientRateLimiter

func routes(_ app: Application) throws {
    app.get { req in
        return "It works!"
    }

    app.get("hello") { req async throws -> String in
        let response = try await req.clientRateLimiter.get("https://www.google.com")
        req.logger.info("Time: \(Date()): \(response)")
        return "Hello, world!"
    }

    try app.register(collection: TodoController())
}
