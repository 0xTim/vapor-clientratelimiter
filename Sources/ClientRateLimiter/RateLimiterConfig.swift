struct RateLimiterConfig {
    let maxRequestsPerSecond: Double
    let timeout: Double
    
    var requestInterval: Double {
        1.0 / maxRequestsPerSecond
    }
}
