import Foundation

protocol HostCache {
    func makeRequest(to: String) async throws -> Double?
}

actor ActorHostCache: HostCache {
    let hosts: [String: Date] = [:]
    
    func makeRequest(to host: String) async throws -> Double? {
        if let lastHostTime = hosts[host] {
            return Date().distance(to: lastHostTime)
        } else {
            return nil
        }
    }
}
