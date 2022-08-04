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
        let requestTime = Date()
        do {
            for x in 1...10 {
                _ = try await req.clientRateLimiter.get("https://www.google.com")
            }
        } catch {
            req.logger.info("Rate limiter error: \(error)")
            throw Abort(.internalServerError)
        }
        let clientRequestTime = Date()
        req.logger.info("Request processed. Request received at \(dateFormatter.string(from: requestTime)), sent to 3rd party API at \(dateFormatter.string(from: clientRequestTime))")
        return "Hello, world!"
    }

    try app.register(collection: TodoController())
}
