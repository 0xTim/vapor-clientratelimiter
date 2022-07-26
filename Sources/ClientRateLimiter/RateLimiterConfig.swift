public struct RateLimiterConfig {
    let defaulMaxRequestsPerSecond: Double
    let timeout: Double
    let siteRPS: [String: Double]
    
    func requestInterval(for hostname: String) -> Double {
        if let maxRequestsPerSecond = siteRPS[hostname] {
            return (1.0 / maxRequestsPerSecond)
        } else {
            return (1.0 / defaulMaxRequestsPerSecond)
        }
    }
    
    public init(maxRequestsPerSecond: Double, timeout: Double) {
        self.defaulMaxRequestsPerSecond = maxRequestsPerSecond
        self.timeout = timeout
        self.siteRPS = [:]
    }
    
    public init(defaultMaxRequestsPerSecond: Double, timeout: Double, siteSpecificRPS: [String: Double]) {
        self.defaulMaxRequestsPerSecond = defaultMaxRequestsPerSecond
        self.timeout = timeout
        self.siteRPS = siteSpecificRPS
    }
}
