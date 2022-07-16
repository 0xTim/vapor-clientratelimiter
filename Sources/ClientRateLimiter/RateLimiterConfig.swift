public struct RateLimiterConfig {
    let maxRequestsPerSecond: Double
    let timeout: Double
    
    var requestInterval: Double {
        1.0 / maxRequestsPerSecond
    }
    
    public init(maxRequestsPerSecond: Double, timeout: Double) {
        self.maxRequestsPerSecond = maxRequestsPerSecond
        self.timeout = timeout
    }
}
