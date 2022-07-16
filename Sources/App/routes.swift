import Fluent
import Vapor
import ClientRateLimiter

func routes(_ app: Application) throws {
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "y-MM-dd H:mm:ss.SSSS"
    
    app.get { req in
        return "It works!"
    }

    app.get("hello") { req async throws -> String in
        let response = try await req.clientRateLimiter.get("https://www.google.com")
        req.logger.info("Time: \(dateFormatter.string(from: Date())): \(response.status)")
        return "Hello, world!"
    }

    try app.register(collection: TodoController())
}
