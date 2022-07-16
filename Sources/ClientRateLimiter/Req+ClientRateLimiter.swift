import Vapor

extension Request {
    public var clientRateLimiter: ClientRateLimiter {
        self.application.clientRateLimiter.for(req: self)
    }
}
